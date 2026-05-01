#' Footprint standardization
#'
#' @description This function is used to standardize the harvest areas across all HFI products
#'
#' @param hfi.inventory Lookup table of file paths for relevant HFI
#' @param hfi.year Year of HFI 
#' @param arcpy Arcpy object defined using reticulate
#'
#' @export
#'
#'

footprint_standardization <- function(hfi.inventory, hfi.year, arcpy) {
        
        # If 2022 or 2023, just copy and clean
        if(hfi.year %in% c(2022, 2023)) {
                
                # Define the geodatabase for storing results
                arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/2_pipeline/hfi/"), 
                                               out_name = paste0("hfi_", hfi.year, ".gdb"))
                
                # Define workspace
                arcpy$env$workspace <-paste0(getwd(), "/2_pipeline/hfi/hfi_", hfi.year, ".gdb")
                
                # Select the harvest area polygons from the layer of interest
                arcpy$Copy_management(in_data = hfi.inventory[hfi.inventory$HFI == hfi.year, "Path"], 
                                      out_data = paste0("hfi_", hfi.year))
                
                # Correct the naming convention in the new harvest polygons ("HARVEST-AREA")
                cursor <- arcpy$da$UpdateCursor(in_table = paste0("hfi_", hfi.year), 
                                                field_names = c("FEATURE_TY", "YEAR"), 
                                                where_clause = "FEATURE_TY IN ('TIMBER-HARVEST-GREEN-AREA', 'TIMBER-HARVEST-WHITE-AREA')")
                
                # Update each row in the cursor
                row <- iter_next(cursor)
                while (!is.null(row)) {
                        
                        # Update Feature Type
                        row[[1]] <- "HARVEST-AREA"
                        
                        # Update the value
                        cursor$updateRow(row)
                        
                        # Go to the next row
                        row <- iter_next(cursor)  
                        
                }
                
                rm(row, cursor)
                
        } else {
                
                # Otherwise perform the standardization
                
                # Define the geodatabase for storing results
                arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/2_pipeline/"), 
                                               out_name = paste0("hfi_", hfi.year, ".gdb"))
                
                # Define workspace
                arcpy$env$workspace <-paste0(getwd(), "/2_pipeline/hfi_", hfi.year, ".gdb")
                
                # Select the potential harvest area polygons from the layer of interest
                arcpy$Select_analysis(in_features = hfi.inventory[hfi.inventory$HFI == hfi.year, "Path"], 
                                      out_feature_class = "potential_harvest", 
                                      where_clause = "FEATURE_TY IN ('HARVEST-AREA', 'HARVEST-AREA-WHITE-ZONE')")
                
                # Select the harvest area polygons from the 2022 HFI
                arcpy$Select_analysis(in_features = hfi.inventory[hfi.inventory$HFI == 2022, "Path"], 
                                      out_feature_class = "harvest_2022", 
                                      where_clause = "FEATURE_TY IN ('TIMBER-HARVEST-GREEN-AREA', 'TIMBER-HARVEST-WHITE-AREA')")
                
                # Clip the potential polygons to the extent of the 2022 harvest
                arcpy$PairwiseClip_analysis(in_features = "potential_harvest", 
                                            clip_features = "harvest_2022",
                                            out_feature_class = "harvest")
                
                # Erase the defined harvest areas from the original focal year to isolate permanent polygons that
                # are in a transition to another feature type.
                arcpy$PairwiseErase_analysis(in_features = "potential_harvest", 
                                             erase_features = "harvest", 
                                             out_feature_class = "disturbance")
                
                # Correct the naming convention in the new harvest polygons ("HARVEST-AREA")
                cursor <- arcpy$da$UpdateCursor(in_table = "harvest", 
                                                field_names = c("FEATURE_TY", "YEAR"))
                
                # Update each row in the cursor
                row <- iter_next(cursor)
                while (!is.null(row)) {
                        
                        # Update Feature Type
                        row[[1]] <- "HARVEST-AREA"
                        
                        # Update the value
                        cursor$updateRow(row)
                        
                        # Go to the next row
                        row <- iter_next(cursor)  
                        
                }
                
                # Clear row and cursor
                rm(row, cursor)
                
                # Correct the naming convention in the remaining disturbed polygons ("WOODY-VEGETATION-REMOVAL")
                cursor <- arcpy$da$UpdateCursor(in_table = "disturbance", 
                                                field_names = c("FEATURE_TY", "YEAR"))
                
                # Update each row in the cursor
                row <- iter_next(cursor)
                while (!is.null(row)) {
                        
                        # Update Feature Type
                        row[[1]] <-"WOODY-VEGETATION-REMOVAL"
                        
                        # Update the value
                        cursor$updateRow(row)
                        
                        # Go to the next row
                        row <- iter_next(cursor)  
                        
                }
                
                # Clear row and cursor
                rm(row, cursor)
                
                # Create a new HFI layer with the harvest areas erased
                arcpy$PairwiseErase_analysis(in_features = hfi.inventory[hfi.inventory$HFI == hfi.year, "Path"], 
                                             erase_features = "potential_harvest", 
                                             out_feature_class = "hfi_no_harvest")
                
                # Add the newly updated harvest and disturbed polygons
                arcpy$Merge_management(inputs = "hfi_no_harvest; disturbance; harvest", 
                                       output = paste0("hfi_", hfi.year))
                
                arcpy$Delete_management(in_data = "harvest")
                arcpy$Delete_management(in_data = "harvest_2022")
                arcpy$Delete_management(in_data = "potential_harvest")
                arcpy$Delete_management(in_data = "disturbance")
                arcpy$Delete_management(in_data = "hfi_no_harvest")
                
        }
        
}

#' Footprint cleaning
#'
#' @description This function is used to standardize the harvest areas across all HFI products
#'
#' @param nts.tile nts tile used for batch processing
#' @param nts.path path to the nts tile boundaries
#' @param hfi.year Year of HFI 
#' @param hfi.path Path to the standardized HFI produced from the footprint_standardization function
#' @param footprint.buffers Lookup table containing all of the buffer distances for each footprint type
#' @param arcpy Arcpy object defined using reticulate
#'
#' @export
#'
#'

footprint_cleaning <- function(nts.tile, nts.path, hfi.year, hfi.path, footprint.buffers, arcpy) {
  
  ######################
  # Create geodatabase #
  ######################
  arcpy$CreateFileGDB_management(out_folder_path = paste0(getwd(), "/2_pipeline/", hfi.year), 
                                 out_name = paste0("InteriorHabitat_", nts.tile, ".gdb"))
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/2_pipeline/", hfi.year, "/InteriorHabitat_", nts.tile, ".gdb")
  
  # Select the NTS tile
  arcpy$Select_analysis(in_features = paste0(getwd(), "/", nts.path), 
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
    row[[3]] <- paste0(as.numeric(footprint.buffers[footprint.buffers$FEATURE_TY == row[[1]],  "BUFFER_50"]), " Meters")
    row[[4]] <- paste0(as.numeric(footprint.buffers[footprint.buffers$FEATURE_TY == row[[1]],  "BUFFER_200"]), " Meters")
    
    # The 500m buffer is not prorated in any way
    row[[5]] <- "500 Meters"
    
    # If harvest area, correct with the recovery year buffer
    if(row[[1]] == "HARVEST-AREA") {
      
      # If older than 60 years, no buffer
      if(row[[2]] <= (hfi.year - 60)) {
        
        row[[3]] <- paste0(0, " Meters")
        row[[4]] <- paste0(0, " Meters")
        
      } else {
        
        # If less than 60, apply age weighted buffer
        row[[3]] <- paste0(50 * (1 - ((hfi.year - row[[2]]) / 60)), " Meters")
        row[[4]] <- paste0(200 * (1 - ((hfi.year - row[[2]]) / 60)), " Meters")
        
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

#' Interior Buffers
#'
#' @description This function is used to calculate the final buffers used to identify interior habitat
#'
#' @param nts.tile nts tile used for batch processing
#' @param hfi.year Year of HFI 
#' @param hfi.path Path to the standardized HFI produced from the footprint_standardization function
#' @param arcpy Arcpy object defined using reticulate
#'
#' @export
#'
#'

interior_buffers <- function(nts.tile, hfi.year, hfi.path, arcpy) {
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/2_pipeline/", hfi.year, "/InteriorHabitat_", nts.tile, ".gdb")
  
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

