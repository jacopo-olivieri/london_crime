# London Crime Data Processing Workflow

## Overview

This project implements a robust data pipeline for collecting, processing, and caching London crime data from the Police.uk API. The system uses a borough-by-borough approach to overcome API limitations and provides high-performance data access for Shiny applications.

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Data Source   │───▶│   Processing     │───▶│    Storage      │
│                 │    │                  │    │                 │
│ Police.uk API   │    │ • Spatial joins  │    │ Arrow/Parquet   │
│ 33 Borough      │    │ • Data cleaning  │    │ Fast caching    │
│ Polygon calls   │    │ • Validation     │    │ Version control │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📁 Project Structure

```
london_crime/
├── R/                          # Core processing modules
│   ├── spatial_setup.R         # Geographic data management
│   ├── api_wrapper.R           # Police.uk API integration
│   ├── data_processing.R       # Data transformation pipeline
│   ├── caching.R               # High-performance storage
│   ├── update_data.R           # Workflow orchestration
│   └── bulk_historical.R       # Batch operations
├── data/
│   ├── boundaries/             # London LSOA shapefiles (auto-downloaded)
│   └── processed/              # Monthly parquet cache files
├── config/
│   └── london_polygon.rds      # Pre-computed API polygons
├── logs/                       # Operation logs and progress tracking
├── README.md                   # Setup and usage documentation
└── WORKFLOW.md                 # This workflow guide
```

## 🔄 Data Pipeline Workflow

### 1. Initial Setup (One-time)

```r
# Load required functions
source("R/spatial_setup.R")

# Download and setup London boundaries
setup_london_boundaries()      # Downloads 19MB LSOA shapefiles
load_london_boundaries()       # Loads 4,994 LSOA boundaries
get_borough_boundaries()       # Creates 33 borough polygons
```

**What happens:**
- Downloads London LSOA 2021 boundaries from London Datastore
- Extracts shapefiles for all 33 London boroughs
- Creates API-ready polygon strings for each borough
- Stores configuration for future use

### 2. Monthly Data Collection

```r
# Main entry point for single month
source("R/update_data.R")
update_monthly_data("2024-06")
```

**Step-by-step process:**

1. **Cache Check**: Verifies if data already exists
2. **Borough Processing**: Iterates through all 33 London boroughs
   ```
   [1/33] Fetching Barking and Dagenham... ✓ 1,975 crimes
   [2/33] Fetching Barnet... ✓ 3,152 crimes
   [3/33] Fetching Bexley... ✓ 1,837 crimes
   ...continues for all boroughs
   ```
3. **API Calls**: Each borough polygon stays under 10,000 crime limit
4. **Data Aggregation**: Combines ~85,000 total crimes from all boroughs
5. **Spatial Processing**: Assigns each crime to correct LSOA and borough
6. **Data Cleaning**: Standardizes categories, handles missing values
7. **Quality Validation**: Ensures spatial assignments are correct
8. **Caching**: Saves as `crime_data_YYYY-MM.parquet`
9. **Logging**: Records operation details and summary statistics

### 3. Historical Data Loading

```r
# Bulk processing for historical data
source("R/bulk_historical.R")
load_historical_data(start_year = 2015)
```

**Batch processing features:**
- Generates month list from 2015 to present
- Skips months already cached
- Processes sequentially with progress tracking
- Implements retry logic for failed months
- Provides resume capability for interrupted runs

### 4. Data Loading and Access

```r
# Fast data access
source("R/caching.R")

# Single month
jan_data <- load_monthly_data("2024-01")

# Multiple months
multi_data <- load_multiple_months(c("2024-01", "2024-02", "2024-03"))

# Date range
year_data <- load_date_range("2024-01-01", "2024-12-31")
```

## 📊 Data Schema

Each monthly dataset contains:

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `crime_id` | character | Unique crime identifier | `"abc123..."` |
| `category` | character | Standardized crime type | `"burglary"` |
| `location_type` | character | Where crime occurred | `"Force"` |
| `month` | character | Crime month | `"2024-06"` |
| `date` | Date | Parsed date object | `2024-06-01` |
| `year` | integer | Year | `2024` |
| `month_num` | integer | Month number | `6` |
| `quarter` | integer | Quarter | `2` |
| `latitude` | numeric | WGS84 latitude | `51.5074` |
| `longitude` | numeric | WGS84 longitude | `-0.1278` |
| `lsoa_code` | character | LSOA identifier | `"E01000001"` |
| `lsoa_name` | character | LSOA name | `"City of London 001A"` |
| `borough_name` | character | London borough | `"City of London"` |
| `outcome_category` | character | Crime outcome | `"investigation-complete"` |
| `outcome_date` | character | Outcome date | `"2024-06"` |
| `geometry` | sfc_POINT | Spatial coordinates | `POINT(...)` |

## 🚀 Common Operations

### Quick Start Demo
```r
source("R/bulk_historical.R")
quick_start_demo()
```

### Update Latest Month
```r
source("R/update_data.R")
update_latest_month()  # Auto-detects most recent available month
```

### Fill Missing Data
```r
# Find and update any missing months
update_missing_months(start_year_month = "2020-01")
```

### Data Quality Checks
```r
# Verify data integrity
integrity_report <- check_data_integrity()

# Generate data inventory
inventory <- generate_data_inventory()

# View cache summary
cache_summary <- get_cache_summary()
```

### Cache Management
```r
# List available data
available_months <- list_available_months()

# Clean old cache files (keep last 24 months)
clean_old_cache(keep_months = 24)
```

## 🎯 Shiny Integration Examples

### Basic Data Loading
```r
# In your Shiny server.R
crime_data <- reactive({
  selected_months <- format(seq(input$start_date, input$end_date, by = "month"), "%Y-%m")
  load_multiple_months(selected_months)
})
```

### Interactive Filtering
```r
# Filtered dataset for maps and tables
filtered_data <- reactive({
  crime_data() %>%
    filter(
      borough_name %in% input$selected_boroughs,
      category %in% input$crime_types,
      between(date, input$date_range[1], input$date_range[2])
    )
})
```

### Borough Comparison Table
```r
# Summary table for dashboard
borough_summary <- reactive({
  filtered_data() %>%
    count(borough_name, category) %>%
    pivot_wider(names_from = category, values_from = n, values_fill = 0)
})
```

### Leaflet Mapping
```r
# Interactive crime map
output$crime_map <- renderLeaflet({
  leaflet(filtered_data()) %>%
    addTiles() %>%
    addCircleMarkers(
      ~longitude, ~latitude,
      popup = ~paste(category, "<br>", borough_name),
      clusterOptions = markerClusterOptions()
    )
})
```

## 🔧 Maintenance Workflow

### Regular Updates (Monthly)
```r
# Update with latest available data
update_latest_month()

# Or specify exact month
update_monthly_data("2024-07")
```

### Data Monitoring
```r
# Check for any data quality issues
integrity_report <- check_data_integrity()

# Monitor cache size and coverage
cache_summary <- get_cache_summary()
print(cache_summary)
```

### Error Recovery
```r
# If some months failed to process
failed_months <- c("2024-03", "2024-04")
for (month in failed_months) {
  update_monthly_data(month, force_refresh = TRUE)
}
```

## 📈 Performance Characteristics

- **Data Volume**: ~85,000 crimes per month (all London)
- **Processing Time**: ~2-3 minutes per month (33 borough API calls)
- **Storage**: ~2-5MB per month (parquet compression)
- **Loading Speed**: <1 second for monthly data (Arrow/Parquet)
- **API Limits**: Each borough <10,000 crimes (well within Police.uk limits)

## 🛠️ Troubleshooting

### Common Issues

1. **API 503 Errors**: The borough-by-borough approach resolves this
2. **Missing Spatial Assignments**: Some crimes may fall outside London boundaries
3. **Slow Loading**: Use date ranges instead of loading all data at once
4. **Memory Issues**: Process data in smaller chunks for large date ranges

### Log Files

Check the `logs/` directory for detailed operation information:
- `update_YYYY-MM_*.log` - Monthly update logs
- `historical_load_*.log` - Bulk loading progress

### Data Validation

```r
# Run comprehensive integrity checks
integrity_report <- check_data_integrity()

# Check specific month
specific_check <- check_data_integrity("2024-06")
```

## 🎯 Next Steps

1. **Initial Setup**: Run `quick_start_demo()` to verify everything works
2. **Historical Data**: Execute `load_historical_data(2015)` for complete dataset
3. **Shiny Development**: Use cached data for fast, responsive applications
4. **Automation**: Set up scheduled runs for monthly updates

This workflow ensures reliable, high-performance access to London crime data while respecting API constraints and maintaining data quality standards.