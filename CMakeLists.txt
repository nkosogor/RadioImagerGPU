cmake_minimum_required(VERSION 3.10)
project(RadioImager LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_STANDARD 17)

# Specify the CUDA compiler
set(CMAKE_CUDA_COMPILER /usr/local/cuda/bin/nvcc)

# Specify CUDA architecture
set(CUDA_ARCHITECTURES 52) # Use the appropriate architecture for your GPU

# Add include directories
include_directories(${CUDA_INCLUDE_DIRS} include external/argparse/include external/nlohmann_json/include)

# Find CUDA package
find_package(CUDA REQUIRED)

# Add the executable and specify CUDA sources
add_executable(RadioImager src/main.cu src/compute.cu src/data_io.cpp src/config.cpp)

# Link the CUDA libraries
target_link_libraries(RadioImager ${CUDA_LIBRARIES} cufft cudart)

# Set linker flags
set_target_properties(RadioImager PROPERTIES LINK_FLAGS "-L/usr/local/cuda/lib64")

# Ensure C++17 standard is used for CUDA
set_target_properties(RadioImager PROPERTIES CUDA_SEPARABLE_COMPILATION ON)
set_target_properties(RadioImager PROPERTIES CUDA_STANDARD 17)
