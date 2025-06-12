

# Deep Forest Model Scripts
DeepForest.sh
- Slurm script to run and of the deepforest model files with dependencies

DeepForest_NAIP.py
- initial drafting

BART_30cm_prebuilt.py
- running the prebuilt model on a select BART image tile that has been resampled to 30cm

BART_30cm_TrainModel.py
- Training model to see if it improves performance

# Georectification of weinstein tree annotations
TreeAnnotation.sh
- Slurm script to run and of the R file with dependencies

TreeAnnotation.R
processing data provided by https://github.com/weecology/NeonTreeEvaluation_package/tree/master

# log file of issues from initiation
deepforest_troublshoot_notes

# Imagery
This folder contains its own README for imagery processing scripts
# NEON Imagery
## Downloading
```
NEON_image_download.R
NEON_image_download.slurm
```
- Slurm script to run and of the R file with dependencies

## Resamping from native 10cm resolution to 30cm resolution
```
NEON_resample.slurm
```
- Slurm script to run the following scripts with dependencies

```
NEON_resample.sh
NEON_resample_BART.sh
```

# MAXAR
## Moving and organizing data
MAXAR data are cloned from shared Google Drive using rclone

```
MAXAR_unzip_sort_files.sh
```
unzips and organizes the zipped folders from the google drive into two folders depending on the image data type

## Extracing Bounding boxes
We do this to assess the coverage of the existing data.
```
MAXAR_bbox_run.sh
```
- submits slurm job that runs the following files in order:

```
MAXAR_extract_bbox_fromXML.sh
MAXAR_make_bbox.R
```

# NAIP
NAIP imagery was pulled from google earth engine using the following script: https://code.earthengine.google.com/1b8ec0419479e1c448f0dbd275e1a8af
BART_10cm_prebuilt.py
BART_30cm_NAIP_TrainModel.py
BART_30cm_NAIP_Trained.py
BART_30cm_NAIP_prebuilt.py
BART_30cm_prebuilt.py
BART_60cm_NAIP_prebuilt.py
DeepForest.sh
Imagery/MAXAR_bbox_run.sh
Imagery/MAXAR_extract_bbox_fromXML.sh
Imagery/MAXAR_make_bbox.R
Imagery/MAXAR_unzip_sort_files.sh
Imagery/NAIP/Training/Crop_Images/annotations.csv
Imagery/NAIP_retile.R
Imagery/NAIP_retile.slurm
Imagery/NEON_image_download.R
Imagery/NEON_image_download.slurm
Imagery/NEON_resample.sh
Imagery/NEON_resample.slurm
Imagery/NEON_resample_neon_BART.sh
Imagery/README.md
LiDAR/LiDARSegmentedTrainingCrowns.R
LiDAR/LiDAR_download.R
LiDAR/LiDAR_download.slurm
README.md
TrainingTiles
TreeAnnotation.R
TreeAnnotation.sh
deepforest_troublshoot_notes


# Crown_Segmentation
This repository implements a modular pipeline for tree crown segmentation using high-resolution aerial imagery and LiDAR data. It supports model training and evaluation with the DeepForest deep learning model and is designed to accommodate data from multiple spatial resolutions and sources, including NEON, NAIP, and MAXAR.

## Conceptual Overview
The workflow unfolds in five major phases:

1. Imagery Acquisition & Processing
Curate high-resolution remote sensing data from NEON (10 cm), NAIP (30 cm & 60 cm), and MAXAR (in development).
2. Training Data Generation
Combine curated imagery with LiDAR data to extract individual tree crowns and generate bounding boxes for supervised learning.
3. Model Implementation: DeepForest
Run the out-of-the-box DeepForest model on various imagery types. Then fine-tune DeepForest on the custom training data for domain-specific performance.
4. Prediction & Inference
Apply both pretrained and fine-tuned models to different regions and imagery types.
5. Model Comparison & Evaluation (in development)
Quantitatively evaluate and compare the performance of off-the-shelf and fine-tuned models across spatial and resolution contexts.

## 1. Imagery Acquisition & Processing
Download and process high-resolution aerial imagery:
- NEON (10 cm):
  - Download: NEON_image_download.R, NEON_image_download.slurm
  - Resample: NEON_resample.slurm → .sh scripts resample to 30/60 cm
- NAIP (30 cm / 60 cm):
  - Download via GEE: NAIP_export.js
  - Tiling and preprocessing handled in Imagery/
- MAXAR (∼30 cm RGB, in progress):
  - Unzipping and bounding box extraction: MAXAR_unzip_sort_files.sh, MAXAR_bbox_run.sh
 
## 2. Training Data Generation
- Combine imagery tiles with LiDAR-detected tree crowns from LiDARSegmentedTrainingCrowns.R
- Manual annotations from NEON (or custom) are converted into training targets using TreeAnnotation.R
- Assemble training data in developTrainingData.R, which merges tiles with annotation metadata and creates input for DeepForest

## 3. DeepForest Model Workflow
### Out-of-the-Box
- Run pretrained DeepForest on different imagery types (10 cm NEON, 30/60 cm NAIP)
- Scripts:
  - DeepForest.sh (Slurm job runner)
  -  
### Fine-Tuning
- Train DeepForest on custom annotation + imagery dataset (BART_30cm_NAIP_TrainModel.py)
- Apply trained model: BART_30cm_NAIP_Trained.py

## 4. Model Application
- Use trained and pretrained models to segment tree crowns across new tiles, sites, and imagery resolutions
- Support for batch prediction and export of results to shapefiles or GeoTIFFs (planned)

## 5. Model Comparison & Evaluation (coming soon)
- Evaluate precision, recall, and intersection-over-union (IoU) for each model run
- Compare:
  - Different image resolutions (10 cm vs 30 cm vs 60 cm)
  - Pretrained vs fine-tuned DeepForest
  - NAIP vs NEON vs MAXAR imagery

## Requirements & Dependencies
### Python: 
- Python 3.8+
- deepforest, rasterio, torch, numpy, pandas, scikit-learn

### R:
- sf, raster, rgdal, lidR, NeonTreeEvaluation, terra

### System:
- Slurm scheduler
- GDAL, PROJ (for geospatial ops)
