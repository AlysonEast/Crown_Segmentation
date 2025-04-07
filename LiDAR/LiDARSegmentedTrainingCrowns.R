library(lidR)
library(neonUtilities)
library(neonOS)
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
NAIP_base_path<-"../Imagery/NAIP/BART/"

#Read in LiDAR data and georectify
NEON_las<-readLAS(paste0(LAS_base_path,"NEON_D01_BART_DP1_",Training_tiles[1,1],"_classified_point_cloud_colorized.laz"))
sps <- as(extent(st_bbox(NEON_las)), 'SpatialPolygons')
NEON_las@crs
proj4string(sps)
proj4string(sps)<-CRS(paste0("+proj=utm +zone=19 +datum=WGS84")) #This is for zone 19 utm projects

#Read in the chm raster provided by NEON
NEON_chm<-raster(paste0(CHM_base_path,"NEON_D01_BART_DP3_",Training_tiles[1,1],"_CHM.tif"))
#Read in the dtm raster provided by NEON
NEON_chm<-raster(paste0(CHM_base_path,"NEON_D01_BART_DP3_",Training_tiles[1,1],"_CHM.tif"))


#Read in associated NAIP Images
NAIP_30<-raster(paste0(NAIP_base_path,"30cm/match_NEON/NAIP_30cm_BART_6_",Training_tiles[1,1],".tif"))
NAIP_60<-raster(paste0(NAIP_base_path,"60cm/match_NEON/NAIP_60cm_BART_6_",Training_tiles[1,1],".tif"))


#Run secgmentation on the whole tile 
#We want to manually choose a region with high LiDAR segmentation success
#this will yield the most reliable bounding boxes for training
segment_NEON <- segment_trees(las = NEON_las, 
                              algorithm = watershed(chm = NEON_chm, 
                                                    th_tree = 3, 
                                                    tol = 0.5, 
                                                    ext = 1))
plot(segment_NEON)


####Crop to 60m by 60m region####
#define the box for the cropping
crop_60<-c()
  
#Crop the LiDAR files
NEON_las_crop<-c()
#Crop CHM
NEON_chm_crop<-crop(NEON_chm, crop_60)
#Crop NAIP Images
  


metrics_NEON <- crown_metrics(tree_NEON, .stdtreemetrics, geom = "bbox")
plot(metrics_NEON["Z"])