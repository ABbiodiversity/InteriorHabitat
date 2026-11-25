# ---
# title: "Data merging for the interior habitat indicator"
# author: "Brandon Allen"
# created: "2023-11-15"
# inputs: ["2_pipeline/year/" - NTS tiles for each year and buffer]
# outputs: ["3_output/gis/InteriorHabitat_" - for each year]
# notes: 
#   "Merging the cleaned datasets into a single provincial layer"
# ---

# 1.0 Initializing environment ----
# This section handles defining the input data and required functions.

# Clear memory
rm(list=ls())
gc()

# Load libraries
library(reticulate)
library(sf)
library(raster)

# Define year
hfi_series <- c(2010, 2018, 2019, 2020, 2021, 2022, 2023)

# Set python 
use_python(python = "C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe")

# Load arcpy
arcpy <- import('arcpy') 

# Define parallel processing factor
arcpy$env$parallelProcessingFactor <- "100%"

# 2.0 Merging polygons ----
# For each year and each of the the three buffers, combine the tiles into a single dataset

for (year in hfi_series) {
  
  # Create geodatabase
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/3_output/gis"), 
                                 out_name = paste0("InteriorHabitat_", year, ".gdb"))
  
  # Define the list of geodatabases that are required for the merge
  tile_path <- list.files(paste0(getwd(), "/2_pipeline/", year), full.names = TRUE)
  tile_list <- list(IntHab_50 = NULL,
                    IntHab_200 = NULL,
                    IntHab_500 = NULL,
                    Buffer_50 = NULL,
                    Buffer_200 = NULL,
                    Buffer_500 = NULL)
  
  for (tile in tile_path) {
    
    arcpy$env$workspace <- tile
    layer_id <- arcpy$ListFeatureClasses()
    
    tile_list$IntHab_50 <- c(tile_list$IntHab_50, paste0(tile, "/", layer_id[grep("IntHab_50_", layer_id)]))
    tile_list$IntHab_200 <- c(tile_list$IntHab_200, paste0(tile, "/", layer_id[grep("IntHab_200_", layer_id)]))
    tile_list$IntHab_500 <- c(tile_list$IntHab_500, paste0(tile, "/", layer_id[grep("IntHab_500_", layer_id)]))
    tile_list$Buffer_50 <- c(tile_list$Buffer_50, paste0(tile, "/", layer_id[grep("Buffer_50", layer_id)]))
    tile_list$Buffer_200 <- c(tile_list$Buffer_200, paste0(tile, "/", layer_id[grep("Buffer_200", layer_id)]))
    tile_list$Buffer_500 <- c(tile_list$Buffer_500, paste0(tile, "/", layer_id[grep("Buffer_500", layer_id)]))
    
  }
  
  # Create the merged layer
  arcpy$Merge_management(inputs = paste(tile_list$IntHab_50, collapse = ";"), 
                         output = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_50"))
  
  arcpy$Merge_management(inputs = paste(tile_list$IntHab_200, collapse = ";"), 
                         output = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_200"))
  
  arcpy$Merge_management(inputs = paste(tile_list$IntHab_500, collapse = ";"), 
                         output = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_500"))
  
  arcpy$Merge_management(inputs = paste(tile_list$Buffer_50, collapse = ";"), 
                         output = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/Buffer_50"))
  
  arcpy$Merge_management(inputs = paste(tile_list$Buffer_200, collapse = ";"), 
                         output = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/Buffer_200"))
  
  arcpy$Merge_management(inputs = paste(tile_list$Buffer_500, collapse = ";"), 
                         output = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/Buffer_500"))

  print(year)
  
}

rm(list=ls())
gc()
