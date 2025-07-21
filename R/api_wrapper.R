library(httr)
library(dplyr)
library(purrr)
library(tibble)
library(stringr)
library(sf)
library(here)
library(glue)
library(lubridate)

source(here("R", "spatial_setup.R"))

fetch_crime_data <- function(year_month) {
  if (!str_detect(year_month, "^\\d{4}-\\d{2}$")) {
    stop("year_month must be in YYYY-MM format")
  }
  
  cat(glue("Fetching crime data for {year_month} using borough-by-borough approach...\n"))
  
  borough_polygons <- get_all_borough_polygons()
  
  cat(glue("Processing {nrow(borough_polygons)} London boroughs...\n"))
  
  all_crime_data <- list()
  successful_boroughs <- 0
  failed_boroughs <- character(0)
  
  for (i in seq_len(nrow(borough_polygons))) {
    borough_name <- borough_polygons$borough_name[i]
    borough_polygon <- borough_polygons$api_polygon[i]
    
    cat(glue("  [{i}/{nrow(borough_polygons)}] Fetching {borough_name}..."))
    
    tryCatch({
      borough_data <- fetch_crime_data_by_borough(year_month, borough_name, borough_polygon)
      
      if (nrow(borough_data) > 0) {
        all_crime_data[[borough_name]] <- borough_data
        successful_boroughs <- successful_boroughs + 1
        cat(glue(" ✓ {nrow(borough_data)} crimes\n"))
      } else {
        cat(" ✓ 0 crimes\n")
      }
      
      Sys.sleep(0.5)
      
    }, error = function(e) {
      failed_boroughs <<- c(failed_boroughs, borough_name)
      cat(glue(" ✗ Error: {e$message}\n"))
      
      Sys.sleep(1)
    })
  }
  
  if (length(all_crime_data) == 0) {
    cat("No crime data retrieved from any borough\n")
    return(create_empty_crime_sf())
  }
  
  cat(glue("Combining data from {successful_boroughs} successful boroughs...\n"))
  combined_crime_sf <- do.call(rbind, all_crime_data)
  
  if (length(failed_boroughs) > 0) {
    cat(glue("Warning: Failed to fetch data for {length(failed_boroughs)} boroughs: {paste(failed_boroughs, collapse = ', ')}\n"))
  }
  
  cat(glue("Successfully fetched {nrow(combined_crime_sf)} total crimes for {year_month}\n"))
  
  return(combined_crime_sf)
}

fetch_crime_data_by_borough <- function(year_month, borough_name, borough_polygon) {
  base_url <- "https://data.police.uk/api/crimes-street/all-crime"
  
  query_params <- list(
    date = year_month,
    poly = borough_polygon
  )
  
  result <- retry_api_call(base_url, query_params, max_retries = 2)
  
  if (is.null(result)) {
    stop(glue("Failed to fetch data for {borough_name} after retries"))
  }
  
  crime_sf <- process_api_response(result, year_month)
  
  return(crime_sf)
}

retry_api_call <- function(url, params, max_retries = 3, base_delay = 1) {
  for (attempt in 1:max_retries) {
    cat(glue("API attempt {attempt}/{max_retries}...\n"))
    
    response <- tryCatch({
      GET(url, query = params, timeout(30))
    }, error = function(e) {
      cat(glue("Network error: {e$message}\n"))
      return(NULL)
    })
    
    if (is.null(response)) {
      if (attempt < max_retries) {
        delay <- base_delay * (2 ^ (attempt - 1))
        cat(glue("Waiting {delay} seconds before retry...\n"))
        Sys.sleep(delay)
      }
      next
    }
    
    if (status_code(response) == 200) {
      content_data <- content(response, "parsed")
      
      if (length(content_data) == 0) {
        cat("Warning: API returned empty data\n")
        return(list())
      }
      
      return(content_data)
    } else if (status_code(response) == 429) {
      cat("Rate limit exceeded, waiting longer...\n")
      if (attempt < max_retries) {
        delay <- base_delay * (3 ^ attempt)
        Sys.sleep(delay)
      }
    } else {
      cat(glue("API error: Status {status_code(response)}\n"))
      if (attempt < max_retries) {
        delay <- base_delay * (2 ^ (attempt - 1))
        Sys.sleep(delay)
      }
    }
  }
  
  return(NULL)
}

process_api_response <- function(api_data, year_month) {
  if (length(api_data) == 0) {
    return(create_empty_crime_sf())
  }
  
  crime_df <- map_dfr(api_data, function(crime) {
    location <- crime$location %||% list()
    outcome <- crime$outcome_status %||% list()
    
    tibble(
      crime_id = crime$persistent_id %||% NA_character_,
      category = crime$category %||% NA_character_,
      location_type = location$type %||% NA_character_,
      location_subtype = location$subtype %||% NA_character_,
      month = crime$month %||% year_month,
      latitude = as.numeric(location$latitude %||% NA),
      longitude = as.numeric(location$longitude %||% NA),
      outcome_category = outcome$category %||% NA_character_,
      outcome_date = outcome$date %||% NA_character_
    )
  })
  
  crime_df <- crime_df %>%
    filter(!is.na(latitude), !is.na(longitude)) %>%
    mutate(
      date = ym(month),
      year = year(date),
      month_num = month(date),
      quarter = quarter(date)
    )
  
  if (nrow(crime_df) == 0) {
    return(create_empty_crime_sf())
  }
  
  crime_sf <- crime_df %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
  
  return(crime_sf)
}

create_empty_crime_sf <- function() {
  empty_df <- tibble(
    crime_id = character(0),
    category = character(0),
    location_type = character(0),
    location_subtype = character(0),
    month = character(0),
    outcome_category = character(0),
    outcome_date = character(0),
    date = as.Date(character(0)),
    year = integer(0),
    month_num = integer(0),
    quarter = integer(0)
  )
  
  empty_sf <- st_as_sf(empty_df, crs = 4326)
  empty_sf$geometry <- st_sfc(crs = 4326)
  
  return(empty_sf)
}

validate_crime_data <- function(crime_sf) {
  required_cols <- c("crime_id", "category", "month", "date", "year")
  missing_cols <- setdiff(required_cols, names(crime_sf))
  
  if (length(missing_cols) > 0) {
    stop(glue("Missing required columns: {paste(missing_cols, collapse = ', ')}"))
  }
  
  if (!inherits(crime_sf, "sf")) {
    stop("Data must be an sf object")
  }
  
  if (st_crs(crime_sf)$epsg != 4326) {
    stop("Data must be in WGS84 (EPSG:4326)")
  }
  
  return(TRUE)
}