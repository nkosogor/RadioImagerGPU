#include "config.hpp"
#include "compute.hpp"
#include <cufft.h>
#include <thrust/complex.h>
#include <thrust/device_vector.h>
#include <vector>
#include <algorithm>
#include <iostream>
#include <cuda_runtime.h>

/**
 * @brief Check CUDA error and print a message if an error occurs.
 * 
 * @param err CUDA error code.
 * @param msg Error message to display if an error occurs.
 */
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



/**
 * @brief Perform a 2D FFT shift operation on the given data.
 * 
 * @param data Input data to be shifted.
 * @param temp Temporary data storage for shifting.
 * @param width Width of the data array.
 * @param height Height of the data array.
 * @param shiftX Amount to shift in the X direction.
 * @param shiftY Amount to shift in the Y direction.
 */
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

/**
 * @brief Perform a 2D FFT shift on a thrust::device_vector.
 * 
 * @param data Data to be shifted.
 * @param width Width of the data array.
 * @param height Height of the data array.
 */
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


/**
 * @brief Map visibilities to a grid for multiple directions (batches).
 * 
 * @param grid Output grid to store the mapped visibilities.
 * @param visibilities Input visibilities to map.
 * @param u U coordinates of visibilities.
 * @param v V coordinates of visibilities.
 * @param uv_max Maximum UV coordinate value.
 * @param grid_res Resolution of the grid.
 * @param image_size Size of the output image.
 * @param num_visibilities Number of visibilities.
 * @param num_directions Number of directions.
 */
__global__ void mapVisibilitiesMultiDir(cufftDoubleComplex* grid, const cufftDoubleComplex* visibilities, const double* u, const double* v, double uv_max, double grid_res, int image_size, int num_visibilities, int num_directions) {
    extern __shared__ double shared_mem[];
    double* shared_u = shared_mem;
    double* shared_v = shared_u + blockDim.x;
    cufftDoubleComplex* shared_vis = (cufftDoubleComplex*)(shared_v + blockDim.x);

    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int dir_idx = blockIdx.y;

    if (dir_idx >= num_directions) return;

    if (idx < num_visibilities) {
        shared_u[threadIdx.x] = u[dir_idx * num_visibilities + idx];
        shared_v[threadIdx.x] = v[dir_idx * num_visibilities + idx];
        shared_vis[threadIdx.x] = visibilities[dir_idx * num_visibilities + idx];
    }
    __syncthreads();

    if (idx < num_visibilities) {
        // Skip adding visibility if both u and v are zero
        if (shared_u[threadIdx.x] == 0.0 && shared_v[threadIdx.x] == 0.0) {
            return;
        }

        int i_index = static_cast<int>((shared_u[threadIdx.x] + uv_max) / grid_res);
        int j_index = static_cast<int>((shared_v[threadIdx.x] + uv_max) / grid_res);
        i_index = (i_index + image_size) % image_size;
        j_index = (j_index + image_size) % image_size;

        if (i_index < image_size && j_index < image_size) {
            atomicAdd(&grid[dir_idx * image_size * image_size + i_index * image_size + j_index].x, shared_vis[threadIdx.x].x);
            atomicAdd(&grid[dir_idx * image_size * image_size + i_index * image_size + j_index].y, shared_vis[threadIdx.x].y);
        }
    }
}

/**
 * @brief Generate a uniform image from visibilities using FFT.
 * 
 * @param visibilities_batch Batch of visibilities for multiple directions.
 * @param u_batch U coordinates for multiple directions.
 * @param v_batch V coordinates for multiple directions.
 * @param image_size Size of the output image.
 * @param images Output images.
 */
void uniformImage(const std::vector<std::vector<std::complex<double>>>& visibilities_batch,
                  const std::vector<std::vector<double>>& u_batch, const std::vector<std::vector<double>>& v_batch,
                  int image_size, std::vector<std::vector<double>>& images, bool use_predefined_params) {
    int num_batches = visibilities_batch.size();
    images.resize(num_batches);

    thrust::device_vector<cufftDoubleComplex> d_visibility_grid(num_batches * image_size * image_size, make_cuDoubleComplex(0.0, 0.0));
    thrust::device_vector<double> d_u(num_batches * u_batch[0].size());
    thrust::device_vector<double> d_v(num_batches * v_batch[0].size());

    for (int b = 0; b < num_batches; ++b) {
        thrust::copy(u_batch[b].begin(), u_batch[b].end(), d_u.begin() + b * u_batch[0].size());
        thrust::copy(v_batch[b].begin(), v_batch[b].end(), d_v.begin() + b * v_batch[0].size());
    }

    double max_uv = use_predefined_params ? config::PREDEFINED_MAX_UV : *std::max_element(u_batch[0].begin(), u_batch[0].end());
    double pixel_resolution = (0.20 / max_uv) / 3;
    double uv_resolution = 1 / (image_size * pixel_resolution);
    double uv_max = uv_resolution * image_size / 2;
    double grid_res = 2 * uv_max / image_size;

    int threadsPerBlock = 256;
    size_t sharedMemSize = threadsPerBlock * (sizeof(double) * 2 + sizeof(cufftDoubleComplex));
    size_t chunk_size = image_size * image_size;
    size_t num_chunks = (visibilities_batch[0].size() + chunk_size - 1) / chunk_size;

    cudaStream_t stream1, stream2;
    cudaStreamCreate(&stream1);
    cudaStreamCreate(&stream2);

    for (size_t chunk = 0; chunk < num_chunks; ++chunk) {
        size_t start = chunk * chunk_size;
        size_t end = std::min(start + chunk_size, visibilities_batch[0].size());

        std::vector<cufftDoubleComplex> vis_chunk_cufft;
        for (int b = 0; b < num_batches; ++b) {
            for (size_t i = start; i < end; ++i) {
                vis_chunk_cufft.push_back(make_cuDoubleComplex(visibilities_batch[b][i].real(), visibilities_batch[b][i].imag()));
            }
        }

        thrust::device_vector<cufftDoubleComplex> d_vis_chunk = vis_chunk_cufft;

        dim3 blocksPerGrid((end - start + threadsPerBlock - 1) / threadsPerBlock, num_batches);
        mapVisibilitiesMultiDir<<<blocksPerGrid, threadsPerBlock, sharedMemSize, stream1>>>(thrust::raw_pointer_cast(d_visibility_grid.data()),
                                                                                            thrust::raw_pointer_cast(d_vis_chunk.data()),
                                                                                            thrust::raw_pointer_cast(d_u.data()),
                                                                                            thrust::raw_pointer_cast(d_v.data()),
                                                                                            uv_max, grid_res, image_size, end - start, num_batches);
        CHECK_CUDA(cudaGetLastError());
        CHECK_CUDA(cudaStreamSynchronize(stream1));
    }

    for (int b = 0; b < num_batches; ++b) {
        thrust::device_vector<cufftDoubleComplex> d_visibility_grid_batch(d_visibility_grid.begin() + b * image_size * image_size, d_visibility_grid.begin() + (b + 1) * image_size * image_size);

        fftshift(d_visibility_grid_batch, image_size, image_size);

        cufftHandle plan;
        cufftPlan2d(&plan, image_size, image_size, CUFFT_Z2Z);
        cufftSetStream(plan, stream2);
        cufftExecZ2Z(plan, thrust::raw_pointer_cast(d_visibility_grid_batch.data()), thrust::raw_pointer_cast(d_visibility_grid_batch.data()), CUFFT_INVERSE);
        cufftDestroy(plan);

        fftshift(d_visibility_grid_batch, image_size, image_size);

        thrust::host_vector<cufftDoubleComplex> h_output_grid = d_visibility_grid_batch;

        double max_value = 0.0;
        for (size_t i = 0; i < h_output_grid.size(); ++i) {
            if (abs(h_output_grid[i].x) > max_value) {
                max_value = abs(h_output_grid[i].x);
            }
        }

        images[b].resize(image_size * image_size);
        for (size_t i = 0; i < images[b].size(); ++i) {
            images[b][i] = h_output_grid[i].x / max_value;
        }
    }

    cudaStreamDestroy(stream1);
    cudaStreamDestroy(stream2);
}

/**
 * @brief CUDA kernel to compute UVW coordinates from XYZ coordinates for multiple directions.
 * 
 * @param x_m X coordinates of the antennas.
 * @param y_m Y coordinates of the antennas.
 * @param z_m Z coordinates of the antennas.
 * @param HAs Hour angles for multiple directions.
 * @param Decs Declinations for multiple directions.
 * @param u Output U coordinates.
 * @param v Output V coordinates.
 * @param w Output W coordinates.
 * @param N Number of antennas.
 * @param num_directions Number of directions.
 */
__global__ void computeUVWKernel(const double* x_m, const double* y_m, const double* z_m, 
                                 const double* HAs, const double* Decs, 
                                 double* u, double* v, double* w, int N, int num_directions) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int dir_idx = blockIdx.y;

    if (dir_idx >= num_directions || idx >= N * (N - 1) / 2) return;

    double HA = HAs[dir_idx];
    double Dec = Decs[dir_idx];

    // Calculate the baseline indices
    int i = static_cast<int>(sqrt(2 * idx + 0.25) - 0.5);
    int j = idx - i * (i + 1) / 2;

    if (i < N && j < N) {
        double dx = x_m[j] - x_m[i];
        double dy = y_m[j] - y_m[i];
        double dz = z_m[j] - z_m[i];

        double u_ij = dx * sin(HA) + dy * cos(HA);
        double v_ij = -dx * sin(Dec) * cos(HA) + dy * sin(Dec) * sin(HA) + dz * cos(Dec);
        double w_ij = dx * cos(Dec) * cos(HA) - dy * cos(Dec) * sin(HA) + dz * sin(Dec);

        int index = dir_idx * N * (N - 1) / 2 + idx;
        u[index] = u_ij;
        v[index] = v_ij;
        w[index] = w_ij;
    }
}

/**
 * @brief Compute UVW coordinates from XYZ coordinates for multiple directions.
 * 
 * @param x_m X coordinates of the antennas.
 * @param y_m Y coordinates of the antennas.
 * @param z_m Z coordinates of the antennas.
 * @param HAs Hour angles for multiple directions.
 * @param Decs Declinations for multiple directions.
 * @param u Output U coordinates for multiple directions.
 * @param v Output V coordinates for multiple directions.
 * @param w Output W coordinates for multiple directions.
* @param use_predefined_params Flag to determine if predefined parameters should be used.
 */
void computeUVW(const std::vector<double>& x_m, const std::vector<double>& y_m, const std::vector<double>& z_m, 
                const std::vector<double>& HAs, const std::vector<double>& Decs, 
                std::vector<std::vector<double>>& u, std::vector<std::vector<double>>& v, std::vector<std::vector<double>>& w) {
    int N = x_m.size();
    int num_directions = HAs.size();
    int num_baselines = N * (N - 1) / 2;

    // Resize output vectors
    u.resize(num_directions, std::vector<double>(num_baselines));
    v.resize(num_directions, std::vector<double>(num_baselines));
    w.resize(num_directions, std::vector<double>(num_baselines));

    thrust::device_vector<double> d_x_m = x_m;
    thrust::device_vector<double> d_y_m = y_m;
    thrust::device_vector<double> d_z_m = z_m;
    thrust::device_vector<double> d_HAs = HAs;
    thrust::device_vector<double> d_Decs = Decs;
    thrust::device_vector<double> d_u(num_directions * num_baselines);
    thrust::device_vector<double> d_v(num_directions * num_baselines);
    thrust::device_vector<double> d_w(num_directions * num_baselines);

    int threadsPerBlock = 256;
    dim3 blocksPerGrid((num_baselines + threadsPerBlock - 1) / threadsPerBlock, num_directions);

    computeUVWKernel<<<blocksPerGrid, threadsPerBlock>>>(thrust::raw_pointer_cast(d_x_m.data()), 
                                                         thrust::raw_pointer_cast(d_y_m.data()), 
                                                         thrust::raw_pointer_cast(d_z_m.data()), 
                                                         thrust::raw_pointer_cast(d_HAs.data()), 
                                                         thrust::raw_pointer_cast(d_Decs.data()), 
                                                         thrust::raw_pointer_cast(d_u.data()), 
                                                         thrust::raw_pointer_cast(d_v.data()), 
                                                         thrust::raw_pointer_cast(d_w.data()), N, num_directions);

    cudaDeviceSynchronize();

    for (int d = 0; d < num_directions; ++d) {
        thrust::copy(d_u.begin() + d * num_baselines, d_u.begin() + (d + 1) * num_baselines, u[d].begin());
        thrust::copy(d_v.begin() + d * num_baselines, d_v.begin() + (d + 1) * num_baselines, v[d].begin());
        thrust::copy(d_w.begin() + d * num_baselines, d_w.begin() + (d + 1) * num_baselines, w[d].begin());
    }
}