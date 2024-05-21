#ifndef IMAGING_HPP
#define IMAGING_HPP

#include <vector>
#include <complex>

namespace config {
    const int IMAGE_SIZE = 512; // Default image size, adjust as necessary
}

// Declare the uniformImage function that processes the imaging
void uniformImage(const std::vector<std::complex<double>>& visibilities,
                  const std::vector<double>& u, const std::vector<double>& v,
                  int image_size, std::vector<double>& image);

// Declare function for computing UVW coordinates
void computeUVW(const std::vector<double>& x_m, const std::vector<double>& y_m, const std::vector<double>& z_m, 
                double HA, double Dec, std::vector<double>& u, std::vector<double>& v, std::vector<double>& w);

#endif // IMAGING_HPP
