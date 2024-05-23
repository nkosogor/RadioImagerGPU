#include "data_io.hpp"
#include <fstream>
#include <sstream>
#include <iostream>
#include <cmath>

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



