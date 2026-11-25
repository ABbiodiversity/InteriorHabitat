#' Interior Buffers
#'
#' @description This function is used to calculate the final buffers used to identify interior habitat
#'
#' @param huc_id Boundary used for batch processing
#' @param hfi_year Year of HFI 
#' @param arcpy Arcpy object defined using reticulate
#'
#' @export
#'
#'

interior_buffers <- function(huc_id, hfi_year, arcpy) {
  
  # Define workspace
  arcpy$env$workspace <- paste0(getwd(), "/2_pipeline/", hfi_year, "/InteriorHabitat_", huc_id, ".gdb")
  
  # Create the three buffers
  arcpy$PairwiseBuffer_analysis(in_features = paste0("NoOldHarvest_", huc_id), 
                                out_feature_class = "Buffer_50", 
                                buffer_distance_or_field = "Buffer_50", 
                                method = "PLANAR")
  
  arcpy$PairwiseBuffer_analysis(in_features = paste0("NoOldHarvest_", huc_id), 
                                out_feature_class = "Buffer_200", 
                                buffer_distance_or_field = "Buffer_200", 
                                method = "PLANAR")
  
  arcpy$PairwiseBuffer_analysis(in_features = paste0("NoOldHarvest_", huc_id), 
                                out_feature_class = "Buffer_500", 
                                buffer_distance_or_field = "Buffer_500", 
                                method = "PLANAR")
  
  # Erase the buffers from the focal boundary
  arcpy$PairwiseErase_analysis(in_features = paste0("boundary_", huc_id), 
                               erase_features = "Buffer_50", 
                               out_feature_class = paste0("IntHab_50_", huc_id))
  
  arcpy$PairwiseErase_analysis(in_features = paste0("boundary_", huc_id), 
                               erase_features = "Buffer_200", 
                               out_feature_class = paste0("IntHab_200_", huc_id))
  
  arcpy$PairwiseErase_analysis(in_features = paste0("boundary_", huc_id), 
                               erase_features = "Buffer_500", 
                               out_feature_class = paste0("IntHab_500_", huc_id))
  
  # We keep both the buffers as well as the erased areas as they can support 
  # multiple complimentary analyses
  
}

