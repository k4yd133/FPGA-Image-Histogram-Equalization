from PIL import Image
import numpy as np

img = Image.open("C:\\Users\\admin\\OneDrive\\Desktop\\General\\Đồ án Thiết kế luận lý HDL\\3840x2160.webp").convert("L")
pixels = np.array(img).flatten()

with open("image_data3840x2160.mem", "w") as f:
    for p in pixels:
        f.write(f"{p:02x}\n")

