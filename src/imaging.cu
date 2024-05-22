#include "imaging.hpp"
#include <cufft.h>
#include <thrust/complex.h>
#include <thrust/device_vector.h>
#include <vector>
#include <algorithm>
#include <iostream>
#include <cuda_runtime.h>

void checkCudaError(cudaError_t err, const char* msg) {
    if (err != cudaSuccess) {
        std::cerr << msg << " Error: " << cudaGetErrorString(err) << "\n";
        exit(EXIT_FAILURE);
    }
}

#define CHECK_CUDA(call) { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        std::cerr << "CUDA Error: " << cudaGetErrorString(err) << " at " << __FILE__ << ":" << __LINE__ << std::endl; \
        exit(EXIT_FAILURE); \
    } \
}

// This atomicAdd is required if your GPU compute capability is less than 6.0
#if !defined(__CUDA_ARCH__) || __CUDA_ARCH__ >= 600
#else
__device__ double atomicAdd(double* address, double val) {
    unsigned long long int* address_as_ull = (unsigned long long int*)address;
    unsigned long long int old = *address_as_ull, assumed;
    do {
        assumed = old;
        old = atomicCAS(address_as_ull, assumed, __double_as_longlong(val + __longlong_as_double(assumed)));
    } while (assumed != old);
    return __longlong_as_double(old);
}
#endif

__global__ void mapVisibilities(cufftDoubleComplex* grid, const cufftDoubleComplex* visibilities, const double* u, const double* v, double uv_max, double grid_res, int image_size, int num_visibilities) {
    extern __shared__ double shared_mem[];
    double* shared_u = shared_mem;
    double* shared_v = shared_u + blockDim.x;
    cufftDoubleComplex* shared_vis = (cufftDoubleComplex*)(shared_v + blockDim.x);

    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < num_visibilities) {
        shared_u[threadIdx.x] = u[idx];
        shared_v[threadIdx.x] = v[idx];
        shared_vis[threadIdx.x] = visibilities[idx];
    }
    __syncthreads();

    if (idx < num_visibilities) {
        int i_index = static_cast<int>((shared_u[threadIdx.x] + uv_max) / grid_res);
        int j_index = static_cast<int>((shared_v[threadIdx.x] + uv_max) / grid_res);
        i_index = (i_index + image_size) % image_size;
        j_index = (j_index + image_size) % image_size;

        if (i_index < image_size && j_index < image_size) {
            atomicAdd(&grid[i_index * image_size + j_index].x, shared_vis[threadIdx.x].x);
            atomicAdd(&grid[i_index * image_size + j_index].y, shared_vis[threadIdx.x].y);
        }
    }
}


__global__ void fftshift_kernel(cufftDoubleComplex* data, cufftDoubleComplex* temp, int width, int height, int shiftX, int shiftY) {
    extern __shared__ cufftDoubleComplex shared_data[];
    
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int tid = threadIdx.y * blockDim.x + threadIdx.x;

    if (x < width && y < height) {
        shared_data[tid] = data[y * width + x];
    }
    __syncthreads();

    if (x < width && y < height) {
        int new_i = (y + shiftY) % height;
        int new_j = (x + shiftX) % width;
        temp[new_i * width + new_j] = shared_data[tid];
    }
}


void fftshift(thrust::device_vector<cufftDoubleComplex>& data, int width, int height) {
    thrust::device_vector<cufftDoubleComplex> temp(data.size());

    dim3 threadsPerBlock(16, 16);
    dim3 blocksPerGrid((width + threadsPerBlock.x - 1) / threadsPerBlock.x,
                       (height + threadsPerBlock.y - 1) / threadsPerBlock.y);

    int shiftX = width / 2;
    int shiftY = height / 2;
    size_t sharedMemSize = threadsPerBlock.x * threadsPerBlock.y * sizeof(cufftDoubleComplex);

    cudaStream_t stream;
    cudaStreamCreate(&stream);

    fftshift_kernel<<<blocksPerGrid, threadsPerBlock, sharedMemSize, stream>>>(thrust::raw_pointer_cast(data.data()),
                                                        thrust::raw_pointer_cast(temp.data()),
                                                        width, height, shiftX, shiftY);

    cudaStreamSynchronize(stream);
    cudaStreamDestroy(stream);
    data = temp;
}



void uniformImage(const std::vector<std::complex<double>>& visibilities,
                  const std::vector<double>& u, const std::vector<double>& v,
                  int image_size, std::vector<double>& image) {
    double max_uv = *std::max_element(u.begin(), u.end());
    double pixel_resolution = (0.20 / max_uv) / 3;
    double uv_resolution = 1 / (image_size * pixel_resolution);
    double uv_max = uv_resolution * image_size / 2;
    double grid_res = 2 * uv_max / image_size;

    std::vector<cufftDoubleComplex> host_visibility_grid(image_size * image_size, make_cuDoubleComplex(0.0, 0.0));

    thrust::device_vector<cufftDoubleComplex> d_visibility_grid(image_size * image_size, make_cuDoubleComplex(0.0, 0.0));
    thrust::device_vector<double> d_u = u;
    thrust::device_vector<double> d_v = v;

    int threadsPerBlock = 256;
    size_t sharedMemSize = threadsPerBlock * (sizeof(double) * 2 + sizeof(cufftDoubleComplex));
    size_t chunk_size = image_size * image_size;
    size_t num_chunks = (visibilities.size() + chunk_size - 1) / chunk_size;

    cudaStream_t stream1, stream2;
    cudaStreamCreate(&stream1);
    cudaStreamCreate(&stream2);

    for (size_t chunk = 0; chunk < num_chunks; ++chunk) {
        size_t start = chunk * chunk_size;
        size_t end = std::min(start + chunk_size, visibilities.size());

        std::vector<cufftDoubleComplex> vis_chunk_cufft;
        for (size_t i = start; i < end; ++i) {
            vis_chunk_cufft.push_back(make_cuDoubleComplex(visibilities[i].real(), visibilities[i].imag()));
        }

        thrust::device_vector<cufftDoubleComplex> d_vis_chunk = vis_chunk_cufft;

        int blocksPerGrid = (vis_chunk_cufft.size() + threadsPerBlock - 1) / threadsPerBlock;
        mapVisibilities<<<blocksPerGrid, threadsPerBlock, sharedMemSize, stream1>>>(thrust::raw_pointer_cast(d_visibility_grid.data()),
                                                            thrust::raw_pointer_cast(d_vis_chunk.data()),
                                                            thrust::raw_pointer_cast(d_u.data()) + start,
                                                            thrust::raw_pointer_cast(d_v.data()) + start,
                                                            uv_max, grid_res, image_size, vis_chunk_cufft.size());
        CHECK_CUDA(cudaGetLastError());
        CHECK_CUDA(cudaStreamSynchronize(stream1));
    }

    fftshift(d_visibility_grid, image_size, image_size);

    cufftHandle plan;
    cufftPlan2d(&plan, image_size, image_size, CUFFT_Z2Z);
    cufftSetStream(plan, stream2);
    cufftExecZ2Z(plan, thrust::raw_pointer_cast(d_visibility_grid.data()), thrust::raw_pointer_cast(d_visibility_grid.data()), CUFFT_INVERSE);
    cufftDestroy(plan);

    fftshift(d_visibility_grid, image_size, image_size);

    thrust::host_vector<cufftDoubleComplex> h_output_grid = d_visibility_grid;

    double max_value = 0.0;
    for (size_t i = 0; i < h_output_grid.size(); ++i) {
        if (abs(h_output_grid[i].x) > max_value) {
            max_value = abs(h_output_grid[i].x);
        }
    }

    image.resize(image_size * image_size);
    for (size_t i = 0; i < image.size(); ++i) {
        image[i] = h_output_grid[i].x / max_value;
    }

    cudaStreamDestroy(stream1);
    cudaStreamDestroy(stream2);
}