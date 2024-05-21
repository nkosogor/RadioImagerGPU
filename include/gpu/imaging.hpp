#ifndef IMAGING_HPP
#define IMAGING_HPP

#include <cufft.h>
#include <thrust/complex.h>
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <cmath>
#include <algorithm>
#include <vector>

// Configuration and utility functions
namespace config {
    const int IMAGE_SIZE = 256;  // Image size in pixels
}

void uniformImage(const std::vector<std::complex<double>>& visibilities,
                  const std::vector<double>& u, const std::vector<double>& v,
                  int image_size, std::vector<double>& image);

__global__ void mapVisibilities(cufftDoubleComplex* grid, const cufftDoubleComplex* visibilities, const double* u, const double* v, double uv_max, double grid_res, int image_size, int num_visibilities);

void fftshift(thrust::device_vector<cufftDoubleComplex>& data, int width, int height);


#endif
