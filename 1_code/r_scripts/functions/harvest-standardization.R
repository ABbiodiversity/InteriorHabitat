#' Harvest standardization
#'
#' @description This function is used to standardize the harvest areas across all HFI products
#'
#' @param hfi_inventory Lookup table of file paths for relevant HFI
#' @param hfi_year Year of HFI 
#' @param workspace_path Path to the working directory for storing temporary resutls
#' @param arcpy Arcpy object defined using reticulate
#'
#' @export
#'
#'

harvest_standardization <- function(hfi_inventory, hfi_year, workspace_path, arcpy) {
        
        # Define the geodatabase for storing results
        arcpy$CreateFileGDB_management(out_folder_path = workspace_path, 
                                       out_name = paste0("hfi_", hfi_year, ".gdb"))
        
        # Define workspace
        arcpy$env$workspace <- paste0(getwd(), "/2_pipeline/hfi/hfi_", hfi_year, ".gdb")
        
        # If 2022 or 2023, copy and clean
        if(hfi_year %in% c(2022, 2023)) {
                
                # Select the harvest area polygons from the layer of interest
                arcpy$Copy_management(in_data = hfi_inventory[hfi_inventory$HFI == hfi_year, "Path"], 
                                      out_data = paste0("hfi_", hfi_year))
                
                # Correct the naming convention in the new harvest polygons ("HARVEST-AREA")
                cursor <- arcpy$da$UpdateCursor(in_table = paste0("hfi_", hfi_year), 
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
                
                # Select the potential harvest area polygons from the layer of interest
                arcpy$Select_analysis(in_features = hfi_inventory[hfi_inventory$HFI == hfi_year, "Path"], 
                                      out_feature_class = "potential_harvest", 
                                      where_clause = "FEATURE_TY IN ('HARVEST-AREA', 'HARVEST-AREA-WHITE-ZONE')")
                
                # Select the harvest area polygons from the 2022 HFI
                arcpy$Select_analysis(in_features = hfi_inventory[hfi_inventory$HFI == 2022, "Path"], 
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
                arcpy$PairwiseErase_analysis(in_features = hfi_inventory[hfi_inventory$HFI == hfi_year, "Path"], 
                                             erase_features = "potential_harvest", 
                                             out_feature_class = "hfi_no_harvest")
                
                # Add the newly updated harvest and disturbed polygons
                arcpy$Merge_management(inputs = "hfi_no_harvest; disturbance; harvest", 
                                       output = paste0("hfi_", hfi_year))
                
                arcpy$Delete_management(in_data = "harvest")
                arcpy$Delete_management(in_data = "harvest_2022")
                arcpy$Delete_management(in_data = "potential_harvest")
                arcpy$Delete_management(in_data = "disturbance")
                arcpy$Delete_management(in_data = "hfi_no_harvest")
                
        }
        
}
