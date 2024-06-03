// src/config.cpp
#include "config.hpp"

namespace config {
    int IMAGE_SIZE;
    double PREDEFINED_MAX_UV;

    void load_config(const std::string& config_file) {
        std::ifstream file(config_file);
        nlohmann::json config_json;
        file >> config_json;

        IMAGE_SIZE = config_json["IMAGE_SIZE"];
        PREDEFINED_MAX_UV = config_json["PREDEFINED_MAX_UV"];
    }
}
