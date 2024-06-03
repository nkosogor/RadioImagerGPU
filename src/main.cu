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
 * @brief Main function to compute UVW coordinates, perform imaging, and save results.
 * 
 * @param argc Argument count.
 * @param argv Argument vector.
 * @return int Exit status of the program.
 */
int main(int argc, char* argv[]) {
    config::load_config("config.json");
    
    argparse::ArgumentParser program("RadioImager");

    program.add_argument("--input")
        .default_value(std::string("data/xyz_coordinates.csv"))
        .help("Path to the input CSV file with XYZ coordinates.");

    program.add_argument("--directions")
        .default_value(std::string("data/directions.csv"))
        .help("Path to the directions CSV file with HAs and Decs.");

    program.add_argument("--use_predefined_params")
        .default_value(std::string("true"))
        .help("Use predefined UVW parameters (default: true).");

    program.add_argument("--output_uvw")
        .default_value(std::string("true"))
        .help("Output UVW coordinates (default: true).");

    program.add_argument("--uvw_dir")
        .default_value(std::string("data/uvw_coordinates"))
        .help("Directory to save UVW coordinates.");

    program.add_argument("--image_dir")
        .default_value(std::string("data/images_gpu"))
        .help("Directory to save images.");

    program.add_argument("--save_images")
        .default_value(std::string("true"))
        .help("Save images (default: true).");

    try {
        program.parse_args(argc, argv);
    } catch (const std::runtime_error& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << program;
        return 1;
    }

    const std::string input_path = program.get<std::string>("--input");
    const std::string directions_path = program.get<std::string>("--directions");
    const std::string use_predefined_params_str = program.get<std::string>("--use_predefined_params");
    const bool use_predefined_params = (use_predefined_params_str == "true");
    const std::string output_uvw_str = program.get<std::string>("--output_uvw");
    const bool output_uvw = (output_uvw_str == "true");
    const std::string uvw_dir = program.get<std::string>("--uvw_dir");
    const std::string image_dir = program.get<std::string>("--image_dir");
    const std::string save_images_str = program.get<std::string>("--save_images");
    const bool save_images = (save_images_str == "true");

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
    uniformImage(visibilities, u, v, image_size, images, use_predefined_params);
    auto stop = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(stop - start);
    std::cout << "Imaging complete. Execution time: " << duration.count() << " ms\n";

    std::ofstream log_file("output.log", std::ios_base::app);
    log_file << "UVW computation time: " << duration_uvw.count() << " ms\n";
    log_file << "Imaging time: " << duration.count() << " ms\n";
    log_file.close();

    if (save_images) {
        saveImages(images, image_size, image_dir);
    }

    // Reset the GPU
    cudaDeviceReset();

    return 0;
}