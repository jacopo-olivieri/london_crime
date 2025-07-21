library(tidyverse)
library(sf)
library(here)
library(glue)

source(here("R", "spatial_setup.R"))

process_monthly_crime <- function(crime_sf, lsoa_boundaries = NULL) {
  if (is.null(lsoa_boundaries)) {
    cat("Loading LSOA boundaries...\n")
    lsoa_boundaries <- load_london_boundaries()
  }
  
  if (nrow(crime_sf) == 0) {
    cat("No crime data to process\n")
    return(create_empty_processed_sf())
  }
  
  cat(glue("Processing {nrow(crime_sf)} crime records...\n"))
  
  crime_sf <- standardize_crime_data(crime_sf)
  
  crime_with_areas <- perform_spatial_join(crime_sf, lsoa_boundaries)
  
  processed_crime <- finalize_crime_data(crime_with_areas)
  
  cat(glue("Successfully processed {nrow(processed_crime)} crimes with area assignments\n"))
  
  return(processed_crime)
}

standardize_crime_data <- function(crime_sf) {
  crime_sf %>%
    mutate(
      category = str_to_lower(str_trim(category)),
      category = case_when(
        str_detect(category, "anti-social") ~ "anti-social-behaviour",
        str_detect(category, "bicycle") ~ "bicycle-theft",
        str_detect(category, "burglary") ~ "burglary",
        str_detect(category, "criminal damage") ~ "criminal-damage-arson",
        str_detect(category, "drugs") ~ "drugs",
        str_detect(category, "other theft") ~ "other-theft",
        str_detect(category, "possession of weapons") ~ "possession-of-weapons",
        str_detect(category, "public order") ~ "public-order",
        str_detect(category, "robbery") ~ "robbery",
        str_detect(category, "shoplifting") ~ "shoplifting",
        str_detect(category, "theft from the person") ~ "theft-from-the-person",
        str_detect(category, "vehicle crime") ~ "vehicle-crime",
        str_detect(category, "violence and sexual") ~ "violence-and-sexual-offences",
        str_detect(category, "other crime") ~ "other-crime",
        TRUE ~ category
      ),
      location_type = str_to_lower(str_trim(location_type)),
      outcome_category = case_when(
        is.na(outcome_category) ~ "investigation-incomplete",
        str_trim(outcome_category) == "" ~ "investigation-incomplete",
        TRUE ~ str_to_lower(str_trim(outcome_category))
      )
    ) %>%
    filter(!is.na(category)) %>%
    arrange(date, category)
}

perform_spatial_join <- function(crime_sf, lsoa_boundaries) {
  cat("Performing spatial join with LSOA boundaries...\n")
  
  crime_sf <- st_transform(crime_sf, st_crs(lsoa_boundaries))
  
  joined_data <- st_join(crime_sf, lsoa_boundaries, join = st_within)
  
  unmatched_count <- sum(is.na(joined_data$lsoa_code))
  if (unmatched_count > 0) {
    cat(glue("Warning: {unmatched_count} crimes could not be matched to LSOA boundaries\n"))
    
    joined_data <- joined_data %>%
      filter(!is.na(lsoa_code))
  }
  
  return(joined_data)
}

finalize_crime_data <- function(crime_with_areas) {
  crime_with_areas %>%
    st_transform(4326) %>%
    mutate(
      latitude = st_coordinates(.)[, 2],
      longitude = st_coordinates(.)[, 1]
    ) %>%
    select(
      crime_id,
      category,
      location_type,
      location_subtype,
      month,
      date,
      year,
      month_num,
      quarter,
      latitude,
      longitude,
      lsoa_code,
      lsoa_name,
      borough_name,
      outcome_category,
      outcome_date,
      geometry
    ) %>%
    arrange(date, borough_name, lsoa_code, category)
}

create_empty_processed_sf <- function() {
  empty_df <- tibble(
    crime_id = character(0),
    category = character(0),
    location_type = character(0),
    location_subtype = character(0),
    month = character(0),
    date = as.Date(character(0)),
    year = integer(0),
    month_num = integer(0),
    quarter = integer(0),
    latitude = numeric(0),
    longitude = numeric(0),
    lsoa_code = character(0),
    lsoa_name = character(0),
    borough_name = character(0),
    outcome_category = character(0),
    outcome_date = character(0)
  )
  
  empty_sf <- st_as_sf(empty_df, crs = 4326)
  empty_sf$geometry <- st_sfc(crs = 4326)
  
  return(empty_sf)
}

validate_processed_data <- function(processed_sf) {
  required_cols <- c(
    "crime_id", "category", "date", "year", "month_num",
    "latitude", "longitude", "lsoa_code", "borough_name"
  )
  
  missing_cols <- setdiff(required_cols, names(processed_sf))
  if (length(missing_cols) > 0) {
    stop(glue("Missing required columns: {paste(missing_cols, collapse = ', ')}"))
  }
  
  if (!inherits(processed_sf, "sf")) {
    stop("Processed data must be an sf object")
  }
  
  if (st_crs(processed_sf)$epsg != 4326) {
    stop("Processed data must be in WGS84 (EPSG:4326)")
  }
  
  unmatched_areas <- sum(is.na(processed_sf$lsoa_code))
  if (unmatched_areas > 0) {
    warning(glue("{unmatched_areas} crimes have no LSOA assignment"))
  }
  
  return(TRUE)
}

get_crime_summary <- function(processed_sf) {
  if (nrow(processed_sf) == 0) {
    return(tibble(
      metric = character(0),
      value = character(0)
    ))
  }
  
  summary_stats <- tibble(
    metric = c(
      "Total crimes",
      "Date range", 
      "Unique crime categories",
      "Boroughs covered",
      "LSOAs covered",
      "Most common crime type",
      "Crimes with outcomes"
    ),
    value = c(
      format(nrow(processed_sf), big.mark = ","),
      glue("{min(processed_sf$date)} to {max(processed_sf$date)}"),
      as.character(n_distinct(processed_sf$category)),
      as.character(n_distinct(processed_sf$borough_name, na.rm = TRUE)),
      as.character(n_distinct(processed_sf$lsoa_code, na.rm = TRUE)),
      processed_sf %>% count(category, sort = TRUE) %>% slice(1) %>% pull(category),
      format(sum(!is.na(processed_sf$outcome_category) & 
                 processed_sf$outcome_category != "investigation-incomplete"), 
             big.mark = ",")
    )
  )
  
  return(summary_stats)
}