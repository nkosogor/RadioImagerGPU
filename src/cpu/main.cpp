#include "imaging.hpp"
#include "data_io.hpp"
#include <iostream>
#include <vector>
#include <complex>
#include <chrono>
#include <fstream>  // For file operations
#include <cmath>    // For M_PI

int main() {
    /*const int image_size = config::IMAGE_SIZE;  // Use the defined image size from the header
    const int num_visibilities = 8192-1;  // A large number of visibilities

    // Create vectors to store visibility data and coordinates
    std::vector<std::complex<double>> visibilities(num_visibilities+1, std::complex<double>(0, 0));
    std::vector<double> u(num_visibilities+1), v(num_visibilities+1), image(image_size * image_size);

    std::default_random_engine generator;
    std::uniform_real_distribution<double> distribution(0.0, 1000.0);

    // Randomly generate u and v coordinates within the range [0, 1000]
    for (int i = 0; i < num_visibilities; ++i) {
        u[i] = distribution(generator);
        v[i] = distribution(generator);
        // Optionally set visibilities, e.g., all to 1 or some pattern
        visibilities[i] = std::complex<double>(1, 0);
    }

    // Add an extra visibility at (0, 0) with visibility 1
    u[num_visibilities] = 0;
    v[num_visibilities] = 0;
    visibilities[num_visibilities] = std::complex<double>(1, 0);  // Visibility value of 1 at the origin
    */

    const int image_size = config::IMAGE_SIZE;  // Use the defined image size from the header
    const double HA = M_PI / 4;  // Example Hour Angle in radians
    const double Dec = M_PI / 6;  // Example Declination in radians

    // Vectors to store coordinates
    std::vector<double> x_m, y_m, z_m;
    std::vector<double> u, v, w;

    // Read XYZ coordinates from file
    readXYZCoordinates("data/xyz_coordinates.csv", x_m, y_m, z_m);

    if (x_m.empty() || y_m.empty() || z_m.empty()) {
        std::cerr << "Error: No data read from file.\n";
        return 1;
    }

    // Compute UVW coordinates
    computeUVW(x_m, y_m, z_m, HA, Dec, u, v, w);

    // Check if the UVW coordinates are computed
    if (u.empty() || v.empty() || w.empty()) {
        std::cerr << "Error: UVW coordinates not computed.\n";
        return 1;
    }

    // Vectors to store visibility data
    std::vector<std::complex<double>> visibilities(u.size(), std::complex<double>(1, 0));
    std::vector<double> image;


    // Start timing
    auto start = std::chrono::high_resolution_clock::now();
    // Perform imaging
    uniformImage(visibilities, u, v, image_size, image);

    // End timing
    auto stop = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(stop - start);
    std::cout << "Imaging complete. Execution time: " << duration.count() << " ms\n";

    // Save the image data to the "data" folder as a CSV file
    std::ofstream outfile("data/image_data.csv");
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
        std::cout << "Image data saved to data/image_data.csv\n";
    } else {
        std::cerr << "Error opening file for writing.\n";
    }

    // Save the u and v coordinates to the "data" folder as a CSV file
    std::ofstream uvfile("data/uv_coordinates.csv");
    if (uvfile.is_open()) {
        uvfile << "u,v\n";  // Write the header
        for (size_t i = 0; i < u.size(); ++i) {
            uvfile << u[i] << "," << v[i] << "\n";
        }
        uvfile.close();
        std::cout << "u and v coordinates saved to data/uv_coordinates.csv\n";
    } else {
        std::cerr << "Error opening file for writing.\n";
    }

    return 0;
}
