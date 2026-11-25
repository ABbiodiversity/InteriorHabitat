# ---
# title: "Data cleaning for the interior habitat indicator"
# author: "Brandon Allen"
# created: "2023-11-15"
# inputs: ["0_data/external/lookup/hfi-path-lookup.csv";
#          "0_data/external/boundaries/HydrologicUnitCodeWatershedsofAlberta.gdb";
#          "0_data/external/lookup/footprint-buffer.xlsx";
#          "0_data/external/footprint/" - for each year of interest]
# outputs: ["2_pipeline/" - Processed watersheds for each year]
# notes: 
#   "This script completes the process of the interior habitat indicator by watershed boundary"
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
source("1_code/r_scripts/functions/harvest-standardization.R")
source("1_code/r_scripts/functions/linear-feature-standardization.R")
source("1_code/r_scripts/functions/buffer-assignment.R")

# Load HFI path and focal years
hfi_paths <- read.csv("0_data/external/lookup/hfi-path-lookup.csv")
hfi_series <- c(2010, 2018, 2019, 2020, 2021, 2022, 2023)

# Create the directory for temporary files
if(!dir.exists(paste0(getwd(), "/2_pipeline/hfi/"))) {
        
        dir.create(paste0(getwd(), "/2_pipeline/hfi/"))
        
}

working_directory <- paste0(getwd(), "/2_pipeline/hfi/")

for (year in hfi_series) {
        
        if(!dir.exists(paste0(getwd(), "/2_pipeline/", year))) {
                
                dir.create(paste0(getwd(), "/2_pipeline/", year))
                
        }
        
}

# Define the watershed boundaries
boundary_path <- "0_data/external/boundaries/HydrologicUnitCodeWatershedsofAlberta.gdb/HydrologicUnitCode8WatershedsOfAlberta"
watershed_layer <- read_sf(dsn = "0_data/external/boundaries/HydrologicUnitCodeWatershedsofAlberta.gdb", 
                           layer = "HydrologicUnitCode8WatershedsOfAlberta")
watershed_ids <- watershed_layer$HUC_8

# Define footprint buffers
footprint_buffers <- as.data.frame(read_excel("0_data/external/lookup/footprint-buffer.xlsx", 
                                              sheet = "buffers"))

# 1.1 Initializing parallel processing ----

# Define the cores for parallel processing
n_clusters <- length(hfi_series)
core_input <- makeCluster(n_clusters)
clusterExport(core_input, c("hfi_paths", "footprint_buffers", 
                            "harvest_standardization", "linear_standardization", 
                            "buffer_assignment", "working_directory"))
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

# 2.0 Footprint Standardization ----
# 2.1 Standardize the harvest area polygons ----
# Function has a catch to just update attribute names for 2023 (HARVEST-AREA)
parLapply(core_input, 
          as.list(hfi_series), 
          fun = function(hfi) tryCatch(harvest_standardization(hfi_inventory = hfi_paths,
                                                               hfi_year = hfi,
                                                               workspace_path = working_directory,
                                                               arcpy = arcpy), error = function(e) e)
)

# 2.2 Standardize the linear feature polygons ----
# Function has a catch to just update attribute names for 2023 (HARVEST-AREA)
parLapply(core_input, 
          as.list(hfi_series), 
          fun = function(hfi) tryCatch(linear_standardization(hfi_year = hfi,
                                                              workspace_path = working_directory,
                                                              arcpy = arcpy), error = function(e) e)
)

# 3.0 Buffer assignment ----
# This function assigns buffer distances and clips to the focal region of interest
# Clean the watershed tiles
foreach(hfi = hfi_series) %dopar% 
  
  parLapply(core_input, 
            as.list(watershed_ids), 
            fun = function(huc_id) tryCatch(buffer_assignment(huc_id = huc_id, 
                                                              watershed_path = boundary_path, 
                                                              hfi_year = hfi, 
                                                              workspace_path = working_directory, 
                                                              footprint_buffers = footprint_buffers, 
                                                              arcpy = arcpy), error = function(e) e)
  )

stopCluster(core_input)

# Clear memory
rm(list=ls())
gc()
