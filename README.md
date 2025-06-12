# Crown_Segmentation
This repository implements a modular pipeline for tree crown segmentation using high-resolution aerial imagery and LiDAR data. It supports model training and evaluation with the DeepForest deep learning model and is designed to accommodate data from multiple spatial resolutions and sources, including NEON, NAIP, and MAXAR.

## Conceptual Overview
The workflow unfolds in five major phases:

1. Imagery Acquisition & Processing
    - Curate high-resolution remote sensing data from NEON (10 cm), NAIP (30 cm & 60 cm), and MAXAR (in development).
2. Model Implementation: DeepForest
    - Run the out-of-the-box DeepForest model on various imagery types. Then fine-tune DeepForest on the custom training data for domain-specific performance.
3. Training Data Generation
    - Combine curated imagery with LiDAR data to extract individual tree crowns and generate bounding boxes for supervised learning.
4. DeepForest Model Fine-Tuning and Model Application
    - Apply both pretrained and fine-tuned models to different regions and imagery types.
5. Model Comparison & Evaluation (in development)
    - Quantitatively evaluate and compare the performance of off-the-shelf and fine-tuned models across spatial and resolution contexts.

## 1. Imagery Acquisition & Processing
Download and process high-resolution aerial imagery, housed in: ```./Imagery/```
- NEON (10 cm):
  - Download: `NEON_image_download.R`
    - job submitted by: `NEON_image_download.slurm` with dependencies
  - Resample: `NEON_resample.sh` scripts resample to 30/60 cm using `gdalwarp`
    - job submitted by: `NEON_resample.slurm` with dependencies
- NAIP (30 cm / 60 cm):
  - Download via GEE: https://code.earthengine.google.com/1b8ec0419479e1c448f0dbd275e1a8af
  - Tiling and preprocessing: `NAIP_retile.R`
    - GEE outputs of NAIP do not allign with the 1km x 1km tiles that NEON data are served in, so we moasic them and crop them to match the NEON tiles
    - job submitted by: `NAIP_retile.slurm` with dependencies
- MAXAR (∼30 cm RGB, in progress):
  - Unzipping and : `MAXAR_unzip_sort_files.sh`
  - Bounding box extraction: `MAXAR_extract_bbox_fromXML.sh` `MAXAR_bbox_run.sh`, `MAXAR_make_bbox.R`
    - We do this to assess the coverage of the existing data

## 2. DeepForest Model Workflow
### Out-of-the-Box
- Run pretrained DeepForest on different imagery types (10 cm NEON, 30/60 cm NAIP)
- Script naming convention: `<Site>_<spatialResolution>_<dataSource>_prebuilt.py`
- Scripts:
  - DeepForest.sh (Slurm job runner)
  - NEON Data
    - BART_10cm_prebuilt.py
      - First pass model run to ensure that outputs look reasonable on the data the model was trained on
    - BART_30cm_prebuilt.py
      - First pass model run look at the effects of 30cm data instead of 10 cm (had not finished processing NAIP imagry yet)
  -NAIP Data
    - BART_30cm_NAIP_prebuilt.py
      - Run out of the box model on 30cm NAIP imagery at Bartlett Forest.
    - BART_60cm_NAIP_prebuilt.py
      - Run out of the box model on 60cm NAIP imagery at Bartlett Forest.

## 3. Training Data Generation
- Assemble training data in `developTrainingData.R`, which merges tiles with annotation metadata and creates input for DeepForest
  - Development of training data uses a suite of NEON data products to aid in visual assessment, including LIDAR and field data
    - LiDAR data download: `LiDAR/LiDAR_download.R` submitted by `LiDAR/LiDAR_download.slurm`
  
## 4. DeepForest Model Fine-Tuning and Model Application
- Train DeepForest on custom annotation + imagery dataset (`BART_30cm_NAIP_TrainModel.py`)
- Apply trained model: `BART_30cm_NAIP_Trained.py`

- Use trained and pretrained models to segment tree crowns across new tiles, sites, and imagery resolutions
- Support for batch prediction and export of results to shapefiles or GeoTIFFs (planned)

## 5. Model Comparison & Evaluation (coming soon)
- Evaluate precision, recall, and intersection-over-union (IoU) for each model run
- Compare:
  - Different image resolutions (10 cm vs 30 cm vs 60 cm)
  - Pretrained vs fine-tuned DeepForest
  - NAIP vs NEON vs MAXAR imagery

## Other Scripts
### Georectification of Weinstein tree annotations
`TreeAnnotation.sh`
- Slurm script to run and of the R file with dependencies
- TreeAnnotation.R processing data provided by https://github.com/weecology/NeonTreeEvaluation_package/tree/master

## Requirements & Dependencies
### Python: 
- Python 3.8+
- deepforest, rasterio, torch, numpy, pandas, scikit-learn

### R:
- sf, raster, rgdal, lidR, NeonTreeEvaluation, terra

### System:
- Slurm scheduler
- GDAL, PROJ (for geospatial ops)
