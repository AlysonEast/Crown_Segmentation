#!/bin/bash
#SBATCH --job-name=Download_Neon_Image
#SBATCH --time=12:00:00 #4 hours
#SBATCH --mail-type=ALL
#SBATCH --output=out.%j
#SBATCH --account=PUOM0017

module load gdal/3.3.1
module load sqlite/3.36.0
module load proj/8.1.0
module load R/4.4.0-gnu11.2

Rscript NEON_image_download.R
