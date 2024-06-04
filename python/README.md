## CPU Implementation

### How to Execute

To run the CPU implementation, execute the `imaging_cpu.py` script from the `python` directory:
```bash
python3 python/imaging_cpu.py [OPTIONS]
```

### What the Code Does

The `imaging_cpu.py` script computes UVW coordinates from XYZ coordinates, performs imaging using CPU processing, and saves the resulting images and coordinates.

### Options

The following options can be provided to the `imaging_cpu.py` script:

- `--input`: Path to the input CSV file with XYZ coordinates. Default: `data/xyz_coordinates.csv`
- `--directions`: Path to the directions CSV file with Hour Angles (HAs) and Declinations (Decs). Default: `data/directions.csv`
- `--use_predefined_params`: Use predefined UVW parameters. Default: `true`
- `--image_dir`: Directory to save images. Default: `data/images`
- `--uvw_dir`: Directory to save UVW coordinates. Default: `data/uvw_coordinates`
- `--optimized`: Use optimized implementation. Default: `true`
- `--save_uvw`: Save UVW coordinates to CSV. Default: `true`
- `--generate_images`: Generate and save images. Default: `true`
- `--save_im`: Save images (default: true)
- `--save_as_csv`: Additionally save images as CSV files apart from PNG. Default: `true`


### Optimized vs. Non-Optimized Implementation

#### Optimized Implementation
The optimized implementation leverages NumPy's broadcasting and vectorized operations to efficiently compute the UVW coordinates and map visibilities to a grid. This approach minimizes the use of explicit loops and takes advantage of NumPy's internal optimizations for array operations, resulting in significant performance improvements, especially for large datasets.

- **UVW Computation**: 
  - Uses broadcasting to compute the differences between XYZ coordinates.
  - Calculates UVW coordinates for all baselines.
  - Masks and flattens arrays to select relevant baselines.
- **Visibility Mapping**:
  - Uses vectorized operations to compute grid indices.
  - Employs `np.add.at` to accumulate visibilities on the grid efficiently.

#### Non-Optimized Implementation
The non-optimized implementation uses explicit loops to compute UVW coordinates and map visibilities to a grid. While this approach is straightforward and easier to understand, it is significantly slower for large datasets due to the overhead of Python loops and the lack of vectorized operations.

- **UVW Computation**:
  - Uses nested loops to compute the differences between XYZ coordinates for each pair of antennas.
  - Calculates UVW coordinates for each baseline individually.
- **Visibility Mapping**:
  - Uses loops to compute grid indices and accumulate visibilities.
  
### Example Command
```bash
python3 python/imaging_cpu.py --input data/xyz_coordinates.csv --directions data/directions.csv --use_predefined_params false --image_dir output/images --uvw_dir output/uvw --optimized false --save_uvw true --generate_images true --save_im true --save_as_csv true
```

This command will use custom input files, disable predefined UVW parameters, output UVW coordinates to the specified directory, and save images to the specified directory together with saving them as CSV files.

Got it. Here is the text to be added to your README without the code:


## Additional Scripts

### Generating Synthetic Data

The `generate_synthetic_data.py` script can be used to generate synthetic XYZ coordinates and directions for testing purposes. This script can be executed with the following command:

```bash
python3 python/generate_synthetic_data.py
```


This generates synthetic data which can be used for testing with different configurations, such as:

```bash
python3 python/imaging_cpu.py --input data/elements_25_directions_1/xyz_coordinates.csv --directions data/elements_25_directions_1/directions.csv --use_predefined_params true --image_dir data/elements_25_directions_1/output_images_python --save_uvw false --generate_images true --save_im true --save_as_csv true
```

```bash
./build/RadioImager --input data/elements_25_directions_1/xyz_coordinates.csv --directions data/elements_25_directions_1/directions.csv --use_predefined_params true --image_dir data/elements_25_directions_1/output_images_gpu --save_images true
```

### Converting CSV to PNG

The `convert_gpu_csv_to_png.py` script converts CSV files containing image data to PNG format for easier visualization. This script can be executed with the following command:

```bash
python3 python/convert_gpu_csv_to_png.py --input_csv data/elements_25_directions_1/output_images_gpu/image_data_gpu_0.csv --output_dir data/elements_25_directions_1/output_images_gpu/
```

These scripts can be modified to test different numbers of elements and configurations as needed. The `data` directory in the root of the repository contains examples of the output CSV and PNG files.

