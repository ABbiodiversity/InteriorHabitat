#
# Title: Package the indicator
# Created: April 9th, 2024
# Last Updated: April 9th, 2024
# Author: Brandon Allen
# Objectives: Package the indicator layers in the format appropriate for the custom reporting tool.
# Keywords: Packaging
#

#############
# Packaging #  
#############~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Clear memory
rm(list=ls())
gc()

# Load libraries
library(reticulate)
library(sf)
library(raster)

# Define year
hfi.years <- c(2010, 2021)

# Initialize arcpy
py_discover_config() # We need version 3.9
py_config() # Double check it is version 3.9

# Set python 
use_python(python = "C:/Users/ballen/AppData/Local/r-miniconda/envs/r-reticulate/python.exe")

# Load arcpy
arcpy <- import('arcpy') 

# Define parallel processing factor
arcpy$env$parallelProcessingFactor <- "100%"

# For each year and each of the the three buffers, copy into single layers
for (year in hfi.years) {
  
  # 50m buffer
  # Create geodatabases
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/results/gis/custom-reporting/"), 
                                 out_name = paste0("InteriorHabitat_50_", year, ".gdb")) 
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/results/gis/custom-reporting/InteriorHabitat_50_", year, ".gdb")
  
  # Copy the layer from one geodatabase to the other
  arcpy$Copy_management(in_data =  paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_50"), 
                        out_data = "interior_habitat")
  
  # 200m buffer
  # Create geodatabases
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/results/gis/custom-reporting/"), 
                                 out_name = paste0("InteriorHabitat_200_", year, ".gdb")) 
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/results/gis/custom-reporting/InteriorHabitat_200_", year, ".gdb")
  
  # Copy the layer from one geodatabase to the other
  arcpy$Copy_management(in_data =  paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_200"), 
                        out_data = "interior_habitat")
  
  # 500m buffer
  # Create geodatabases
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/results/gis/custom-reporting/"), 
                                 out_name = paste0("InteriorHabitat_500_", year, ".gdb")) 
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/results/gis/custom-reporting/InteriorHabitat_500_", year, ".gdb")
  
  # Copy the layer from one geodatabase to the other
  arcpy$Copy_management(in_data =  paste0(getwd(), "/results/gis/InteriorHabitat_", year, ".gdb/IntHab_500"), 
                        out_data = "interior_habitat")
  
  
}
  