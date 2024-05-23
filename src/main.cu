// src/main.cu
#include "config.hpp"
#include "compute.hpp"
#include "data_io.hpp"
#include <iostream>
#include <vector>
#include <complex>
#include <chrono>
#include <fstream>
#include <cmath>  // For M_PI
#include <filesystem>  // For creating directories

namespace fs = std::filesystem;

/**
 * @brief Saves UVW coordinates to CSV files in the specified directory.
 * 
 * @param u Vector of U coordinates for multiple directions.
 * @param v Vector of V coordinates for multiple directions.
 * @param w Vector of W coordinates for multiple directions.
 * @param directory The directory to save the UVW coordinate files.
 */
void saveUVWCoordinates(const std::vector<std::vector<double>>& u, const std::vector<std::vector<double>>& v, const std::vector<std::vector<double>>& w, const std::string& directory) {
    fs::create_directories(directory);
    for (size_t d = 0; d < u.size(); ++d) {
        std::ofstream uvwfile(directory + "/uvw_coordinates_" + std::to_string(d) + ".csv");
        if (uvwfile.is_open()) {
            uvwfile << "u,v,w\n";
            for (size_t i = 0; i < u[d].size(); ++i) {
                uvwfile << u[d][i] << "," << v[d][i] << "," << w[d][i] << "\n";
            }
            uvwfile.close();
            std::cout << "UVW coordinates saved to " << directory + "/uvw_coordinates_" + std::to_string(d) + ".csv\n";
        } else {
            std::cerr << "Error opening file for writing UVW coordinates.\n";
        }
    }
}

/**
 * @brief Main function to compute UVW coordinates, perform imaging, and save results.
 * 
 * @return int Exit status of the program.
 */
int main() {
    const int image_size = config::IMAGE_SIZE;
    std::vector<double> HAs = {M_PI / 4, M_PI / 3, M_PI / 10};  // Example Hour Angles
    std::vector<double> Decs = {M_PI / 6, M_PI / 5, M_PI / 2};  // Example Declinations

    std::vector<double> x_m, y_m, z_m;
    std::vector<std::vector<double>> u, v, w;

    readXYZCoordinates("data/large_xyz_coordinates.csv", x_m, y_m, z_m);

    if (x_m.empty() || y_m.empty() || z_m.empty()) {
        std::cerr << "Error: No data read from file.\n";
        return 1;
    }

    auto start_uvw = std::chrono::high_resolution_clock::now();
    computeUVW(x_m, y_m, z_m, HAs, Decs, u, v, w);
    auto stop_uvw = std::chrono::high_resolution_clock::now();
    auto duration_uvw = std::chrono::duration_cast<std::chrono::milliseconds>(stop_uvw - start_uvw);
    std::cout << "UVW computation complete. Execution time: " << duration_uvw.count() << " ms\n";

    saveUVWCoordinates(u, v, w, "data/uvw_coordinates");

    int num_batches = HAs.size();
    std::vector<std::vector<std::complex<double>>> visibilities(num_batches, std::vector<std::complex<double>>(u[0].size(), std::complex<double>(1, 0)));
    std::vector<std::vector<double>> images;

    auto start = std::chrono::high_resolution_clock::now();
    uniformImage(visibilities, u, v, image_size, images);
    auto stop = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(stop - start);
    std::cout << "Imaging complete. Execution time: " << duration.count() << " ms\n";

    // Create the directory if it doesn't exist
    fs::create_directories("data/images_gpu");

    for (size_t d = 0; d < images.size(); ++d) {
        std::ofstream outfile("data/images_gpu/image_data_gpu_" + std::to_string(d) + ".csv");
        if (outfile.is_open()) {
            for (int i = 0; i < image_size; ++i) {
                for (int j = 0; j < image_size; ++j) {
                    int index = i * image_size + j;
                    outfile << images[d][index];
                    if (j < image_size - 1) {
                        outfile << ",";
                    }
                }
                outfile << "\n";
            }
            outfile.close();
            std::cout << "Image data saved to data/images_gpu/image_data_gpu_" << d << ".csv\n";
        } else {
            std::cerr << "Error opening file for writing.\n";
        }
    }

    return 0;
}
