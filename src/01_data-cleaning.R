#
# Title: Data cleaning for the interior habitat indicator
# Created: November 7th, 2023
# Last Updated: November 15th, 2023
# Author: Brandon Allen
# Objectives: Clean GIS data required for creating the interior habitat indicator. 
# Keywords: Notes, Initialization, Footprint cleaning, Interior habitat, Merging
#

##################
# Initialization #  
##################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Clear memory, source scripts
rm(list=ls())
gc()

# Load libraries
library(foreach)
library(parallel)
library(readxl)
library(reticulate)
library(sf)

# Load the relevant functions
source("src/data-cleaning_functions.R")

# Load the lookup table for the inventories
hfi.lookup <- read.csv("data/lookup/hfi-year-lookup.csv")

# Define provincial boundary
provincial.boundary <- "D:/spatial/ab_base2.gdb/GeoAdmin/PROVINCIAL_POLYGON_2020"

# Define the NTS tiles
nts.tiles <- read_sf("data/base/nts_snrc_250k_AB.shp")
nts.tiles <- nts.tiles$NTS_SNRC

# Define footprint buffers
footprint.buffers <- as.data.frame(read_excel("data/lookup/footprint-buffer.xlsx", 
                                sheet = "buffers"))

##################################
# Initialize parallel processing #
##################################

# Define the cores for parallel processing
n.clusters <- 12
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("hfi.lookup", "provincial.boundary", "footprint.buffers", "footprint_cleaning", "interior_buffers"))
clusterEvalQ(core.input, {
  
  # Load libraries
  library(reticulate)
  library(sf)
  library(raster)
  
  # Initialize arcpy
  py_discover_config() # We need version 3.9
  py_config() # Double check it is version 3.9
  
  # Set python 
  use_python(python = "C:/Users/ballen/AppData/Local/r-miniconda/envs/r-reticulate/python.exe")
  
  # Load arcpy
  arcpy <- import('arcpy') 
  
  # Define parallel processing factor
  # This needs to be set to 0 when performing parallel processing on workers.
  # If not set to 0, processes get jumbled and may fail.
  arcpy$env$parallelProcessingFactor <- "0%"
  
})

######################
# Footprint Cleaning #  
######################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Clean the NTS tiles
hfi.series <- c(2018, 2019, 2020)
foreach(hfi = hfi.series) %dopar% 
  
  parLapply(core.input, 
            as.list(nts.tiles), 
            fun = function(tile) tryCatch(footprint_cleaning(nts.tile = tile, 
                                                             hfi.year = hfi, 
                                                             hfi.path = hfi.lookup[hfi.lookup$HFI_YEAR == hfi, "Path"], 
                                                             footprint.buffers = footprint.buffers, 
                                                             arcpy = arcpy), error = function(e) e)
  )

####################
# Interior Habitat #  
####################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Calculate the appropriate buffers
foreach(hfi = hfi.series) %dopar% 
  
  parLapply(core.input, 
            as.list(nts.tiles), 
            fun = function(tile) tryCatch(interior_buffers(nts.tile = tile, 
                                                           hfi.year = hfi, 
                                                           hfi.path = hfi.lookup[hfi.lookup$HFI_YEAR == hfi, "Path"], 
                                                           arcpy = arcpy), error = function(e) e)
  )


stopCluster(core.input)

###########
# Merging #  
###########~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Clear memory
rm(list=ls())
gc()

# Load libraries
library(reticulate)
library(sf)
library(raster)

# Define year
hfi.years <- c(2010, 2018, 2019, 2020, 2021)

# Initialize arcpy
py_discover_config() # We need version 3.9
py_config() # Double check it is version 3.9

# Set python 
use_python(python = "C:/Users/ballen/AppData/Local/r-miniconda/envs/r-reticulate/python.exe")

# Load arcpy
arcpy <- import('arcpy') 

# Define parallel processing factor
arcpy$env$parallelProcessingFactor <- "100%"

# For each year and each of the the three buffers, combine the tiles into a single dataset

for (year in hfi.years) {
  
  # Create geodatabase
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/results/gis"), 
                                 out_name = paste0("InteriorHabitat_", year, ".gdb"))
  
  # Define the list of geodatabases that are required for the merge
  tile.path <- list.files(paste0(getwd(), "/data/processed/", year), full.names = TRUE)
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
                         output = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_50"))
  
  arcpy$Merge_management(inputs = paste(tile.list$IntHab_200, collapse = ";"), 
                         output = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_200"))
  
  arcpy$Merge_management(inputs = paste(tile.list$IntHab_500, collapse = ";"), 
                         output = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_500"))
  
  # # Clip to the backfill layer
  # arcpy$PairwiseClip_analysis(in_features = paste0("D:/backfill/Version7.0/gdb_veghf_reference_condition_", year, ".gdb/veghf_", year), 
  #                             clip_features = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_50"), 
  #                             out_feature_class = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_50_backfill"))
  # 
  # arcpy$PairwiseClip_analysis(in_features = paste0("D:/backfill/Version7.0/gdb_veghf_reference_condition_", year, ".gdb/veghf_", year), 
  #                             clip_features = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_200"), 
  #                             out_feature_class = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_200_backfill"))
  # 
  # arcpy$PairwiseClip_analysis(in_features = paste0("D:/backfill/Version7.0/gdb_veghf_reference_condition_", year, ".gdb/veghf_", year), 
  #                             clip_features = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_500"), 
  #                             out_feature_class = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_500_backfill"))
  # 
  # # Export table as a csv for processing
  # arcpy$ExportTable_conversion(in_table = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_50_backfill"),
  #                              out_table = paste0(getwd(), "/results/gis/InteriorHabitat_", year, "_50.csv"))
  # 
  # arcpy$ExportTable_conversion(in_table = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_200_backfill"),
  #                              out_table = paste0(getwd(), "/results/gis/InteriorHabitat_", year, "_200.csv"))
  # 
  # arcpy$ExportTable_conversion(in_table = paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_500_backfill"),
  #                              out_table = paste0(getwd(), "/results/gis/InteriorHabitat_", year, "_500.csv"))
  # 
  # # Clean up the files
  # arcpy$Delete_management(paste0(getwd(), "/results/tables/InteriorHabitat_", year, ".gdb/IntHab_50_backfill"))
  # arcpy$Delete_management(paste0(getwd(), "/results/tables/InteriorHabitat_", year, ".gdb/IntHab_200_backfill"))
  # arcpy$Delete_management(paste0(getwd(), "/results/tables/InteriorHabitat_", year, ".gdb/IntHab_500_backfill"))
  
  print(year)
  
}

rm(list=ls())
gc()
