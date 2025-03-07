library(terra)
library(sf)

# Define paths
raster_dir <- "./NAIP/BART/"   # Directory containing .tif files
shapefile_path <- "../Shapefiles/LiDAR_Tiles.shp"  # Path to the shapefile
output_dir <- "./NAIP/BART/match_NEON/"  # Directory for cropped output rasters
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Define target projection (UTM Zone 19N)
#target_crs <- "EPSG:32619"

# Load shapefile
polygons <- st_read(shapefile_path)

# Process each polygon separately
for (i in 1:nrow(polygons)) {
  poly <- polygons[i, ]  # Extract single polygon
  #poly <- st_transform(poly, target_crs)  # Reproject polygon to match target CRS
  poly_name <- poly$TileID  # Get polygon name
  output_filename <- file.path(output_dir, paste0("NAIP_", poly_name, ".tif"))

  # Identify and process intersecting raster tiles
  intersecting_rasters <- list()
  tif_files <- list.files(raster_dir, pattern = "\\.tif$", full.names = TRUE)
  
  for (tif in tif_files) {
    r <- rast(tif)  # Load raster on-demand

    # Check for spatial intersection
    if (relate(ext(r), vect(poly), "intersects")) {
      cropped_raster <- crop(r, vect(poly))  # Crop before adding to list
      intersecting_rasters <- append(intersecting_rasters, list(cropped_raster))
    }
    
    rm(r)  # Remove raster from memory after checking
    gc()
  }

  if (length(intersecting_rasters) == 0) {
    print(paste("No matching rasters for", poly_name))
    next  # Skip if no rasters intersect
  }

  # Mosaic if multiple rasters intersect
  if (length(intersecting_rasters) > 1) {
    merged_raster <- do.call(mosaic, c(intersecting_rasters, list(fun = mean)))
  } else {
    merged_raster <- intersecting_rasters[[1]]
  }

  # Reproject raster to UTM Zone 19N
#  reprojected_raster <- project(merged_raster, target_crs, method = "bilinear", res = target_res)

  # Mask the merged raster with the polygon
  masked_raster <- mask(merged_raster, vect(poly))
  masked_raster[is.nan(masked_raster)] <- NA  # Convert NaN to NA

  # Drop Band 4 (N_median), keep Band 1 (R), Band 2 (G), and Band 3 (B)
  bands <- c(1, 2, 3)
  masked_raster <- masked_raster[[bands]]

  # Convert to Byte format (0-255 range)
  masked_raster <- clamp(masked_raster, 0, 255)  # Ensure pixel values stay in 8-bit range
  #masked_raster <- as.int(masked_raster, "INT1U")  # Convert to 8-bit unsigned integer

  # Update band descriptions and ColorInterp to match NEON
  names(masked_raster) <- c("Red", "Green", "Blue")

  # Write output with appropriate metadata
  writeRaster(masked_raster, output_filename, overwrite = TRUE,
              datatype = "INT1U",  # Match NEON datatype
              gdal = c("COMPRESS=LZW", "TILED=YES", "INTERLEAVE=PIXEL"))
  print(paste("Saved:", output_filename))

  # Cleanup memory
  # rm(masked_raster, reprojected_raster, merged_raster, intersecting_rasters)
  rm(masked_raster, merged_raster, intersecting_rasters)
  gc()

}

