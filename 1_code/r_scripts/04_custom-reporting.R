# ---
# title: "Custom Reporting for focal regions"
# author: "Brandon Allen"
# created: "2025-02-03"
# inputs: ["Focal spatial boundaries";
#          "Backfill landcover information";
#          "Interior Habitat layers for each year"]
# outputs: ["beta/custom-reporting/results/interior-habtiat_results_2022.csv"]
# notes: 
#   "This script calculates the interior habitat indicator for user defined regions"
#   " Current regions include AlPac and COSIA (OSR) boundaries."
#
# ---

# 1.0 Initialization ----
rm(list=ls())
gc()

# 1.1 Import libraries and functions----
library(readxl)
library(reticulate)
library(sf)
library(veghfsoil)

# 1.2 Define the file paths ----
region.paths <- data.frame(Region = c("alpac", "minable", "coldlake", "peaceriver", "athabasca", "osmregion"),
                           Path = c("D:/spatial/Land_Cover_analysis/export_shapefile/aoi_69.shp",
                                    "D:/spatial/Land_Cover_analysis/export_shapefile/aoi_67.shp",
                                    "D:/spatial/Land_Cover_analysis/export_shapefile/aoi_66.shp",
                                    "D:/spatial/Land_Cover_analysis/export_shapefile/aoi_68.shp",
                                    "D:/spatial/Land_Cover_analysis/export_shapefile/aoi_65.shp",
                                    "D:/spatial/Land_Cover_analysis/export_shapefile/aoi_64.shp"))

# Backfill paths
backfill.paths <- data.frame(Backfill = c("Veg_2010", "Veg_2022"),
                             Path = c("D:/backfill/Version7.0/gdb_veghf_reference_condition_2010.gdb/veghf_2010",
                                      "K:/Landcover/Backfill/backfilledV71/Backfill_veghf_V71_2022_final_rev01.gdb/veghf_V71_2022"))

# Backfill version and offset file
load("beta/kgrid/kgrid_2.1.Rdata")
ver.id <- "V7.0"

# 1.3 Initialize arcpy ----
# Set python 
use_python(python = "C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe")

# Load arcpy
arcpy <- import('arcpy') 

# Define parallel processing factor
# This needs to be set to 0 when performing parallel processing on workers.
# If not set to 0, processes get jumbled and may fail.
arcpy$env$parallelProcessingFactor <- "100%"

# Create the table for storing results
interior.regions <- c("alpac", "minable", "coldlake", "peaceriver", "athabasca", "osmregion")
interior.results <- data.frame(Region = NA,
                               Year = NA,
                               Habitat = NA,
                               Buffer = NA,
                               Area = NA)

# 2.0 Interior Habitat 2010 ----
for(region in interior.regions) {
  
  #
  # Define region path
  #
  
  region.path <- region.paths[region.paths$Region == region, "Path"]
  
  #
  # Create geodatabase 
  #
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/beta/custom-reporting/gis/"), 
                                 out_name = paste0(region, ".gdb"))
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/beta/custom-reporting/gis/", 
                                region, ".gdb")
  
  # Clip interior habitat to the regions of interest
  arcpy$PairwiseClip_analysis(in_features = backfill.paths$Path[1], 
                              clip_features = region.path, 
                              out_feature_class = "IntHab_0_veg")
  
  arcpy$PairwiseClip_analysis(in_features = "results/gis/InteriorHabitat_2010.gdb/IntHab_50", 
                              clip_features = region.path, 
                              out_feature_class = "IntHab_50")
  
  arcpy$PairwiseClip_analysis(in_features = "results/gis/InteriorHabitat_2010.gdb/IntHab_200", 
                              clip_features = region.path, 
                              out_feature_class = "IntHab_200")
  
  arcpy$PairwiseClip_analysis(in_features = "results/gis/InteriorHabitat_2010.gdb/IntHab_500", 
                              clip_features = region.path, 
                              out_feature_class = "IntHab_500")
  
  # Clip the backfill vegetation information to the interior habitat boundaries
  arcpy$PairwiseClip_analysis(in_features = "IntHab_0_veg", 
                              clip_features = "IntHab_50", 
                              out_feature_class = "IntHab_50_veg")
  
  arcpy$PairwiseClip_analysis(in_features = "IntHab_0_veg", 
                              clip_features = "IntHab_200", 
                              out_feature_class = "IntHab_200_veg")
  
  arcpy$PairwiseClip_analysis(in_features = "IntHab_0_veg", 
                              clip_features = "IntHab_500", 
                              out_feature_class = "IntHab_500_veg")
  
  # Export as csv
  arcpy$TableToTable_conversion(in_rows = "IntHab_0_veg",
                                out_path = "beta/custom-reporting/landcover/", 
                                out_name = paste0(region, "_0_veg.csv"))
  
  arcpy$TableToTable_conversion(in_rows = "IntHab_50_veg",
                                out_path = "beta/custom-reporting/landcover/", 
                                out_name = paste0(region, "_50_veg.csv"))
  
  arcpy$TableToTable_conversion(in_rows = "IntHab_200_veg",
                                out_path = "beta/custom-reporting/landcover/", 
                                out_name = paste0(region, "_200_veg.csv"))
  
  arcpy$TableToTable_conversion(in_rows = "IntHab_500_veg",
                                out_path = "beta/custom-reporting/landcover/", 
                                out_name = paste0(region, "_500_veg.csv"))
  
  # For the three distances, load and process the landcover information
  landcover.summaries <- list()
  
  for(buffer in c("0", "50", "200", "500")) {
    
    # Process the landcover inventories
    landcover <- read.csv(paste0("beta/custom-reporting/landcover/", region, "_", buffer, "_veg.csv"))
    landcover <- landcover[landcover$GRID_LABEL != "", ]
    
    # Correct the feature types that have been added in 2022
    landcover$FEATURE_TY[landcover$FEATURE_TY %in% c("REC-TRAIL", "OTHER-LINEAR-FEATURES")] <- "TRAIL"
    landcover$FEATURE_TY[landcover$FEATURE_TY %in% c("TIMBER-HARVEST-GREEN-AREA", "TIMBER-HARVEST-WHITE-AREA")] <- "HARVEST-AREA"
    
    # If NSRNAME is missing, fill in based on the kgrid to approximate.
    # Not sure why we have a few missing values
    valid.pixels <- landcover$NSRNAME == ""
    landcover$NSRNAME[valid.pixels] <- kgrid$NsrName[match(landcover$GRID_LABEL, kgrid$LinkID)][valid.pixels]
    
    # Impute the unknown ages
    landcover <- impute_unknown_ages(landcover = landcover,
                                     ages.list = ages.list,
                                     col.baseyear = 2010, 
                                     decadal.fix = TRUE,
                                     origin.fix = TRUE,
                                     unknown.fix = TRUE,
                                     age.data = "Maltman.Old",
                                     ver.id = "V7.0")
    
    # Create the long form summary
    d.long <- make_landcover_long(landcover = landcover,
                                  col.label = "GRID_LABEL",
                                  col.baseyear = 2010, 
                                  col.hfyear = "YEAR",
                                  col.veg = "Combined_ChgByCWCS",
                                  col.soil = "Soil_Type_1",
                                  hf.fine = TRUE,
                                  burn.cc = TRUE,
                                  unround = FALSE,
                                  age.correction = "Age_Correction",
                                  ver.id = ver.id)
    
    # Create the wide format
    d.wide <- make_landcover_wide(long.output = d.long,
                                  col.label = "GRID_LABEL",
                                  col.area = "Shape_Area",
                                  hf.fine = TRUE,
                                  tol = 0,
                                  sparse = TRUE,
                                  assign.unknown.ages = FALSE,
                                  age.data = "Maltman.Old",
                                  rm0 = TRUE)
    
    landcover.summaries[[buffer]] <- as.matrix(d.wide$veg.current)
    
    rm(d.wide, d.long, landcover, valid.pixels)
    
  }
  
  # Save the simplified version
  save(landcover.summaries, file = paste0("beta/custom-reporting/landcover/IntHab_", region, "_2010_veg.Rdata"))
  
  # Load the results and process into reporting attributes
  for(buffer in c("0", "50", "200", "500")) { 
    
    region.buffer <- colSums(landcover.summaries[[buffer]]) / 1000000
    
    # Create aggregated classes
    all.area <- sum(region.buffer)
    spruce.area <- sum(region.buffer[c("SpruceR", "Spruce1", "Spruce2", "Spruce3", "Spruce4",  
                                       "Spruce5", "Spruce6", "Spruce7", "Spruce8", "Spruce9")])
    decid.area <- sum(region.buffer[c("DecidR", "Decid1", "Decid2", "Decid3", "Decid4",  
                                   "Decid5", "Decid6", "Decid7", "Decid8", "Decid9")])
    mixedwood.area <- sum(region.buffer[c("MixedwoodR", "Mixedwood1", "Mixedwood2", "Mixedwood3", "Mixedwood4",  
                                    "Mixedwood5", "Mixedwood6", "Mixedwood7", "Mixedwood8", "Mixedwood9")])
    pine.area <- sum(region.buffer[c("PineR", "Pine1", "Pine2", "Pine3", "Pine4",  
                                    "Pine5", "Pine6", "Pine7", "Pine8", "Pine9")])
    blackspruce.area <- sum(region.buffer[c("TreedBogR", "TreedBog1", "TreedBog2", "TreedBog3", "TreedBog4",  
                                    "TreedBog5", "TreedBog6", "TreedBog7", "TreedBog8", "TreedBog9")])
    treedfen.area <- sum(region.buffer[c("TreedFenR", "TreedFen1", "TreedFen2", "TreedFen3", "TreedFen4",  
                                    "TreedFen5", "TreedFen6", "TreedFen7", "TreedFen8", "TreedFen9")])
    treedswamp.area <- sum(region.buffer[c("TreedSwampR", "TreedSwamp1", "TreedSwamp2", "TreedSwamp3", "TreedSwamp4",  
                                    "TreedSwamp5", "TreedSwamp6", "TreedSwamp7", "TreedSwamp8", "TreedSwamp9")])
    graminoidfen.area <- sum(region.buffer["GraminoidFen"])
    marsh.area <- sum(region.buffer["Marsh"])
    shrubbybog.area <- sum(region.buffer["ShrubbyBog"])
    shrubbyfen.area <- sum(region.buffer["ShrubbyFen"])
    shrubbyswamp.area <- sum(region.buffer["ShrubbySwamp"])
    grass.area <- sum(region.buffer["GrassHerb"])
    shrub.area <- sum(region.buffer["Shrub"])
    water.area <- sum(region.buffer[c("SnowIce", "Bare", "Water")])
    upland.area <- sum(spruce.area, decid.area, mixedwood.area, pine.area, grass.area, shrub.area)
    lowland.area <- sum(blackspruce.area, treedfen.area, treedswamp.area, graminoidfen.area,
                        marsh.area, shrubbybog.area, shrubbyfen.area, shrubbyswamp.area)
    native.area <- sum(upland.area, lowland.area)
    
    interior.temp <- data.frame(Region = region,
                                Year = 2010,
                                Habitat = c("AllFeatures", "WhiteSpruce", "Deciduous",
                                            "Mixedwood", "Pine", "BlackSpruce", 
                                            "TreedFen", "TreedSwamp", "GraminoidFen",
                                            "Marsh", "ShrubbyBog", "ShrubbyFen", "ShrubbySwamp",
                                            "Grass", "Shrub", "WaterIceBare", "Upland", "Lowland", "Native"),
                                Buffer = buffer,
                                Area = c(all.area, spruce.area, decid.area,
                                mixedwood.area, pine.area, blackspruce.area,
                                treedfen.area, treedswamp.area, graminoidfen.area,
                                marsh.area, shrubbybog.area, shrubbyfen.area, shrubbyswamp.area,
                                grass.area, shrub.area, water.area,
                                upland.area, lowland.area, native.area))
    
    # Bind 
    interior.results <- rbind(interior.results, interior.temp)
    
  }
  
  interior.results <- interior.results[!is.na(interior.results$Habitat), ]
  
  # Remove geodatabase and temporary files
  arcpy$Delete_management(in_data = arcpy$env$workspace)
  file.remove(paste0("beta/custom-reporting/landcover/", region, "_0_veg.csv"))
  file.remove(paste0("beta/custom-reporting/landcover/", region, "_50_veg.csv"))
  file.remove(paste0("beta/custom-reporting/landcover/", region, "_200_veg.csv"))
  file.remove(paste0("beta/custom-reporting/landcover/", region, "_500_veg.csv"))
  
  print(region)
  
}


# Save the results
write.csv(interior.results, file = "beta/custom-reporting/results/interior-habtiat_results_2010.csv",
          row.names = FALSE)

# 3.0 Interior Habitat 2022 ----
interior.results <- data.frame(Region = NA,
                               Year = NA,
                               Habitat = NA,
                               Buffer = NA,
                               Area = NA)

for(region in interior.regions) {
  
  #
  # Define region path
  #
  
  region.path <- region.paths[region.paths$Region == region, "Path"]
  
  #
  # Create geodatabase 
  #
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/beta/custom-reporting/gis/"), 
                                 out_name = paste0(region, ".gdb"))
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/beta/custom-reporting/gis/", 
                                region, ".gdb")
  
  # Clip interior habitat to the regions of interest
  arcpy$PairwiseClip_analysis(in_features = backfill.paths$Path[2], 
                              clip_features = region.path, 
                              out_feature_class = "IntHab_0_veg")
  
  arcpy$PairwiseClip_analysis(in_features = "results/gis/InteriorHabitat_2022.gdb/IntHab_50", 
                              clip_features = region.path, 
                              out_feature_class = "IntHab_50")
  
  arcpy$PairwiseClip_analysis(in_features = "results/gis/InteriorHabitat_2022.gdb/IntHab_200", 
                              clip_features = region.path, 
                              out_feature_class = "IntHab_200")
  
  arcpy$PairwiseClip_analysis(in_features = "results/gis/InteriorHabitat_2022.gdb/IntHab_500", 
                              clip_features = region.path, 
                              out_feature_class = "IntHab_500")
  
  # Clip the backfill vegetation information to the interior habitat boundaries
  arcpy$PairwiseClip_analysis(in_features = "IntHab_0_veg", 
                              clip_features = "IntHab_50", 
                              out_feature_class = "IntHab_50_veg")
  
  arcpy$PairwiseClip_analysis(in_features = "IntHab_0_veg", 
                              clip_features = "IntHab_200", 
                              out_feature_class = "IntHab_200_veg")
  
  arcpy$PairwiseClip_analysis(in_features = "IntHab_0_veg", 
                              clip_features = "IntHab_500", 
                              out_feature_class = "IntHab_500_veg")
  
  # Export as csv
  arcpy$TableToTable_conversion(in_rows = "IntHab_0_veg",
                                out_path = "beta/custom-reporting/landcover/", 
                                out_name = paste0(region, "_0_veg.csv"))
  
  arcpy$TableToTable_conversion(in_rows = "IntHab_50_veg",
                                out_path = "beta/custom-reporting/landcover/", 
                                out_name = paste0(region, "_50_veg.csv"))
  
  arcpy$TableToTable_conversion(in_rows = "IntHab_200_veg",
                                out_path = "beta/custom-reporting/landcover/", 
                                out_name = paste0(region, "_200_veg.csv"))
  
  arcpy$TableToTable_conversion(in_rows = "IntHab_500_veg",
                                out_path = "beta/custom-reporting/landcover/", 
                                out_name = paste0(region, "_500_veg.csv"))
  
  # For the three distances, load and process the landcover information
  landcover.summaries <- list()
  
  for(buffer in c("0", "50", "200", "500")) {
    
    # Process the landcover inventories
    landcover <- read.csv(paste0("beta/custom-reporting/landcover/", region, "_", buffer, "_veg.csv"))
    landcover <- landcover[landcover$GRID_LABEL != "", ]
    
    # Correct the feature types that have been added in 2022
    landcover$FEATURE_TY[landcover$FEATURE_TY %in% c("REC-TRAIL", "OTHER-LINEAR-FEATURES")] <- "TRAIL"
    landcover$FEATURE_TY[landcover$FEATURE_TY %in% c("TIMBER-HARVEST-GREEN-AREA", "TIMBER-HARVEST-WHITE-AREA")] <- "HARVEST-AREA"
    
    # If NSRNAME is missing, fill in based on the kgrid to approximate.
    # Not sure why we have a few missing values
    valid.pixels <- landcover$NSRNAME == ""
    landcover$NSRNAME[valid.pixels] <- kgrid$NsrName[match(landcover$GRID_LABEL, kgrid$LinkID)][valid.pixels]
    
    # Impute the unknown ages
    landcover <- impute_unknown_ages(landcover = landcover,
                                     ages.list = ages.list,
                                     col.baseyear = 2022, 
                                     decadal.fix = TRUE,
                                     origin.fix = TRUE,
                                     unknown.fix = TRUE,
                                     age.data = "Maltman.Old",
                                     ver.id = "V7.0")
    
    # Create the long form summary
    d.long <- make_landcover_long(landcover = landcover,
                                  col.label = "GRID_LABEL",
                                  col.baseyear = 2022, 
                                  col.hfyear = "YEAR",
                                  col.veg = "Combined_ChgByCWCS",
                                  col.soil = "Soil_Type_1",
                                  hf.fine = TRUE,
                                  burn.cc = TRUE,
                                  unround = FALSE,
                                  age.correction = "Age_Correction",
                                  ver.id = ver.id)
    
    # Create the wide format
    d.wide <- make_landcover_wide(long.output = d.long,
                                  col.label = "GRID_LABEL",
                                  col.area = "Shape_Area",
                                  hf.fine = TRUE,
                                  tol = 0,
                                  sparse = TRUE,
                                  assign.unknown.ages = FALSE,
                                  age.data = "Maltman.Old",
                                  rm0 = TRUE)
    
    landcover.summaries[[buffer]] <- as.matrix(d.wide$veg.current)
    
    rm(d.wide, d.long, landcover, valid.pixels)
    
  }
  
  # Save the simplified version
  save(landcover.summaries, file = paste0("beta/custom-reporting/landcover/IntHab_", region, "_2022_veg.Rdata"))
  
  # Load the results and process into reporting attributes
  for(buffer in c("0", "50", "200", "500")) { 
    
    region.buffer <- colSums(landcover.summaries[[buffer]]) / 1000000
    
    # Create aggregated classes
    all.area <- sum(region.buffer)
    spruce.area <- sum(region.buffer[c("SpruceR", "Spruce1", "Spruce2", "Spruce3", "Spruce4",  
                                       "Spruce5", "Spruce6", "Spruce7", "Spruce8", "Spruce9")])
    decid.area <- sum(region.buffer[c("DecidR", "Decid1", "Decid2", "Decid3", "Decid4",  
                                      "Decid5", "Decid6", "Decid7", "Decid8", "Decid9")])
    mixedwood.area <- sum(region.buffer[c("MixedwoodR", "Mixedwood1", "Mixedwood2", "Mixedwood3", "Mixedwood4",  
                                          "Mixedwood5", "Mixedwood6", "Mixedwood7", "Mixedwood8", "Mixedwood9")])
    pine.area <- sum(region.buffer[c("PineR", "Pine1", "Pine2", "Pine3", "Pine4",  
                                     "Pine5", "Pine6", "Pine7", "Pine8", "Pine9")])
    blackspruce.area <- sum(region.buffer[c("TreedBogR", "TreedBog1", "TreedBog2", "TreedBog3", "TreedBog4",  
                                            "TreedBog5", "TreedBog6", "TreedBog7", "TreedBog8", "TreedBog9")])
    treedfen.area <- sum(region.buffer[c("TreedFenR", "TreedFen1", "TreedFen2", "TreedFen3", "TreedFen4",  
                                         "TreedFen5", "TreedFen6", "TreedFen7", "TreedFen8", "TreedFen9")])
    treedswamp.area <- sum(region.buffer[c("TreedSwampR", "TreedSwamp1", "TreedSwamp2", "TreedSwamp3", "TreedSwamp4",  
                                           "TreedSwamp5", "TreedSwamp6", "TreedSwamp7", "TreedSwamp8", "TreedSwamp9")])
    graminoidfen.area <- sum(region.buffer["GraminoidFen"])
    marsh.area <- sum(region.buffer["Marsh"])
    shrubbybog.area <- sum(region.buffer["ShrubbyBog"])
    shrubbyfen.area <- sum(region.buffer["ShrubbyFen"])
    shrubbyswamp.area <- sum(region.buffer["ShrubbySwamp"])
    grass.area <- sum(region.buffer["GrassHerb"])
    shrub.area <- sum(region.buffer["Shrub"])
    water.area <- sum(region.buffer[c("SnowIce", "Bare", "Water")])
    upland.area <- sum(spruce.area, decid.area, mixedwood.area, pine.area, grass.area, shrub.area)
    lowland.area <- sum(blackspruce.area, treedfen.area, treedswamp.area, graminoidfen.area,
                        marsh.area, shrubbybog.area, shrubbyfen.area, shrubbyswamp.area)
    native.area <- sum(upland.area, lowland.area)
    
    interior.temp <- data.frame(Region = region,
                                Year = 2022,
                                Habitat = c("AllFeatures", "WhiteSpruce", "Deciduous",
                                            "Mixedwood", "Pine", "BlackSpruce", 
                                            "TreedFen", "TreedSwamp", "GraminoidFen",
                                            "Marsh", "ShrubbyBog", "ShrubbyFen", "ShrubbySwamp",
                                            "Grass", "Shrub", "WaterIceBare", "Upland", "Lowland", "Native"),
                                Buffer = buffer,
                                Area = c(all.area, spruce.area, decid.area,
                                         mixedwood.area, pine.area, blackspruce.area,
                                         treedfen.area, treedswamp.area, graminoidfen.area,
                                         marsh.area, shrubbybog.area, shrubbyfen.area, shrubbyswamp.area,
                                         grass.area, shrub.area, water.area,
                                         upland.area, lowland.area, native.area))
    
    # Bind 
    interior.results <- rbind(interior.results, interior.temp)
    
  }
  
  interior.results <- interior.results[!is.na(interior.results$Habitat), ]
  
  # Remove geodatabase and temporary files
  arcpy$Delete_management(in_data = arcpy$env$workspace)
  file.remove(paste0("beta/custom-reporting/landcover/", region, "_0_veg.csv"))
  file.remove(paste0("beta/custom-reporting/landcover/", region, "_50_veg.csv"))
  file.remove(paste0("beta/custom-reporting/landcover/", region, "_200_veg.csv"))
  file.remove(paste0("beta/custom-reporting/landcover/", region, "_500_veg.csv"))
  
  print(region)
  
}

# Save the results
write.csv(interior.results, file = "beta/custom-reporting/results/interior-habtiat_results_2022.csv",
          row.names = FALSE)

rm(list=ls())
gc()

# # 4.0 Kgrid versus Polygon comparison ----
# 
# # 4.1 Load kgrid and polygon interior habitat results for OSR
# load("beta/cosia-alpac/landcover/IntHab_osmregion_2021_veg.Rdata")
# load("beta/kgrid-summaries/interior-habitat_2021HFI_500m.Rdata")
# 
# # 4.2 Load the lookup table for determining valid pixels and filter
# osmregion <- read.csv("D:/abmi/BiodiversityBrowser/results/tables/aoi/kgrid/aoi_64.csv")
# d.wide <- as.matrix(d.wide$veg.current)
# d.wide <- d.wide[rownames(d.wide) %in% osmregion$LinkID, ]
# 
# #colnames(d.wide)
# sum(colSums(d.wide)[1:40]) / 1000000
# 
# sum(colSums(d.wide)[c(1:10, 122)]) / 1000000
# 
# 
# sum(colSums(landcover.summaries[["500"]])[c(1:10, 122)]) / 1000000
# sum(colSums(landcover.summaries[["500"]])[c(1:40)]) / 1000000
