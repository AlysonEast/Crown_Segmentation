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
os.chdir('/fs/ess/PUOM0017/ForestScaling/DeepForest')

SITE = "BART"
PRODUCT = "NAIP"
RES = 0.3
RES_CM = int(RES * 100)
EPOCHS = 50

#Load the pretrained model
prebuilt_model = main.deepforest()
prebuilt_model.use_release()

#Predict entire tile
prebuilt_model.config["score_threshold"] = 0.05

##################################################Model Training##############################################################
##Format training annotations
#Write converted dataframe to file. Saved alongside the images
crop_dir = "./Imagery/NAIP/Training/Crop_Images/"

#Write window annotations file without a header row, same location as the "base_dir" above.
annotations_file= os.path.join(crop_dir, "annotations.csv")
annotations_df = pd.read_csv(annotations_file)
sample_image = os.path.join(crop_dir, annotations_df["image_path"].iloc[0])

##Train Model
# Example run with short training
prebuilt_model.config["epochs"] = EPOCHS
prebuilt_model.config["save-snapshot"] = False
#prebuilt_model.train(annotations=annotations_file, input_type="fit_generator")
prebuilt_model.config["train"]["csv_file"] = annotations_file
prebuilt_model.config["train"]["root_dir"] = os.path.dirname(annotations_file)

prebuilt_model.create_trainer()
prebuilt_model.config["train"]["fast_dev_run"] = False
prebuilt_model.trainer.fit(prebuilt_model)
pred_after_train = prebuilt_model.predict_image(path = sample_image)

#Create a trainer to make a checkpoint
tmpdir = tempfile.TemporaryDirectory()
prebuilt_model.trainer.save_checkpoint(f"{tmpdir.name}/checkpoint.ckpt")

#reload the checkpoint to model object
after = main.deepforest.load_from_checkpoint(f"{tmpdir.name}/checkpoint.ckpt")
pred_after_reload = after.predict_image(path = sample_image)

assert not pred_after_train.empty
assert not pred_after_reload.empty
pd.testing.assert_frame_equal(pred_after_train,pred_after_reload)

model_path = f"./TrainedModels/{PRODUCT}_{RES_CM}cm_trained.pt"
os.makedirs(os.path.dirname(model_path), exist_ok=True)
torch.save(prebuilt_model.model.state_dict(), model_path)
