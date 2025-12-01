# Crown Segmentation

> **⚠️ DEVELOPMENT STATUS:** This repository is under active development. Scripts, file paths, and workflows are subject to change. Please report issues or suggestions via GitHub Issues.

This repository implements a modular pipeline for tree crown segmentation using high-resolution aerial imagery and LiDAR data. It supports model training and evaluation with the [DeepForest](https://github.com/weecology/DeepForest) deep learning model and is designed to accommodate data from multiple spatial resolutions and sources, including NEON, NAIP, and MAXAR.

## Conceptual Overview
The workflow unfolds in five major phases:

1. **Imagery Acquisition & Processing** - Curate high-resolution remote sensing data from NEON (10 cm), NAIP (30 cm & 60 cm), and MAXAR (in development).
2. **Model Implementation** DeepForest - Run the out-of-the-box DeepForest model on various imagery types, then fine-tune on custom training data
3. **Training Data Generation** - Combine curated imagery with LiDAR data to extract individual tree crowns and generate bounding boxes for supervised learning
4. **DeepForest Model Fine-Tuning and Application** - Apply both pretrained and fine-tuned models to different regions and imagery types
5. **Model Comparison & Evaluation** (in development) - Quantitatively evaluate and compare the performance of off-the-shelf and fine-tuned models across spatial and resolution contexts


---

## Data Requirements

### Input Data Sources

This pipeline requires multiple types of geospatial data. Below are details on each data source, including acquisition methods, formats, and storage considerations.

#### 1. **NEON Aerial Imagery (RGB)**
- **Resolution:** 10 cm (native), resampled to 30 cm and 60 cm for multi-resolution analysis
- **Format:** GeoTIFF (.tif)
- **Acquisition:** Downloaded via NEON Data Portal API
  - **Data Product:** [DP3.30010.001](https://data.neonscience.org/data-products/DP3.30010.001) (High-resolution orthorectified camera imagery mosaic)
  - **Scripts:** `Imagery/NEON_image_download.R`, submitted via `Imagery/NEON_image_download.slurm`
- **Resampling:** Use `NEON_resample.sh` (submitted via `NEON_resample.slurm`) to resample from 10 cm to 30 cm and 60 cm using `gdalwarp`
- **Coordinate System:** UTM (zone varies by site; e.g., UTM Zone 19N for BART and HARV)
- **Tile Structure:** 1 km × 1 km tiles following NEON's naming convention
- **Storage Requirements:** ~500 GB per site for full resolution imagery

#### 2. **NAIP Imagery (RGB/RGBN)**
- **Resolution:** 30 cm and 60 cm
- **Format:** GeoTIFF (.tif)
- **Acquisition:** Downloaded from Google Earth Engine
  - **GEE Script:** https://code.earthengine.google.com/1b8ec0419479e1c448f0dbd275e1a8af
- **Processing:** 
  - NAIP imagery does not align with NEON's 1 km × 1 km tile grid
  - Use `Imagery/NAIP_retile.R` (submitted via `NAIP_retile.slurm`) to mosaic and crop NAIP tiles to match NEON tile boundaries
- **Bands:** RGB (3-band) or RGBN (4-band, includes Near-Infrared)
- **Coordinate System:** Must be reprojected to match NEON imagery (UTM)
- **Storage Requirements:** ~200 GB per site

#### 3. **NEON LiDAR Data**
LiDAR data is essential for training data generation, crown height extraction, and filtering detections below canopy height thresholds.

- **Classified Point Cloud (LAS/LAZ)**
  - **Data Product:** [DP1.30003.001](https://data.neonscience.org/data-products/DP1.30003.001)
  - **Format:** LAZ (compressed LAS)
  - **Use:** Tree segmentation, canopy structure analysis
  - **Scripts:** `LiDAR/LiDAR_download.R`, submitted via `LiDAR/LiDAR_download.slurm`

- **Canopy Height Model (CHM)**
  - **Data Product:** [DP3.30015.001](https://data.neonscience.org/data-products/DP3.30015.001)
  - **Format:** GeoTIFF (.tif)
  - **Resolution:** 1 m
  - **Use:** Filtering crown detections (removing detections where CHM < 3 m), extracting tree heights
  
- **Digital Terrain Model (DTM)**
  - **Data Product:** [DP3.30024.001](https://data.neonscience.org/data-products/DP3.30024.001)
  - **Format:** GeoTIFF (.tif)
  - **Use:** Normalizing point cloud heights

- **Coordinate System:** Same UTM zone as imagery
- **Storage Requirements:** ~100 GB per site for all LiDAR products

#### 4. **MAXAR Commercial Satellite Imagery** (In Development)
- **Resolution:** ~30 cm (pan-sharpened RGB)
- **Format:** GeoTIFF (.tif) with XML metadata
- **Acquisition:** Obtained via institutional access or commercial license
- **Processing:**
  - `Imagery/MAXAR_unzip_sort_files.sh` - Unzips and organizes data into Mono and RGB folders
  - `Imagery/MAXAR_extract_bbox_fromXML.sh` and `MAXAR_make_bbox.R` - Extracts bounding boxes from XML metadata to assess coverage
- **Bands:** RGB, RGB+NIR, RGB+NIR+SWIR (depending on product)
- **Status:** Coverage assessment in progress; full integration pending

#### 5. **Manual Tree Annotations (Training/Testing Data)**
- **Format:** Shapefiles (.shp) with bounding box polygons
- **Creation:** Manual annotation in QGIS using imagery and LiDAR products as reference
- **Annotation Support:** `developTrainingData.R` assists with visualization and data preparation
  - Uses NEON field data, LiDAR-derived tree crowns (via `lidR` watershed segmentation), and existing crown annotations from [Weinstein et al. (2019)](https://zenodo.org/records/3765872)
- **Storage Location:**
  - Training: `./Imagery/NAIP/Training/bbox/`
  - Testing: `./Imagery/NAIP/Testing/bbox/`
- **Expected Format:** Each shapefile contains polygons representing individual tree crowns with an optional `label` column (defaults to "Tree")

### Storage and Directory Structure

Expected directory structure for organizing data:

```
Crown_Segmentation/
├── Imagery/
│   ├── NEON/
│   │   └── DP3.30010.001/neon-aop-products/YYYY/FullSite/DXX/YYYY_SITE_X/L3/Camera/Mosaic/
│   │       └── YYYY_SITE_X_XXXXXX_image.tif
│   ├── NAIP/
│   │   ├── SITE/
│   │   │   ├── 30cm/match_NEON/
│   │   │   │   └── NAIP_30cm_SITE_X_XXXXXX.tif
│   │   │   └── 60cm/match_NEON/
│   │   │       └── NAIP_60cm_SITE_X_XXXXXX.tif
│   │   ├── Training/
│   │   │   ├── bbox/           # Manual annotations for training
│   │   │   └── Crop_Images/    # Cropped training images and annotations.csv
│   │   └── Testing/
│   │       └── bbox/            # Manual annotations for testing
│   └── MAXAR/
│       ├── RGB/
│       └── Mono/
├── LiDAR/
│   └── NEON/
│       └── SITE/
│           ├── DP1.30003.001/.../ClassifiedPointCloud/
│           ├── DP3.30015.001/.../CanopyHeightModelGtif/
│           └── DP3.30024.001/.../DTMGtif/
├── Outputs/
│   └── PRODUCT/
│       └── SITE/
│           └── [model output shapefiles]
└── Shapefiles/
    ├── LiDAR_Tiles.shp          # Reference tiles for processing
    └── SITE_AOP.shp             # AOP coverage extent
```
### Data Access

- **NEON Data:** Free and publicly available via [NEON Data Portal](https://data.neonscience.org/)
- **NAIP Data:** Free via [Google Earth Engine](https://earthengine.google.com/) or [USDA NAIP](https://naip-usdaonline.hub.arcgis.com/)
- **MAXAR Data:** Requires commercial license or institutional access

---

## Workflow Details

### 1. Imagery Acquisition & Processing

#### NEON Imagery (10 cm)
```bash
# Download imagery
Rscript Imagery/NEON_image_download.R
# Or submit as SLURM job
sbatch Imagery/NEON_image_download.slurm

# Resample to 30 cm and 60 cm
sbatch Imagery/NEON_resample.slurm
```

#### NAIP Imagery (30 cm / 60 cm)
1. Download via Google Earth Engine: https://code.earthengine.google.com/1b8ec0419479e1c448f0dbd275e1a8af
2. Retile to match NEON grid:
```bash
Rscript Imagery/NAIP_retile.R
# Or submit as SLURM job
sbatch Imagery/NAIP_retile.slurm
```

#### MAXAR Imagery (In Development)
```bash
# Unzip and organize files
bash Imagery/MAXAR_unzip_sort_files.sh

# Extract bounding boxes for coverage assessment
bash Imagery/MAXAR_bbox_run.sh
```

### 2. DeepForest Model Workflow
#### Out-of-the-Box Pretrained Model
Run the pretrained DeepForest model on different imagery types to establish baseline performance.

**Script naming convention:** `<Site>_<spatialResolution>_<dataSource>_prebuilt.py`

**Examples:**
- `BART_10cm_prebuilt.py` - Validate model on NEON 10 cm imagery (model training resolution)
- `BART_30cm_prebuilt.py` - Test model on resampled NEON 30 cm imagery
- `BART_30cm_NAIP_prebuilt.py` - Test model on NAIP 30 cm imagery
- `BART_60cm_NAIP_prebuilt.py` - Test model on NAIP 60 cm imagery

**Submission:**
```bash
sbatch DeepForest.sh
```

### 3. Training Data Generation

Manual annotation of tree crowns in QGIS is supported by automated data preparation and visualization.

**Script:** `developTrainingData.R`

**Workflow:**
1. Load NEON and NAIP imagery at multiple resolutions
2. Load LiDAR products (LAS point cloud, CHM, DTM)
3. Perform automated tree crown segmentation using `lidR::watershed()` for visual reference
4. Load existing tree crown annotations (e.g., [Weinstein et al. 2019](https://zenodo.org/records/3765872))
5. Visualize field data (growth form, canopy position) overlaid on imagery
6. Manually annotate tree crowns in QGIS as bounding box polygons
7. Convert annotations to DeepForest training format (CSV with image-relative coordinates)

**Key Functions:**
- `shapefile_to_annotations()` - Converts QGIS shapefiles to DeepForest annotation CSV
- **Output:** `./Imagery/NAIP/Training/Crop_Images/annotations.csv`

**LiDAR Download:**
```bash
Rscript LiDAR/LiDAR_download.R
# Or submit as SLURM job
sbatch LiDAR/LiDAR_download.slurm
```
  
### 4. DeepForest Model Fine-Tuning and Application

#### Train Custom Model
**Script:** `BART_30cm_NAIP_TrainModel.py`

Trains a DeepForest model on custom annotations from BART (New Hampshire) for geographic generalization testing on HARV (Massachusetts).

#### Apply Trained Model
**Scripts:** 
- `BART_30cm_NAIP_Trained.py` - Apply trained model to BART site
- `HARV_30cm_NAIP_Trained.py` - Apply trained model to HARV site

**Key Features:**
- Runs inference with configurable patch size and overlap
- Filters detections using CHM (removes detections where canopy height < 3 m)
- Outputs shapefiles with tree crown bounding boxes

**Output Format:** `{PRODUCT}{resolution}cm_trained_model_p{PATCH}_o{OVERLAP}_t005_f{field_of_view}_{SITE}_{TILE}.shp`

**Example:**
```
NAIP30cm_trained_model_p400_o050_t005_f120_BART_123456.shp
```

### 5. Model Comparison & Evaluation

Model evaluation is performed using DeepForest's built-in evaluation framework, comparing predictions against manually annotated ground truth data from geographically isolated test sites.

#### Evaluation Script
**Script:** `HARV_30cm_NAIP_Trained_Evaluate.py`

This script evaluates trained models on test annotations from HARV (Massachusetts), having been trained on BART (New Hampshire) data for geographic generalization testing.

**Key Features:**
- Loads trained model weights from `./TrainedModel`
- Runs inference on test images from `./Imagery/NAIP/Testing/Crop_Images/`
- Computes evaluation metrics using DeepForest's `evaluate.evaluate_boxes()` function
- Generates visualization plots comparing predictions vs ground truth
- Exports detailed results to CSV

**Evaluation Metrics:**
- **Intersection over Union (IoU)** - Spatial overlap between predicted and ground truth bounding boxes
- **Mean Average Precision (mAP)** - Detection accuracy across confidence thresholds (in development)
- **Precision** - Proportion of correct detections among all predictions (True Positives / All Predictions)
- **Recall** - Proportion of ground truth trees successfully detected (True Positives / All Ground Truth)
- **True Positive Count** - Number of correctly detected trees

**Outputs:**
- `HARV_Eval_Detections.csv` - Detailed detection results per tree
- `HARV_Eval_Figures/` - Visualization plots showing predictions (pink/salmon) overlaid on ground truth (white) for each test image


## Outputs and Downstream Use

### Crown Segmentation Outputs

DeepForest model outputs are shapefiles containing tree crown bounding boxes:

**Attributes:**
- `geometry` - Bounding box polygon (UTM coordinates)
- `score` - Model confidence score (0-1)
- `label` - Tree label (default: "Tree")

**Location:** `./Outputs/{PRODUCT}/{SITE}/`

### Integration with ScalingAcrossResolutions Repository

Crown segmentation outputs from this repository feed into the [ScalingAcrossResolutions](#) repository for size-abundance analysis. The downstream workflow:

1. **Crown Metrics Calculation** (`GenerateDatasetsIndv.R`)
   - Assigns crowns to 1-hectare grid cells
   - Calculates crown area, perimeter, and diameter
   - Extracts tree height from CHM
   - Estimates diameter at breast height (DBH) using allometric equations

2. **Exported Data Format:** CSV files with columns:
   - `crown_id` - Unique crown identifier
   - `grid_id` - 1-hectare grid cell assignment
   - `Area` - Crown area (m²)
   - `Perimeter` - Crown perimeter (m)
   - `Diameter` - Crown diameter (m)
   - `Max_Height` - Maximum tree height from CHM (m)
   - `DBH` - Estimated diameter at breast height (cm)

3. **Output Location:** `../ScalingAcrossResolutions/CrownDatasets/`

These tree-level metrics enable Bayesian size-abundance modeling to recover complete forest size distributions from remotely sensed data, addressing canopy occlusion biases. See the [ScalingAcrossResolutions repository](#) for details on size-abundance parameter recovery.

---

## Other Scripts

### Georectification of Weinstein Tree Annotations
- **Script:** `TreeAnnotation.R`
- **Submission:** `TreeAnnotation.sh`
- **Purpose:** Process tree crown annotations from [Weinstein et al. (2019)](https://github.com/weecology/NeonTreeEvaluation_package/tree/master) for use as reference data

---

## Requirements & Dependencies

### Python
- Python 3.8+
- `deepforest` - Deep learning tree crown detection
- `rasterio` - Geospatial raster I/O
- `geopandas` - Vector geospatial operations
- `torch` - PyTorch deep learning framework
- `numpy`, `pandas` - Data manipulation
- `scikit-learn` - Machine learning utilities
- `Pillow` - Image processing

### R
- `sf` - Simple features for vector data
- `raster`, `terra` - Raster data processing
- `rgdal` - Geospatial data abstraction
- `lidR` - LiDAR data processing
- `itcSegment` - Individual tree crown segmentation
- `neonUtilities` - NEON data access
- `geoNEON` - NEON geolocation utilities

### System
- **SLURM scheduler** - For HPC job submission
- **GDAL** - Geospatial data abstraction library
- **PROJ** - Cartographic projections library

---
## Citations

- **DeepForest:** Weinstein, B.G., et al. (2019). Individual tree-crown detection in RGB imagery using semi-supervised deep learning neural networks. *Remote Sensing*, 11(11), 1309.
- **NEON:** National Ecological Observatory Network. https://www.neonscience.org/

---
