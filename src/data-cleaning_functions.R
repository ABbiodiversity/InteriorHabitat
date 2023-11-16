#
# Title: Data cleaning functions
# Created: November 14th, 2023
# Last Updated: November 14th, 2023
# Author: Brandon Allen
# Objectives: Functions required for cleaning the layers required for interior native habitat
# Keywords: Footprint cleaning, Interior habitat
#

######################
# Footprint cleaning # 
######################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

footprint_cleaning <- function(nts.tile, hfi.year, hfi.path, hfi.layer, footprint.buffers, arcpy) {
  
  ######################
  # Create geodatabase #
  ######################
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/data/processed/", hfi.year), 
                                 out_name = paste0("InteriorHabitat_", nts.tile, ".gdb"))
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/data/processed/", hfi.year, "/InteriorHabitat_", nts.tile, ".gdb")
  
  # Select the NTS tile
  arcpy$Select_analysis(in_features = paste0(getwd(), "/data/base/nts_snrc_250k_AB.shp"), 
                        out_feature_class = paste0("boundary_", nts.tile), 
                        where_clause = paste0("NTS_SNRC = '", nts.tile, "'"))
  
  # Buffer by 1km in order to make sure footprint buffers are properly captured
  arcpy$PairwiseBuffer_analysis(in_features =  paste0("boundary_", nts.tile), 
                                out_feature_class =  paste0("boundary_1km2_", nts.tile), 
                                buffer_distance_or_field = "1000 Meters", 
                                method = "PLANAR")
  
  # Pairwise clip the HFI layer to the buffered NTS tile
  arcpy$PairwiseClip_analysis(in_features = hfi.path, 
                              clip_features = paste0("boundary_1km2_", nts.tile), 
                              out_feature_class = paste0("HFI_", nts.tile))
  
  # Update each FEATURE_TY in the inventory with the appropriate three buffers (50m, 200m, 500m)
  # Create the new fields
  arcpy$AddField_management(in_table = paste0("HFI_", nts.tile), 
                            field_name = "Buffer_50", 
                            field_type = "TEXT")
  
  arcpy$AddField_management(in_table = paste0("HFI_", nts.tile), 
                            field_name = "Buffer_200", 
                            field_type = "TEXT")
  
  arcpy$AddField_management(in_table = paste0("HFI_", nts.tile), 
                            field_name = "Buffer_500", 
                            field_type = "TEXT")
  
  # Use an update cursor to loop through the cells
  cursor <- arcpy$da$UpdateCursor(in_table = paste0("HFI_", nts.tile), 
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
  recovery.year <- hfi.year - 80
  arcpy$Select_analysis(in_features = paste0("HFI_", nts.tile), 
                        out_feature_class = paste0("OldHarvest_", nts.tile),
                        where_clause = paste0("FEATURE_TY = 'HARVEST-AREA' And YEAR <= ", recovery.year))
  
  arcpy$PairwiseErase_analysis(in_features = paste0("HFI_", nts.tile), 
                               erase_features = paste0("OldHarvest_", nts.tile), 
                               out_feature_class = paste0("NoOldHarvest_", nts.tile))
  
  # Delete the unnecessary information
  arcpy$Delete_management(paste0("OldHarvest_", nts.tile))
  arcpy$Delete_management(paste0("HFI_", nts.tile))
  
}

####################
# Interior buffers # 
####################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

interior_buffers <- function(nts.tile, hfi.year, hfi.path, arcpy) {
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/data/processed/", hfi.year, "/InteriorHabitat_", nts.tile, ".gdb")
  
  # Create the three buffers
  arcpy$PairwiseBuffer_analysis(in_features = paste0("NoOldHarvest_", nts.tile), 
                                out_feature_class = "Buffer_50", 
                                buffer_distance_or_field = "Buffer_50", 
                                method = "PLANAR")
  
  arcpy$PairwiseBuffer_analysis(in_features = paste0("NoOldHarvest_", nts.tile), 
                                out_feature_class = "Buffer_200", 
                                buffer_distance_or_field = "Buffer_200", 
                                method = "PLANAR")
  
  arcpy$PairwiseBuffer_analysis(in_features = paste0("NoOldHarvest_", nts.tile), 
                                out_feature_class = "Buffer_500", 
                                buffer_distance_or_field = "Buffer_500", 
                                method = "PLANAR")
  
  # Erase the buffers from the original NTS tile
  arcpy$PairwiseErase_analysis(in_features = paste0("boundary_", nts.tile), 
                               erase_features = "Buffer_50", 
                               out_feature_class = paste0("IntHab_50_", nts.tile))
  
  arcpy$PairwiseErase_analysis(in_features = paste0("boundary_", nts.tile), 
                               erase_features = "Buffer_200", 
                               out_feature_class = paste0("IntHab_200_", nts.tile))
  
  arcpy$PairwiseErase_analysis(in_features = paste0("boundary_", nts.tile), 
                               erase_features = "Buffer_500", 
                               out_feature_class = paste0("IntHab_500_", nts.tile))
  
  # Remove all of the unnecessary information
  arcpy$Delete_management("Buffer_50")
  arcpy$Delete_management("Buffer_200")
  arcpy$Delete_management("Buffer_500")
  
}

