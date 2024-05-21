#include <iostream>
#include <vector>
#include <complex>
#include "imaging.hpp"  // Ensure this header contains the necessary function prototype and namespace
#include <chrono>
#include <random>
#include <fstream> 

int main() {
    const int image_size = config::IMAGE_SIZE;  // Use the defined image size from the header
    std::vector<std::complex<double>> visibilities(image_size * image_size, std::complex<double>(1, 0));
    std::vector<double> u(image_size * image_size), v(image_size * image_size), image;




    double scale_factor = 1000.0 / (image_size - 1);
    // Create an impulse in the center of the visibility plane
    for (int i = 0; i < image_size; ++i) {
        for (int j = 0; j < image_size; ++j) {
            int index = i * image_size + j;
            u[index] = i * scale_factor;  // Scale u coordinates
            v[index] = j * scale_factor;  // Scale v coordinates
            if (i == image_size / 2 && j == image_size / 2) {
                visibilities[index] = std::complex<double>(1, 0); // Impulse at the center
            }
        }
    }
    /*const int num_visibilities = 255;  // A large number of visibilities

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
        visibilities[i] = std::complex<double>(0, 0);
    }

    // Add an extra visibility at (0, 0) with visibility 1
    u[num_visibilities] = 0;
    v[num_visibilities] = 0;
    visibilities[num_visibilities] = std::complex<double>(1, 0);  // Visibility value of 1 at the origin

    */

    // Start timing
    auto start = std::chrono::high_resolution_clock::now();

    // Perform imaging
    uniformImage(visibilities, u, v, image_size, image);

    // End timing
    auto stop = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(stop - start);
    std::cout << "Imaging complete. Execution time: " << duration.count() << " ms\n";


    // Output the image to console or file (simple console output here)
    std::cout << "Imaging complete. Outputting image data:" << std::endl;

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


    /*for (int i = 0; i < image_size; ++i) {
        for (int j = 0; j < image_size; ++j) {
            int index = i * image_size + j;
            std::cout << image[index] << " ";
        }
        std::cout << std::endl;
    }*/
    return 0;
}

