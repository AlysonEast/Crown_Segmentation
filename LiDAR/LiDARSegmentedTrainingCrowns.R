library(lidR)
library(neonUtilities)
library(neonOS)
devtools::install_github("NEONScience/NEON-geolocation/geoNEON")
library(geoNEON)
library(terra)

library(sf)
library(sp)
library(raster)
library(rgl)
library(EBImage)

#Setting up the environment
setwd("/media/aly/Penobscot/ForestScaling/Crown_Segmentation/LiDAR")
Training_tiles<-read.delim("../TrainingTiles",header = FALSE)
NEON_TOKEN<-read.delim("../NEON_token_AE",header = FALSE)[1,1]

LAS_base_path<-"./NEON/BART/DP1.30003.001/neon-aop-products/2022/FullSite/D01/2022_BART_6/L1/DiscreteLidar/ClassifiedPointCloud/"
CHM_base_path<-"./NEON/BART/DP3.30015.001/neon-aop-products/2022/FullSite/D01/2022_BART_6/L3/DiscreteLidar/CanopyHeightModelGtif/"
DTM_base_path<-"./NEON/BART/DP3.30024.001/neon-aop-products/2022/FullSite/D01/2022_BART_6/L3/DiscreteLidar/DTMGtif/"
NAIP_base_path<-"../Imagery/NAIP/BART/"
NEON_base_path<-"../Imagery/NEON/DP3.30010.001/neon-aop-products/2022/FullSite/D01/2022_BART_6/L3/Camera/Mosaic/"

#Read in LiDAR data and georectify
NEON_las<-readLAS(paste0(LAS_base_path,"NEON_D01_BART_DP1_",Training_tiles[1,1],"_classified_point_cloud_colorized.laz"))
sps <- as(extent(st_bbox(NEON_las)), 'SpatialPolygons')
NEON_las@crs
proj4string(sps)
proj4string(sps)<-CRS(paste0("+proj=utm +zone=19 +datum=WGS84")) #This is for zone 19 utm projects

#Read in the chm raster provided by NEON
NEON_chm<-raster(paste0(CHM_base_path,"NEON_D01_BART_DP3_",Training_tiles[1,1],"_CHM.tif"))
#Read in the dtm raster provided by NEON
NEON_dtm<-raster(paste0(DTM_base_path,"NEON_D01_BART_DP3_",Training_tiles[1,1],"_DTM.tif"))

#Read in associated NAIP Images
NEON_10<-brick(paste0(NEON_base_path,"2022_BART_6_",Training_tiles[1,1],"_image.tif"))
NAIP_30<-brick(paste0(NAIP_base_path,"30cm/match_NEON/NAIP_30cm_BART_6_",Training_tiles[1,1],".tif"))
NAIP_60<-brick(paste0(NAIP_base_path,"60cm/match_NEON/NAIP_60cm_BART_6_",Training_tiles[1,1],".tif"))

plotRGB(NAIP_30)

NAIP_30_utm <- raster::projectRaster(from = NAIP_30, 
                                 to = NEON_10,
                                 method = "ngb")
plotRGB(NAIP_30_utm)


#Pulling in NEON Veg Data
veglist <- loadByProduct(dpID="DP1.10098.001", 
                         site="BART", 
                         package="basic", 
                         release="RELEASE-2025",
                         check.size = FALSE)
vegmap <- getLocTOS(veglist$vst_mappingandtagging, 
                    "vst_mappingandtagging")
veg <- joinTableNEON(veglist$vst_apparentindividual, 
                     vegmap, 
                     name1="vst_apparentindividual",
                     name2="vst_mappingandtagging")



symbols(veg$adjEasting, 
        veg$adjNorthing, 
        circles=veg$stemDiameter/100/2, 
        inches=F, xlab="Easting", ylab="Northing")
plot(NEON_chm, add = TRUE)

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



#BART_073
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

BART_073<-subset(veg, plotID=="BART_073")


table(BART_073$individualID, useNA="ifany")
table(BART_073$eventID.x, useNA="ifany")
table(BART_073$plantStatus, useNA="ifany")
table(BART_073$growthForm, useNA="ifany")
subset(BART_073, individualID=="NEON.PLA.D01.BART.03666")
subset(BART_073, individualID=="NEON.PLA.D01.BART.05867")

BART_073$sampleYear<-as.numeric(substr(BART_073$eventID.x, 
                                       (nchar(BART_073$eventID.x)-3), 
                                       nchar(BART_073$eventID.x)))
table(BART_073$sampleYear)

table(BART_073$canopyPosition, useNA="ifany")
table(BART_073$canopyPosition, BART_073$individualID, useNA="ifany")

BART_073 <- BART_073 %>%
  arrange(individualID, desc(sampleYear)) %>%
  group_by(individualID) %>%
  mutate(canopyPosition_filled = zoo::na.locf(canopyPosition, na.rm = FALSE)) %>%
  ungroup()

BART_073_clean<-BART_073 %>%
  filter(!is.na(adjEasting), !is.na(adjNorthing)) %>%
  group_by(individualID) %>%
  arrange(desc(sampleYear))%>%
  slice(1) %>%
  ungroup()

table(BART_073_clean$sampleYear)
table(BART_073_clean$canopyPosition_filled, useNA = "ifany")

# Convert the BART_073 coordinates to a spatial object
BART_073_pts <- BART_073_clean %>%
  st_as_sf(coords = c("adjEasting", "adjNorthing"), crs = 32619)

# Get bounding box + 3m buffer
buffered_box <- st_bbox(BART_073_pts) + c(-3, -3, 3, 3)
crop_60 <- extent(buffered_box)
plot(crop_60, add=TRUE)

# Create extent object for cropping
box_width <- crop_60@xmax - crop_60@xmin
box_height <- crop_60@ymax - crop_60@ymin
cat("Width:", box_width, "m\n")
cat("Height:", box_height, "m\n")

# Crop everything
NEON_las_crop <- clip_roi(NEON_las, crop_60)
NEON_chm_crop <- crop(NEON_chm, crop_60)
NEON_dtm_crop <- crop(NEON_dtm, crop_60)
NEON_10_crop <- crop(NEON_10, crop_60)
NAIP_30_crop <- crop(NAIP_30_utm, crop_60)
NAIP_60_crop <- crop(NAIP_60_utm, crop_60)
  
plot(NEON_las_crop)
rgl::rglwidget()
max(NEON_las_crop$Z)
min(NEON_las_crop$Z)
median(NEON_las_crop$Z)

NEON_las_crop<-filter_poi(NEON_las_crop, Z<=334)
plot(NEON_las_crop)
rgl::rglwidget()

#normalize las by DTM
NEON_las_norm<- normalize_height(NEON_las_crop, NEON_dtm_crop) # 

plot(NEON_las_norm)
rgl::rglwidget()

#Run secgmentation on the whole tile 
#We want to manually choose a region with high LiDAR segmentation success
#this will yield the most reliable bounding boxes for training
segment_NEON<- segment_trees(las = NEON_las_norm, 
                             algorithm = lidR::watershed(chm = NEON_chm, 
                                                         th_tree = 3, 
                                                         tol = 0.2, 
                                                         ext = 1))
ttops<-locate_trees(NEON_las_norm, lmf(5))
# plot the point cloud
offsets <- plot(segment_NEON, bg = "white", size = 3)
add_treetops3d(offsets, ttops)
rgl::rglwidget()

plot(segment_NEON, color="treeID")
rgl::rglwidget()

metrics_NEON <- crown_metrics(segment_NEON, .stdtreemetrics, geom = "bbox")

# Now plot using plotRGB
plotRGB(NEON_10_crop)

# Then overlay the crown metrics polygons with no fill, just outlines
# plot(st_geometry(metrics_NEON), 
#      border = "red",    # outline color
#      lwd = 1,
#      add = TRUE)        # add to existing plot

#Add Tree Tops
plot(ttops, add=TRUE, col = "white", pch = 17)

# Add in NEON base plot data
BART_073_pts$growthForm<-as.factor(BART_073_pts$growthForm)
table(BART_073_pts$growthForm, useNA="ifany")
BART_073_pts$canopyPosition_filled[is.na(BART_073_pts$canopyPosition_filled)] <- "Not Recorded"
BART_073_pts$canopyPosition_filled<-as.factor(BART_073_pts$canopyPosition_filled)
table(BART_073_pts$canopyPosition_filled, useNA="ifany")


colors <- c("black", "white", "lightblue","purple")
pchs <- c(4, 16, 8, 1, 10)

plot(BART_073_pts, 
     col = colors[BART_073_pts$growthForm],
     pch = pchs[BART_073_pts$canopyPosition_filled],
     add = TRUE)

# Now plot using plotRGB
plotRGB(NAIP_30_crop)
# Then overlay the crown metrics polygons with no fill, just outlines
# plot(st_geometry(metrics_NEON), 
#      border = "red",    # outline color
#      lwd = 1,
#      add = TRUE)        # add to existing plot
#Add Tree Tops
plot(ttops, add=TRUE, col = "white", pch = 17)
plot(BART_073_pts, 
     col = colors[BART_073_pts$growthForm],
     pch = pchs[BART_073_pts$canopyPosition_filled],
     add = TRUE)


