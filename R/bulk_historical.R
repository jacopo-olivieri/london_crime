library(tidyverse)
library(sf)
library(here)
library(glue)
library(lubridate)

source(here("R", "update_data.R"))

load_historical_data <- function(start_year = 2015, end_year_month = NULL, parallel = FALSE) {
  if (is.null(end_year_month)) {
    end_year_month <- get_latest_available_month()
  }
  
  start_year_month <- glue("{start_year}-01")
  
  all_months <- seq(
    from = ym(start_year_month),
    to = ym(end_year_month),
    by = "month"
  )
  
  year_months <- format(all_months, "%Y-%m")
  
  cat(glue("Loading historical data from {start_year_month} to {end_year_month}\n"))
  cat(glue("Total months to process: {length(year_months)}\n"))
  
  progress_file <- setup_progress_tracking(start_year_month, end_year_month)
  
  if (parallel && require(parallel, quietly = TRUE)) {
    load_historical_parallel(year_months, progress_file)
  } else {
    load_historical_sequential(year_months, progress_file)
  }
  
  cat("\nHistorical data loading completed!\n")
  print_final_summary()
}

load_historical_sequential <- function(year_months, progress_file) {
  results <- list()
  failed_months <- character(0)
  
  for (i in seq_along(year_months)) {
    month <- year_months[i]
    
    cat(glue("\n--- Processing {month} ({i}/{length(year_months)}) ---\n"))
    
    tryCatch({
      if (monthly_cache_exists(month)) {
        cat(glue("Skipping {month} - already cached\n"))
        results[[month]] <- "CACHED"
      } else {
        result <- update_monthly_data(month)
        results[[month]] <- "SUCCESS"
        
        update_progress(progress_file, month, "SUCCESS", nrow(result))
        
        Sys.sleep(2)
      }
      
    }, error = function(e) {
      error_msg <- glue("Failed {month}: {e$message}")
      cat(error_msg, "\n")
      
      failed_months <<- c(failed_months, month)
      results[[month]] <- paste("ERROR:", e$message)
      
      update_progress(progress_file, month, "ERROR", NA)
      
      Sys.sleep(5)
    })
    
    if (i %% 10 == 0) {
      print_progress_summary(results, failed_months)
    }
  }
  
  if (length(failed_months) > 0) {
    cat(glue("\nRetrying {length(failed_months)} failed months...\n"))
    retry_failed_months(failed_months, progress_file)
  }
}

load_historical_parallel <- function(year_months, progress_file) {
  cat("Parallel processing not yet implemented. Using sequential processing.\n")
  load_historical_sequential(year_months, progress_file)
}

retry_failed_months <- function(failed_months, progress_file, max_retries = 2) {
  for (retry in 1:max_retries) {
    if (length(failed_months) == 0) break
    
    cat(glue("\n--- Retry attempt {retry}/{max_retries} for {length(failed_months)} months ---\n"))
    
    still_failed <- character(0)
    
    for (month in failed_months) {
      cat(glue("Retrying {month}...\n"))
      
      tryCatch({
        result <- update_monthly_data(month)
        update_progress(progress_file, month, "SUCCESS_RETRY", nrow(result))
        cat(glue("Successfully processed {month} on retry {retry}\n"))
        
        Sys.sleep(3)
        
      }, error = function(e) {
        cat(glue("Still failing {month}: {e$message}\n"))
        still_failed <<- c(still_failed, month)
        update_progress(progress_file, month, glue("ERROR_RETRY_{retry}"), NA)
        
        Sys.sleep(5)
      })
    }
    
    failed_months <- still_failed
  }
  
  if (length(failed_months) > 0) {
    cat(glue("\nPersistently failing months: {paste(failed_months, collapse = ', ')}\n"))
    cat("These may need manual intervention.\n")
  }
}

setup_progress_tracking <- function(start_month, end_month) {
  logs_dir <- here("logs")
  if (!dir.exists(logs_dir)) {
    dir.create(logs_dir, recursive = TRUE)
  }
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  progress_file <- here(logs_dir, glue("historical_load_{timestamp}.log"))
  
  cat(glue("Historical Data Loading Progress"), file = progress_file, sep = "\n")
  cat(glue("Date Range: {start_month} to {end_month}"), file = progress_file, append = TRUE, sep = "\n")
  cat(glue("Started: {Sys.time()}"), file = progress_file, append = TRUE, sep = "\n")
  cat("", file = progress_file, append = TRUE, sep = "\n")
  cat("month,status,records,timestamp", file = progress_file, append = TRUE, sep = "\n")
  
  return(progress_file)
}

update_progress <- function(progress_file, month, status, records) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  progress_line <- glue("{month},{status},{records %||% 'NA'},{timestamp}")
  cat(progress_line, file = progress_file, append = TRUE, sep = "\n")
}

print_progress_summary <- function(results, failed_months) {
  successful <- sum(results == "SUCCESS" | results == "CACHED", na.rm = TRUE)
  total <- length(results)
  
  cat(glue("\n--- Progress Summary ---\n"))
  cat(glue("Processed: {total} months\n"))
  cat(glue("Successful: {successful}\n"))
  cat(glue("Failed: {length(failed_months)}\n"))
  cat(glue("Success rate: {round(successful/total * 100, 1)}%\n"))
}

print_final_summary <- function() {
  available_months <- list_available_months()
  cache_summary <- get_cache_summary()
  
  cat("\n=== FINAL SUMMARY ===\n")
  print(cache_summary)
  
  if (length(available_months) > 0) {
    cat(glue("\nAvailable months: {length(available_months)}\n"))
    cat(glue("From: {min(available_months)} to {max(available_months)}\n"))
    
    total_records <- map_dbl(available_months, function(ym) {
      tryCatch({
        data <- load_monthly_data(ym)
        nrow(data)
      }, error = function(e) 0)
    })
    
    cat(glue("Total crime records: {format(sum(total_records), big.mark = ',')}\n"))
  }
}

generate_data_inventory <- function() {
  available_months <- list_available_months()
  
  if (length(available_months) == 0) {
    cat("No data available\n")
    return(tibble())
  }
  
  cat(glue("Generating inventory for {length(available_months)} months...\n"))
  
  inventory <- map_dfr(available_months, function(ym) {
    tryCatch({
      data <- load_monthly_data(ym)
      
      file_path <- here("data", "processed", glue("crime_data_{ym}.parquet"))
      file_size <- file.size(file_path)
      
      tibble(
        year_month = ym,
        records = nrow(data),
        file_size_mb = round(file_size / 1024^2, 2),
        categories = n_distinct(data$category),
        boroughs = n_distinct(data$borough_name),
        lsoas = n_distinct(data$lsoa_code),
        with_outcomes = sum(!is.na(data$outcome_category) & 
                           data$outcome_category != "investigation-incomplete")
      )
    }, error = function(e) {
      tibble(
        year_month = ym,
        records = NA,
        file_size_mb = NA,
        categories = NA,
        boroughs = NA,
        lsoas = NA,
        with_outcomes = NA
      )
    })
  })
  
  return(inventory)
}

quick_start_demo <- function() {
  cat("=== London Crime Data Quick Start Demo ===\n\n")
  
  cat("1. Testing spatial setup...\n")
  tryCatch({
    boundaries <- load_london_boundaries()
    cat(glue("✓ Loaded {nrow(boundaries)} LSOA boundaries\n"))
  }, error = function(e) {
    cat("✗ Failed to load boundaries:", e$message, "\n")
    return()
  })
  
  cat("\n2. Testing API connection...\n")
  test_month <- "2024-06"
  
  tryCatch({
    cat("Testing borough-by-borough approach with 3 sample boroughs...\n")
    
    borough_polygons <- get_all_borough_polygons()
    test_boroughs <- head(borough_polygons, 3)
    
    total_crimes <- 0
    successful_boroughs <- 0
    
    for (i in 1:3) {
      borough_name <- test_boroughs$borough_name[i]
      borough_polygon <- test_boroughs$api_polygon[i]
      
      cat(glue("  Testing {borough_name}..."))
      
      tryCatch({
        borough_data <- fetch_crime_data_by_borough(test_month, borough_name, borough_polygon)
        cat(glue(" ✓ {nrow(borough_data)} crimes\n"))
        total_crimes <- total_crimes + nrow(borough_data)
        successful_boroughs <- successful_boroughs + 1
      }, error = function(e) {
        cat(glue(" ✗ {e$message}\n"))
      })
      
      Sys.sleep(0.5)
    }
    
    if (successful_boroughs > 0) {
      cat(glue("✓ Borough-by-borough approach working! {total_crimes} crimes from {successful_boroughs}/3 test boroughs\n"))
      cat(glue("✓ Ready to process all {nrow(borough_polygons)} London boroughs\n"))
    } else {
      cat("✗ All test boroughs failed\n")
    }
    
  }, error = function(e) {
    cat("✗ API test failed:", e$message, "\n")
  })
  
  cat("\n3. Cache summary:\n")
  cache_summary <- get_cache_summary()
  print(cache_summary)
  
  cat("\nDemo completed! You can now run:\n")
  cat("- update_monthly_data('YYYY-MM') for single months\n")
  cat("- load_historical_data(2015) for all data since 2015\n")
  cat("- update_latest_month() for the most recent month\n")
}