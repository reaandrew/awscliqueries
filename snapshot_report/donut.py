import matplotlib.pyplot as plt
from matplotlib.offsetbox import OffsetImage, AnnotationBbox
from PIL import Image
import numpy as np

# Sample data
sizes = [30, 20, 25, 25]
labels = ['A', 'B', 'C', 'D']

# Create a pie chart
fig, ax = plt.subplots()
ax.pie(sizes, labels=labels, startangle=90, wedgeprops=dict(width=0.3))

# Load the cloud image
img = Image.open("cloud.png")  # Replace with your cloud image path
img = img.resize((70, 70))  # Resize image to fit the donut hole

# Create an offset image
imagebox = OffsetImage(img, zoom=1)
ab = AnnotationBbox(imagebox, (0, 0), frameon=False, boxcoords="data", pad=0)

# Add the image to the plot
ax.add_artist(ab)

# Equal aspect ratio ensures that pie is drawn as a circle.
ax.axis('equal')

plt.savefig('output.png')