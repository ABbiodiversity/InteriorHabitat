#
# Title: Data cleaning for the interior habitat indicator
# Created: November 7th, 2023
# Last Updated: November 8th, 2023
# Author: Brandon Allen
# Objectives: Clean GIS data required for creating the interior habitat indicator. 
# Keywords: Notes, Initialization
#

##################
# Initialization #  
##################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Clear memory, source scripts
rm(list=ls())
gc()

# Load libraries
library(parallel)
library(readxl)
library(reticulate)
library(sf)

# Create the start time
Start.time <- Sys.time()

# Define HFI inventories
HFI <- 2021
hfi.path <- "K:/Anthropogenic/HumanFootprint/HFI/HFI_2021/HFI2021.gdb/HFI2021_Integrated/HFI2021"

# Define footprint buffers
footprint.buffers <- read_excel("data/lookup/footprint-buffer.xlsx", 
                                sheet = "buffers")

####################
# Initialize ArcPy # 
#################### 

# Initialize arcpy
py_discover_config() # We need version 3.9
py_config() # Double check it is version 3.9

# Set python 
use_python(python = "C:/Users/ballen/AppData/Local/r-miniconda/envs/r-reticulate/python.exe")

# Load arcpy
arcpy <- import('arcpy') 

# Define parallel processing factor
arcpy$env$parallelProcessingFactor <- "100%"

####################
# Interior Habitat # 
####################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Create geodatabase
arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/data/processed/"), 
                               out_name = paste0("InteriorHabitat_", HFI,  ".gdb"))

# Copy HFI layer
arcpy$Copy_management(in_data = hfi.path, 
                      out_data = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"))

# Define workspace
arcpy$env$workspace <- paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb")

# Loop through the HFI layer and assign the buffer distance to each feature type
# Create the new fields
arcpy$AddField_management(in_table = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"), 
                          field_name = "Buffer_50", 
                          field_type = "DOUBLE")

arcpy$AddField_management(in_table = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"), 
                          field_name = "Buffer_200", 
                          field_type = "DOUBLE")

# Use an update cursor to loop through the cells
cursor <- arcpy$da$UpdateCursor(in_table = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"), 
                                field_names = list("FEATURE_TY", "YEAR", 
                                                   "Buffer_50", "Buffer_200"))

# Remove harvest areas that are greater than 80 years old (can't be many)

# Update each row in the cursor
row <- iter_next(cursor)
while (!is.null(row)) {
  
  # If harvest area, assign the year buffer
  if(row[[1]] == "HARVEST-AREA") {
    
    # If older than 60, no buffer
    if(row[[2]] >= 60) {
      
      row[[3]] <- 0
      row[[3]] <- 0
      
    }
    
    # If less than 60, apply age weighted buffer
    row[[3]] <- 50 * (1 - (row[[2]] / 60))
    row[[4]] <- 50 * (1 - (row[[2]] / 60))
    
  }
  
  # All other feature types use the lookup table buffer
  row[[3]] <- as.numeric(footprint.buffers[footprint.buffers$FEATURE_TY == row[[1]],  "BUFFER_50"][,1])
  row[[4]] <- as.numeric(footprint.buffers[footprint.buffers$FEATURE_TY == row[[1]],  "BUFFER_200"][,1])
  
  # Update the value
  cursor$updateRow(row)
  
  # Go to the next row
  row <- iter_next(cursor)  
  
}

# Create the two different buffers
arcpy$PairwiseBuffer_analysis(in_features = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"), 
                              out_feature_class = "Buffer_50", 
                              buffer_distance_or_field = "Buffer_50", 
                              method = "GEODESIC")

arcpy$PairwiseBuffer_analysis(in_features = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"), 
                              out_feature_class = "Buffer_200", 
                              buffer_distance_or_field = "Buffer_200", 
                              method = "GEODESIC")

# Create the end time
End.time <- Sys.time()

End.time - Start.time