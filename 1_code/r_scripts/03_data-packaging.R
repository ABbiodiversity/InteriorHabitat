# ---
# title: "Packaging the interior habitat indicator"
# author: "Brandon Allen"
# created: "2023-11-15"
# inputs: ["3_output/gis/InteriorHabitat_" - for each year]
# outputs: ["3_output/gis/custom-reporting/InteriorHabitat_" - for each year and buffer]
# notes: 
#   "Package the indicator layers in the format appropriate for the custom reporting tool"
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
hfi.years <- c(2010, 2022)

# Set python 
use_python(python = "C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe")

# Load arcpy
arcpy <- import('arcpy') 

# Define parallel processing factor
arcpy$env$parallelProcessingFactor <- "100%"

# 2.0 Packaging ----
# For each year and each of the the three buffers, copy into single layers
for (year in hfi.years) {
  
  # 50m buffer
  # Create geodatabases
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/3_output/gis/custom-reporting/"), 
                                 out_name = paste0("InteriorHabitat_50_", year, ".gdb")) 
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/3_output/gis/custom-reporting/InteriorHabitat_50_", year, ".gdb")
  
  # Copy the layer from one geodatabase to the other
  arcpy$Copy_management(in_data =  paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_50"), 
                        out_data = "interior_habitat")
  
  # 200m buffer
  # Create geodatabases
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/3_output/gis/custom-reporting/"), 
                                 out_name = paste0("InteriorHabitat_200_", year, ".gdb")) 
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/3_output/gis/custom-reporting/InteriorHabitat_200_", year, ".gdb")
  
  # Copy the layer from one geodatabase to the other
  arcpy$Copy_management(in_data =  paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_200"), 
                        out_data = "interior_habitat")
  
  # 500m buffer
  # Create geodatabases
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/3_output/gis/custom-reporting/"), 
                                 out_name = paste0("InteriorHabitat_500_", year, ".gdb")) 
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/3_output/gis/custom-reporting/InteriorHabitat_500_", year, ".gdb")
  
  # Copy the layer from one geodatabase to the other
  arcpy$Copy_management(in_data =  paste0(getwd(), "/3_output/gis/InteriorHabitat_", year, ".gdb/IntHab_500"), 
                        out_data = "interior_habitat")
  
  print(year)
  
}
  