# ---
# title: "Data cleaning for the interior habitat indicator"
# author: "Brandon Allen"
# created: "2023-11-15"
# inputs: ["0_data/external/lookup/hfi-path-lookup.csv";
#          "D:/spatial/ab_base2.gdb/GeoAdmin/PROVINCIAL_POLYGON_2020";
#          "0_data/external/lookup/footprint-buffer.xlsx";
#          "0_data/external/footprint/" - for each year of interest]
# outputs: ["2_pipeline/" - Processed NTS tiles for each year]
# notes: 
#   "This script completes the process of the interior habitat indicator by NTS tile"
# ---

# 1.0 Initializing environment ----
# This section handles defining the input data and required functions.

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
source("1_code/r_scripts/data-cleaning_functions.R")

# Load HFI paths
hfi.paths <- read.csv("0_data/external/lookup/hfi-path-lookup.csv")

# Define provincial boundary
provincial.boundary <- "D:/spatial/ab_base2.gdb/GeoAdmin/PROVINCIAL_POLYGON_2020"

# Define the NTS tiles
nts.tiles <- read_sf("0_data/external/boundaries/nts_snrc_250k_AB.shp")
nts.tiles <- nts.tiles$NTS_SNRC

# Define footprint buffers
footprint.buffers <- as.data.frame(read_excel("0_data/external/lookup/footprint-buffer.xlsx", 
                                sheet = "buffers"))

# 1.1 Initializing parallel processing ----

# Define the cores for parallel processing
n.clusters <- 10
core.input <- makeCluster(n.clusters)
clusterExport(core.input, c("hfi.paths", "provincial.boundary", "footprint.buffers", 
                            "footprint_standardization", "footprint_cleaning", "interior_buffers"))
clusterEvalQ(core.input, {
  
  # Load libraries
  library(reticulate)
  library(sf)
  library(raster)
  
  # Set python 
  use_python(python = "C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe")
  
  # Load arcpy
  arcpy <- import('arcpy') 
  
  # Define parallel processing factor
  # This needs to be set to 0 when performing parallel processing on workers.
  # If not set to 0, processes get jumbled and may fail.
  arcpy$env$parallelProcessingFactor <- "0%"
  
})

# 2.0 Footprint Standardization ----
# This function standardizes the harvest area attribution across years 

# Standardize the harvest area polygons
# Function has a catch to just update attribute names for 2022 (HARVEST-AREA)
hfi.series <- c(2010, 2018, 2019, 2020, 2021, 2022)
parLapply(core.input, 
          as.list(hfi.series), 
          fun = function(hfi) tryCatch(footprint_standardization(hfi.inventory = hfi.paths,
                                                                 hfi.year = hfi,
                                                                 arcpy = arcpy), error = function(e) e)
)

# 3.0 Footprint Cleaning ----
# This function cleans the human footprint layer and assigns buffer distances

# Clean the NTS tiles
foreach(hfi = hfi.series) %dopar% 
  
  parLapply(core.input, 
            as.list(nts.tiles), 
            fun = function(tile) tryCatch(footprint_cleaning(nts.tile = tile, 
                                                             nts.path = "0_data/external/boundaries/nts_snrc_250k_AB.shp",
                                                             hfi.year = hfi, 
                                                             hfi.path = paste0("2_pipeline/hfi_", hfi, ".gdb/hfi_", hfi), 
                                                             footprint.buffers = footprint.buffers, 
                                                             arcpy = arcpy), error = function(e) e)
  )

# 4.0 Interior Habitat ----
# This function calculates the polygons used for estimating interior native habitat

# Calculate the appropriate buffers
foreach(hfi = hfi.series) %dopar% 
  
  parLapply(core.input, 
            as.list(nts.tiles), 
            fun = function(tile) tryCatch(interior_buffers(nts.tile = tile, 
                                                           hfi.year = hfi, 
                                                           hfi.path = paste0("2_pipeline/hfi_", hfi, ".gdb/hfi_", hfi), 
                                                           arcpy = arcpy), error = function(e) e)
  )


stopCluster(core.input)

# Clear memory
rm(list=ls())
gc()
