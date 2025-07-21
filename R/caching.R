library(arrow)
library(sf)
library(here)
library(glue)
library(tidyverse)
library(lubridate)

monthly_cache_exists <- function(year_month) {
  if (!str_detect(year_month, "^\\d{4}-\\d{2}$")) {
    stop("year_month must be in YYYY-MM format")
  }
  
  cache_file <- here("data", "processed", glue("crime_data_{year_month}.parquet"))
  return(file.exists(cache_file))
}

load_monthly_data <- function(year_month) {
  if (!str_detect(year_month, "^\\d{4}-\\d{2}$")) {
    stop("year_month must be in YYYY-MM format")
  }
  
  cache_file <- here("data", "processed", glue("crime_data_{year_month}.parquet"))
  
  if (!file.exists(cache_file)) {
    stop(glue("No cached data found for {year_month}"))
  }
  
  cat(glue("Loading cached data for {year_month}...\n"))
  
  df <- read_parquet(cache_file)
  
  if (nrow(df) == 0) {
    return(create_empty_crime_sf_for_cache())
  }
  
  crime_sf <- df %>%
    st_as_sf(
      coords = c("longitude", "latitude"),
      crs = 4326,
      remove = FALSE
    )
  
  cat(glue("Loaded {nrow(crime_sf)} records for {year_month}\n"))
  
  return(crime_sf)
}

save_monthly_data <- function(crime_sf, year_month) {
  if (!str_detect(year_month, "^\\d{4}-\\d{2}$")) {
    stop("year_month must be in YYYY-MM format")
  }
  
  if (!inherits(crime_sf, "sf")) {
    stop("Data must be an sf object")
  }
  
  processed_dir <- here("data", "processed")
  if (!dir.exists(processed_dir)) {
    dir.create(processed_dir, recursive = TRUE)
  }
  
  cache_file <- here(processed_dir, glue("crime_data_{year_month}.parquet"))
  
  cat(glue("Saving {nrow(crime_sf)} records to cache for {year_month}...\n"))
  
  df_to_save <- crime_sf %>%
    st_drop_geometry() %>%
    mutate(
      date = as.character(date),
      outcome_date = as.character(outcome_date)
    )
  
  write_parquet(df_to_save, cache_file)
  
  file_size <- format(file.size(cache_file), units = "MB", digits = 2)
  cat(glue("Cache file saved: {basename(cache_file)} ({file_size})\n"))
  
  return(cache_file)
}

list_available_months <- function() {
  processed_dir <- here("data", "processed")
  
  if (!dir.exists(processed_dir)) {
    return(character(0))
  }
  
  cache_files <- list.files(
    processed_dir,
    pattern = "^crime_data_\\d{4}-\\d{2}\\.parquet$",
    full.names = FALSE
  )
  
  if (length(cache_files) == 0) {
    return(character(0))
  }
  
  months <- str_extract(cache_files, "\\d{4}-\\d{2}")
  months <- sort(months)
  
  return(months)
}

get_cache_summary <- function() {
  available_months <- list_available_months()
  
  if (length(available_months) == 0) {
    return(tibble(
      metric = "Available months",
      value = "None"
    ))
  }
  
  processed_dir <- here("data", "processed")
  cache_files <- file.path(
    processed_dir,
    glue("crime_data_{available_months}.parquet")
  )
  
  file_sizes <- map_dbl(cache_files, file.size)
  total_size <- sum(file_sizes)
  
  summary_stats <- tibble(
    metric = c(
      "Available months",
      "Date range",
      "Total cache files",
      "Total cache size",
      "Average file size"
    ),
    value = c(
      as.character(length(available_months)),
      glue("{min(available_months)} to {max(available_months)}"),
      as.character(length(cache_files)),
      format(total_size, units = "MB", digits = 2),
      format(mean(file_sizes), units = "MB", digits = 2)
    )
  )
  
  return(summary_stats)
}

load_multiple_months <- function(year_months) {
  if (length(year_months) == 0) {
    return(create_empty_crime_sf_for_cache())
  }
  
  cat(glue("Loading data for {length(year_months)} months...\n"))
  
  crime_data_list <- map(year_months, function(ym) {
    if (monthly_cache_exists(ym)) {
      load_monthly_data(ym)
    } else {
      warning(glue("No cached data for {ym}"))
      create_empty_crime_sf_for_cache()
    }
  })
  
  crime_data_list <- keep(crime_data_list, ~ nrow(.x) > 0)
  
  if (length(crime_data_list) == 0) {
    return(create_empty_crime_sf_for_cache())
  }
  
  combined_data <- do.call(rbind, crime_data_list)
  
  cat(glue("Loaded {nrow(combined_data)} total records\n"))
  
  return(combined_data)
}

load_date_range <- function(start_date, end_date) {
  start_ym <- format(as.Date(start_date), "%Y-%m")
  end_ym <- format(as.Date(end_date), "%Y-%m")
  
  all_months <- seq(
    from = ym(start_ym),
    to = ym(end_ym),
    by = "month"
  )
  
  year_months <- format(all_months, "%Y-%m")
  
  return(load_multiple_months(year_months))
}

clean_old_cache <- function(keep_months = 24) {
  available_months <- list_available_months()
  
  if (length(available_months) <= keep_months) {
    cat("No old cache files to clean\n")
    return(invisible())
  }
  
  months_to_remove <- head(available_months, -keep_months)
  
  processed_dir <- here("data", "processed")
  files_to_remove <- file.path(
    processed_dir,
    glue("crime_data_{months_to_remove}.parquet")
  )
  
  cat(glue("Removing {length(files_to_remove)} old cache files...\n"))
  
  removed_count <- sum(file.remove(files_to_remove))
  
  cat(glue("Removed {removed_count} cache files\n"))
  
  return(invisible())
}

create_empty_crime_sf_for_cache <- function() {
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