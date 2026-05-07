#### 1. Load Required Libraries ####
library(sf)
library(sp)
library(terra)

#### Defining Paths and Preliminarly Data Processing ####
#Setting up the environment
setwd("/fs/ess/PUOM0017/ForestScaling/DeepForest")

# Read in training tile names and NEON API token
NEON_TOKEN<-read.delim("./NEON_token_AE",header = FALSE)[1,1]

# Define paths to NEON and NAIP datasets
NAIP_base_path<-"./Imagery/NAIP/"

splits<-c("Testing","Training")

# =============================================================================
# Step 0: Reproject all crop image TIFs to EPSG:32619 (UTM Zone 19N)
# Run once before annotation processing to ensure CRS consistency.
# Overwrites files only if reprojection is needed.
# =============================================================================
TARGET_CRS <- "EPSG:32619"

for (t in 1:2) {
  Split <- splits[t]
  crop_image_dir <- paste0("./Imagery/NAIP/", Split, "/Crop_Images/")
  tif_files <- list.files(crop_image_dir, pattern = "\\.tif$", full.names = TRUE)
  
  cat(paste0("\n--- Checking CRS for ", Split, " crop images (", length(tif_files), " files) ---\n"))
  
  for (tif in tif_files) {
    r <- rast(tif)
    current_crs <- crs(r, describe = TRUE)$authority
    current_code <- crs(r, describe = TRUE)$code
    
    if (is.na(current_code) || paste0(current_crs, ":", current_code) != TARGET_CRS) {
      cat(paste0("  Reprojecting: ", basename(tif), 
                 " [", ifelse(is.na(current_code), "NO CRS", 
                              paste0(current_crs, ":", current_code)), 
                 "] -> ", TARGET_CRS, "\n"))
      
      r_reproj <- project(r, TARGET_CRS, method = "near")  # "near" preserves uint8 values
      writeRaster(r_reproj, tif, overwrite = TRUE)
      rm(r_reproj)
    } else {
      cat(paste0("  OK: ", basename(tif), "\n"))
    }
    
    rm(r); gc()
  }
}

cat("\nAll crop images confirmed in EPSG:32619. Proceeding to annotation processing.\n")

for (t in 1:2) {
  print(paste0("processing: ",splits[t]))
  Split<-splits[t]
  
  ####bounding boxes are manually annotated in QGIS ####
  ## Here we read those annotations back in to process and clean data for model training
  # Add manually annotated boxes
  bboxlist<-list.files(paste0("./Imagery/NAIP/",Split,"/bbox"), pattern = "*.shp$")
  print(bboxlist)
  
  #Process the first entry and use it to make plots
  NAIP_bbox<-read_sf(paste0("./Imagery/NAIP/",Split,"/bbox/",bboxlist[1]))
  
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
    cropped    <- rast(paste0(crop_image_dir,substr(bboxlist[j], 1, (nchar(bboxlist[j])-4)),".tif"))
    
    #Precompute for pixel conversion
    res_xy <- res(cropped)    # e.g. (0.3, 0.3) meters/pixel
    ext_xy <- ext(cropped) # xmin, xmax, ymin, ymax in map units
    #Loop over each polygon – compute relative bbox
    for (i in seq_len(nrow(sa))) {
      feature <- sa[i, ]
      bb_f    <- st_bbox(feature)
      
      # pixel indices
      xmin_px <- max(0, round((bb_f["xmin"] - ext_xy$xmin) / res_xy[1]))
      xmax_px <- min(ncol(cropped), round((bb_f["xmax"] - ext_xy$xmin) / res_xy[1]))
      ymin_px <- max(0, round((ext_xy$ymax - bb_f["ymax"]) / res_xy[2]))
      ymax_px <- min(nrow(cropped), round((ext_xy$ymax - bb_f["ymin"]) / res_xy[2]))
      
      # 5. Append one row per feature
      annotations <- rbind(
        annotations,
        data.frame(
          image_path = paste0(paste0(substr(bboxlist[j], 1, (nchar(bboxlist[j])-4)),".tif")),
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
  print(table(annotations$image_path))
  print(head(annotations))
  annotations<-na.omit(annotations)
  write.csv(annotations, annotations_csv, row.names = FALSE, quote = FALSE)
}
