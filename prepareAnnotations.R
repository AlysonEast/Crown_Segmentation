#### 1. Load Required Libraries ####
library(sf)
library(sp)
library(raster)

Split<-"Training"

#### Defining Paths and Preliminarly Data Processing ####
#Setting up the environment
setwd("/fs/ess/PUOM0017/ForestScaling/DeepForest")

# Read in training tile names and NEON API token
NEON_TOKEN<-read.delim("./NEON_token_AE",header = FALSE)[1,1]

# Define paths to NEON and NAIP datasets
NAIP_base_path<-"./Imagery/NAIP/"

####bounding boxes are manually annotated in QGIS ####
## Here we read those annotations back in to process and clean data for model training
# Add manually annotated boxes
bboxlist<-list.files(paste0("./Imagery/NAIP/",Split,"/bbox"), pattern = "*.shp$")
bboxlist

#Process the first entry and use it to make plots
NAIP_bbox<-read_sf(paste0("../Imagery/NAIP/",Split,"/bbox/",bboxlist[1]))

bbox_folder <- paste0("./Imagery/NAIP/",Split,"/bbox/")
crop_image_dir <- paste0("./Imagery/NAIP/",Split,"/Crop_Images/")
annotations_csv <- paste0("./Imagery/NAIP/",Split,"/Crop_Images/annotations.csv")

annotations <- data.frame(
  image_path = character(),
  xmin       = integer(),
  ymin       = integer(),
  xmax       = integer(),
  ymax       = integer(),
  label      = character(),  # e.g., "Tree"
  stringsAsFactors = FALSE
)

shapefiles <- list.files(bbox_folder, pattern = "\\.shp$", full.names = TRUE)
bboxlist <- list.files(bbox_folder, pattern = "\\.shp$", full.names = FALSE)

for (j in 1:length(shapefiles)) {
  sa <- st_read(shapefiles[j], quiet = TRUE)  #Read manual annotation (polygon or box)
  full_bb    <- st_bbox(sa)
  cropped    <- brick(paste0(crop_image_dir,substr(bboxlist[j], 1, (nchar(bboxlist[j])-4)),".tif"))
  
  #Precompute for pixel conversion
  res_xy <- res(cropped)    # e.g. (0.3, 0.3) meters/pixel
  ext_xy <- extent(cropped) # xmin, xmax, ymin, ymax in map units
  #Loop over each polygon – compute relative bbox
  for (i in seq_len(nrow(sa))) {
    feature <- sa[i, ]
    bb_f    <- st_bbox(feature)
    
    # X pixel indices
    xmin_px <- round((bb_f["xmin"] - ext_xy@xmin) / res_xy[1])
    xmax_px <- round((bb_f["xmax"] - ext_xy@xmin) / res_xy[1])
    # Y pixel indices (invert origin)
    ymin_px <- round((ext_xy@ymax - bb_f["ymax"]) / res_xy[2])
    ymax_px <- round((ext_xy@ymax - bb_f["ymin"]) / res_xy[2])
    
    # 5. Append one row per feature
    annotations <- rbind(
      annotations,
      data.frame(
        image_path = paste0(substr(bboxlist[j], 1, nchar(bboxlist[j])-15),".tif"),
        xmin       = xmin_px,
        ymin       = ymin_px,
        xmax       = xmax_px,
        ymax       = ymax_px,
        label      = "Tree",
        stringsAsFactors = FALSE
      )
    )
  }
}
table(annotations$image_path)
head(annotations)
annotations<-na.omit(annotations)
write.csv(annotations, annotations_csv, row.names = FALSE, quote = FALSE)
