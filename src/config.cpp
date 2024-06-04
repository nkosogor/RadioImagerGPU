// src/config.cpp
#include "config.hpp"

/**
 * @namespace config
 * @brief Contains functions and variables related to configuration settings.
 */
namespace config {
    int IMAGE_SIZE;
    double PREDEFINED_MAX_UV;

    /**
     * @brief Loads the configuration settings from a JSON file.
     * 
     * @param config_file The path to the JSON configuration file.
     */
    void load_config(const std::string& config_file) {
        std::ifstream file(config_file);
        nlohmann::json config_json;
        file >> config_json;

        IMAGE_SIZE = config_json["IMAGE_SIZE"];
        PREDEFINED_MAX_UV = config_json["PREDEFINED_MAX_UV"];
    }
}
