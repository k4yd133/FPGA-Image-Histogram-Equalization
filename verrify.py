import numpy as np
from PIL import Image

# The resolution of image (must be exactly equal to T_TOTAL in TB)
width, height = 64,64

with open("output_image.txt", "r") as f:
    # read hex row -> int
    data = [int(line.strip(), 16) for line in f if line.strip()]

# convert to numpy and save image
img_array = np.array(data, dtype=np.uint8).reshape((height, width))
img = Image.fromarray(img_array)
img.save("result_equalized.png")
print("Done! Open file result_equalized.png to see the result.")