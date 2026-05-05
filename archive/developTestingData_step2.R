#### 1. Load Required Libraries ####
library(terra)
library(sf)
library(sp)
library(raster)

setwd("/media/aly/Penobscot/ForestScaling/Crown_Segmentation/LiDAR")

#### Format bounding boxes that are manually annotated in QGIS ####
## Here we read those annotations back in to process and clean data for model Testing
# Add manually annotated boxes
bboxlist<-list.files("../Imagery/NAIP/Testing/bbox", pattern = "*.shp")
bboxlist

#Process the first entry and use it to make plots
NAIP_bbox<-read_sf(paste0("../Imagery/NAIP/Testing/bbox/",bboxlist[1]))
buffered_box <- st_bbox(NAIP_bbox)
bbox_crop <- extent(buffered_box)

# Cleaning and generating DeepForest Annotations for Testing
bbox_folder <- "../Imagery/NAIP/Testing/bbox/"
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
crop_image_dir <- "../Imagery/NAIP/Testing/Crop_Images/"
imagelist<- list.files(crop_image_dir, pattern = "\\.tif$", full.names = TRUE)

for (j in seq_along(shapefiles)) {
  sa <- st_read(shapefiles[j], quiet = TRUE)
  bb <- st_bbox(sa)
  cropped <- brick(imagelist[j])

  ext_xy <- extent(cropped)
  res_xy <- res(cropped)
  
  out_name <- paste0(
    crop_image_dir,
    substr(bboxlist[j], 1, nchar(bboxlist[j]) - 15),
    ".tif"
  )
  
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
