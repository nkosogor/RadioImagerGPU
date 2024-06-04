##  GPU Implementation

### How to Execute

After building the project, one can execute the `RadioImager` using the following command from the `build` directory:
```bash
./build/RadioImager [OPTIONS]
```

### What the Code Does

The `RadioImager` program computes UVW coordinates from XYZ coordinates, performs imaging using GPU acceleration, and saves the resulting images and coordinates.

### Options

The following options can be provided to the `RadioImager` program:

- `--input`: Path to the input CSV file with XYZ coordinates. Default: `data/xyz_coordinates.csv`
- `--directions`: Path to the directions CSV file with Hour Angles (HAs) and Declinations (Decs). Default: `data/directions.csv`
- `--use_predefined_params`: Use predefined UVW parameters. Default: `true`
- `--output_uvw`: Output UVW coordinates. Default: `true`
- `--uvw_dir`: Directory to save UVW coordinates. Default: `data/uvw_coordinates`
- `--image_dir`: Directory to save images. Default: `data/images_gpu`
- `--save_images`: Save images. Default: `true`

### Example Command

```bash
./build/RadioImager --input data/xyz_coordinates.csv --directions data/directions.csv --use_predefined_params false --output_uvw true --uvw_dir output/uvw --image_dir output/images --save_images true
```

This command will use custom input files, disable predefined UVW parameters, output UVW coordinates to the specified directory, and save images to the specified directory.
