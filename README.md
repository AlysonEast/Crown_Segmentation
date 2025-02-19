

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

# NEON Imagery
## Downloading
Imagery/NEON_image_download.slurm
- Slurm script to run and of the R file with dependencies

Imagery/NEON_image_download.R
## Resamping from native 10cm resolution to 30cm resolution
Imagery/resample_neon.slurm
- Slurm script to run and of the R file with dependencies

Imagery/resample_neon.sh
Imagery/resample_neon_BART.sh

# log file of issues from initiation
deepforest_troublshoot_notes
