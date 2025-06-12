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

# Read in training tile names and NEON API token
Training_tiles<-read.delim("../TrainingTiles",header = FALSE)
NEON_TOKEN<-read.delim("../NEON_token_AE",header = FALSE)[1,1]

# Define paths to NEON and NAIP datasets
LAS_base_path<-"./NEON/BART/DP1.30003.001/neon-aop-products/2022/FullSite/D01/2022_BART_6/L1/DiscreteLidar/ClassifiedPointCloud/"
CHM_base_path<-"./NEON/BART/DP3.30015.001/neon-aop-products/2022/FullSite/D01/2022_BART_6/L3/DiscreteLidar/CanopyHeightModelGtif/"
DTM_base_path<-"./NEON/BART/DP3.30024.001/neon-aop-products/2022/FullSite/D01/2022_BART_6/L3/DiscreteLidar/DTMGtif/"
NAIP_base_path<-"../Imagery/NAIP/BART/"
NEON_base_path<-"../Imagery/NEON/DP3.30010.001/neon-aop-products/2022/FullSite/D01/2022_BART_6/L3/Camera/Mosaic/"
bbox_base_path<-"/media/aly/Penobscot/NEON/Crowns_Weinstein/predictions"

# Load the first LAS file for exploration
NEON_las<-readLAS(paste0(LAS_base_path,"NEON_D01_BART_DP1_",Training_tiles[1,1],"_classified_point_cloud_colorized.laz"))

# Create bounding box and set projection manually
sps <- as(extent(st_bbox(NEON_las)), 'SpatialPolygons')
NEON_las@crs  # Check CRS of LAS
proj4string(sps)
proj4string(sps)<-CRS(paste0("+proj=utm +zone=19 +datum=WGS84")) #This is for zone 19 utm projects

# Load NEON canopy height model and DTM
NEON_chm<-raster(paste0(CHM_base_path,"NEON_D01_BART_DP3_",Training_tiles[1,1],"_CHM.tif"))
NEON_dtm<-raster(paste0(DTM_base_path,"NEON_D01_BART_DP3_",Training_tiles[1,1],"_DTM.tif"))

# Load high-res imagery from NEON and NAIP at multiple resolutions
NEON_10<-brick(paste0(NEON_base_path,"2022_BART_6_",Training_tiles[1,1],"_image.tif"))
NAIP_30<-brick(paste0(NAIP_base_path,"30cm/match_NEON/NAIP_30cm_BART_6_",Training_tiles[1,1],".tif"))
NAIP_60<-brick(paste0(NAIP_base_path,"60cm/match_NEON/NAIP_60cm_BART_6_",Training_tiles[1,1],".tif"))

# Visual inspection of NAIP
plotRGB(NAIP_30)

# Reproject NAIP to match NEON 10 cm raster
NAIP_30_utm <- raster::projectRaster(from = NAIP_30, 
                                 to = NEON_10,
                                 method = "ngb")
# Side-by-side view of aligned images
par(mfrow=c(1,2))
plotRGB(NEON_10)
plotRGB(NAIP_30_utm)

# Load Weisntein tree crown shapefile: https://zenodo.org/records/3765872
tree_crowns<-read_sf(paste0(bbox_base_path,"/2019_BART_5_",Training_tiles[1,1],"_image.shp"))

#### 3. Loading NEON data from catalog and exploring its utility for ground truthing ####
# Pull NEON vegetation structure data for the BART site 
veglist <- loadByProduct(dpID="DP1.10098.001", 
                         site="BART", 
                         package="basic", 
                         release="RELEASE-2025",
                         check.size = FALSE)
# Merge mapping and tagging with apparent individual observations
vegmap <- getLocTOS(veglist$vst_mappingandtagging, 
                    "vst_mappingandtagging")
veg <- joinTableNEON(veglist$vst_apparentindividual, 
                     vegmap, 
                     name1="vst_apparentindividual",
                     name2="vst_mappingandtagging")

# Plot stems as circles scaled by diameter over CHM
par(mfrow=c(1,1))
symbols(veg$adjEasting, 
        veg$adjNorthing, 
        circles=veg$stemDiameter/100/2, 
        inches=F, xlab="Easting", ylab="Northing")
plot(NEON_chm, add = TRUE)

# Add labels for first observation per plot
plot(NEON_chm)
symbols(veg$adjEasting, 
        veg$adjNorthing, 
        circles=veg$stemDiameter/100/2, 
        inches=F, xlab="Easting", ylab="Northing", 
        add = TRUE)
library(dplyr)
labs <- veg %>%
  filter(!is.na(adjEasting), !is.na(adjNorthing)) %>%
  group_by(plotID) %>%
  slice(1) %>%
  ungroup()
text(labs$adjEasting, 
     labs$adjNorthing,
     labels = labs$plotID)


#### 4. Using BART_073 for first manual annotations ####
# Focused analysis on one plot (BART_073)
symbols(veg$adjEasting[which(veg$plotID=="BART_073")], 
        veg$adjNorthing[which(veg$plotID=="BART_073")], 
        circles=veg$stemDiameter[which(veg$plotID=="BART_073")]/100/2, 
        inches=F, xlab="Easting", ylab="Northing")
plot(NEON_chm, add = TRUE)
symbols(veg$adjEasting[which(veg$plotID=="BART_073")], 
        veg$adjNorthing[which(veg$plotID=="BART_073")], 
        circles=veg$stemDiameter[which(veg$plotID=="BART_073")]/100/2, 
        inches=F, xlab="Easting", ylab="Northing", 
        add = TRUE)
symbols(veg$adjEasting[which(veg$plotID=="BART_073")], 
        veg$adjNorthing[which(veg$plotID=="BART_073")], 
        circles=veg$adjCoordinateUncertainty[which(veg$plotID=="BART_073")], 
        inches=F, add=T, fg="lightblue")
# Subset vegetation data
BART_073<-subset(veg, plotID=="BART_073")

# Explore data availability
table(BART_073$individualID, useNA="ifany")
table(BART_073$eventID.x, useNA="ifany")
table(BART_073$plantStatus, useNA="ifany")
table(BART_073$growthForm, useNA="ifany")
subset(BART_073, individualID=="NEON.PLA.D01.BART.03666")
subset(BART_073, individualID=="NEON.PLA.D01.BART.05867")
table(BART_073$canopyPosition, useNA="ifany")
table(BART_073$canopyPosition, BART_073$individualID, useNA="ifany")

# Extract year from eventID and fill canopy position if missing
BART_073$sampleYear<-as.numeric(substr(BART_073$eventID.x, 
                                       (nchar(BART_073$eventID.x)-3), 
                                       nchar(BART_073$eventID.x)))
BART_073 <- BART_073 %>%
  arrange(individualID, desc(sampleYear)) %>%
  group_by(individualID) %>%
  mutate(canopyPosition_filled = zoo::na.locf(canopyPosition, na.rm = FALSE)) %>%
  ungroup()
table(BART_073$sampleYear)

# Select most recent measurement for each tree
BART_073_clean<-BART_073 %>%
  filter(!is.na(adjEasting), !is.na(adjNorthing)) %>%
  group_by(individualID) %>%
  arrange(desc(sampleYear))%>%
  slice(1) %>%
  ungroup()

table(BART_073_clean$sampleYear)
table(BART_073_clean$canopyPosition_filled, useNA = "ifany")

# Convert points to spatial features
BART_073_pts <- BART_073_clean %>%
  st_as_sf(coords = c("adjEasting", "adjNorthing"), crs = 32619)

# Define crop area and visualize
buffered_box <- st_bbox(BART_073_pts) + c(-3, -3, 3, 3)
crop_60 <- extent(buffered_box)
plot(crop_60, add=TRUE)

# Log bounding box dimensions
cat("Width:",  crop_60@xmax - crop_60@xmin, "m\n")
cat("Height:", crop_60@ymax - crop_60@ymin, "m\n")

# Crop rasters and LAS to target region
NEON_las_crop <- clip_roi(NEON_las, crop_60)
NEON_chm_crop <- crop(NEON_chm, crop_60)
NEON_dtm_crop <- crop(NEON_dtm, crop_60)
NEON_10_crop <- crop(NEON_10, crop_60)
NAIP_30_crop <- crop(NAIP_30_utm, crop_60)
NAIP_60_crop <- crop(NAIP_60_utm, crop_60)

# Explore LAS point cloud
plot(NEON_las_crop)
rgl::rglwidget()
max(NEON_las_crop$Z)
min(NEON_las_crop$Z)
median(NEON_las_crop$Z)

NEON_las_crop<-filter_poi(NEON_las_crop, Z<=334)
plot(NEON_las_crop)
rgl::rglwidget()

# Normalize LAS heights using DTM
NEON_las_norm<- normalize_height(NEON_las_crop, NEON_dtm_crop) # 
plot(NEON_las_norm)
rgl::rglwidget()

# Segment crowns using CHM-guided watershed method
segment_NEON<- segment_trees(las = NEON_las_norm, 
                             algorithm = lidR::watershed(chm = NEON_chm, 
                                                         th_tree = 3, 
                                                         tol = 0.2, 
                                                         ext = 1))
# Locate treetops
ttops<-locate_trees(NEON_las_norm, lmf(5))
# Visualize segmented trees
offsets <- plot(segment_NEON, bg = "white", size = 3)
add_treetops3d(offsets, ttops)
rgl::rglwidget()

plot(segment_NEON, color="treeID")
rgl::rglwidget()

# Calculate crown metrics for polygons
metrics_NEON <- crown_metrics(segment_NEON, .stdtreemetrics, geom = "bbox")

# Side-by-side RGB visualization of cropped images
par(mfrow=c(1,2))
plotRGB(NEON_10_crop)
plotRGB(NAIP_30_crop)

# Add treetops to NAIP
plot(ttops, add=TRUE, col = "white", pch = 17)

# Plot trees with growth form and canopy position using shapes/colors
BART_073_pts$growthForm<-as.factor(BART_073_pts$growthForm)
table(BART_073_pts$growthForm, useNA="ifany")
BART_073_pts$canopyPosition_filled[is.na(BART_073_pts$canopyPosition_filled)] <- "Not Recorded"
BART_073_pts$canopyPosition_filled<-as.factor(BART_073_pts$canopyPosition_filled)
table(BART_073_pts$canopyPosition_filled, useNA="ifany")
colors <- c("black", "gold", "lightblue","purple","white")
pchs <- c(4, 16, 8, 1, 10)

plot(BART_073_pts, 
     col = colors[BART_073_pts$growthForm],
     pch = pchs[BART_073_pts$canopyPosition_filled],
     add = TRUE)

plotRGB(NAIP_30_crop)
plot(ttops, add=TRUE, col = "white", pch = 17)
plot(BART_073_pts, 
     col = colors[BART_073_pts$growthForm],
     pch = pchs[BART_073_pts$canopyPosition_filled],
     add = TRUE)

#### 5. Using the information and exploration above, bounding boxes are manually annotated in QGIS ####
## Here we read those annotations back in to process and clean data for model training
# Add manually annotated boxes
bboxlist<-list.files("../Imagery/NAIP/Training/bbox", pattern = "*.shp")
bboxlist

#Process the first entry and use it to make plots
NAIP_bbox<-read_sf(paste0("../Imagery/NAIP/Training/bbox/",bboxlist[1]))
buffered_box <- st_bbox(NAIP_bbox)
bbox_crop <- extent(buffered_box)

# Generate 2x2 visual layout for training documentation
png("../Figures/TrainingVis.png", height = 10, width = 10, res = 300, units = "in")
par(mfrow=c(2,2))
plotRGB(NEON_10)
plot(crop_60, add=TRUE, col="red")

plotRGB(NAIP_30_utm)
plot(crop_60, add=TRUE, col="red")

plotRGB(NEON_10_crop)
plot(BART_073_pts, 
     col = colors[BART_073_pts$canopyPosition_filled],
     pch = 16,
     add = TRUE)
plot(tree_crowns, col=NULL, border="lightblue", add=TRUE)

plotRGB(NEON_10_crop)
plot(BART_073_pts, 
     col = colors[BART_073_pts$canopyPosition_filled],
     pch = 16,
     add = TRUE)
plot(tree_crowns, col="transparent", border="lightblue", add=TRUE)

plotRGB(NAIP_30_crop)
plot(NAIP_bbox, col="transparent", border="lightblue", add=TRUE)
dev.off()

#### 6. Cleaning and generating DeepForest Annotations for Training
NEON_10_2<-brick(paste0(NEON_base_path,"2022_BART_6_",Training_tiles[2,1],"_image.tif"))
NAIP_30_2<-brick(paste0(NAIP_base_path,"30cm/match_NEON/NAIP_30cm_BART_6_",Training_tiles[2,1],".tif"))
NAIP_30_2_utm <- raster::projectRaster(from = NAIP_30_2, 
                                       to = NEON_10_2,
                                       method = "ngb")

NAIP_30_mosaic<-mosaic(NAIP_30_2_utm, NAIP_30_utm, fun="mean")

bbox_folder <- "../Imagery/NAIP/Training/bbox/"
naip_raster_path <- "../Imagery/NAIP/BART/NAIP_30cm_BART_6_<tile>.tif"
crop_image_dir <- "../Imagery/NAIP/Training/Crop_Images/"
annotations_csv <- "../Imagery/NAIP/Training/Crop_Images/annotations.csv"

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
  cropped    <- crop(NAIP_30_mosaic, extent(full_bb))
  names(cropped) <- c("Red", "Green", "Blue")
  writeRaster(cropped, paste0("../Imagery/NAIP/Training/Crop_Images/",
                                   substr(bboxlist[j], 1, nchar(bboxlist[j])-15),
                                   ".tif"), 
              overwrite=TRUE,
              datatype = "INT1U")
  
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
