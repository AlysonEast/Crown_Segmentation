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

#Geospatial packages
import shapely
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
tiles_df = pd.read_csv("HARV_tilesOverlap.csv")

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

###################################################Patch size = 200 px, 0.3m res, 60m focal####################################
for tile in tiles_df["TileID"]:
    # Split tile ID: e.g., "2022_HARV_7_724000_4705000"
    parts = tile.split("_")
    if len(parts) < 5:
        print(f"Skipping malformed TileID: {tile}")
        continue
    
    SITE = parts[1]
    PANNEL = f"{parts[3]}_{parts[4]}"
    
    raster_path = f"/fs/ess/PUOM0017/ForestScaling/DeepForest/Imagery/{PRODUCT}/{SITE}/30cm/match_NEON/{PRODUCT}_30cm_{SITE}_7_{PANNEL}.tif"
    
    if not os.path.exists(raster_path):
        print(f"Raster not found for {tile}, skipping...")
        continue

    print(f"Processing tile: {tile}")
    
    # Read image for shape check (optional)
    raster = Image.open(raster_path)
    numpy_image = np.array(raster)
    print(f"Image shape: {numpy_image.shape}")
    
    for OVERLAP in OVERLAP_VALUES:
        print(f"Running inference with PATCH={PATCH}, OVERLAP={OVERLAP}")
        prediction = model.predict_tile(raster_path, patch_size=PATCH, patch_overlap=OVERLAP)
        boxes = project(raster_path, prediction)

        output_path = f"/fs/ess/PUOM0017/ForestScaling/DeepForest/Outputs/{PRODUCT}{int(RES*100)}cm_trained_model_p{PATCH}_o{int(OVERLAP*1000):03d}_t005_f{int(PATCH * RES)}_{SITE}_{PANNEL}.shp"
        boxes.to_file(output_path, driver="ESRI Shapefile")

################################################################################################################################
