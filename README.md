# London Crime Data Processing Backend

A robust R data pipeline for fetching, processing, and caching crime data for Greater London from the Police.uk API. Designed to power interactive Shiny applications with efficient spatial analysis capabilities.

## Features

- **Automated Data Fetching**: Direct integration with Police.uk API
- **Spatial Processing**: Automatic assignment of crimes to London Boroughs and LSOAs
- **High-Performance Caching**: Arrow/Parquet-based storage for fast loading
- **Error Handling**: Robust retry logic and comprehensive logging
- **GitHub Deployment Ready**: Relative paths and environment-agnostic configuration

## Quick Start

### Prerequisites

- R (>= 4.0)
- renv package for dependency management

### Installation

1. Clone and navigate to the project:
```bash
git clone https://github.com/jacopo-olivieri/london_crime.git
cd london_crime
```

2. Activate the R environment:
```r
renv::activate()
renv::restore()
```

3. Run the quick start demo:
```r
source("R/bulk_historical.R")
quick_start_demo()
```

## Usage

### Basic Operations

```r
# Load the main functions
source("R/update_data.R")

# Update a single month
crime_data <- update_monthly_data("2024-01")

# Update the latest available month
latest_data <- update_latest_month()

# Load historical data from 2015
load_historical_data(start_year = 2015)
```

### Data Loading

```r
source("R/caching.R")

# Load specific months
jan_data <- load_monthly_data("2024-01")
feb_data <- load_monthly_data("2024-02")

# Load multiple months
multi_month <- load_multiple_months(c("2024-01", "2024-02", "2024-03"))

# Load date range
year_data <- load_date_range("2024-01-01", "2024-12-31")
```

### Data Management

```r
# Check available data
available_months <- list_available_months()
cache_summary <- get_cache_summary()

# Data integrity checks
integrity_report <- check_data_integrity()

# Generate data inventory
inventory <- generate_data_inventory()
```

## Data Schema

Each monthly parquet file contains an sf object with these columns:

| Column | Type | Description |
|--------|------|-------------|
| `crime_id` | character | Unique crime identifier |
| `category` | character | Standardized crime category |
| `location_type` | character | Type of location where crime occurred |
| `month` | character | Crime month (YYYY-MM) |
| `date` | Date | Parsed date object |
| `year` | integer | Year |
| `month_num` | integer | Month number (1-12) |
| `quarter` | integer | Quarter (1-4) |
| `latitude` | numeric | WGS84 latitude |
| `longitude` | numeric | WGS84 longitude |
| `lsoa_code` | character | Lower Layer Super Output Area code |
| `lsoa_name` | character | LSOA name |
| `borough_name` | character | London Borough name |
| `outcome_category` | character | Crime outcome category |
| `outcome_date` | character | Outcome date if available |
| `geometry` | sfc_POINT | Spatial geometry (sf) |

## File Structure

```
london_crime/
├── R/
│   ├── spatial_setup.R      # Boundary data management
│   ├── api_wrapper.R        # Police.uk API functions
│   ├── data_processing.R    # Data cleaning and spatial joins
│   ├── caching.R           # Parquet-based caching system
│   ├── update_data.R       # Main update functions
│   └── bulk_historical.R   # Historical data loading
├── data/
│   ├── boundaries/         # London LSOA shapefiles
│   └── processed/          # Monthly parquet cache files
├── config/
│   └── london_polygon.rds  # Pre-computed API polygon
├── logs/                   # Operation logs
└── README.md
```

## Crime Categories

The system standardizes Police.uk crime categories:

- `anti-social-behaviour`
- `bicycle-theft`
- `burglary`
- `criminal-damage-arson`
- `drugs`
- `other-theft`
- `possession-of-weapons`
- `public-order`
- `robbery`
- `shoplifting`
- `theft-from-the-person`
- `vehicle-crime`
- `violence-and-sexual-offences`
- `other-crime`

## API Limitations

- Police.uk API returns maximum 10,000 crimes per request
- Data is typically available 1-2 months behind current date
- Rate limiting is automatically handled with exponential backoff

## Performance Tips

1. **Use date ranges wisely**: Load only the months you need
2. **Leverage caching**: Check `monthly_cache_exists()` before API calls
3. **Filter after loading**: Parquet files load quickly for subsequent filtering
4. **Monitor file sizes**: Each monthly file is typically 2-5MB

## Shiny Integration

Example Shiny app usage:

```r
library(shiny)
library(sf)
library(arrow)

# In server.R
crime_data <- reactive({
  months_to_load <- input$date_range  # e.g., c("2024-01", "2024-02")
  load_multiple_months(months_to_load)
})

filtered_data <- reactive({
  crime_data() %>%
    filter(
      category %in% input$crime_types,
      borough_name %in% input$boroughs
    )
})
```

## Troubleshooting

### Common Issues

1. **Boundary download fails**: Check internet connection and London Datastore availability
2. **API timeout**: The system auto-retries with exponential backoff
3. **Missing spatial assignments**: Some crimes may fall outside London boundaries
4. **Memory issues**: Process data in smaller date ranges

### Error Logs

Check the `logs/` directory for detailed operation logs:
- `update_YYYY-MM_*.log` - Monthly update logs
- `historical_load_*.log` - Bulk loading progress

### Data Validation

Run integrity checks if you suspect data issues:

```r
source("R/update_data.R")
integrity_report <- check_data_integrity()
print(integrity_report)
```

## Development

### Adding New Features

1. Follow the existing code structure and naming conventions
2. Add comprehensive error handling
3. Include logging for debugging
4. Update tests and documentation

### Testing

Test with a recent month before processing historical data:

```r
# Test with recent month
test_data <- update_monthly_data("2024-01")
summary(test_data)
```

## Dependencies

Core packages (managed by renv):
- `tidyverse` - Data manipulation
- `sf` - Spatial data processing  
- `httr` - HTTP requests
- `arrow` - High-performance data files
- `here` - Path management
- `glue` - String interpolation
- `lubridate` - Date handling

## License

This project uses data from Police.uk under the Open Government License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

For issues or questions, please create a GitHub issue.