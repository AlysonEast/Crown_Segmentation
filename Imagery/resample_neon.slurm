#!/bin/bash
#SBATCH --job-name=resample_neon
#SBATCH --time=12:00:00 #4 hours
#SBATCH --mail-type=ALL
#SBATCH --output=resample.out.%j
#SBATCH --account=PUOM0017

module load gdal/3.3.1
module load sqlite/3.36.0
module load proj/8.1.0

./resample_neon.sh
