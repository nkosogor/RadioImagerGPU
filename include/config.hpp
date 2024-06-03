// include/config.hpp
#ifndef CONFIG_HPP
#define CONFIG_HPP

#include <fstream>
#include <nlohmann/json.hpp>

namespace config {
    extern int IMAGE_SIZE;
    extern double PREDEFINED_MAX_UV;

    void load_config(const std::string& config_file);
}

#endif

