

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
