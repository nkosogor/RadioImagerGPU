#ifndef DATA_IO_HPP
#define DATA_IO_HPP

#include <vector>
#include <string>

// Declare functions for reading and writing data
void readXYZCoordinates(const std::string& filename, 
                        std::vector<double>& x_m, 
                        std::vector<double>& y_m, 
                        std::vector<double>& z_m);

#endif // DATA_IO_HPP
