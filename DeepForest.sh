#!/bin/bash
#SBATCH --job-name=DeepForest
#SBATCH --time=3-00:00:00 #7 days
#SBATCH --mail-type=ALL
#SBATCH --output=./outfiles/out.BART_30cm_NAIP_Trained%j
#SBATCH --account=PUOM0017

#module load miniconda3/4.12.0-py38
module load miniconda3/24.1.2-py310

source activate deepforest2

#prebulit
#python BART_30cm_NAIP_prebuilt.py
#python BART_30cm_prebuilt.py
#python BART_10cm_prebuilt.py


#Train
#python BART_30cm_NAIP_TrainModel.py

#Evaluate
#python HARV_30cm_NAIP_Trained_Evaluate.py

#Trained Models
python BART_30cm_NAIP_Trained.py
#python HARV_30cm_NAIP_Trained.py
