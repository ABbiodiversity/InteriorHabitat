#' Linear feature standardization
#'
#' @description This function is used to standardize the linear features across all HFI products
#'
#' @param hfi_year Year of HFI 
#' @param workspace_path Directory of the HFI that has been standardized for harvest areas
#' @param arcpy Arcpy object defined using reticulate
#'
#' @export
#'
#'

linear_standardization <- function(hfi_year, workspace_path, arcpy) {
        
        # Define workspace and allow for overwriting
        arcpy$env$workspace <- paste0(workspace_path, "hfi_", hfi_year, ".gdb")
        
        # 2023 is already standardized, so only process the other years
        if(hfi_year != 2023) {
                
                # Select the vegetated road features polygons from the 2023 HFI
                arcpy$Select_analysis(in_features = paste0(workspace_path, "hfi_2023.gdb/hfi_2023"), 
                                      out_feature_class = "vegetated_road_2023", 
                                      where_clause = "FEATURE_TY IN ('ROAD-VEGETATED-OSE', 'ROAD-VEGETATED')")
                
                # Clip the the 2023 vegetated roads to the extent of target HFI
                arcpy$PairwiseClip_analysis(in_features = "vegetated_road_2023", 
                                            clip_features = paste0("hfi_", hfi_year),
                                            out_feature_class = "vegetated_road")
                
                # Erase the defined vegetated roads from the focal year
                arcpy$PairwiseErase_analysis(in_features = paste0("hfi_", hfi_year), 
                                             erase_features = "vegetated_road", 
                                             out_feature_class = paste0("hfi_", hfi_year, "_temp"))
                
                # Delete the original HFI layer
                arcpy$Delete_management(in_data = paste0("hfi_", hfi_year))
                
                # Add the newly updated vegetated road polygons
                arcpy$Merge_management(inputs = paste0("hfi_", hfi_year, "_temp", "; vegetated_road"), 
                                       output = paste0("hfi_", hfi_year))
                
                arcpy$Delete_management(in_data = "vegetated_road_2023")
                arcpy$Delete_management(in_data = "vegetated_road")
                arcpy$Delete_management(in_data = paste0("hfi_", hfi_year, "_temp"))
                
        } 
        
}
