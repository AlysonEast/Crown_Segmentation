#!/bin/bash
#SBATCH --job-name=Annotations
#SBATCH --time=1:00:00 #1 hour
#SBATCH --mail-type=ALL
#SBATCH --output=out_BartAnnotations.%j
#SBATCH --account=PUOM0017


module load gdal/3.3.1
module load sqlite/3.36.0
module load proj/8.1.0
module load R/4.4.0-gnu11.2

#Beacsue the R file appends to the all_annotations shapefile
#we need to remove the previous version before rerunning
rm ./Weinstein/all_annotations.dbf
rm ./Weinstein/all_annotations.prj
rm ./Weinstein/all_annotations.shp
rm ./Weinstein/all_annotations.shx

Rscript TreeAnnotation.R 
