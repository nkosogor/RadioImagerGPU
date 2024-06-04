import numpy as np
import pandas as pd
import os

def generate_synthetic_data(num_elements, num_directions, output_dir):
    np.random.seed(42)
    
    x = np.random.uniform(-1000, 1000, num_elements)
    y = np.random.uniform(-1000, 1000, num_elements)
    z = np.random.uniform(-10, 10, num_elements)
    data = pd.DataFrame({'x': x, 'y': y, 'z': z})
    data.to_csv(f'{output_dir}/xyz_coordinates.csv', index=False, header=False)
    
    HAs = np.random.uniform(-np.pi, np.pi, num_directions)
    Decs = np.random.uniform(-np.pi/2, np.pi/2, num_directions)
    directions = pd.DataFrame({'HA': HAs, 'Dec': Decs})
    directions.to_csv(f'{output_dir}/directions.csv', index=False)

output_dir = 'data'
os.makedirs(output_dir, exist_ok=True)

# Test configurations
test_configs = [
    (25, 1),
]

for num_elements, num_directions in test_configs:
    config_dir = f"{output_dir}/elements_{num_elements}_directions_{num_directions}"
    os.makedirs(config_dir, exist_ok=True)
    generate_synthetic_data(num_elements, num_directions, config_dir)
