# RadioImagerGPU

...

## Overview

...

## System Requirements

To fully utilize the GPU acceleration capabilities, ensure you have a compatible NVIDIA GPU. Below is the hardware and software setup used for developing and testing this project:

### Operating System
- **OS:** Ubuntu 22.04.4 LTS (Jammy)
- **Kernel:** Linux 6.5.0-28-generic

### NVIDIA Driver and GPU
- **Driver Version:** 550.54.15
- **CUDA Version:** 12.4
- **GPUs:**: NVIDIA GeForce GTX TITAN X (2 units, 12 GB each)

### CUDA Toolkit
- **Version:** CUDA 12.4

### Python Environment
- **Python Version:** 3.10.12
- The required Python packages are listed in `requirements.txt`.

### Installation and Building the Project

Clone the repository and navigate to the project directory:

```bash
git clone https://github.com/nkosogor/RadioImagerGPU.git
cd RadioImagerGPU
pip install -r requirements.txt
```
Use CMake to configure and build the project:

```bash
mkdir build
cd build
cmake ..
make
```




