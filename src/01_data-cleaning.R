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

# Load HFI paths
hfi.paths <- read.csv("data/lookup/hfi-path-lookup.csv")

# Define provincial boundary
provincial.boundary <- "D:/spatial/ab_base2.gdb/GeoAdmin/PROVINCIAL_POLYGON_2020"

# Define the NTS tiles
nts.tiles <- read_sf("data/base/boundaries/nts_snrc_250k_AB.shp")
nts.tiles <- nts.tiles$NTS_SNRC

# Define footprint buffers
footprint.buffers <- as.data.frame(read_excel("data/lookup/footprint-buffer.xlsx", 
                                sheet = "buffers"))

##################################
# Initialize parallel processing #
##################################

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
  use_python(python = "C:/Users/ballen/AppData/Local/r-miniconda/envs/r-reticulate/python.exe")
  
  # Load arcpy
  arcpy <- import('arcpy') 
  
  # Define parallel processing factor
  # This needs to be set to 0 when performing parallel processing on workers.
  # If not set to 0, processes get jumbled and may fail.
  arcpy$env$parallelProcessingFactor <- "0%"
  
})

#############################
# Footprint Standardization # This function standardizes the harvest area attribution across years 
#############################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Standardize the harvest area polygons
# Function has a catch to just update attribute names for 2022 (HARVEST-AREA)
hfi.series <- c(2010, 2018, 2019, 2020, 2021, 2022)
parLapply(core.input, 
          as.list(hfi.series), 
          fun = function(hfi) tryCatch(footprint_standardization(hfi.inventory = hfi.paths,
                                                                 hfi.year = hfi,
                                                                 arcpy = arcpy), error = function(e) e)
)

######################
# Footprint Cleaning #  
######################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Clean the NTS tiles
foreach(hfi = hfi.series) %dopar% 
  
  parLapply(core.input, 
            as.list(nts.tiles), 
            fun = function(tile) tryCatch(footprint_cleaning(nts.tile = tile, 
                                                             hfi.year = hfi, 
                                                             hfi.path = paste0("data/processed/hfi/hfi_", hfi, ".gdb/hfi_", hfi), 
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
                                                           hfi.path = paste0("data/processed/hfi/hfi_", hfi, ".gdb/hfi_", hfi), 
                                                           arcpy = arcpy), error = function(e) e)
  )


stopCluster(core.input)

# Clear memory
rm(list=ls())
gc()
