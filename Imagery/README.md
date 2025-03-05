# NEON Imagery
## Downloading
NEON_image_download.R
NEON_image_download.slurm
- Slurm script to run and of the R file with dependencies

## Resamping from native 10cm resolution to 30cm resolution
Imagery/resample_neon.sh
Imagery/resample_neon_BART.sh
Imagery/resample_neon.slurm
- Slurm script to run and of the R file with dependencies

# MAXAR
## Moving and organizing data
MAXAR data are cloned from shared Google Drive using rclone
MAXAR_unzip_sort_files.sh
- unzips and organizes the zipped folders from the google drive into two folders depending on the image data type

## Extracing Bounding boxes
We do this to assess the coverage of the existing data.
MAXAR_bbox_run.sh
- submits slurm job that runs the following files in order:
MAXAR_extract_bbox_fromXML.sh
MAXAR_make_bbox.R


# NAIP
NAIP imagery was pulled from google earth engine using the following script: https://code.earthengine.google.com/1b8ec0419479e1c448f0dbd275e1a8af
