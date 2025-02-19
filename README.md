

# Deep Forest Model Scripts
DeepForest.sh
- Slurm script to run and of the deepforest model files with dependancies
DeepForest_NAIP.py
- inital drafting
BART_30cm_prebuilt.py
- running the prebuilt model on a select BART image tile that has been resampled to 30cm
BART_30cm_TrainModel.py
- Training model to see if it impproves performance

# Georectification of weinstein tree annotations
TreeAnnotation.sh
- Slurm script to run and of the R file with dependancies
TreeAnnotation.R
processing data provieded by https://github.com/weecology/NeonTreeEvaluation_package/tree/master

# NEON Imagery
## Downloading
Imagery/NEON_image_download.slurm
- Slurm script to run and of the R file with dependancies
Imagery/NEON_image_download.R
## resamping from native 10cm resolution to 30cm resolution
Imagery/resample_neon.slurm
- Slurm script to run and of the R file with dependancies
Imagery/resample_neon.sh
Imagery/resample_neon_BART.sh

# log file of issues from initation
deepforest_troublshoot_notes
