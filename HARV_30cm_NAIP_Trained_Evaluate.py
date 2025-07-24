#Load packages
import numpy as np
from PIL import Image
import os
from matplotlib import pyplot as plt

#Load deepforest
#Optional comet_ml for tracking experiments
#from comet_ml import Experiment
import deepforest
from deepforest import utilities
from deepforest import main
from deepforest import preprocess
from deepforest import utilities
from deepforest import __version__
from deepforest import evaluate
from deepforest import get_data
from deepforest import visualize

#Geospatial packages
import shapely
from shapely.geometry import box

import geopandas
import rasterio
#import descartes 

import tempfile
import torch
import pandas as pd

seed = 42
#np.random.seed(seed)
#random.seed(seed)
#torch.manual_seed(seed)


## Define geospatial function from https://gist.github.com/bw4sz/e2fff9c9df0ae26bd2bfa8953ec4a24c
#"project" into layer CRS to overlap with street trees. This isn't really a projection but a translation of the coordinate system
#Here is a simple utility function for reading in annotation files from .shp. This is not pre-installed in DeepForest since it relies on GDAL python packages, which can be tricky to prebuild for multiple operating systems and are only needed for this task. See http://geopandas.org/install.html.
def project(raster_path, boxes):
    """
    Convert image coordinates into a geospatial object to overlap with input image
    raster_path: path to the raster .tif on disk. Assumed to have a valid spatial projection
    boxes: a prediction pandas dataframe from deepforest.predict_tile()
    """
    with rasterio.open(raster_path) as dataset:
        bounds = dataset.bounds
        pixelSizeX, pixelSizeY  = dataset.res

    #subtract origin. Recall that numpy origin is top left! Not bottom left.
    boxes["left"] = (boxes["xmin"] *pixelSizeX) + bounds.left
    boxes["right"] = (boxes["xmax"] * pixelSizeX) + bounds.left
    boxes["top"] = bounds.top - (boxes["ymin"] * pixelSizeY) 
    boxes["bottom"] = bounds.top - (boxes["ymax"] * pixelSizeY)
    
    # combine column to a shapely Box() object, save shapefile
    boxes['geometry'] = boxes.apply(lambda x: shapely.geometry.box(x.left,x.bottom,x.right,x.top), axis=1)
    boxes = geopandas.GeoDataFrame(boxes, geometry='geometry')
    
    # **Change 1: Automatically inherit CRS from raster**
    with rasterio.open(raster_path) as dataset:
        boxes.crs = dataset.crs

    return boxes

def shapefile_to_annotations(shapefile, rgb, savedir="."):
    """
    Convert a shapefile of annotations into annotations csv file for DeepForest training and evaluation
    Args:
        shapefile: Path to a shapefile on disk. If a label column is present, it will be used, else all labels are assumed to be "Tree"
        rgb: Path to the RGB image on disk
        savedir: Directory to save csv files
    Returns:
        None: a csv file is written
    """
    #Read shapefile
    gdf = geopandas.read_file(shapefile)

    #get coordinates
    df = gdf.geometry.bounds

    #raster bounds
    with rasterio.open(rgb) as src:
        left, bottom, right, top = src.bounds

    #Transform project coordinates to image coordinates
    df["tile_xmin"] = df.minx - left
    df["tile_xmin"] = df["tile_xmin"].astype(int)

    df["tile_xmax"] = df.maxx - left
    df["tile_xmax"] = df["tile_xmax"].astype(int)

    #UTM is given from the top, but origin of an image is top left

    df["tile_ymax"] = top - df.miny 
    df["tile_ymax"] = df["tile_ymax"].astype(int)

    df["tile_ymin"] = top - df.maxy
    df["tile_ymin"] = df["tile_ymin"].astype(int)    

    #Add labels is they exist
    if "label" in gdf.columns:
        df["label"] = gdf["label"]
    else:
        df["label"] = "Tree"

    #add filename
    df["image_path"] = os.path.basename(rgb)

    #select columns
    result = df[["image_path","tile_xmin","tile_ymin","tile_xmax","tile_ymax","label"]]
    result = result.rename(columns={"tile_xmin":"xmin","tile_ymin":"ymin","tile_xmax":"xmax","tile_ymax":"ymax"})
    
    #ensure no zero area polygons due to rounding to pixel size
    result = result[~(result.xmin == result.xmax)]
    result = result[~(result.ymin == result.ymax)]

    
    return result

############################################################################################################################
########################################## Setting up for standarized outputs ##############################################
############################################################################################################################
# Settings
PRODUCT = "NAIP"
RES = 0.3
# Load tile information
tiles_df = pd.read_csv("TestingTiles")
#2022_HARV_7_731000_4712000

# Initialize DeepForest
model = main.deepforest()
model.use_release = False
model.create_model()
model.model.load_state_dict(torch.load("./TrainedModel"))
model.model.eval()
model.config["score_threshold"] = 0.05

#Model Parameters
PATCH = 200
OVERLAP_VALUES = [0.25]

############################################################################################################################
########################################## Setting evaluations from training data ##########################################
############################################################################################################################

csv_file = "./Imagery/NAIP/Testing/Crop_Images/annotations.csv"
root_dir = os.path.dirname(csv_file)

predictions = model.predict_file(csv_file=csv_file, root_dir=os.path.dirname(csv_file))
predictions.head()

ground_truth = pd.read_csv(csv_file)

ground_truth['geometry'] = ground_truth.apply(lambda row: box(row['xmin'], row['ymin'], row['xmax'], row['ymax']), axis=1)
ground_truth = geopandas.GeoDataFrame(ground_truth, geometry='geometry')


result = evaluate.evaluate_boxes(
    predictions=predictions,
    ground_df=ground_truth,
    root_dir=os.path.dirname(csv_file),  # Only needed if image_path is relative
    savedir=None  # Set to a path if you want visualizations saved
)


#visualize.plot_prediction_dataframe(predictions=predictions, ground_df=ground_truth, root_dir=os.path.dirname(csv_file))

#true_positive = sum(result["match"])
#recall = true_positive / result.shape[0]
#precision = true_positive / predictions.shape[0]

print("\n=== Evaluation Results Summary ===")
print(result["results"])

#print("\n=== Precision and Recall ===")
#print(f"Recall: {recall}")
#print(f"Precision: {precision}")

print("\n=== Class Recall ===")
print(result["class_recall"])

print("\n=== Full Results Table Head ===")
print(result["results"].head())


result["results"].to_csv("HARV_Eval_Detections.csv", index=False)


################################################################################################################################

import matplotlib.patches as patches

# Create output directory for figures
os.makedirs("HARV_Eval_Figures", exist_ok=True)

# Loop through unique images in your annotations
for image_name in ground_truth["image_path"].unique():
    print(f"Plotting for image: {image_name}")
    
    # Load the image
    image_path = os.path.join(root_dir, image_name)
    image = Image.open(image_path)
    
    # Set up the plot
    fig, ax = plt.subplots(figsize=(6, 6))
    ax.imshow(image)
    ax.set_title(f"{image_name} — Predictions (Pink) vs Ground Truth (White)")

    # Plot ground truth boxes (green)
    gt_subset = ground_truth[ground_truth["image_path"] == image_name]
    for _, row in gt_subset.iterrows():
        rect = patches.Rectangle(
            (row["xmin"], row["ymin"]),
            row["xmax"] - row["xmin"],
            row["ymax"] - row["ymin"],
            linewidth=2,
            edgecolor='white',
            facecolor='none'
        )
        ax.add_patch(rect)

    # Plot prediction boxes (red)
    pred_subset = predictions[predictions["image_path"] == image_name]
    for _, row in pred_subset.iterrows():
        rect = patches.Rectangle(
            (row["xmin"], row["ymin"]),
            row["xmax"] - row["xmin"],
            row["ymax"] - row["ymin"],
            linewidth=2,
            edgecolor='lightsalmon',
            linestyle='--',
            facecolor='none'
        )
        ax.add_patch(rect)

    # Save figure
    out_path = os.path.join("HARV_Eval_Figures", f"{os.path.splitext(image_name)[0]}_eval_plot.png")
    plt.axis('off')
    plt.tight_layout()
    plt.savefig(out_path, dpi=300, bbox_inches='tight')
    plt.close()

