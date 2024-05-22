#include "data_io.hpp"
#include <fstream>
#include <sstream>
#include <iostream>
#include <cmath>

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

/*void computeUVW(const std::vector<double>& x_m, const std::vector<double>& y_m, const std::vector<double>& z_m, 
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
}*/

