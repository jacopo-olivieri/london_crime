library(tidyverse)
library(sf)
library(here)
library(glue)

setup_london_boundaries <- function() {
  boundaries_dir <- here("data", "boundaries")
  
  if (!dir.exists(boundaries_dir)) {
    dir.create(boundaries_dir, recursive = TRUE)
  }
  
  lsoa_zip_path <- here(boundaries_dir, "LB_LSOA2021_shp.zip")
  
  if (!file.exists(lsoa_zip_path)) {
    cat("Downloading London LSOA 2021 boundaries...\n")
    download.file(
      url = "https://data.london.gov.uk/download/38460723-837c-44ec-b9f0-1ebe939de89a/2a5e50ac-c22e-4d68-89e2-85f1e0ff9057/LB_LSOA2021_shp.zip",
      destfile = lsoa_zip_path,
      mode = "wb"
    )
  }
  
  shp_dir <- here(boundaries_dir, "lsoa")
  if (!dir.exists(shp_dir)) {
    cat("Extracting LSOA boundaries...\n")
    unzip(lsoa_zip_path, exdir = shp_dir)
  }
  
  return(shp_dir)
}

load_london_boundaries <- function() {
  shp_dir <- here("data", "boundaries", "lsoa")
  
  if (!dir.exists(shp_dir)) {
    cat("LSOA boundaries not found. Setting up...\n")
    setup_london_boundaries()
  }
  
  shp_files <- list.files(shp_dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
  if (length(shp_files) == 0) {
    stop("No shapefile found in boundaries directory")
  }
  
  cat(glue("Found {length(shp_files)} borough shapefiles, loading and combining...\n"))
  
  all_boundaries <- map_dfr(shp_files, function(shp_file) {
    st_read(shp_file, quiet = TRUE)
  })
  
  lsoa_boundaries <- all_boundaries
  
  lsoa_boundaries <- lsoa_boundaries %>%
    st_transform(4326) %>%
    select(
      lsoa_code = lsoa21cd,
      lsoa_name = lsoa21nm,
      borough_name = lad22nm
    )
  
  return(lsoa_boundaries)
}

create_london_polygon <- function(boundaries = NULL) {
  if (is.null(boundaries)) {
    boundaries <- load_london_boundaries()
  }
  
  bbox <- st_bbox(boundaries)
  
  london_polygon <- st_as_sfc(bbox)
  
  polygon_coords <- london_polygon %>%
    st_coordinates() %>%
    as.data.frame() %>%
    select(X, Y) %>%
    slice(1:4)
  
  api_polygon <- paste(
    paste(polygon_coords$Y, polygon_coords$X, sep = ","),
    collapse = ":"
  )
  
  config_dir <- here("config")
  if (!dir.exists(config_dir)) {
    dir.create(config_dir, recursive = TRUE)
  }
  
  saveRDS(list(
    sf_polygon = london_polygon,
    api_string = api_polygon,
    bbox = bbox
  ), here(config_dir, "london_polygon.rds"))
  
  return(api_polygon)
}

get_london_polygon <- function() {
  polygon_file <- here("config", "london_polygon.rds")
  
  if (!file.exists(polygon_file)) {
    cat("Creating London polygon for API calls...\n")
    create_london_polygon()
  }
  
  polygon_data <- readRDS(polygon_file)
  return(polygon_data$api_string)
}

get_london_bbox <- function() {
  boundaries <- load_london_boundaries()
  bbox <- st_bbox(boundaries)
  
  return(list(
    xmin = bbox["xmin"],
    ymin = bbox["ymin"], 
    xmax = bbox["xmax"],
    ymax = bbox["ymax"]
  ))
}

get_borough_boundaries <- function() {
  lsoa_boundaries <- load_london_boundaries()
  
  borough_boundaries <- lsoa_boundaries %>%
    group_by(borough_name) %>%
    summarise(
      lsoa_count = n(),
      .groups = "drop"
    ) %>%
    st_cast("MULTIPOLYGON")
  
  return(borough_boundaries)
}

create_borough_polygon <- function(borough_boundary) {
  if (!inherits(borough_boundary, "sf")) {
    stop("Borough boundary must be an sf object")
  }
  
  if (nrow(borough_boundary) != 1) {
    stop("Must provide exactly one borough boundary")
  }
  
  polygon_coords <- borough_boundary %>%
    st_coordinates() %>%
    as.data.frame() %>%
    select(X, Y) %>%
    distinct()
  
  if (nrow(polygon_coords) > 50) {
    indices <- round(seq(1, nrow(polygon_coords), length.out = min(50, nrow(polygon_coords))))
    polygon_coords <- polygon_coords[indices, ]
  }
  
  api_polygon <- paste(
    paste(polygon_coords$Y, polygon_coords$X, sep = ","),
    collapse = ":"
  )
  
  return(api_polygon)
}

get_all_borough_polygons <- function() {
  borough_boundaries <- get_borough_boundaries()
  
  borough_polygons <- borough_boundaries %>%
    rowwise() %>%
    mutate(
      api_polygon = create_borough_polygon(st_sf(geometry = geometry, borough_name = borough_name))
    ) %>%
    ungroup() %>%
    st_drop_geometry() %>%
    select(borough_name, lsoa_count, api_polygon)
  
  return(borough_polygons)
}