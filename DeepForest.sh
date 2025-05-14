#!/bin/bash
#SBATCH --job-name=DeepForest_train
#SBATCH --time=8:00:00 #4 hours
#SBATCH --mail-type=ALL
#SBATCH --output=./outfiles/out.deepforest_train%j
#SBATCH --account=PUOM0017

module load miniconda3/4.12.0-py38

source activate deepforest2

#python BART_30cm_NAIP_prebuilt.py
#python BART_30cm_prebuilt.py
#python BART_10cm_prebuilt.py
#

#python BART_30cm_NAIP_TrainModel.py
python BART_30cm_NAIP_Trained.py
