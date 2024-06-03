import numpy as np
import pandas as pd
import time
from numpy.fft import ifft2, ifftshift
import matplotlib.pyplot as plt
import os
import argparse
import json

def load_config(config_file):
    """
    Load configuration from a JSON file.

    Parameters:
    config_file (str): The path to the JSON configuration file.

    Returns:
    dict: Configuration dictionary.
    """
    with open(config_file, 'r') as f:
        config = json.load(f)
    return config

def read_xyz_coordinates(filename):
    """
    Read XYZ coordinates from a CSV file.

    Parameters:
    filename (str): The path to the CSV file.

    Returns:
    tuple: Arrays of X, Y, and Z coordinates.
    """
    data = pd.read_csv(filename, header=None)
    return data[0].values, data[1].values, data[2].values

def compute_uvw(x_m, y_m, z_m, HAs, Decs, optimized=True):
    """
    Compute UVW coordinates from XYZ coordinates for multiple directions.

    Parameters:
    x_m, y_m, z_m (array-like): XYZ coordinates of the antennas.
    HAs, Decs (array-like): Hour angles and declinations for multiple directions.
    optimized (bool): Use optimized implementation if True, else use non-optimized implementation.

    Returns:
    tuple: Lists of U, V, and W coordinates for each direction.
    """
    N = len(x_m)
    u, v, w = [], [], []

    if optimized:
        for HA, Dec in zip(HAs, Decs):
            dx = x_m[:, np.newaxis] - x_m[np.newaxis, :]
            dy = y_m[:, np.newaxis] - y_m[np.newaxis, :]
            dz = z_m[:, np.newaxis] - z_m[np.newaxis, :]

            u_batch = (dx * np.sin(HA) + dy * np.cos(HA)).flatten()
            v_batch = (-dx * np.sin(Dec) * np.cos(HA) + dy * np.sin(Dec) * np.sin(HA) + dz * np.cos(Dec)).flatten()
            w_batch = (dx * np.cos(Dec) * np.cos(HA) - dy * np.cos(Dec) * np.sin(HA) + dz * np.sin(Dec)).flatten()

            mask = np.tri(N, k=-1, dtype=bool).T.flatten()
            u.append(u_batch[mask])
            v.append(v_batch[mask])
            w.append(w_batch[mask])
    else:
        for HA, Dec in zip(HAs, Decs):
            u_batch, v_batch, w_batch = [], [], []

            for i in range(N):
                for j in range(i + 1, N):
                    dx = x_m[j] - x_m[i]
                    dy = y_m[j] - y_m[i]
                    dz = z_m[j] - z_m[i]

                    u_ij = dx * np.sin(HA) + dy * np.cos(HA)
                    v_ij = -dx * np.sin(Dec) * np.cos(HA) + dy * np.sin(Dec) * np.sin(HA) + dz * np.cos(Dec)
                    w_ij = dx * np.cos(Dec) * np.cos(HA) - dy * np.cos(Dec) * np.sin(HA) + dz * np.sin(Dec)

                    u_batch.append(u_ij)
                    v_batch.append(v_ij)
                    w_batch.append(w_ij)

            u.append(np.array(u_batch))
            v.append(np.array(v_batch))
            w.append(np.array(w_batch))

    return u, v, w

def save_uvw(u, v, w, directory):
    """
    Save UVW coordinates to CSV files in the specified directory.

    Parameters:
    u, v, w (list): Lists of U, V, and W coordinates for each direction.
    directory (str): The directory to save the UVW coordinate files.
    """
    os.makedirs(directory, exist_ok=True)
    for idx, (u_batch, v_batch, w_batch) in enumerate(zip(u, v, w)):
        df = pd.DataFrame({'u': u_batch, 'v': v_batch, 'w': w_batch})
        df.to_csv(f'{directory}/uvw_coordinates_{idx}.csv', index=False)

def uniform_image(visibilities, u, v, image_size, predefined_max_uv, use_predefined_params=False, optimized=True):
    """
    Generate a uniform image from visibilities using FFT.

    Parameters:
    visibilities (array-like): The visibilities for multiple directions.
    u, v (array-like): U and V coordinates.
    image_size (int): The size of the output image.
    predefined_max_uv (float): Predefined maximum UV value.
    use_predefined_params (bool): Whether to use predefined UVW parameters.
    optimized (bool): Use optimized implementation if True, else use non-optimized implementation.

    Returns:
    ndarray: The generated dirty image.
    """
    max_uv = np.max(u) if not use_predefined_params else predefined_max_uv
    pixel_resolution = (0.20 / max_uv) / 3
    uv_resolution = 1 / (image_size * pixel_resolution)
    uv_max = uv_resolution * image_size / 2
    grid_res = 2 * uv_max / image_size

    visibility_grid = np.zeros((image_size, image_size), dtype=complex)

    if optimized:
        i_indices = np.clip((u + uv_max) / grid_res, 0, image_size - 1).astype(int)
        j_indices = np.clip((v + uv_max) / grid_res, 0, image_size - 1).astype(int)
        np.add.at(visibility_grid, (i_indices, j_indices), visibilities)
    else:
        for i in range(len(u)):
            i_index = int((u[i] + uv_max) / grid_res)
            j_index = int((v[i] + uv_max) / grid_res)

            if i_index >= image_size:
                i_index = image_size - 1
            if j_index >= image_size:
                j_index = image_size - 1

            visibility_grid[i_index, j_index] += visibilities[i]

    dirty_image = ifftshift(ifft2(ifftshift(visibility_grid)))
    dirty_image = np.real(dirty_image)
    dirty_image /= np.max(dirty_image)
    
    return dirty_image

def save_images(images, image_size, directory, save_as_csv=False):
    """
    Save images to the specified directory as PNG files and optionally as CSV files.

    Parameters:
    images (list): List of images to save.
    image_size (int): The size of the images.
    directory (str): The directory to save the images.
    save_as_csv (bool): Save images as CSV files if True.
    """
    os.makedirs(directory, exist_ok=True)
    for idx, image in enumerate(images):
        # Save as PNG
        plt.imshow(image, cmap='gray', vmin=0.0, vmax=1.0)
        plt.colorbar()
        plt.title(f'Image {idx}')
        plt.savefig(f'{directory}/image_{idx}.png')
        plt.close()

        # Save as CSV
        if save_as_csv:
            np.savetxt(f'{directory}/image_{idx}.csv', image, delimiter=',')

def str2bool(v):
    if isinstance(v, bool):
        return v
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')

def main():
    parser = argparse.ArgumentParser(description="Compute UVW coordinates and generate images using CPU.")
    parser.add_argument('--input', type=str, default='data/xyz_coordinates.csv', help='Path to the input CSV file with XYZ coordinates.')
    parser.add_argument('--directions', type=str, default='data/directions.csv', help='Path to the directions CSV file with HAs and Decs.')
    parser.add_argument('--use_predefined_params', type=str2bool, default=True, help='Use predefined UVW parameters (default: True).')
    parser.add_argument('--image_dir', type=str, default='data/images', help='Directory to save images.')
    parser.add_argument('--uvw_dir', type=str, default='data/uvw_coordinates', help='Directory to save UVW coordinates.')
    parser.add_argument('--optimized', type=str2bool, default=True, help='Use optimized implementation (default: True).')
    parser.add_argument('--save_uvw', type=str2bool, default=True, help='Save UVW coordinates to CSV (default: True).')
    parser.add_argument('--generate_images', type=str2bool, default=True, help='Generate and save images (default: True).')
    parser.add_argument('--save_im', type=str2bool, default=True, help='Save images (default: True).')
    parser.add_argument('--save_as_csv', type=str2bool, default=True, help='Additionally save images as CSV files apart from PNG (default: True).')

    args = parser.parse_args()

    # Load configuration
    config = load_config('config.json')
    image_size = config['IMAGE_SIZE']
    predefined_max_uv = config['PREDEFINED_MAX_UV']

    x_m, y_m, z_m = read_xyz_coordinates(args.input)
    directions = pd.read_csv(args.directions)
    HAs = directions.iloc[:, 0].values
    Decs = directions.iloc[:, 1].values

    start_time = time.time()
    u, v, w = compute_uvw(x_m, y_m, z_m, HAs, Decs, optimized=args.optimized)
    uvw_time = time.time() - start_time
    print(f"UVW computation complete. Execution time: {uvw_time * 1000:.2f} ms")

    if args.save_uvw:
        save_uvw(u, v, w, args.uvw_dir)
        print(f"UVW coordinates saved successfully.")

    if args.generate_images:
        images = []
        start_time = time.time()
        for idx, (u_batch, v_batch) in enumerate(zip(u, v)):
            visibilities = np.ones(len(u_batch), dtype=complex)
            image = uniform_image(visibilities, u_batch, v_batch, image_size, predefined_max_uv, args.use_predefined_params, optimized=args.optimized)
            images.append(image)
        imaging_time = time.time() - start_time
        print(f"Imaging complete. Execution time: {imaging_time * 1000:.2f} ms")

        if args.save_im:
            save_images(images, image_size, args.image_dir, save_as_csv=args.save_as_csv)
            print(f"Images saved successfully.")

if __name__ == '__main__':
    main()
