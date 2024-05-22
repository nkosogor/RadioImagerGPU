#include "imaging.hpp"
#include <cufft.h>
#include <thrust/complex.h>
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <algorithm>
#include <vector>

// Helper function to replace std::clamp not available in C++11
template<typename T>
T clamp(T val, T minVal, T maxVal) {
    return std::max(minVal, std::min(val, maxVal));
}

// Function to perform circular shift
template<typename T>
void circular_shift(std::vector<T>& data, int image_size) {
    int shift = image_size / 2;
    for (int i = 0; i < shift; ++i) {
        for (int j = 0; j < image_size; ++j) {
            std::swap(data[j * image_size + i], data[j * image_size + (i + shift)]);
        }
    }
    for (int i = 0; i < image_size; ++i) {
        for (int j = 0; j < shift; ++j) {
            std::swap(data[j + i * image_size], data[(j + shift) + i * image_size]);
        }
    }
}


void uniformImage(const std::vector<std::complex<double>>& visibilities,
                  const std::vector<double>& u, const std::vector<double>& v,
                  int image_size, std::vector<double>& image) {
    // Calculate pixel resolution and grid parameters
    double max_uv = *std::max_element(u.begin(), u.end());
    double pixel_resolution = (0.20 / max_uv) / 3;
    double uv_resolution = 1 / (image_size * pixel_resolution);
    double uv_max = uv_resolution * image_size / 2;
    double grid_res = 2 * uv_max / image_size;

    // Create visibility grid on host using CUDA compatible types
    std::vector<cufftDoubleComplex> h_visibility_grid(image_size * image_size, make_cuDoubleComplex(0, 0));

    // Map visibilities to grid
    for (size_t i = 0; i < visibilities.size(); ++i) {
        int i_index = clamp(static_cast<int>((u[i] + uv_max) / grid_res), 0, image_size - 1);
        int j_index = clamp(static_cast<int>((v[i] + uv_max) / grid_res), 0, image_size - 1);
        int index = i_index * image_size + j_index;
        h_visibility_grid[index].x += visibilities[i].real();
        h_visibility_grid[index].y += visibilities[i].imag();
    }

    // Shift the grid to center the zero-frequency component

    circular_shift(h_visibility_grid, image_size);

    // Transfer data to device
    thrust::device_vector<cufftDoubleComplex> d_visibility_grid = h_visibility_grid;

    // Prepare and execute FFT
    cufftHandle plan;
    cufftResult result = cufftPlan2d(&plan, image_size, image_size, CUFFT_Z2Z);
    if (result != CUFFT_SUCCESS) {
        std::cerr << "CUFFT error: Plan creation failed, error code " << result << std::endl;
        return;
    }

    result = cufftExecZ2Z(plan, thrust::raw_pointer_cast(d_visibility_grid.data()), thrust::raw_pointer_cast(d_visibility_grid.data()), CUFFT_INVERSE);
    if (result != CUFFT_SUCCESS) {
        std::cerr << "CUFFT error: Executing FFT failed, error code " << result << std::endl;
        cufftDestroy(plan);
        return;
    }

    cufftDestroy(plan);

    // Transfer the data back to host
    thrust::host_vector<cufftDoubleComplex> h_output_grid = d_visibility_grid;

    circular_shift(h_output_grid, image_size);  // Shift back if necessary

    // Normalize the FFT output
    double scale = 1.0 / (image_size * image_size);
    image.resize(image_size * image_size);
    for (size_t i = 0; i < image.size(); ++i) {
        image[i] = h_output_grid[i].x * scale; // Real part of the complex number
    }
}


