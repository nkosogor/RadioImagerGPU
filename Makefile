# Directory names
SRCDIR = src
OBJDIR = obj
BINDIR = bin
INCDIR = include

# CUDA path and configuration
CUDA_PATH = /usr/local/cuda
CUDA_INC_PATH = $(CUDA_PATH)/include
CUDA_LIB_PATH = $(CUDA_PATH)/lib64

NVCC = $(CUDA_PATH)/bin/nvcc
GPP = g++

# Compiler flags
NVCC_FLAGS = -c -I$(INCDIR) -I$(CUDA_INC_PATH) --gpu-architecture=compute_52 --gpu-code=sm_52 -dc
GPP_FLAGS = -c -I$(INCDIR) -I$(CUDA_INC_PATH) -std=c++11 -Wall -O2
LINK_FLAGS = -L$(CUDA_LIB_PATH) -lcudart -lcufft

# File names
EXECUTABLE = RadioImager
CUDA_SOURCES = $(wildcard $(SRCDIR)/*.cu)
CPP_SOURCES = $(wildcard $(SRCDIR)/*.cpp)
CUDA_OBJECTS = $(CUDA_SOURCES:$(SRCDIR)/%.cu=$(OBJDIR)/%.o)
CPP_OBJECTS = $(CPP_SOURCES:$(SRCDIR)/%.cpp=$(OBJDIR)/%.o)
ALL_OBJECTS = $(CUDA_OBJECTS) $(CPP_OBJECTS)

# Rules
all: $(BINDIR)/$(EXECUTABLE)

$(BINDIR)/$(EXECUTABLE): $(ALL_OBJECTS)
	$(GPP) $^ -o $@ $(LINK_FLAGS)

$(OBJDIR)/%.o: $(SRCDIR)/%.cu
	$(NVCC) $(NVCC_FLAGS) $< -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.cpp
	$(GPP) $(GPP_FLAGS) $< -o $@

clean:
	rm -f $(OBJDIR)/*.o $(BINDIR)/$(EXECUTABLE)

.PHONY: all clean
