#install.packages("sourcetools", dependencies = TRUE, INSTALL_opts = '--no-lock', repos = "http://cran.us.r-project.org")
#install.packages("devtools", repos = "http://cran.us.r-project.org", dependencies = TRUE, INSTALL_opts = '--no-lock')
library(devtools)
#install_github("Weecology/NeonTreeEvaluation_package", force = TRUE)
library(NeonTreeEvaluation)
library(stringr)
library(sf)
library(raster)

download(training=FALSE)

an_list<-list_annotations()
rgb_list<-list_rgb()

find_overlapping_entries <- function(list_annotations, list_rgb) {
  # Extract filenames from the full file paths
  rgb_names <- basename(list_rgb) # Extracts file names (e.g., "NIWO_012_2020.tif")
  rgb_names <- sub("\\.tif$", "", rgb_names) # Remove ".tif" extension
  
  # Find the intersection of both lists
  overlapping_entries <- intersect(list_annotations, rgb_names)
  
  return(overlapping_entries)
}

# Get matches
matching_entries <- find_overlapping_entries(list_annotations(), list_rgb())
length(matching_entries)
length(an_list)
length(rgb_list)

for (i in 1:length(matching_entries)) {
  xml<-get_data(matching_entries[i],"annotations")
  annotations<-xml_parse(xml)
  rgb_path<-get_data(matching_entries[i],"rgb")
  rgb<-raster::stack(rgb_path)
  ground_truth <- boxes_to_spatial_polygons(annotations,rgb)
  ground_truth$plot_name<-matching_entries[i]
  
  # Ensure CRS is correctly set from raster data
  utm_crs <- crs(rgb)  # Get UTM projection from raster
  st_crs(ground_truth) <- utm_crs  # Assign to spatial object
  
  # Reproject to WGS 84
  ground_truth_wgs84 <- st_transform(ground_truth, crs = 4326)
  
  # Save output shapefile
  st_write(ground_truth_wgs84, "/fs/ess/PUOM0017/ForestScaling/DeepForest/Weinstein/all_annotations.shp", append=TRUE)
}
