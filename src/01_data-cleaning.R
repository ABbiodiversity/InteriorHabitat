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
provincial.boundary <- "D:/spatial/ab_base2.gdb/GeoAdmin/PROVINCIAL_POLYGON_2020"

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

# Define workspace
arcpy$env$workspace <- paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb")

# Copy HFI layer
arcpy$Copy_management(in_data = hfi.path, 
                      out_data = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"))

# Copy provincial boundary layer
arcpy$Copy_management(in_data = provincial.boundary,
                      out_data = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/ProvincialBoundary"))


# Loop through the HFI layer and assign the buffer distance to each feature type
# Create the new fields
arcpy$AddField_management(in_table = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"), 
                          field_name = "Buffer_50", 
                          field_type = "TEXT")

arcpy$AddField_management(in_table = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"), 
                          field_name = "Buffer_200", 
                          field_type = "TEXT")

arcpy$AddField_management(in_table = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"), 
                          field_name = "Buffer_500", 
                          field_type = "TEXT")

# Use an update cursor to loop through the cells
cursor <- arcpy$da$UpdateCursor(in_table = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021"), 
                                field_names = list("FEATURE_TY", "YEAR", 
                                                   "Buffer_50", "Buffer_200", "Buffer_500"))

# Update each row in the cursor
row <- iter_next(cursor)
while (!is.null(row)) {
  
  # All feature types excluding harvest areas use the lookup table buffer
  row[[3]] <- paste0(as.numeric(footprint.buffers[footprint.buffers$FEATURE_TY == row[[1]],  "BUFFER_50"][,1]), " Meters")
  row[[4]] <- paste0(as.numeric(footprint.buffers[footprint.buffers$FEATURE_TY == row[[1]],  "BUFFER_200"][,1]), " Meters")
  
  # The 500m buffer is not prorated in any way
  row[[5]] <- "500 Meters"
  
  # If harvest area, correct with the recovery year buffer
  if(row[[1]] == "HARVEST-AREA") {
    
    # If older than 60 years, no buffer
    if(row[[2]] <= (HFI - 60)) {
      
      row[[3]] <- paste0(0, " Meters")
      row[[4]] <- paste0(0, " Meters")
      
    } else {
      
      # If less than 60, apply age weighted buffer
      row[[3]] <- paste0(50 * (1 - ((HFI - row[[2]]) / 60)), " Meters")
      row[[4]] <- paste0(200 * (1 - ((HFI - row[[2]]) / 60)), " Meters")
      
    }
    
  }
  
  # Update the value
  cursor$updateRow(row)
  
  # Go to the next row
  row <- iter_next(cursor)  
  
}

# Remove harvest areas that are greater than 80 years old as they are fully recovered
recovery.year <- HFI - 80
arcpy$Select_analysis(in_features = "HFI2021", 
                      out_feature_class = "HFI2021_OldHarvest", 
                      where_clause =  paste0("FEATURE_TY = 'HARVEST-AREA' And YEAR <= ", recovery.year))

arcpy$PairwiseErase_analysis(in_features = "HFI2021", 
                             erase_features = "HFI2021_OldHarvest", 
                             out_feature_class = "HFI2021_NoOldHarvest")

# Create the three different buffers
arcpy$PairwiseBuffer_analysis(in_features = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021_NoOldHarvest"), 
                              out_feature_class = "Buffer_50", 
                              buffer_distance_or_field = "Buffer_50", 
                              method = "PLANAR", 
                              dissolve_option = "ALL")

arcpy$PairwiseBuffer_analysis(in_features = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021_NoOldHarvest"), 
                              out_feature_class = "Buffer_200", 
                              buffer_distance_or_field = "Buffer_200", 
                              method = "PLANAR", 
                              dissolve_option = "ALL")

arcpy$PairwiseBuffer_analysis(in_features = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/HFI2021_NoOldHarvest"), 
                              out_feature_class = "Buffer_500", 
                              buffer_distance_or_field = "Buffer_500", 
                              method = "PLANAR", 
                              dissolve_option = "ALL")

# Erase with the provincial boundary to get the remaining interior habitat
arcpy$PairwiseErase_analysis(in_features = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/ProvincialBoundary"), 
                             erase_features = "Buffer_50", 
                             out_feature_class = "IntHab_50")

arcpy$PairwiseErase_analysis(in_features = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/ProvincialBoundary"), 
                             erase_features = "Buffer_200", 
                             out_feature_class = "IntHab_200")

arcpy$PairwiseErase_analysis(in_features = paste0(getwd(), "/data/processed/InteriorHabitat_", HFI,  ".gdb/ProvincialBoundary"), 
                             erase_features = "Buffer_500", 
                             out_feature_class = "IntHab_500")

# Create the end time
End.time <- Sys.time()

End.time - Start.time