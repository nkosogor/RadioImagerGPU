#include "imaging.hpp"
#include <complex>
#include <vector>
#include <cmath>
#include <algorithm>

const double PI = 3.141592653589793238462643383279502884;

void fft(std::vector<std::complex<double>>& x, bool inverse = false) {
    int N = x.size();
    // Bit reversal permutation
    int j = 0;
    for (int i = 0; i < N; ++i) {
        if (i < j) {
            std::swap(x[i], x[j]);
        }
        int m = N >> 1;
        while (m >= 1 && j >= m) {
            j -= m;
            m >>= 1;
        }
        j += m;
    }

    // Cooley-Tukey
    for (int len = 2; len <= N; len <<= 1) {
        double angle = 2 * PI / len * (inverse ? -1 : 1);
        std::complex<double> wlen(cos(angle), sin(angle));
        for (int i = 0; i < N; i += len) {
            std::complex<double> w(1);
            for (int j = 0; j < len / 2; ++j) {
                std::complex<double> u = x[i + j];
                std::complex<double> v = x[i + j + len / 2] * w;
                x[i + j] = u + v;
                x[i + j + len / 2] = u - v;
                w *= wlen;
            }
        }
    }

    // If inverse FFT, divide by N
    if (inverse) {
        for (auto& num : x) {
            num /= N;
        }
    }
}

template<typename T>
void fftshift(std::vector<T>& data, int rows, int cols) {
    int N = rows * cols;
    std::vector<T> temp(N);

    int halfRow = rows / 2;
    int halfCol = cols / 2;

    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            int srcIdx = i * cols + j;
            int destI = (i + halfRow) % rows;
            int destJ = (j + halfCol) % cols;
            int destIdx = destI * cols + destJ;
            temp[destIdx] = data[srcIdx];
        }
    }
    data.swap(temp); // Now data contains the shifted values
}

// Helper function to replace std::clamp not available in C++11
template<typename T>
T clamp(T val, T minVal, T maxVal) {
    return std::max(minVal, std::min(val, maxVal));
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

    // Create visibility grid on host
    std::vector<std::complex<double>> visibility_grid(image_size * image_size);

    // Map visibilities to grid
    for (size_t i = 0; i < visibilities.size(); ++i) {
        int i_index = clamp(static_cast<int>((u[i] + uv_max) / grid_res), 0, image_size - 1);
        int j_index = clamp(static_cast<int>((v[i] + uv_max) / grid_res), 0, image_size - 1);
        int index = i_index * image_size + j_index;

        visibility_grid[index] += visibilities[i];
    }

    fftshift(visibility_grid, image_size, image_size);
    // Perform the FFT on the CPU using the custom FFT function
    fft(visibility_grid);

    fftshift(visibility_grid, image_size, image_size);

    // Extract real part of the image
    image.resize(image_size * image_size);
    double normalization_factor = 1.0;
    for (size_t i = 0; i < image.size(); ++i) {
        image[i] = visibility_grid[i].real() * normalization_factor;  // Normalize the output
    }
}


void computeUVW(const std::vector<double>& x_m, const std::vector<double>& y_m, const std::vector<double>& z_m, 
                double HA, double Dec, std::vector<double>& u, std::vector<double>& v, std::vector<double>& w) {
    int N = x_m.size();
    for (int i = 0; i < N; ++i) {
        for (int j = i + 1; j < N; ++j) {
            double dx = x_m[j] - x_m[i];
            double dy = y_m[j] - y_m[i];
            double dz = z_m[j] - z_m[i];

            double u_ij = dx * sin(HA) + dy * cos(HA);
            double v_ij = -dx * sin(Dec) * cos(HA) + dy * sin(Dec) * sin(HA) + dz * cos(Dec);
            double w_ij = dx * cos(Dec) * cos(HA) - dy * cos(Dec) * sin(HA) + dz * sin(Dec);

            u.push_back(u_ij);
            v.push_back(v_ij);
            w.push_back(w_ij);

            // Add conjugate points
            u.push_back(-u_ij);
            v.push_back(-v_ij);
            w.push_back(-w_ij);
        }
    }
}