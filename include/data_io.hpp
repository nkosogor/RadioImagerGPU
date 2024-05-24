// include/data_io.hpp
#ifndef DATA_IO_HPP
#define DATA_IO_HPP

#include <vector>
#include <string>

void readXYZCoordinates(const std::string& filename, 
                        std::vector<double>& x_m, 
                        std::vector<double>& y_m, 
                        std::vector<double>& z_m);


void readDirections(const std::string& filename, 
                    std::vector<double>& HAs, 
                    std::vector<double>& Decs);


void saveUVWCoordinates(const std::vector<std::vector<double>>& u, 
                        const std::vector<std::vector<double>>& v, 
                        const std::vector<std::vector<double>>& w, 
                        const std::string& directory);

void saveImages(const std::vector<std::vector<double>>& images, 
                int image_size, 
                const std::string& directory);

#endif
