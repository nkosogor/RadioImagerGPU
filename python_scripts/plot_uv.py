import numpy as np
import matplotlib.pyplot as plt

# Read the u and v coordinates from the CSV file
uv_data = np.loadtxt('data/uv_coordinates.csv', delimiter=',', skiprows=1)

# Extract u and v coordinates
u = uv_data[:, 0]
v = uv_data[:, 1]

# Create the plot
plt.figure(figsize=(8, 6))
plt.scatter(u, v, s=1)  # Use small dots for scatter plot
plt.title('u and v Coordinates')
plt.xlabel('u')
plt.ylabel('v')

# Save the plot as a PNG file
plt.savefig('data/uv_plot.png')

# Close the plot to free memory
plt.close()
