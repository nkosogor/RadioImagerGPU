import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import os
import argparse

def convert_csv_to_png(csv_file, output_dir):
    """
    Convert a CSV file containing image data to a PNG file.

    Parameters:
    csv_file (str): Path to the input CSV file.
    output_dir (str): Directory to save the PNG file.
    """
    # Read the CSV file
    image_data = pd.read_csv(csv_file, header=None).values
    
    # Create the output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Get the filename without the extension
    base_filename = os.path.basename(csv_file).split('.')[0]
    
    # Save the image as PNG
    plt.imshow(image_data, cmap='gray', vmin=0.0, vmax=1.0)
    plt.colorbar()
    plt.title(f'{base_filename}')
    plt.savefig(f'{output_dir}/{base_filename}.png')
    plt.close()

def main():
    parser = argparse.ArgumentParser(description="Convert GPU-generated CSV image to PNG.")
    parser.add_argument('--input_csv', type=str, required=True, help='Path to the input CSV file with image data.')
    parser.add_argument('--output_dir', type=str, required=True, help='Directory to save the PNG file.')

    args = parser.parse_args()
    
    convert_csv_to_png(args.input_csv, args.output_dir)

if __name__ == '__main__':
    main()
