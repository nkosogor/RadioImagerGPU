// include/compute.hpp
#ifndef COMPUTE_HPP
#define COMPUTE_HPP

#include <cufft.h>
#include <thrust/complex.h>
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <cmath>
#include <algorithm>
#include <vector>

// Function declarations
void uniformImage(const std::vector<std::vector<std::complex<double>>>& visibilities_batch,
                  const std::vector<std::vector<double>>& u_batch, const std::vector<std::vector<double>>& v_batch,
                  int image_size, std::vector<std::vector<double>>& images, bool use_predefined_params);

__global__ void mapVisibilitiesMultiDir(cufftDoubleComplex* grid, const cufftDoubleComplex* visibilities, const double* u, const double* v, double uv_max, double grid_res, int image_size, int num_visibilities, int num_directions);

void fftshift(thrust::device_vector<cufftDoubleComplex>& data, int width, int height);

void computeUVW(const std::vector<double>& x_m, const std::vector<double>& y_m, const std::vector<double>& z_m, 
                const std::vector<double>& HAs, const std::vector<double>& Decs, 
                std::vector<std::vector<double>>& u, std::vector<std::vector<double>>& v, std::vector<std::vector<double>>& w);

#endif
