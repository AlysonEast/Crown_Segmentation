#!/bin/bash
#SBATCH --job-name=DeepForest
#SBATCH --time=4:00:00 #4 hours
#SBATCH --mail-type=ALL
#SBATCH --output=out.deepforest_test%j
#SBATCH --account=PUOM0017

module load miniconda3/4.12.0-py38

source activate deepforest2

python BART_30cm_TrainModel.py
