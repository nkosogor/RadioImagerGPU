NVCC = /usr/local/cuda/bin/nvcc
NVCC_FLAGS = -arch=sm_52 -I/usr/local/cuda/include -Iinclude
LD_FLAGS = -L/usr/local/cuda/lib64 -lcudart -lcufft

SRC_CUDA = src/main.cu src/imaging.cu
SRC_CPP = src/data_io.cpp
OBJ_CUDA = $(SRC_CUDA:.cu=.o)
OBJ_CPP = $(SRC_CPP:.cpp=.o)
TARGET = bin/RadioImager

all: clean $(TARGET)

$(TARGET): $(OBJ_CUDA) $(OBJ_CPP)
	$(NVCC) $(OBJ_CUDA) $(OBJ_CPP) -o $@ $(LD_FLAGS)

%.o: %.cu
	$(NVCC) $(NVCC_FLAGS) -c $< -o $@

%.o: %.cpp
	g++ -c $< -o $@ -Iinclude

clean:
	rm -f $(OBJ_CUDA) $(OBJ_CPP) $(TARGET)
