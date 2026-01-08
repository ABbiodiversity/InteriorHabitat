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
hfi.years <- c(2010, 2018, 2019, 2020, 2021, 2022)

# Set python 
use_python(python = "C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe")

# Load arcpy
arcpy <- import('arcpy') 

# Define parallel processing factor
arcpy$env$parallelProcessingFactor <- "100%"

# 2.0 Merging polygons ----
# For each year and each of the the three buffers, combine the tiles into a single dataset

for (year in hfi.years) {
  
  # Create geodatabase
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/3_output/gis"), 
                                 out_name = paste0("InteriorHabitat_", year, ".gdb"))
  
  # Define the list of geodatabases that are required for the merge
  tile.path <- list.files(paste0(getwd(), "/2_pipeline/", year), full.names = TRUE)
  tile.list <- list(IntHab_50 = NULL,
                    IntHab_200 = NULL,
                    IntHab_500 = NULL)
  
  for (tile in tile.path) {
    
    arcpy$env$workspace <- tile
    layer.id <- arcpy$ListFeatureClasses()
    
    tile.list$IntHab_50 <- c(tile.list$IntHab_50, paste0(tile, "/", layer.id[grep("IntHab_50_", layer.id)]))
    tile.list$IntHab_200 <- c(tile.list$IntHab_200, paste0(tile, "/", layer.id[grep("IntHab_200_", layer.id)]))
    tile.list$IntHab_500 <- c(tile.list$IntHab_500, paste0(tile, "/", layer.id[grep("IntHab_500_", layer.id)]))
    
  }
  
  # Create the merged layer
  arcpy$Merge_management(inputs = paste(tile.list$IntHab_50, collapse = ";"), 
                         output = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_50"))
  
  arcpy$Merge_management(inputs = paste(tile.list$IntHab_200, collapse = ";"), 
                         output = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_200"))
  
  arcpy$Merge_management(inputs = paste(tile.list$IntHab_500, collapse = ";"), 
                         output = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_500"))
  
  # # Clip to the backfill layer
  # arcpy$PairwiseClip_analysis(in_features = paste0("D:/backfill/Version7.0/gdb_veghf_reference_condition_", year, ".gdb/veghf_", year),
  #                             clip_features = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_50"),
  #                             out_feature_class = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_50_backfill"))
  # 
  # arcpy$PairwiseClip_analysis(in_features = paste0("D:/backfill/Version7.0/gdb_veghf_reference_condition_", year, ".gdb/veghf_", year),
  #                             clip_features = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_200"),
  #                             out_feature_class = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_200_backfill"))
  # 
  # arcpy$PairwiseClip_analysis(in_features = paste0("D:/backfill/Version7.0/gdb_veghf_reference_condition_", year, ".gdb/veghf_", year),
  #                             clip_features = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_500"),
  #                             out_feature_class = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_500_backfill"))
  # 
  # # Export table as a csv for processing
  # arcpy$ExportTable_conversion(in_table = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_50_backfill"),
  #                              out_table = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, "_50.csv"))
  # 
  # arcpy$ExportTable_conversion(in_table = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_200_backfill"),
  #                              out_table = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, "_200.csv"))
  # 
  # arcpy$ExportTable_conversion(in_table = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_500_backfill"),
  #                              out_table = paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, "_500.csv"))
  # 
  # # Clean up the files
  # arcpy$Delete_management(paste0(getwd(), "/3_output/tables/InteriorHabitat_", year, ".gdb/IntHab_50_backfill"))
  # arcpy$Delete_management(paste0(getwd(), "/3_output/tables/InteriorHabitat_", year, ".gdb/IntHab_200_backfill"))
  # arcpy$Delete_management(paste0(getwd(), "/3_output/tables/InteriorHabitat_", year, ".gdb/IntHab_500_backfill"))

  print(year)
  
}

rm(list=ls())
gc()
