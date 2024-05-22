#include "imaging.hpp"
#include "data_io.hpp"
#include <iostream>
#include <vector>
#include <complex>
#include <chrono>
#include <fstream>
#include <cmath>  // For M_PI

int main() {
    const int image_size = config::IMAGE_SIZE;  // Use the defined image size from the header
    const double HA = M_PI / 4;  // Example Hour Angle in radians
    const double Dec = M_PI / 6;  // Example Declination in radians

    // Vectors to store coordinates
    std::vector<double> x_m, y_m, z_m;
    std::vector<double> u, v, w;

    // Read XYZ coordinates from file
    readXYZCoordinates("data/large_xyz_coordinates.csv", x_m, y_m, z_m);

    if (x_m.empty() || y_m.empty() || z_m.empty()) {
        std::cerr << "Error: No data read from file.\n";
        return 1;
    }

    // Start timing for UVW computation
    auto start_uvw = std::chrono::high_resolution_clock::now();

    // Compute UVW coordinates
    computeUVW(x_m, y_m, z_m, HA, Dec, u, v, w);

    // End timing for UVW computation
    auto stop_uvw = std::chrono::high_resolution_clock::now();
    auto duration_uvw = std::chrono::duration_cast<std::chrono::milliseconds>(stop_uvw - start_uvw);
    std::cout << "UVW computation complete. Execution time: " << duration_uvw.count() << " ms\n";



    // Check if the UVW coordinates are computed
    if (u.empty() || v.empty() || w.empty()) {
        std::cerr << "Error: UVW coordinates not computed.\n";
        return 1;
    }

    // Vectors to store visibility data
    std::vector<std::complex<double>> visibilities(u.size(), std::complex<double>(1, 0));
    std::vector<double> image;
    std::cout << "Vis length " << u.size() <<"\n";

    // Start timing
    auto start = std::chrono::high_resolution_clock::now();

    // Perform imaging
    uniformImage(visibilities, u, v, image_size, image);

    // End timing
    auto stop = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(stop - start);
    std::cout << "Imaging complete. Execution time: " << duration.count() << " ms\n";

    // Save the image data to the "data" folder as a CSV file
    std::ofstream outfile("data/image_data_gpu.csv");
    if (outfile.is_open()) {
        for (int i = 0; i < image_size; ++i) {
            for (int j = 0; j < image_size; ++j) {
                int index = i * image_size + j;
                outfile << image[index];
                if (j < image_size - 1) {
                    outfile << ",";
                }
            }
            outfile << "\n";
        }
        outfile.close();
        std::cout << "Image data saved to data/image_data_gpu.csv\n";
    } else {
        std::cerr << "Error opening file for writing.\n";
    }

    // Save the u and v coordinates to the "data" folder as a CSV file
    std::ofstream uvfile("data/uv_coordinates_gpu.csv");
    if (uvfile.is_open()) {
        uvfile << "u,v\n";  // Write the header
        for (size_t i = 0; i < u.size(); ++i) {
            uvfile << u[i] << "," << v[i] << "\n";
        }
        uvfile.close();
        std::cout << "u and v coordinates saved to data/uv_coordinates_gpu.csv\n";
    } else {
        std::cerr << "Error opening file for writing.\n";
    }

    return 0;
}
