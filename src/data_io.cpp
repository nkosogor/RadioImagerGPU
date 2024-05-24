#include "data_io.hpp"
#include <fstream>
#include <sstream>
#include <iostream>
#include <filesystem>

namespace fs = std::filesystem;

/**
 * @brief Reads XYZ coordinates from a CSV file.
 * 
 * @param filename The name of the CSV file to read from.
 * @param x_m Vector to store the X coordinates.
 * @param y_m Vector to store the Y coordinates.
 * @param z_m Vector to store the Z coordinates.
 */
void readXYZCoordinates(const std::string& filename, 
                        std::vector<double>& x_m, 
                        std::vector<double>& y_m, 
                        std::vector<double>& z_m) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error opening file: " << filename << "\n";
        return;
    }

    std::string line;
    while (std::getline(file, line)) {
        std::istringstream ss(line);
        double x_val, y_val, z_val;
        char comma;

        ss >> x_val >> comma >> y_val >> comma >> z_val;
        x_m.push_back(x_val);
        y_m.push_back(y_val);
        z_m.push_back(z_val);
    }
    file.close();
}


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
