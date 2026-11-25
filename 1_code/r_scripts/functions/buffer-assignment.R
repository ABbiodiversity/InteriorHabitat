#' Buffer assignment
#'
#' @description This function is used to assign associated buffers to the human footprint inventories and clip to the associated focal boundary
#'
#' @param huc_id watershed tile used for batch processing
#' @param watershed_path path to the watershed tile boundaries
#' @param hfi_year Year of HFI 
#' @param workspace_path Path to the standardized HFI produced from the harvest_standardization function
#' @param footprint_buffers Lookup table containing all of the buffer distances for each footprint type
#' @param arcpy Arcpy object defined using reticulate
#'
#' @export
#'
#'

buffer_assignment <- function(huc_id, watershed_path, hfi_year, workspace_path, footprint_buffers, arcpy) {
  
  ######################
  # Create geodatabase #
  ######################
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/2_pipeline/", hfi_year), 
                                 out_name = paste0("InteriorHabitat_", huc_id, ".gdb"))
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/2_pipeline/", hfi_year, "/InteriorHabitat_", huc_id, ".gdb")
  
  # Select the watershed tile
  arcpy$Select_analysis(in_features = paste0(getwd(), "/", watershed_path), 
                        out_feature_class = paste0("boundary_", huc_id), 
                        where_clause = paste0("HUC_8 = '", huc_id, "'"))
  
  # Buffer by 1km in order to make sure footprint buffers are properly captured
  arcpy$PairwiseBuffer_analysis(in_features =  paste0("boundary_", huc_id), 
                                out_feature_class =  paste0("boundary_1km2_", huc_id), 
                                buffer_distance_or_field = "1000 Meters", 
                                method = "PLANAR")
  
  # Pairwise clip the HFI layer to the buffered tile
  arcpy$PairwiseClip_analysis(in_features = paste0(workspace_path, "hfi_", hfi_year, ".gdb/", "hfi_", hfi_year), 
                              clip_features = paste0("boundary_1km2_", huc_id), 
                              out_feature_class = paste0("HFI_", huc_id))
                              
  # Update each FEATURE_TY in the inventory with the appropriate three buffers (50m, 200m, 500m)
  # Create the new fields
  arcpy$AddField_management(in_table = paste0("HFI_", huc_id), 
                            field_name = "Buffer_50", 
                            field_type = "TEXT")
  
  arcpy$AddField_management(in_table = paste0("HFI_", huc_id), 
                            field_name = "Buffer_200", 
                            field_type = "TEXT")
  
  arcpy$AddField_management(in_table = paste0("HFI_", huc_id), 
                            field_name = "Buffer_500", 
                            field_type = "TEXT")
  
  # Use an update cursor to loop through the cells
  cursor <- arcpy$da$UpdateCursor(in_table = paste0("HFI_", huc_id), 
                                  field_names = list("FEATURE_TY", "YEAR", 
                                                     "Buffer_50", "Buffer_200", "Buffer_500"))
  
  # Update each row in the cursor
  row <- iter_next(cursor)
  while (!is.null(row)) {
    
    # All feature types excluding harvest areas use the lookup table buffer
    row[[3]] <- paste0(as.numeric(footprint_buffers[footprint_buffers$FEATURE_TY == row[[1]],  "BUFFER_50"]), " Meters")
    row[[4]] <- paste0(as.numeric(footprint_buffers[footprint_buffers$FEATURE_TY == row[[1]],  "BUFFER_200"]), " Meters")
    
    # The 500m buffer is not prorated in any way
    row[[5]] <- "500 Meters"
    
    # If harvest area, correct with the recovery year buffer
    if(row[[1]] == "HARVEST-AREA") {
      
      # If older than 60 years, no buffer
      if(row[[2]] <= (hfi_year - 60)) {
        
        row[[3]] <- paste0(0, " Meters")
        row[[4]] <- paste0(0, " Meters")
        
      } else {
        
        # If less than 60, apply age weighted buffer
        row[[3]] <- paste0(50 * (1 - ((hfi_year - row[[2]]) / 60)), " Meters")
        row[[4]] <- paste0(200 * (1 - ((hfi_year - row[[2]]) / 60)), " Meters")
        
      }
      
    }
    
    # Update the value
    cursor$updateRow(row)
    
    # Go to the next row
    row <- iter_next(cursor)  
    
  }
  
  # Remove harvest areas that are greater than 80 years old as they are fully recovered
  recovery.year <- hfi_year - 80
  arcpy$Select_analysis(in_features = paste0("HFI_", huc_id), 
                        out_feature_class = paste0("OldHarvest_", huc_id),
                        where_clause = paste0("FEATURE_TY = 'HARVEST-AREA' And YEAR <= ", recovery.year))
  
  arcpy$PairwiseErase_analysis(in_features = paste0("HFI_", huc_id), 
                               erase_features = paste0("OldHarvest_", huc_id), 
                               out_feature_class = paste0("NoOldHarvest_", huc_id))
  
  # Delete the unnecessary information
  arcpy$Delete_management(paste0("OldHarvest_", huc_id))
  arcpy$Delete_management(paste0("HFI_", huc_id))
  
}

