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
source("1_code/r_scripts/functions/interior-buffers.R")

# Define HFI years
hfi_series <- c(2010, 2018, 2019, 2020, 2021, 2022, 2023)

# Define the watershed boundaries
boundary_path <- "0_data/external/boundaries/HydrologicUnitCodeWatershedsofAlberta.gdb/HydrologicUnitCode8WatershedsOfAlberta"
watershed_layer <- read_sf(dsn = "0_data/external/boundaries/HydrologicUnitCodeWatershedsofAlberta.gdb", 
                           layer = "HydrologicUnitCode8WatershedsOfAlberta")
watershed_ids <- watershed_layer$HUC_8

# Define working directory
working_directory <- paste0(getwd(), "/2_pipeline/hfi/")

# 1.1 Initializing parallel processing ----

# Define the cores for parallel processing
n_clusters <- 12
core_input <- makeCluster(n_clusters)
clusterExport(core_input, c("interior_buffers"))
clusterEvalQ(core_input, {
  
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


# 2.0 Interior Habitat ----
# This function calculates the polygons used for estimating interior native habitat

# Calculate the appropriate buffers
foreach(hfi = hfi_series) %dopar% 
  
  parLapply(core_input, 
            as.list(watershed_ids), 
            fun = function(huc_id) tryCatch(interior_buffers(huc_id = huc_id, 
                                                           hfi_year = hfi,
                                                           arcpy = arcpy), error = function(e) e)
  )


stopCluster(core_input)

# Clear memory
rm(list=ls())
gc()
