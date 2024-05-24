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
#include <argparse/argparse.hpp>

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
    int total_directions = u.size();
    for (size_t d = 0; d < u.size(); ++d) {
        std::ofstream uvwfile(directory + "/uvw_coordinates_" + std::to_string(d) + ".csv");
        if (uvwfile.is_open()) {
            uvwfile << "u,v,w\n";
            for (size_t i = 0; i < u[d].size(); ++i) {
                uvwfile << u[d][i] << "," << v[d][i] << "," << w[d][i] << "\n";
            }
            uvwfile.close();
            if (d % 10 == 0 || d == u.size() - 1) { // Print progress every 10 directions
                std::cout << "UVW Progress: " << ((d + 1) * 100 / total_directions) << "% (" << (d + 1) << "/" << total_directions << " directions saved)\n";
            }
        } else {
            std::cerr << "Error opening file for writing UVW coordinates.\n";
        }
    }
}

/**
 * @brief Saves images to CSV files in the specified directory.
 * 
 * @param images Vector of images.
 * @param image_size Size of the images.
 * @param directory The directory to save the image files.
 */
void saveImages(const std::vector<std::vector<double>>& images, int image_size, const std::string& directory) {
    fs::create_directories(directory);
    int total_images = images.size();
    for (size_t d = 0; d < images.size(); ++d) {
        std::ofstream outfile(directory + "/image_data_gpu_" + std::to_string(d) + ".csv");
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
            if (d % 10 == 0 || d == images.size() - 1) { // Print progress every 10 images
                std::cout << "Progress: " << ((d + 1) * 100 / total_images) << "% (" << (d + 1) << "/" << total_images << " images saved)\n";
            }
        } else {
            std::cerr << "Error opening file for writing images.\n";
        }
    }
}

/**
 * @brief Reads HAs and Decs from a CSV file.
 * 
 * @param filename The path to the CSV file.
 * @param HAs Vector to store the Hour Angles.
 * @param Decs Vector to store the Declinations.
 */
void readDirections(const std::string& filename, std::vector<double>& HAs, std::vector<double>& Decs) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error opening file: " << filename << std::endl;
        return;
    }

    std::string line;
    std::getline(file, line); // Skip header
    while (std::getline(file, line)) {
        std::stringstream ss(line);
        std::string ha_str, dec_str;
        std::getline(ss, ha_str, ',');
        std::getline(ss, dec_str, ',');
        HAs.push_back(std::stod(ha_str));
        Decs.push_back(std::stod(dec_str));
    }
    file.close();
}

/**
 * @brief Main function to compute UVW coordinates, perform imaging, and save results.
 * 
 * @param argc Argument count.
 * @param argv Argument vector.
 * @return int Exit status of the program.
 */
int main(int argc, char* argv[]) {
    argparse::ArgumentParser program("RadioImager");

    program.add_argument("--input")
        .default_value(std::string("data/xyz_coordinates.csv"))
        .help("Path to the input CSV file with XYZ coordinates.");

    program.add_argument("--directions")
        .default_value(std::string("data/directions.csv"))
        .help("Path to the directions CSV file with HAs and Decs.");

    program.add_argument("--output_uvw")
        .default_value(std::string("true"))
        .help("Output UVW coordinates (default: true).");

    program.add_argument("--uvw_dir")
        .default_value(std::string("data/uvw_coordinates"))
        .help("Directory to save UVW coordinates.");

    program.add_argument("--image_dir")
        .default_value(std::string("data/images_gpu"))
        .help("Directory to save images.");

    try {
        program.parse_args(argc, argv);
    } catch (const std::runtime_error& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << program;
        return 1;
    }

    const std::string input_path = program.get<std::string>("--input");
    const std::string directions_path = program.get<std::string>("--directions");
    const std::string output_uvw_str = program.get<std::string>("--output_uvw");
    const bool output_uvw = (output_uvw_str == "true");
    const std::string uvw_dir = program.get<std::string>("--uvw_dir");
    const std::string image_dir = program.get<std::string>("--image_dir");

    std::vector<double> HAs, Decs;
    readDirections(directions_path, HAs, Decs);

    const int image_size = config::IMAGE_SIZE;
    std::vector<double> x_m, y_m, z_m;
    std::vector<std::vector<double>> u, v, w;

    readXYZCoordinates(input_path, x_m, y_m, z_m);

    if (x_m.empty() || y_m.empty() || z_m.empty()) {
        std::cerr << "Error: No data read from file.\n";
        return 1;
    }

    auto start_uvw = std::chrono::high_resolution_clock::now();
    computeUVW(x_m, y_m, z_m, HAs, Decs, u, v, w);
    auto stop_uvw = std::chrono::high_resolution_clock::now();
    auto duration_uvw = std::chrono::duration_cast<std::chrono::milliseconds>(stop_uvw - start_uvw);
    std::cout << "UVW computation complete. Execution time: " << duration_uvw.count() << " ms\n";

    if (output_uvw) {
        saveUVWCoordinates(u, v, w, uvw_dir);
    }

    int num_batches = HAs.size();
    std::vector<std::vector<std::complex<double>>> visibilities(num_batches, std::vector<std::complex<double>>(u[0].size(), std::complex<double>(1, 0)));
    std::vector<std::vector<double>> images;

    auto start = std::chrono::high_resolution_clock::now();
    uniformImage(visibilities, u, v, image_size, images);
    auto stop = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(stop - start);
    std::cout << "Imaging complete. Execution time: " << duration.count() << " ms\n";

    saveImages(images, image_size, image_dir);

    return 0;
}