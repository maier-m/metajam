## TODO:: create check_versions function Irene

#' Downloads data from DataOne along with metadata
#'
#' @param data_obj (character) An identifier or url for a DataONE object to download.
#' @param path (character) Path to a directory to download data to
#' 
#' @import eml2
#' @import purrr
#' @import dataone
#' @import tidyr
#' @importFrom xml2 read_xml write_xml
#' @importFrom emld as_emld
#' @importFrom lubridate ymd_hms
#' 
#' @return (character) Path where data is downloaded to
#'
#' @export

download_d1_data <- function(data_obj, path) {
  # TODO: add meta_doi to explicitly specify doi
  # TODO: refine summary_metadata Irene
  
  stopifnot(is.character(data_obj))
  stopifnot(dir.exists(path))
  
  ## Try to get DataONE data_id from data_obj ---------
  data_obj <- utils::URLdecode(data_obj)
  data_versions <- check_version(data_obj, formatType = "data")
  
  if(nrow(data_versions) == 1){
    data_id <- data_versions$identifier
  } else if(nrow(data_versions) > 1){
    #get most recent version
    data_versions$dateUploaded <- lubridate::ymd_hms(data_versions$dateUploaded)
    data_id <- data_versions$identifier[data_versions$dateUploaded == max(data_versions$dateUploaded)]
  } else {
    stop("The DataOne ID could not be found for ", data_obj)
  }
  
  ## Set Nodes ------------
  data_nodes <- dataone::resolve(dataone::CNode("PROD"), data_id)
  d1c <- dataone::D1Client("PROD", data_nodes$data$nodeIdentifier[[1]])
  cn <- dataone::CNode()
  
  ## Download Metadata ------------
  meta_id <- dataone::query(
    cn,
    list(q = sprintf('documents:"%s" AND formatType:"METADATA" AND -obsoletedBy:*', data_id),
         fl = "identifier")) %>% 
    unlist()
  
  # if no results are returned, try without -obsoletedBy
  if (length(meta_id) == 0) {
    meta_id <- dataone::query(
      cn,
      list(q = sprintf('documents:"%s" AND formatType:"METADATA"', data_id),
           fl = "identifier")) %>% 
      unlist()
  }
  
  # depending on results, return warnings
  if (length(meta_id) == 0) {
    warning("no metadata records found")
    meta_id <- NULL
  } else if (length(meta_id) > 1) {
    warning("multiple metadata records found:\n",
            paste(meta_id, collapse = "\n"),
            "\nThe first record was used")
    meta_id <- meta_id[1]
  }

  ## Get package level metadata -----------
  if (!is.null(meta_id)) {
    message("\nDownloading metadata ", meta_id, " ...")
    meta_obj <- dataone::getObject(d1c@mn, meta_id) 
    message("Download complete")
    metadata_nodes <- dataone::resolve(cn, meta_id)
    
    #workaround since eml2::read_eml currently can't take raw
    xml <- xml2::read_xml(meta_obj)
    eml <- tryCatch({emld::as_emld(xml)},  # If eml make EML object
                    error = function(e) {NULL})
    
    # Get attributes ----------
    ## get entity that contains the metadata for the data object
    entities <- c("dataTable", "spatialRaster", "spatialVector", "storedProcedure", "view", "otherEntity")
    entities <- entities[entities %in% names(eml$dataset)]
    
    entity_objs <- purrr::map(entities, ~eml2::eml_get(eml, .x)) %>% 
      # restructure so that all entities are at the same level
      purrr::map_if(~!is.null(.x$entityName), list) %>% 
      unlist(recursive = FALSE) 
    
    #sometimes url is stored in ...online$url instead of ...online$url$url
    #sometimes url needs to be decoded
    entity_data <- entity_objs %>% 
      purrr::keep(~any(grepl(data_id, 
                             purrr::map_chr(.x$physical$distribution$online$url, utils::URLdecode))))
    
    if (length(entity_data) == 0) {
      warning("No data metadata could not be found for ", data_obj)
      
    } else {
      
      if (length(entity_data) > 1) {
      warning("multiple data metadata records found:\n",
              data_obj,
              "\nThe first record was used")
      }
      
      entity_data <- entity_data[[1]]
    }

    attributeList <- suppressWarnings(eml2::get_attributes(entity_data$attributeList, eml))
    
    meta_tabular <- tabularize_eml(eml) %>% tidyr::spread(name, value)
    
    ## TODO:: Collect fields more selectively
    entity_meta <- suppressWarnings(list(
      File_Name = entity_data$physical$objectName,
      Date_Downloaded = paste0(Sys.time()),
      Data_ID = data_id,
      Data_URL = data_nodes$data$url[[1]],
      Metadata_ID = meta_id[[1]],
      Metadata_URL = metadata_nodes$data$url[1],
      Description = entity_data$entityDescription,
      Label = entity_data$entityLabel,
      Dataset_Title = meta_tabular$title,
      Dataset_StartDate = meta_tabular$temporalCoverage.beginDate,
      Dataset_StartDate = meta_tabular$temporalCoverage.endDate,
      Dataset_Location = meta_tabular$geographicCoverage.geographicDescription,
      Dataset_WestBoundingCoordinate = meta_tabular$geographicCoverage.westBoundingCoordinate,
      Dataset_EastBoundingCoordinate = meta_tabular$geographicCoverage.eastBoundingCoordinate,
      Dataset_NorthBoundingCoordinate = meta_tabular$geographicCoverage.northBoundingCoordinate,
      Dataset_SouthBoundingCoordinate = meta_tabular$geographicCoverage.southBoundingCoordinate,
      Dataset_Abstract = meta_tabular$abstract,
      Dataset_Methods = meta_tabular$methods
    ))
    
    entity_meta <- entity_meta %>% unlist() %>% enframe()
    # entity_meta <- entity_meta %>% 
    #   purrr::compact() %>% 
    #   dplyr::bind_rows() %>% 
    #   tidyr::gather()
  }
  
  # Write files & download data--------
  message("\nDownloading data ", data_id, " ...")
  data_sys <- suppressMessages(dataone::getSystemMetadata(d1c@cn, data_id))
  
  data_name <- data_sys@fileName %|||% ifelse(exists("entity_data"), entity_data$physical$objectName %|||% entity_data$entityName, NA) %|||% data_id
  data_name <- gsub("[^a-zA-Z0-9. -]+", "_", data_name) #remove special characters & replace with _
  data_name <- gsub("[.][a-zA-Z0-9]{2,4}$", "", data_name) #remove extension
  meta_name <- gsub("[^a-zA-Z0-9. -]+", "_", meta_id) #remove special characters & replace with _
  
  new_dir <- file.path(path, paste0(meta_name, "__", data_name)) 
  dir.create(new_dir)
  
  ## download Data
  out <- dataone::downloadObject(d1c, data_id, path = new_dir)
  message("Download complete")
  
  # change downloaded data object name to data_name
  data_files <- list.files(new_dir, pattern = ".csv$", full.names = TRUE)
  data_files <- data_files[!grepl(pattern='_metadata.csv', data_files)]
  data_files_ext <- stringr::str_extract(data_files, ".[^.]{2,4}$")
  file.rename(data_files, file.path(new_dir, paste0(data_name, data_files_ext)))
  
  ## write metadata xml/tabular form if exists
  if(exists("xml")) {
    xml2::write_xml(xml, file.path(new_dir, paste0(data_name, "__full_metadata.xml")))
    suppressWarnings(utils::write.csv(x = entity_meta, col.names = FALSE, row.names = FALSE,
                                      file = file.path(new_dir, paste0(data_name, "__summary_metadata.csv"))))
  }
  
  # write attribute tables if data metadata exists
  if(exists("attributeList")) {
    if (nrow(attributeList$attributes) > 0) {
      utils::write.csv(x = attributeList$attributes,
                       file = file.path(new_dir, paste0(data_name, "__attribute_metadata.csv")),
                       row.names = FALSE)
    }
    
    if (!is.null(attributeList$factors)) {
      utils::write.csv(x = attributeList$factors,
                       file = file.path(new_dir, paste0(data_name, "__attribute_factor_metadata.csv")),
                       row.names = FALSE)
    }
  }
  
  ## Output folder name
  return(new_dir)
}
