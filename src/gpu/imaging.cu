#include "imaging.hpp"
#include <cufft.h>
#include <thrust/complex.h>
#include <thrust/device_vector.h>
#include <vector>
#include <algorithm>
#include <iostream> 

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
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < num_visibilities) {
        int i_index = static_cast<int>((u[idx] + uv_max) / grid_res);
        int j_index = static_cast<int>((v[idx] + uv_max) / grid_res);
        i_index = (i_index + image_size) % image_size;
        j_index = (j_index + image_size) % image_size;

        atomicAdd(&grid[i_index * image_size + j_index].x, visibilities[idx].x);
        atomicAdd(&grid[i_index * image_size + j_index].y, visibilities[idx].y);
    }
}

__global__ void fftshift_kernel(cufftDoubleComplex* data, cufftDoubleComplex* temp, int width, int height, int shiftX, int shiftY) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x < width && y < height) {
        int new_i = (y + shiftY) % height;
        int new_j = (x + shiftX) % width;
        temp[new_i * width + new_j] = data[y * width + x];
    }
}

void fftshift(thrust::device_vector<cufftDoubleComplex>& data, int width, int height) {
    thrust::device_vector<cufftDoubleComplex> temp(data.size());

    dim3 threadsPerBlock(16, 16);
    dim3 blocksPerGrid((width + threadsPerBlock.x - 1) / threadsPerBlock.x,
                       (height + threadsPerBlock.y - 1) / threadsPerBlock.y);

    int shiftX = width / 2;
    int shiftY = height / 2;

    fftshift_kernel<<<blocksPerGrid, threadsPerBlock>>>(thrust::raw_pointer_cast(data.data()),
                                                        thrust::raw_pointer_cast(temp.data()),
                                                        width, height, shiftX, shiftY);

    cudaDeviceSynchronize();
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

    // Print the calculated parameters
    std::cout << "max_uv: " << max_uv << "\n";
    std::cout << "pixel_resolution: " << pixel_resolution << "\n";
    std::cout << "uv_resolution: " << uv_resolution << "\n";
    std::cout << "uv_max: " << uv_max << "\n";
    std::cout << "grid_res: " << grid_res << "\n";

    std::vector<cufftDoubleComplex> host_visibility_grid(image_size * image_size, make_cuDoubleComplex(0.0, 0.0));

    // Initialize the visibilities
    for (int i = 0; i < visibilities.size(); ++i) {
        host_visibility_grid[i] = make_cuDoubleComplex(visibilities[i].real(), visibilities[i].imag());
    }

    thrust::device_vector<cufftDoubleComplex> d_visibility_grid = host_visibility_grid;
    thrust::device_vector<double> d_u = u;
    thrust::device_vector<double> d_v = v;

    int threadsPerBlock = 256;
    int blocksPerGrid = (visibilities.size() + threadsPerBlock - 1) / threadsPerBlock;
    mapVisibilities<<<blocksPerGrid, threadsPerBlock>>>(thrust::raw_pointer_cast(d_visibility_grid.data()),
                                                        thrust::raw_pointer_cast(d_visibility_grid.data()),
                                                        thrust::raw_pointer_cast(d_u.data()), 
                                                        thrust::raw_pointer_cast(d_v.data()),
                                                        uv_max, grid_res, image_size, visibilities.size());

    cudaDeviceSynchronize();

    // Print central part of visibility grid after mapping
    thrust::host_vector<cufftDoubleComplex> h_visibility_grid = d_visibility_grid;
    std::cout << "Visibility grid after mapping (central part):\n";
    int center = image_size / 2;
    for (int i = center - 2; i <= center + 2; ++i) {
        for (int j = center - 2; j <= center + 2; ++j) {
            int index = i * image_size + j;
            std::cout << "(" << h_visibility_grid[index].x << ", " << h_visibility_grid[index].y << ") ";
        }
        std::cout << "\n";
    }

    // Apply circular shift before FFT
    fftshift(d_visibility_grid, image_size, image_size);

    // Print central part of visibility grid after first shift
    h_visibility_grid = d_visibility_grid;
    std::cout << "Visibility grid after first FFT shift (central part):\n";
    for (int i = center - 2; i <= center + 2; ++i) {
        for (int j = center - 2; j <= center + 2; ++j) {
            int index = i * image_size + j;
            std::cout << "(" << h_visibility_grid[index].x << ", " << h_visibility_grid[index].y << ") ";
        }
        std::cout << "\n";
    }

    cufftHandle plan;
    cufftPlan2d(&plan, image_size, image_size, CUFFT_Z2Z);
    cufftExecZ2Z(plan, thrust::raw_pointer_cast(d_visibility_grid.data()), thrust::raw_pointer_cast(d_visibility_grid.data()), CUFFT_INVERSE);
    cufftDestroy(plan);

    // Apply circular shift after FFT
    fftshift(d_visibility_grid, image_size, image_size);

    // Print central part of visibility grid after FFT
    h_visibility_grid = d_visibility_grid;
    std::cout << "Visibility grid after FFT (central part):\n";
    for (int i = center - 2; i <= center + 2; ++i) {
        for (int j = center - 2; j <= center + 2; ++j) {
            int index = i * image_size + j;
            std::cout << "(" << h_visibility_grid[index].x << ", " << h_visibility_grid[index].y << ") ";
        }
        std::cout << "\n";
    }

    thrust::host_vector<cufftDoubleComplex> h_output_grid = d_visibility_grid;

    // Normalize by the maximum value in the grid
    double max_value = 0.0;
    for (size_t i = 0; i < h_output_grid.size(); ++i) {
        if (abs(h_output_grid[i].x) > max_value) {
            max_value = abs(h_output_grid[i].x);
        }
    }

    image.resize(image_size * image_size);
    for (size_t i = 0; i < image.size(); ++i) {
        image[i] = h_output_grid[i].x / max_value; // Real part of the complex number normalized
    }
    
    /*double scale = 1.0 / (image_size * image_size);  // Ensure the normalization matches the CPU implementation
    image.resize(image_size * image_size);
    for (size_t i = 0; i < image.size(); ++i) {
        image[i] = h_output_grid[i].x * scale; // Real part of the complex number
    }*/
}
