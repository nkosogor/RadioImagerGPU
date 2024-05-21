#ifndef DATA_IO_HPP
#define DATA_IO_HPP

#include <vector>
#include <string>

// Function to read XYZ coordinates from a CSV file
void readXYZCoordinates(const std::string& filename, 
                        std::vector<double>& x_m, 
                        std::vector<double>& y_m, 
                        std::vector<double>& z_m);

// Function to compute UVW coordinates from XYZ coordinates
void computeUVW(const std::vector<double>& x_m, const std::vector<double>& y_m, const std::vector<double>& z_m, 
                double HA, double Dec, std::vector<double>& u, std::vector<double>& v, std::vector<double>& w);

#endif
