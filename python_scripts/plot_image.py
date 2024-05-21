import numpy as np
import matplotlib.pyplot as plt

# Read the image data from the CSV file
image_data = np.loadtxt('data/image_data_gpu.csv', delimiter=',')

# Create the plot
plt.imshow(image_data, cmap='gray')
plt.colorbar()
plt.title('Image from FFT')

# Save the plot as a PNG file
plt.savefig('data/plot_image_gpu.png')

# Close the plot to free memory
plt.close()