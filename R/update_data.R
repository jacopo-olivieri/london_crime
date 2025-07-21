library(dplyr)
library(purrr)
library(tibble)
library(stringr)
library(sf)
library(here)
library(glue)
library(lubridate)

source(here("R", "api_wrapper.R"))
source(here("R", "data_processing.R"))
source(here("R", "caching.R"))
source(here("R", "spatial_setup.R"))

update_monthly_data <- function(year_month, force_refresh = FALSE) {
  if (!str_detect(year_month, "^\\d{4}-\\d{2}$")) {
    stop("year_month must be in YYYY-MM format")
  }
  
  log_file <- setup_logging(year_month)
  
  tryCatch({
    log_message(glue("Starting update for {year_month}"), log_file)
    
    if (!force_refresh && monthly_cache_exists(year_month)) {
      log_message(glue("Cache exists for {year_month}, loading from cache"), log_file)
      cached_data <- load_monthly_data(year_month)
      log_message(glue("Successfully loaded {nrow(cached_data)} records from cache"), log_file)
      return(cached_data)
    }
    
    log_message("Fetching data from Police.uk API", log_file)
    raw_crime_data <- fetch_crime_data(year_month)
    
    log_message("Loading LSOA boundaries", log_file)
    lsoa_boundaries <- load_london_boundaries()
    
    log_message("Processing crime data", log_file)
    processed_data <- process_monthly_crime(raw_crime_data, lsoa_boundaries)
    
    validate_processed_data(processed_data)
    log_message("Data validation passed", log_file)
    
    log_message("Saving to cache", log_file)
    cache_file <- save_monthly_data(processed_data, year_month)
    
    summary_stats <- get_crime_summary(processed_data)
    log_summary(summary_stats, log_file)
    
    log_message(glue("Successfully completed update for {year_month}"), log_file)
    
    return(processed_data)
    
  }, error = function(e) {
    error_msg <- glue("Error updating {year_month}: {e$message}")
    log_message(error_msg, log_file, level = "ERROR")
    stop(error_msg)
  })
}

update_latest_month <- function(force_refresh = FALSE) {
  latest_month <- get_latest_available_month()
  cat(glue("Updating latest available month: {latest_month}\n"))
  
  return(update_monthly_data(latest_month, force_refresh))
}

get_latest_available_month <- function() {
  current_date <- Sys.Date()
  
  current_month <- format(current_date, "%Y-%m")
  
  if (day(current_date) < 15) {
    latest_month <- format(current_date - months(2), "%Y-%m")
  } else {
    latest_month <- format(current_date - months(1), "%Y-%m")
  }
  
  return(latest_month)
}

update_missing_months <- function(start_year_month = "2015-01", end_year_month = NULL) {
  if (is.null(end_year_month)) {
    end_year_month <- get_latest_available_month()
  }
  
  all_months <- seq(
    from = ym(start_year_month),
    to = ym(end_year_month),
    by = "month"
  )
  
  year_months <- format(all_months, "%Y-%m")
  available_months <- list_available_months()
  missing_months <- setdiff(year_months, available_months)
  
  if (length(missing_months) == 0) {
    cat("No missing months found\n")
    return(invisible())
  }
  
  cat(glue("Found {length(missing_months)} missing months to update\n"))
  
  results <- list()
  
  for (month in missing_months) {
    cat(glue("\n--- Updating {month} ({which(missing_months == month)}/{length(missing_months)}) ---\n"))
    
    tryCatch({
      results[[month]] <- update_monthly_data(month)
      
      Sys.sleep(2)
      
    }, error = function(e) {
      cat(glue("Failed to update {month}: {e$message}\n"))
      results[[month]] <- NULL
    })
  }
  
  successful_updates <- sum(!map_lgl(results, is.null))
  cat(glue("\nCompleted: {successful_updates}/{length(missing_months)} months updated successfully\n"))
  
  return(results)
}

check_data_integrity <- function(year_months = NULL) {
  if (is.null(year_months)) {
    year_months <- list_available_months()
  }
  
  if (length(year_months) == 0) {
    cat("No data to check\n")
    return(tibble())
  }
  
  cat(glue("Checking data integrity for {length(year_months)} months...\n"))
  
  integrity_results <- map_dfr(year_months, function(ym) {
    tryCatch({
      data <- load_monthly_data(ym)
      
      tibble(
        year_month = ym,
        records = nrow(data),
        missing_lsoa = sum(is.na(data$lsoa_code)),
        missing_borough = sum(is.na(data$borough_name)),
        duplicate_ids = sum(duplicated(data$crime_id)),
        date_consistency = all(str_sub(data$month, 1, 7) == ym),
        status = "OK"
      )
    }, error = function(e) {
      tibble(
        year_month = ym,
        records = NA,
        missing_lsoa = NA,
        missing_borough = NA,
        duplicate_ids = NA,
        date_consistency = NA,
        status = paste("ERROR:", e$message)
      )
    })
  })
  
  issues <- integrity_results %>%
    filter(
      !is.na(records) & (
        missing_lsoa > 0 |
        missing_borough > 0 |
        duplicate_ids > 0 |
        !date_consistency
      )
    )
  
  if (nrow(issues) > 0) {
    cat("Data integrity issues found:\n")
    print(issues)
  } else {
    cat("All data integrity checks passed\n")
  }
  
  return(integrity_results)
}

setup_logging <- function(year_month) {
  logs_dir <- here("logs")
  if (!dir.exists(logs_dir)) {
    dir.create(logs_dir, recursive = TRUE)
  }
  
  log_file <- here(logs_dir, glue("update_{year_month}_{format(Sys.time(), '%Y%m%d_%H%M%S')}.log"))
  
  writeLines(glue("London Crime Data Update Log"), log_file)
  writeLines(glue("Year-Month: {year_month}"), log_file)
  writeLines(glue("Started: {Sys.time()}"), log_file)
  writeLines("", log_file)
  
  return(log_file)
}

log_message <- function(message, log_file, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- glue("[{timestamp}] {level}: {message}")
  
  cat(log_entry, file = log_file, append = TRUE, sep = "\n")
  
  if (level == "ERROR") {
    cat(paste("ERROR:", message, "\n"))
  } else {
    cat(paste(message, "\n"))
  }
}

log_summary <- function(summary_stats, log_file) {
  cat("\n--- DATA SUMMARY ---\n", file = log_file, append = TRUE)
  
  for (i in seq_len(nrow(summary_stats))) {
    line <- glue("{summary_stats$metric[i]}: {summary_stats$value[i]}")
    cat(line, "\n", file = log_file, append = TRUE)
  }
  
  cat("\n", file = log_file, append = TRUE)
}