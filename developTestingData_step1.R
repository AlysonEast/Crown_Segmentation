#### 1. Load Required Libraries ####
library(lidR) 
library(neonUtilities)
library(neonOS)
#devtools::install_github("NEONScience/NEON-geolocation/geoNEON")
library(geoNEON)
library(terra)
library(sf)
library(sp)
library(raster)
library(rgl)
library(EBImage)

#### 2. Defining Paths and Preliminarly Data Processing ####
#Setting up the environment
setwd("/media/aly/Penobscot/ForestScaling/Crown_Segmentation/LiDAR")

# Read in Testing tile names and NEON API token
Testing_tiles<-read.delim("../TestingTiles",header = FALSE)
NEON_TOKEN<-read.delim("../NEON_token_AE",header = FALSE)[1,1]

# Define paths to NEON and NAIP datasets
LAS_base_path<-"./NEON/HARV/DP1.30003.001/neon-aop-products/2022/FullSite/D01/2022_HARV_7/L1/DiscreteLidar/ClassifiedPointCloud/"
CHM_base_path<-"./NEON/HARV/DP3.30015.001/neon-aop-products/2022/FullSite/D01/2022_HARV_7/L3/DiscreteLidar/CanopyHeightModelGtif/"
DTM_base_path<-"./NEON/HARV/DP3.30024.001/neon-aop-products/2022/FullSite/D01/2022_HARV_7/L3/DiscreteLidar/DTMGtif/"
NAIP_base_path<-"../Imagery/NAIP/HARV/"
NEON_base_path<-"../Imagery/NEON/DP3.30010.001/neon-aop-products/2022/FullSite/D01/2022_HARV_7/L3/Camera/Mosaic/"
bbox_base_path<-"/media/aly/Penobscot/NEON/Crowns_Weinstein/predictions"

# Load high-res imagery from NEON and NAIP at multiple resolutions
NEON_10<-brick(paste0(NEON_base_path,"2022_HARV_7_",Testing_tiles[1,1],"_image.tif"))
NAIP_30<-brick(paste0(NAIP_base_path,"30cm/match_NEON/NAIP_30cm_HARV_7_",Testing_tiles[1,1],".tif"))
#NAIP_60<-brick(paste0(NAIP_base_path,"60cm/match_NEON/NAIP_60cm_HARV_7_",Testing_tiles[1,1],".tif"))

# Visual inspection of NAIP
plotRGB(NAIP_30)

# Reproject NAIP to match NEON 10 cm raster
NAIP_30_utm <- raster::projectRaster(from = NAIP_30, 
                                 to = NEON_10,
                                 method = "ngb")

#### Format bounding boxes that are manually annotated in QGIS ####
## Here we read those annotations back in to process and clean data for model Testing
# Add manually annotated boxes
bboxlist<-list.files("../Imagery/NAIP/Testing/bbox", pattern = "*.shp")
bboxlist

#Process the first entry and use it to make plots
NAIP_bbox<-read_sf(paste0("../Imagery/NAIP/Testing/bbox/",bboxlist[1]))
buffered_box <- st_bbox(NAIP_bbox)
bbox_crop <- extent(buffered_box)

#### 6. Cleaning and generating DeepForest Annotations for Testing
NEON_10_2<-brick(paste0(NEON_base_path,"2022_HARV_7_",Testing_tiles[2,1],"_image.tif"))
NAIP_30_2<-brick(paste0(NAIP_base_path,"30cm/match_NEON/NAIP_30cm_HARV_7_",Testing_tiles[2,1],".tif"))
NAIP_30_2_utm <- raster::projectRaster(from = NAIP_30_2, 
                                       to = NEON_10_2,
                                       method = "ngb")

bbox_folder <- "../Imagery/NAIP/Testing/bbox/"
naip_raster_path <- "../Imagery/NAIP/HARV/NAIP_30cm_HARV_7_<tile>.tif"
crop_image_dir <- "../Imagery/NAIP/Testing/Crop_Images/"
annotations_csv <- "../Imagery/NAIP/Testing/Crop_Images/annotations.csv"

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

naip_rasters <- list(NAIP_30_utm, NAIP_30_2_utm)

for (j in seq_along(shapefiles)) {
  sa <- st_read(shapefiles[j], quiet = TRUE)
  bb <- st_bbox(sa)
  cropped <- NULL
  
  # Try to find a raster that overlaps the bounding box
  for (r in naip_rasters) {
    if (!is.null(raster::intersect(extent(r), extent(bb)))) {
      cropped <- crop(r, extent(bb))
      break
    }
  }
  
  if (is.null(cropped)) {
    warning(paste("No raster overlaps shapefile", shapefiles[j]))
    next
  }
  
  names(cropped) <- c("Red", "Green", "Blue")
  out_name <- paste0(
    crop_image_dir,
    substr(bboxlist[j], 1, nchar(bboxlist[j]) - 15),
    ".tif"
  )
  writeRaster(cropped, out_name, overwrite = TRUE, datatype = "INT1U")
  
  # Pixel conversion, annotation block stays the same...
  res_xy <- res(cropped)
  ext_xy <- extent(cropped)
  for (i in seq_len(nrow(sa))) {
    feature <- sa[i, ]
    bb_f <- st_bbox(feature)
    xmin_px <- round((bb_f["xmin"] - ext_xy@xmin) / res_xy[1])
    xmax_px <- round((bb_f["xmax"] - ext_xy@xmin) / res_xy[1])
    ymin_px <- round((ext_xy@ymax - bb_f["ymax"]) / res_xy[2])
    ymax_px <- round((ext_xy@ymax - bb_f["ymin"]) / res_xy[2])
    
    annotations <- rbind(
      annotations,
      data.frame(
        image_path = basename(out_name),
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
annotations$label<-"Tree"
annotations<-na.omit(annotations)
write.csv(annotations, annotations_csv, row.names = FALSE, quote = FALSE)
