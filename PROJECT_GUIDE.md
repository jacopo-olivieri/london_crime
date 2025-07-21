# London Crime Data Project - Comprehensive Guide

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture & Design](#architecture--design)
3. [Setup & Installation](#setup--installation)
4. [Data Pipeline](#data-pipeline)
5. [Code Documentation](#code-documentation)
6. [Shiny Dashboard](#shiny-dashboard)
7. [Data Schema](#data-schema)
8. [Operations & Maintenance](#operations--maintenance)
9. [Customization & Extensions](#customization--extensions)
10. [Troubleshooting](#troubleshooting)

---

## Project Overview

### Purpose
This project creates a robust, scalable data pipeline for collecting, processing, and visualizing London crime data from the Police.uk API. It provides an interactive Shiny dashboard for exploring crime patterns across London's 33 boroughs and 4,994 LSOAs (Lower Layer Super Output Areas).

### Key Capabilities
- **Automated Data Collection**: Borough-by-borough API collection respecting 10k crime limits
- **High-Performance Storage**: Arrow/Parquet caching for instant data access
- **Interactive Visualization**: Multi-page Shiny dashboard with maps, trends, and tables
- **Spatial Analysis**: Crime assignment to boroughs and LSOAs with spatial joins
- **Historical Analysis**: Data collection since 2015 with trend analysis capabilities

### Technology Stack
- **Language**: R (>= 4.0)
- **Data Processing**: tidyverse, sf (spatial), lubridate (dates)
- **API Integration**: httr (HTTP requests)
- **Storage**: arrow (Parquet files)
- **Visualization**: Shiny, leaflet (maps), plotly (charts), DT (tables)
- **Documentation**: Quarto (dashboard), Markdown (docs)
- **Environment**: renv (dependency management)

---

## Architecture & Design

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    London Crime Data System                 │
├─────────────────────────────────────────────────────────────┤
│  Data Sources          │  Processing Layer  │  Presentation │
│  ─────────────         │  ─────────────────  │  ──────────── │
│  • Police.uk API       │  • R Scripts       │  • Shiny App  │
│  • London Datastore    │  • Spatial Joins   │  • Leaflet    │
│  • LSOA Boundaries     │  • Data Cleaning   │  • Plotly     │
│                        │  • Validation      │  • DT Tables  │
├─────────────────────────────────────────────────────────────┤
│  Storage Layer                                              │
│  ──────────────                                             │
│  • Parquet Cache (data/processed/)                         │
│  • Spatial Boundaries (data/boundaries/)                   │
│  • Configuration (config/)                                 │
│  • Logs (logs/)                                           │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Police.uk   │───▶│   Borough   │───▶│   Spatial   │───▶│   Parquet   │
│ API (33     │    │ Processing  │    │ Assignment  │    │   Cache     │
│ requests)   │    │ & Cleaning  │    │ (LSOA/Boro) │    │ (monthly)   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                   │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Shiny     │◀───│  Interactive│◀───│    Data     │◀───│   Fast      │
│ Dashboard   │    │  Filtering  │    │   Loading   │    │   Access    │
│ (4 pages)   │    │ & Analysis  │    │ (Arrow)     │    │ (<1 second) │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Design Principles

1. **Modularity**: Each R script handles a specific responsibility
2. **Performance**: Arrow/Parquet for fast I/O, efficient spatial operations
3. **Reliability**: Robust error handling, retry logic, comprehensive logging
4. **Scalability**: Borough-by-borough processing scales within API limits
5. **Maintainability**: Clear documentation, consistent naming, version control

---

## Setup & Installation

### Prerequisites
- R (>= 4.0.0)
- RStudio (recommended)
- Git (for version control)
- Internet connection (for data download)

### Initial Setup

1. **Clone/Download Project**
   ```bash
   git clone <your-repo-url>
   cd london_crime
   ```

2. **Activate R Environment**
   ```r
   # In RStudio or R console
   renv::activate()
   renv::restore()  # Install all required packages
   ```

3. **Verify Installation**
   ```r
   source("R/bulk_historical.R")
   quick_start_demo()
   ```

4. **Initial Data Collection**
   ```r
   # Test with recent month first
   source("R/update_data.R")
   update_monthly_data("2024-06")
   
   # Then load historical data (takes ~4-6 hours)
   source("R/bulk_historical.R")
   load_historical_data(start_year = 2015)
   ```

### Package Dependencies

**Core Data Processing:**
- `tidyverse` (1.3.2+): Data manipulation and visualization
- `sf` (1.0.9+): Spatial data processing
- `arrow` (13.0.0+): High-performance data storage
- `here` (1.0.1+): Path management

**API & Web:**
- `httr` (1.4.6+): HTTP requests to Police.uk API
- `lubridate` (1.9.2+): Date handling
- `glue` (1.6.2+): String interpolation

**Visualization:**
- `shiny` (1.7.4+): Interactive web applications
- `leaflet` (2.1.2+): Interactive maps
- `plotly` (4.10.2+): Interactive charts
- `DT` (0.28+): Interactive tables

### Directory Structure After Setup

```
london_crime/
├── R/                          # Core processing modules
│   ├── spatial_setup.R         ✓ Geographic data management
│   ├── api_wrapper.R           ✓ Police.uk API integration  
│   ├── data_processing.R       ✓ Data transformation
│   ├── caching.R               ✓ Parquet storage system
│   ├── update_data.R           ✓ Workflow orchestration
│   └── bulk_historical.R       ✓ Batch operations
├── data/
│   ├── boundaries/             ✓ LSOA shapefiles (auto-downloaded)
│   └── processed/              ✓ Monthly parquet files
├── config/
│   └── london_polygon.rds      ✓ API polygon cache
├── logs/                       ✓ Operation logs
├── london_crime.qmd            ✓ Shiny dashboard
├── london_crime.Rproj          ✓ RStudio project
├── renv.lock                   ✓ Package versions
├── README.md                   ✓ Quick start guide
├── WORKFLOW.md                 ✓ Operational procedures
└── PROJECT_GUIDE.md            ✓ This comprehensive guide
```

---

## Data Pipeline

### Overview
The data pipeline collects crime data through a borough-by-borough approach, processes it with spatial joins, and caches results for fast access.

### 1. API Collection Strategy

**Challenge Solved**: Police.uk API returns 503 errors for large area requests exceeding 10,000 crimes.

**Solution**: Borough-by-Borough Collection
- London divided into 33 individual borough requests
- Each borough typically has 1,000-5,000 crimes per month
- Sequential processing with rate limiting (0.5s delays)
- Comprehensive retry logic for failed requests

```r
# Example: Manual borough collection
source("R/api_wrapper.R")
crime_data <- fetch_crime_data("2024-06")  # Processes all 33 boroughs
```

### 2. Spatial Processing

**LSOA Assignment Process:**
1. Load 4,994 London LSOA boundaries from London Datastore
2. Transform crime coordinates to British National Grid (EPSG:27700)
3. Perform spatial join (`st_within`) to assign crimes to LSOAs
4. Extract borough names from LSOA data
5. Transform back to WGS84 (EPSG:4326) for web mapping

**Quality Assurance:**
- Validates that >95% of crimes get LSOA assignments
- Logs unmatched crimes for investigation
- Ensures spatial consistency across months

### 3. Data Cleaning & Standardization

**Crime Categories Standardized:**
```r
# Raw API categories → Standardized categories
"Anti-social behaviour" → "anti-social-behaviour"
"Violence and sexual offences" → "violence-and-sexual-offences"
"Public order" → "public-order"
# ... (14 total categories)
```

**Outcome Processing:**
- Missing outcomes → "investigation-incomplete"
- Date parsing and validation
- Outcome category standardization

**Data Enrichment:**
- Add year, month_num, quarter columns
- Calculate derived geographic fields
- Generate unique identifiers

### 4. Caching System

**Parquet Storage Benefits:**
- 5-10x faster loading than CSV/RDS
- Columnar storage for efficient filtering
- Compression reduces file sizes by ~70%
- Schema evolution support

**Caching Strategy:**
```r
# File naming: crime_data_YYYY-MM.parquet
# Example: crime_data_2024-06.parquet (3.2MB, ~85,000 records)

# Smart caching functions:
monthly_cache_exists("2024-06")     # Check if data exists
load_monthly_data("2024-06")        # Load single month
load_multiple_months(c("2024-01", "2024-02"))  # Load range
```

### 5. Error Handling & Logging

**Comprehensive Logging:**
- Operation timestamps and durations
- API response codes and retry attempts
- Data quality metrics (record counts, missing values)
- Error messages with context

**Error Recovery:**
- Borough-level failure isolation
- Automatic retry with exponential backoff
- Resume capability for interrupted batch operations
- Data integrity validation

**Log Locations:**
```
logs/
├── update_2024-06_20240720_143022.log      # Single month updates
├── historical_load_20240720_100000.log     # Bulk operations
└── integrity_check_20240720.log            # Quality assurance
```

---

## Code Documentation

### File Structure & Dependencies

```
R/spatial_setup.R ←─────┐
R/api_wrapper.R ←───────┼─── R/data_processing.R ←─── R/update_data.R
R/caching.R ←───────────┘                           └─── R/bulk_historical.R
```

### R/spatial_setup.R

**Purpose**: Manages all spatial data operations and boundary management.

**Key Functions:**

```r
# Core boundary management
load_london_boundaries()           # Returns: sf object with 4,994 LSOAs
get_borough_boundaries()           # Returns: sf object with 33 boroughs  
get_all_borough_polygons()         # Returns: API-ready polygon strings

# Configuration management
setup_london_boundaries()          # One-time setup: downloads boundaries
create_borough_polygon(boundary)   # Converts sf to API polygon string
get_london_bbox()                  # Returns: bounding box coordinates
```

**Data Sources:**
- London Datastore: LSOA 2021 boundaries
- Auto-download: 19MB shapefile collection
- Processing: Combines 33 borough files into unified dataset

**Spatial Operations:**
- CRS transformations (WGS84 ↔ British National Grid)
- Polygon simplification for API compatibility
- Boundary validation and quality checks

### R/api_wrapper.R

**Purpose**: Handles all Police.uk API interactions with robust error handling.

**Key Functions:**

```r
# Main collection functions
fetch_crime_data(year_month)                    # Borough-by-borough collection
fetch_crime_data_by_borough(year_month, name)  # Single borough collection
retry_api_call(url, params, max_retries)       # Robust HTTP handling

# Data processing
process_api_response(api_data, year_month)     # JSON → sf conversion
validate_crime_data(crime_sf)                  # Data quality checks
create_empty_crime_sf()                        # Error state handling
```

**API Strategy:**
- Rate limiting: 0.5s between requests
- Retry logic: Exponential backoff (1s, 2s, 4s)
- Error isolation: Failed boroughs don't stop others
- Response validation: Checks for valid JSON and expected fields

**Performance Optimizations:**
- Efficient JSON parsing with error handling
- Memory-conscious processing for large responses
- Progress tracking for user feedback

### R/data_processing.R

**Purpose**: Core data transformation pipeline with spatial intelligence.

**Key Functions:**

```r
# Main processing pipeline
process_monthly_crime(crime_sf, boundaries)    # Full processing workflow
standardize_crime_data(crime_sf)               # Data cleaning & standardization
perform_spatial_join(crime_sf, boundaries)    # LSOA assignment
finalize_crime_data(crime_with_areas)         # Final formatting

# Quality assurance
validate_processed_data(processed_sf)          # Data integrity checks
get_crime_summary(processed_sf)               # Summary statistics
create_empty_processed_sf()                   # Error state handling
```

**Processing Steps:**
1. **Standardization**: Clean categories, handle missing values
2. **Spatial Join**: Assign crimes to LSOAs using geometric intersection
3. **Enrichment**: Add derived fields (year, quarter, etc.)
4. **Validation**: Ensure data quality and spatial consistency
5. **Formatting**: Standardize column order and types

**Data Quality Measures:**
- Spatial assignment validation (>95% success rate)
- Category standardization verification
- Date range consistency checks
- Geographic boundary validation

### R/caching.R

**Purpose**: High-performance data storage and retrieval using Arrow/Parquet.

**Key Functions:**

```r
# Cache management
monthly_cache_exists(year_month)               # Check cache availability
save_monthly_data(crime_sf, year_month)       # Store processed data
load_monthly_data(year_month)                 # Load single month
load_multiple_months(year_months)             # Load multiple months

# Bulk operations
load_date_range(start_date, end_date)         # Load by date range
list_available_months()                       # Cache inventory
get_cache_summary()                           # Storage statistics

# Maintenance
clean_old_cache(keep_months)                  # Storage cleanup
```

**Performance Features:**
- Columnar storage: Efficient for filtering operations
- Compression: 70% size reduction vs. CSV
- Schema validation: Ensures data consistency
- Lazy loading: Only reads required columns

**Storage Strategy:**
- Monthly files: `crime_data_YYYY-MM.parquet`
- Atomic operations: Complete success or rollback
- Version tracking: Metadata embedded in files
- Backup friendly: Immutable monthly snapshots

### R/update_data.R

**Purpose**: Orchestrates the complete data pipeline with comprehensive logging.

**Key Functions:**

```r
# Main orchestration
update_monthly_data(year_month, force_refresh) # Complete monthly pipeline
update_latest_month(force_refresh)             # Auto-detect latest month
update_missing_months(start, end)              # Fill gaps in data

# Data management
get_latest_available_month()                   # Intelligent month detection
check_data_integrity(year_months)             # Quality validation
setup_logging(year_month)                     # Initialize logging

# Logging utilities
log_message(message, log_file, level)         # Structured logging
log_summary(summary_stats, log_file)          # Summary statistics
```

**Workflow Orchestration:**
1. **Setup**: Initialize logging, validate inputs
2. **Cache Check**: Skip if data exists (unless force_refresh)
3. **Data Collection**: Execute API collection pipeline
4. **Processing**: Run spatial joins and data cleaning
5. **Validation**: Verify data quality and completeness
6. **Caching**: Store results in Parquet format
7. **Logging**: Record operation summary and statistics

**Smart Features:**
- Automatic latest month detection (accounts for API delay)
- Resume capability for interrupted operations
- Comprehensive progress tracking
- Performance metrics and timing

### R/bulk_historical.R

**Purpose**: Batch operations for historical data collection and management.

**Key Functions:**

```r
# Batch operations
load_historical_data(start_year, end_year)    # Bulk historical collection
load_historical_sequential(months, progress)  # Sequential processing
retry_failed_months(failed_months)           # Error recovery

# Progress management
setup_progress_tracking(start, end)          # Initialize progress logging
update_progress(file, month, status)         # Track processing status
print_progress_summary(results)              # Status reporting

# Analysis utilities
generate_data_inventory()                    # Comprehensive data catalog
quick_start_demo()                          # System validation
print_final_summary()                       # Operation summary
```

**Batch Processing Features:**
- Progress tracking: Month-by-month status
- Resume capability: Continue from failed point
- Parallel processing: Ready for future implementation
- Comprehensive reporting: Success/failure statistics

**Historical Data Management:**
- Systematic processing from 2015 onwards
- Intelligent gap detection and filling
- Data consistency verification across years
- Performance optimization for large-scale operations

---

## Shiny Dashboard

### Architecture Overview

The Shiny dashboard is built using Quarto's dashboard format with server-side Shiny integration. It provides a multi-page interface for comprehensive crime data exploration.

### Dashboard Structure

```
london_crime.qmd
├── YAML Header (format: dashboard, server: shiny)
├── Setup Context (libraries, data initialization)
├── Page 1: Crime Map (interactive spatial visualization)
├── Page 2: Borough Analysis (detailed borough-level insights)
├── Page 3: Crime Trends (temporal pattern analysis)
├── Page 4: Data Explorer (raw data access and export)
└── Server Context (reactive programming logic)
```

### Page 1: Crime Map

**Layout:**
```
┌─────────────────────────────────────────────────────┐
│ Sidebar (30%)           │ Main Panel (70%)         │
│ ─────────────────────   │ ─────────────────────     │
│ • Date Range Picker     │ • Interactive Leaflet    │
│ • Borough Multi-Select  │   Map (500px height)     │
│ • Crime Type Filter     │ • Toggle: Borough/LSOA   │
│ • Map Level Toggle      │                           │
│ • Summary Statistics    │ ───────────────────────   │
│                         │ • Crime Statistics Table │
│                         │ • Top Crimes Chart       │
└─────────────────────────────────────────────────────┘
```

**Key Features:**

1. **Interactive Map (renderLeaflet)**
   - **Borough View**: Choropleth visualization with crime density coloring
   - **LSOA View**: Point markers with clustering for performance
   - **Popups**: Detailed crime information on click
   - **Legend**: Dynamic color scale based on data range

2. **Smart Performance**
   - Point sampling: Limits to 10,000 points for smooth rendering
   - Dynamic color scaling: Adjusts to filtered data range
   - Efficient spatial aggregation: Pre-computed borough summaries

3. **Real-time Filtering**
   - Date range: Loads only required months
   - Geographic: Borough-level filtering
   - Categorical: Crime type selection
   - Summary updates: Live statistics in sidebar

**Technical Implementation:**
```r
# Borough-level choropleth
borough_crimes <- filtered_data() %>%
  st_drop_geometry() %>%
  count(borough_name, name = "crime_count")

borough_map_data <- borough_boundaries %>%
  left_join(borough_crimes, by = "borough_name") %>%
  mutate(crime_count = replace_na(crime_count, 0))

pal <- colorNumeric("YlOrRd", domain = borough_map_data$crime_count)
```

### Page 2: Borough Analysis

**Purpose**: Deep-dive analysis for individual boroughs with comparative context.

**Components:**

1. **Borough Trends Chart (renderPlotly)**
   - Time series visualization with Plotly
   - Multi-category line plots
   - Interactive zoom and hover
   - Responsive to date range changes

2. **Borough Comparison Table (DT::renderDataTable)**
   - Cross-tabulation: Boroughs × Crime Types
   - Sortable columns with total calculations
   - Pagination for large datasets
   - Export functionality

**Reactive Pattern:**
```r
# Event-reactive for performance optimization
analysis_data <- eventReactive(input$update_analysis, {
  # Only triggers when "Update Analysis" button clicked
  # Prevents expensive recalculations on every input change
})
```

### Page 3: Crime Trends

**Purpose**: Temporal pattern analysis with multiple aggregation levels.

**Features:**

1. **Multi-Borough Comparison**
   - Select multiple boroughs for comparison
   - Time series with color-coded borough lines
   - Configurable time aggregation (monthly/quarterly/yearly)

2. **Seasonal Analysis**
   - Average monthly crime patterns
   - Identifies seasonal trends across all years
   - Bar chart with month names

**Technical Highlights:**
```r
# Dynamic time aggregation
if (input$trend_aggregation == "quarter") {
  trends <- data_for_trends %>%
    group_by(borough_name, year, quarter) %>%
    summarise(count = n(), .groups = "drop") %>%
    mutate(date = as.Date(paste(year, (quarter-1)*3 + 1, "01", sep = "-")))
}
```

### Page 4: Data Explorer

**Purpose**: Raw data access with advanced filtering and export capabilities.

**Components:**

1. **Advanced Data Table (DT::renderDataTable)**
   - Column-level filtering with dropdown menus
   - Full-text search across all fields
   - Pagination with configurable page size
   - Responsive column sizing

2. **Export Functionality**
   - CSV download of filtered data
   - Maintains current filter state
   - Real-time file size estimation

3. **Data Information Panel**
   - Record counts and memory usage
   - Selected month overview
   - Cache status and freshness

### Reactive Programming Patterns

**1. Core Data Reactive**
```r
crime_data <- reactive({
  # Loads data based on date range selection
  # Caches result until date range changes
  # Returns empty data frame if no data available
})
```

**2. Filtered Data Reactive**
```r
filtered_data <- reactive({
  req(crime_data(), input$selected_boroughs, input$selected_categories)
  # Depends on crime_data() reactive
  # Updates whenever base data or filters change
  # Used by multiple output functions
})
```

**3. Event-Reactive Pattern**
```r
analysis_data <- eventReactive(input$update_analysis, {
  # Only updates when button clicked
  # Prevents expensive operations on every input change
  # Good for computationally intensive operations
})
```

### Performance Optimizations

**1. Data Loading Strategy**
- Lazy loading: Only loads selected date ranges
- Caching: Leverages fast Parquet access
- Progressive enhancement: Basic functionality loads first

**2. Map Rendering**
- Point sampling: Limits LSOA points to 10,000 for performance
- Clustering: Groups nearby points for visual clarity
- Efficient redraws: Only updates when necessary

**3. Chart Optimization**
- Plotly integration: Hardware-accelerated rendering
- Data aggregation: Pre-computed summaries where possible
- Responsive sizing: Adapts to screen size

**4. Memory Management**
- `st_drop_geometry()`: Removes spatial data when not needed
- Efficient filtering: Uses dplyr for fast operations
- Garbage collection: Implicit through reactive invalidation

---

## Data Schema

### Core Data Structure

Each monthly dataset is an `sf` (Simple Features) object with the following schema:

```r
# Example structure for crime_data_2024-06.parquet
crime_sf <- tibble(
  # Crime Identifiers
  crime_id = "abc123...",                    # chr: Unique crime identifier (64 chars)
  
  # Crime Details  
  category = "burglary",                     # chr: Standardized crime type
  location_type = "Force",                   # chr: BTP vs Force location
  location_subtype = "Station",              # chr: Specific location details
  
  # Temporal Information
  month = "2024-06",                         # chr: Crime month (YYYY-MM)
  date = as.Date("2024-06-01"),             # Date: Parsed date object
  year = 2024L,                             # int: Year
  month_num = 6L,                           # int: Month number (1-12)
  quarter = 2L,                             # int: Quarter (1-4)
  
  # Geographic Information
  latitude = 51.5074,                       # dbl: WGS84 latitude
  longitude = -0.1278,                      # dbl: WGS84 longitude
  
  # Administrative Geography
  lsoa_code = "E01000001",                  # chr: LSOA identifier
  lsoa_name = "City of London 001A",        # chr: LSOA name
  borough_name = "City of London",          # chr: Borough name
  
  # Crime Outcomes
  outcome_category = "investigation-complete", # chr: Outcome type
  outcome_date = "2024-06",                 # chr: Outcome date
  
  # Spatial Geometry
  geometry = POINT(...)                     # sfc_POINT: Spatial coordinates
)
```

### Crime Categories (Standardized)

| API Category | Standardized Value | Description |
|--------------|-------------------|-------------|
| "Anti-social behaviour" | `anti-social-behaviour` | Public nuisance, noise complaints |
| "Bicycle theft" | `bicycle-theft` | Theft of bicycles |
| "Burglary" | `burglary` | Breaking and entering |
| "Criminal damage and arson" | `criminal-damage-arson` | Property damage, arson |
| "Drugs" | `drugs` | Drug-related offenses |
| "Other theft" | `other-theft` | Theft not otherwise specified |
| "Possession of weapons" | `possession-of-weapons` | Weapons offenses |
| "Public order" | `public-order` | Disorder, breach of peace |
| "Robbery" | `robbery` | Theft with force/threat |
| "Shoplifting" | `shoplifting` | Retail theft |
| "Theft from the person" | `theft-from-the-person` | Pickpocketing, personal theft |
| "Vehicle crime" | `vehicle-crime` | Auto theft, vehicle damage |
| "Violence and sexual offences" | `violence-and-sexual-offences` | Violent crimes, sexual offenses |
| "Other crime" | `other-crime` | Crimes not otherwise categorized |

### Outcome Categories

| Outcome Code | Description | Frequency |
|--------------|-------------|-----------|
| `investigation-complete` | Investigation complete; no suspect identified | ~40% |
| `under-investigation` | Currently under investigation | ~25% |
| `investigation-incomplete` | No outcome recorded/missing data | ~15% |
| `unable-to-prosecute` | Unable to prosecute suspect | ~8% |
| `offender-cautioned` | Offender given a caution | ~5% |
| `court-result-unavailable` | Court result unavailable | ~3% |
| `local-resolution` | Local resolution | ~2% |
| `offender-charged` | Suspect charged | ~2% |

### Geographic Hierarchy

```
Greater London (Region)
├── 33 London Boroughs
│   ├── Barking and Dagenham (115 LSOAs)
│   ├── Barnet (220 LSOAs)
│   ├── Bexley (148 LSOAs)
│   └── ... (30 more boroughs)
└── 4,994 LSOAs (Lower Layer Super Output Areas)
    ├── Average population: ~1,500 people
    ├── Geographic building blocks for analysis
    └── Stable boundaries for longitudinal analysis
```

### File Formats & Storage

**1. Processed Crime Data**
```
data/processed/crime_data_YYYY-MM.parquet
├── Format: Apache Parquet (columnar)
├── Size: ~2-5MB per month (~85,000 records)
├── Compression: Snappy (70% size reduction)
├── Schema: Fixed schema with metadata
└── Access: Arrow/R for instant loading
```

**2. Spatial Boundaries**
```
data/boundaries/lsoa/LB_shp/
├── Format: ESRI Shapefile collection
├── Source: London Datastore (OGL v2 license)
├── Update: Annual (LSOA boundaries stable)
├── Processing: Combined into single sf object
└── Usage: Spatial joins, mapping, analysis
```

**3. Configuration Files**
```
config/london_polygon.rds
├── Content: Pre-computed API polygons
├── Purpose: Borough boundary strings for API
├── Update: Regenerated when boundaries change
└── Format: Native R serialization
```

### Data Quality Metrics

**Typical Monthly Statistics:**
- Total records: ~85,000 crimes
- Geographic coverage: 33/33 boroughs
- LSOA assignment rate: >95%
- Missing coordinates: <1%
- Outcome data availability: ~60%
- Duplicate crime IDs: 0%

**Quality Assurance Checks:**
1. **Spatial Validation**: All crimes within London boundaries
2. **Temporal Consistency**: Month field matches file name
3. **Category Standardization**: All categories in expected set
4. **Geographic Completeness**: Borough and LSOA assignments
5. **Data Integrity**: No duplicate crime IDs within month

---

## Operations & Maintenance

### Daily Operations

**System Health Checks**
```r
# Check cache status and data freshness
source("R/caching.R")
cache_summary <- get_cache_summary()
print(cache_summary)

# Verify data integrity
source("R/update_data.R")
integrity_report <- check_data_integrity()
print(integrity_report)
```

**Expected Output:**
```
Cache Summary:
Available months: 118
Date range: 2015-01 to 2024-10
Total cache files: 118
Total cache size: 387.5 MB
Average file size: 3.3 MB

Data Integrity: All checks passed ✓
```

### Weekly Operations

**1. Update Latest Month**
```r
# Automatic detection and update of latest available month
source("R/update_data.R")
update_latest_month()
```

**2. Fill Missing Data**
```r
# Check for and fill any gaps in historical data
update_missing_months(start_year_month = "2024-01")
```

**3. Cache Maintenance**
```r
# Clean old cache files (keep last 24 months)
source("R/caching.R")
clean_old_cache(keep_months = 24)
```

### Monthly Operations

**1. Data Quality Assessment**
```r
# Generate comprehensive data inventory
source("R/bulk_historical.R")
inventory <- generate_data_inventory()
View(inventory)

# Check for data anomalies
recent_months <- tail(list_available_months(), 6)
integrity_check <- check_data_integrity(recent_months)
```

**2. Performance Review**
```r
# Review processing logs for performance trends
log_files <- list.files("logs/", pattern = "update_.*\\.log", full.names = TRUE)
recent_logs <- tail(log_files, 10)

# Manual review of log files for:
# - Processing times per borough
# - API response rates
# - Data quality metrics
# - Error frequencies
```

**3. System Updates**
```r
# Update R packages (test in development first)
renv::update()

# Check for new LSOA boundary releases (annually)
# Download from: https://data.london.gov.uk/
```

### Quarterly Operations

**1. Historical Data Validation**
```r
# Comprehensive validation of all cached data
all_months <- list_available_months()
full_integrity <- check_data_integrity(all_months)

# Identify and investigate any anomalies
anomalies <- full_integrity %>% 
  filter(status != "OK" | missing_lsoa > 100 | duplicate_ids > 0)
```

**2. Performance Optimization**
```r
# Analyze cache sizes and loading times
inventory <- generate_data_inventory()
large_files <- inventory %>% 
  filter(file_size_mb > 10)  # Investigate unusually large files

# Consider data archival for very old months
old_months <- head(list_available_months(), -36)  # Keep last 3 years active
```

**3. Documentation Updates**
- Review and update README.md with new features
- Update WORKFLOW.md with any process changes
- Document any custom modifications in PROJECT_GUIDE.md

### Annual Operations

**1. Boundary Data Updates**
```r
# Check for new LSOA boundary releases
# UK government typically releases annual updates
# Download and test new boundaries before deployment

# Backup current boundaries
backup_dir <- here("data", "boundaries_backup", format(Sys.Date(), "%Y"))
dir.create(backup_dir, recursive = TRUE)
file.copy(here("data", "boundaries"), backup_dir, recursive = TRUE)

# Update boundaries (manual process)
# source("R/spatial_setup.R")
# setup_london_boundaries()  # Downloads latest boundaries
```

**2. Historical Data Archive**
```r
# Archive data older than 5 years to reduce storage
archive_threshold <- format(Sys.Date() - years(5), "%Y-%m")
archive_months <- available_months[available_months < archive_threshold]

# Create archive directory and move files
archive_dir <- here("data", "archive", "pre_2020")
dir.create(archive_dir, recursive = TRUE)

for (month in archive_months) {
  old_file <- here("data", "processed", paste0("crime_data_", month, ".parquet"))
  new_file <- file.path(archive_dir, basename(old_file))
  file.rename(old_file, new_file)
}
```

**3. System Backup**
```bash
# Full system backup (excluding large data files)
tar -czf london_crime_backup_$(date +%Y%m%d).tar.gz \
  --exclude='data/processed' \
  --exclude='data/boundaries' \
  --exclude='logs' \
  london_crime/

# Upload to cloud storage or external backup location
```

### Monitoring & Alerting

**1. Automated Health Checks**
```r
# Create monitoring script for scheduled execution
monitor_system <- function() {
  tryCatch({
    # Test latest month update
    latest_month <- get_latest_available_month()
    if (!monthly_cache_exists(latest_month)) {
      warning("Latest month data missing: ", latest_month)
    }
    
    # Check data freshness (should update within 2 months)
    newest_cached <- max(list_available_months())
    months_behind <- interval(ym(newest_cached), Sys.Date()) %/% months(1)
    
    if (months_behind > 2) {
      warning("Data is ", months_behind, " months behind")
    }
    
    # Test core functions
    quick_start_demo()
    
    cat("System health check passed ✓\n")
    
  }, error = function(e) {
    cat("System health check failed ✗\n")
    cat("Error:", e$message, "\n")
  })
}

# Run health check
monitor_system()
```

**2. Performance Metrics**
- Track API response times and success rates
- Monitor cache file sizes and loading performance
- Measure end-to-end processing times
- Track dashboard response times

**3. Error Tracking**
- Parse log files for error patterns
- Monitor API 503 error frequencies
- Track spatial join failure rates
- Document and investigate anomalies

### Backup & Recovery

**1. Critical Files to Backup**
```
Priority 1 (Essential):
- R/ (all processing scripts)
- london_crime.qmd (dashboard)
- renv.lock (package versions)
- README.md, WORKFLOW.md, PROJECT_GUIDE.md

Priority 2 (Important):
- data/processed/ (cached crime data)
- config/ (system configuration)

Priority 3 (Replaceable):
- data/boundaries/ (can be re-downloaded)
- logs/ (operational logs)
```

**2. Recovery Procedures**

**Scenario: Lost Processed Data**
```r
# Re-process all data from scratch
source("R/bulk_historical.R")
load_historical_data(start_year = 2015)
```

**Scenario: Corrupted Boundary Data**
```r
# Re-download boundary data
source("R/spatial_setup.R")
setup_london_boundaries()
```

**Scenario: Complete System Loss**
1. Restore code from version control
2. Restore renv.lock and reinstall packages
3. Re-download boundary data
4. Re-process crime data (4-6 hours)
5. Validate system with quick_start_demo()

---

## Customization & Extensions

### Adding New Geographic Areas

**Extending Beyond London:**

1. **Modify Spatial Setup**
```r
# R/spatial_setup.R - Add new area functions
setup_manchester_boundaries <- function() {
  # Download Manchester boundary data
  # Adapt URL and processing logic
}

load_manchester_boundaries <- function() {
  # Load Manchester LSOAs
  # Follow same pattern as London
}
```

2. **Update API Wrapper**
```r
# R/api_wrapper.R - Add area parameter
fetch_crime_data <- function(year_month, area = "london") {
  if (area == "manchester") {
    boundaries <- load_manchester_boundaries()
  } else {
    boundaries <- load_london_boundaries()
  }
  # Continue with existing logic
}
```

3. **Configuration Management**
```r
# Create config/areas.yml
areas:
  london:
    boundary_source: "https://data.london.gov.uk/..."
    polygon_cache: "config/london_polygon.rds"
  manchester:
    boundary_source: "https://data.manchester.gov.uk/..."
    polygon_cache: "config/manchester_polygon.rds"
```

### Adding New Crime Categories

**Handling New Police.uk Categories:**

1. **Update Standardization**
```r
# R/data_processing.R - Extend standardize_crime_data()
standardize_crime_data <- function(crime_sf) {
  crime_sf %>%
    mutate(
      category = case_when(
        str_detect(category, "cyber") ~ "cyber-crime",        # New category
        str_detect(category, "fraud") ~ "fraud",              # New category
        str_detect(category, "anti-social") ~ "anti-social-behaviour",
        # ... existing categories
        TRUE ~ category
      )
    )
}
```

2. **Update Dashboard**
```r
# london_crime.qmd - Add new category to filters
crime_categories <- c(
  sort(unique(sample_data$category)),
  "cyber-crime",    # Ensure new categories appear
  "fraud"
)
```

### Adding New Dashboard Features

**Example: Crime Density Heatmap**

1. **Add New Page to Dashboard**
```yaml
# Crime Heatmap

## {.sidebar}
# Heatmap controls here

## Column
### Crime Density Heatmap
```

2. **Implement Heatmap Logic**
```r
# Add to server context
output$crime_heatmap <- renderLeaflet({
  req(filtered_data())
  
  crime_points <- filtered_data() %>%
    select(longitude, latitude) %>%
    st_drop_geometry()
  
  leaflet(crime_points) %>%
    addTiles() %>%
    addHeatmap(
      lng = ~longitude, 
      lat = ~latitude,
      intensity = 1,
      blur = 20,
      max = 0.05
    )
})
```

**Example: Predictive Analytics**

1. **Add Forecasting Module**
```r
# R/forecasting.R
library(forecast)

forecast_crime_trends <- function(crime_data, months_ahead = 6) {
  monthly_counts <- crime_data %>%
    group_by(month) %>%
    summarise(count = n()) %>%
    arrange(month)
  
  ts_data <- ts(monthly_counts$count, frequency = 12)
  forecast_model <- auto.arima(ts_data)
  forecasts <- forecast(forecast_model, h = months_ahead)
  
  return(forecasts)
}
```

2. **Integrate with Dashboard**
```r
# Add forecast chart to dashboard
output$forecast_chart <- renderPlotly({
  req(crime_data())
  
  forecasts <- forecast_crime_trends(crime_data())
  
  # Convert to plotly visualization
  # Implementation details...
})
```

### API Enhancements

**Adding New Data Sources:**

1. **Transport Crime Data (British Transport Police)**
```r
# R/api_wrapper_btp.R
fetch_btp_crime_data <- function(year_month) {
  # BTP-specific API logic
  # Different endpoint structure
  # Merge with main crime data
}
```

2. **Social Media Sentiment Analysis**
```r
# R/sentiment_analysis.R
fetch_crime_sentiment <- function(borough, date_range) {
  # Twitter/social media API integration
  # Sentiment analysis for crime-related posts
  # Geographic matching to boroughs
}
```

**Enhanced Data Processing:**

1. **Real-time Data Streaming**
```r
# R/realtime_processor.R
library(reticulate)  # For Python integration if needed

process_realtime_updates <- function() {
  # Check for new data every hour
  # Incremental processing
  # Live dashboard updates
}
```

2. **Machine Learning Integration**
```r
# R/ml_models.R
library(randomForest)

predict_crime_hotspots <- function(historical_data, borough) {
  # Feature engineering: time, weather, events
  # Train prediction model
  # Generate risk scores by LSOA
}
```

### Dashboard Customization

**Theming and Branding:**

1. **Custom CSS**
```css
/* custom.scss */
$primary-color: #1f4e79;
$secondary-color: #2c5aa0;

.sidebar {
  background-color: $primary-color;
}

.card-header {
  background-color: $secondary-color;
  color: white;
}
```

2. **Logo and Branding**
```yaml
# london_crime.qmd YAML header
format:
  dashboard:
    logo: "assets/logo.png"
    favicon: "assets/favicon.ico"
    nav-buttons:
      - icon: github
        href: https://github.com/your-org/london_crime
```

**Advanced Interactivity:**

1. **Cross-Page Communication**
```r
# Shared reactive values across pages
values <- reactiveValues(
  selected_borough = NULL,
  selected_date_range = NULL,
  selected_categories = NULL
)

# Update from any page
observeEvent(input$map_click, {
  values$selected_borough <- clicked_borough
})
```

2. **Dynamic UI Generation**
```r
# Generate UI elements based on data
output$dynamic_controls <- renderUI({
  available_boroughs <- unique(crime_data()$borough_name)
  
  selectInput(
    "borough_filter",
    "Select Boroughs:",
    choices = available_boroughs,
    multiple = TRUE
  )
})
```

### Integration with External Systems

**Database Integration:**
```r
# R/database_connector.R
library(DBI)
library(RPostgres)

sync_to_database <- function(crime_data, connection) {
  # Write processed data to PostgreSQL
  # Enable SQL-based analysis
  # Support larger datasets
}
```

**API Development:**
```r
# R/api_server.R
library(plumber)

#* @get /api/crime/<borough>/<year_month>
get_borough_crime <- function(borough, year_month) {
  # Serve crime data via REST API
  # Support external applications
  # JSON output format
}
```

**Export Capabilities:**
```r
# R/export_functions.R
export_to_geojson <- function(crime_data, filename) {
  # Export spatial data for GIS software
  # Maintain projection information
  # Support external analysis
}

export_to_excel <- function(crime_data, filename) {
  # Multi-sheet Excel export
  # Summary statistics
  # Raw data with formatting
}
```

---

## Troubleshooting

### Common Issues & Solutions

#### 1. API Connection Problems

**Symptom:** 503 errors or connection timeouts
```
Error updating 2024-06: Failed to fetch data for Camden after retries
```

**Diagnosis:**
```r
# Test basic API connectivity
library(httr)
response <- GET("https://data.police.uk/api/forces")
status_code(response)  # Should return 200
```

**Solutions:**
1. **Check Internet Connection**: Verify network access
2. **API Status**: Check Police.uk service status
3. **Rate Limiting**: Increase delays between requests
```r
# In R/api_wrapper.R, increase sleep time
Sys.sleep(2)  # Instead of 0.5 seconds
```
4. **Proxy Issues**: Configure proxy if needed
```r
set_config(use_proxy(url="proxy.company.com", port=8080))
```

#### 2. Spatial Data Issues

**Symptom:** High percentage of unmatched crimes
```
Warning: 1,234 crimes could not be matched to LSOA boundaries
```

**Diagnosis:**
```r
# Check boundary data integrity
boundaries <- load_london_boundaries()
summary(boundaries)
plot(st_geometry(boundaries))  # Visual inspection
```

**Solutions:**
1. **Boundary Data Corruption**: Re-download boundaries
```r
source("R/spatial_setup.R")
setup_london_boundaries()  # Fresh download
```
2. **CRS Mismatch**: Verify coordinate systems
```r
st_crs(crime_data)    # Should be EPSG:4326
st_crs(boundaries)    # Should be EPSG:4326
```
3. **Geographic Coverage**: Check if crimes are outside London
```r
# Inspect unmatched crimes
unmatched <- crime_data %>% filter(is.na(lsoa_code))
summary(unmatched$latitude)  # Check coordinate ranges
```

#### 3. Memory Issues

**Symptom:** R session crashes or extreme slowness
```
Error: cannot allocate vector of size 1.2 Gb
```

**Diagnosis:**
```r
# Check memory usage
memory.limit()          # Windows
memory.size(max = TRUE) # Current usage
pryr::mem_used()        # Detailed memory info
```

**Solutions:**
1. **Process Smaller Chunks**: Reduce date ranges
```r
# Instead of processing full year
update_monthly_data("2024-01")  # One month at a time
```
2. **Increase Memory Limit**: 
```r
memory.limit(size = 16000)  # 16GB limit (Windows)
```
3. **Optimize Data Handling**:
```r
# Remove geometry when not needed
crime_data %>% st_drop_geometry()
```

#### 4. Package Dependency Issues

**Symptom:** Package loading errors
```
Error: there is no package called 'sf'
```

**Solutions:**
1. **Restore Environment**:
```r
renv::restore()  # Restore all packages
renv::repair()   # Fix broken packages
```
2. **Manual Installation**:
```r
renv::install("sf")
renv::install("tidyverse")
```
3. **System Dependencies** (Linux/Mac):
```bash
# Ubuntu/Debian
sudo apt-get install libudunits2-dev libgdal-dev libgeos-dev libproj-dev

# macOS with Homebrew
brew install udunits gdal geos proj
```

#### 5. Dashboard Rendering Issues

**Symptom:** Blank dashboard or rendering errors
```
Error in renderLeaflet: object 'borough_boundaries' not found
```

**Diagnosis:**
```r
# Check data initialization
source("R/caching.R")
available_months <- list_available_months()
length(available_months)  # Should be > 0
```

**Solutions:**
1. **Data Availability**: Ensure cached data exists
```r
update_monthly_data("2024-06")  # Create sample data
```
2. **Package Installation**: Install dashboard dependencies
```r
renv::install(c("DT", "plotly", "leaflet", "shiny"))
```
3. **Clear Cache**: Reset Shiny cache
```r
# Remove cached reactive values
shiny::runApp(launch.browser = TRUE)
```

### Performance Optimization

#### 1. Slow Data Loading

**Diagnosis:**
```r
# Time data loading operations
system.time({
  data <- load_monthly_data("2024-06")
})
```

**Optimizations:**
1. **Use Arrow Directly**:
```r
library(arrow)
data <- read_parquet(here("data", "processed", "crime_data_2024-06.parquet"))
```
2. **Selective Column Loading**:
```r
# Only load required columns
data <- read_parquet(file, col_select = c("borough_name", "category", "date"))
```
3. **Parallel Processing** (future enhancement):
```r
library(future)
plan(multisession, workers = 4)
```

#### 2. Slow Dashboard Response

**Diagnosis:**
```r
# Profile dashboard performance
profvis::profvis({
  # Dashboard code here
})
```

**Optimizations:**
1. **Reactive Optimization**:
```r
# Use eventReactive for expensive operations
analysis_data <- eventReactive(input$update_button, {
  # Expensive computation only when button clicked
})
```
2. **Data Sampling**:
```r
# Limit map points for performance
if (nrow(data) > 10000) {
  data <- data[sample(nrow(data), 10000), ]
}
```
3. **Caching within Session**:
```r
# Cache expensive computations
cached_summary <- memo({
  compute_expensive_summary(data)
})
```

### Data Quality Issues

#### 1. Missing Spatial Assignments

**Investigation:**
```r
# Analyze unmatched crimes
unmatched_crimes <- crime_data %>%
  filter(is.na(lsoa_code)) %>%
  select(latitude, longitude, borough_name)

# Geographic distribution of unmatched crimes
summary(unmatched_crimes$latitude)
summary(unmatched_crimes$longitude)
```

**Solutions:**
1. **Coordinate Validation**: Check for invalid coordinates
```r
# Remove obviously invalid coordinates
valid_crimes <- crime_data %>%
  filter(
    latitude > 51.2, latitude < 51.7,    # London latitude range
    longitude > -0.6, longitude < 0.4    # London longitude range
  )
```
2. **Boundary Buffer**: Add small buffer to boundaries
```r
boundaries_buffered <- st_buffer(boundaries, dist = 100)  # 100m buffer
```

#### 2. Inconsistent Crime Categories

**Investigation:**
```r
# Check for unexpected categories
crime_categories <- unique(crime_data$category)
expected_categories <- c("burglary", "theft", "violence", ...)
unexpected <- setdiff(crime_categories, expected_categories)
print(unexpected)
```

**Solutions:**
1. **Update Standardization**: Add new categories to standardization logic
2. **Manual Review**: Investigate unexpected categories before processing

### Debugging Procedures

#### 1. Enable Detailed Logging

```r
# R/update_data.R - Add debug logging
log_message <- function(message, log_file, level = "INFO") {
  if (Sys.getenv("DEBUG_MODE") == "TRUE") {
    cat("[DEBUG]", Sys.time(), ":", message, "\n")
  }
  # ... existing logging code
}

# Enable debug mode
Sys.setenv(DEBUG_MODE = "TRUE")
```

#### 2. Interactive Debugging

```r
# Add browser() statements for interactive debugging
process_monthly_crime <- function(crime_sf, boundaries) {
  browser()  # Pause execution here
  
  # Step through code interactively
  standardized <- standardize_crime_data(crime_sf)
  browser()  # Another pause point
  
  # Continue with function
}
```

#### 3. Validation Scripts

```r
# Create comprehensive validation script
validate_system <- function() {
  tests <- list(
    "API connectivity" = test_api_connection(),
    "Boundary data" = test_boundary_integrity(),
    "Cache system" = test_cache_operations(),
    "Data processing" = test_data_pipeline(),
    "Dashboard components" = test_dashboard_functions()
  )
  
  results <- map_dfr(tests, ~tibble(
    test = names(.),
    status = ifelse(., "PASS", "FAIL")
  ))
  
  return(results)
}
```

### Getting Help

#### 1. System Information

When reporting issues, include:
```r
# System information
sessionInfo()
renv::status()

# Data information
cache_summary <- get_cache_summary()
print(cache_summary)

# Recent logs
recent_logs <- list.files("logs/", pattern = "*.log", full.names = TRUE)
recent_logs <- tail(recent_logs, 3)
```

#### 2. Error Reproduction

Create minimal reproducible example:
```r
# Minimal example that reproduces the error
library(tidyverse)
library(sf)

# Load minimal dataset
crime_sample <- load_monthly_data("2024-06") %>% slice(1:100)

# Reproduce error with minimal data
result <- problematic_function(crime_sample)
```

#### 3. Documentation Resources

- **README.md**: Quick start and basic usage
- **WORKFLOW.md**: Operational procedures and common tasks
- **PROJECT_GUIDE.md**: This comprehensive technical guide
- **R Documentation**: `?function_name` for specific functions
- **Package Documentation**: 
  - `vignette("sf")` for spatial operations
  - `vignette("dplyr")` for data manipulation

#### 4. External Resources

- **Police.uk API**: https://data.police.uk/docs/
- **London Datastore**: https://data.london.gov.uk/
- **sf Package**: https://r-spatial.github.io/sf/
- **Shiny**: https://shiny.rstudio.com/
- **Arrow/Parquet**: https://arrow.apache.org/docs/r/

---

## Development Workflow

### Version Control Strategy

**Branch Structure:**
```
main                    # Production-ready code
├── develop            # Integration branch
├── feature/new-api    # Feature development
├── feature/dashboard  # Dashboard enhancements
└── hotfix/api-fix    # Critical bug fixes
```

**Commit Guidelines:**
```bash
# Conventional commit format
git commit -m "feat: add borough-level crime heatmap"
git commit -m "fix: resolve spatial join performance issue"
git commit -m "docs: update API documentation"
git commit -m "refactor: optimize data loading pipeline"
```

### Testing Framework

**Unit Tests:**
```r
# tests/testthat/test-spatial-setup.R
test_that("boundary loading works correctly", {
  boundaries <- load_london_boundaries()
  
  expect_s3_class(boundaries, "sf")
  expect_equal(nrow(boundaries), 4994)  # Expected LSOA count
  expect_true(st_crs(boundaries)$epsg == 4326)
})

test_that("polygon creation produces valid strings", {
  boundaries <- load_london_boundaries()
  borough_polygons <- get_all_borough_polygons()
  
  expect_equal(nrow(borough_polygons), 33)  # London boroughs
  expect_true(all(nchar(borough_polygons$api_polygon) < 4094))  # API limit
})
```

**Integration Tests:**
```r
# tests/testthat/test-integration.R
test_that("complete pipeline works end-to-end", {
  # Test with synthetic data
  test_month <- "2023-12"
  
  # Mock API response
  mock_api_data <- create_mock_crime_data()
  
  # Test processing pipeline
  result <- process_monthly_crime(mock_api_data)
  
  expect_s3_class(result, "sf")
  expect_true(all(!is.na(result$lsoa_code)))
})
```

**Running Tests:**
```r
# Run all tests
testthat::test_dir("tests/")

# Run specific test file
testthat::test_file("tests/testthat/test-spatial-setup.R")

# Test with coverage
covr::package_coverage()
```

### Code Style Guidelines

**R Style Guide (based on tidyverse):**

1. **Naming Conventions:**
```r
# Functions: snake_case
load_london_boundaries <- function() { }

# Variables: snake_case  
crime_data <- load_monthly_data("2024-06")

# Constants: UPPER_SNAKE_CASE
MAX_API_RETRIES <- 3
```

2. **Function Documentation:**
```r
#' Load London LSOA boundaries
#'
#' Downloads and processes London LSOA boundaries from the London Datastore.
#' Combines individual borough shapefiles into a single sf object.
#'
#' @return sf object with 4,994 LSOA boundaries
#' @export
#' @examples
#' boundaries <- load_london_boundaries()
#' nrow(boundaries)  # Should be 4994
load_london_boundaries <- function() {
  # Function implementation
}
```

3. **Code Organization:**
```r
# Group related functions together
# Use consistent spacing and indentation
# Maximum line length: 80 characters

crime_data %>%
  filter(
    borough_name %in% selected_boroughs,
    category %in% selected_categories
  ) %>%
  group_by(borough_name, category) %>%
  summarise(
    count = n(),
    .groups = "drop"
  )
```

### Deployment Process

**Development Environment:**
```r
# Development setup
renv::snapshot()  # Save current package state
git add renv.lock
git commit -m "update: package dependencies"

# Test changes
source("R/bulk_historical.R")
quick_start_demo()
```

**Staging Environment:**
```bash
# Deploy to staging branch
git checkout staging
git merge develop

# Test with production-like data
Rscript -e "source('R/update_data.R'); update_latest_month()"
```

**Production Deployment:**
```bash
# Deploy to production
git checkout main
git merge staging
git tag v1.2.0  # Version tagging

# Production verification
Rscript -e "source('R/bulk_historical.R'); quick_start_demo()"
```

### Performance Monitoring

**Benchmark Scripts:**
```r
# benchmark/data_loading.R
library(microbenchmark)

# Compare loading methods
benchmark_results <- microbenchmark(
  parquet = load_monthly_data("2024-06"),
  rds = readRDS("legacy_crime_data_2024-06.rds"),
  csv = read_csv("legacy_crime_data_2024-06.csv"),
  times = 10
)

print(benchmark_results)
```

**Performance Tracking:**
```r
# Store performance metrics
performance_log <- tibble(
  date = Sys.Date(),
  operation = "monthly_update",
  duration_seconds = processing_time,
  records_processed = nrow(result),
  memory_peak_mb = peak_memory_usage
)

write_csv(performance_log, "logs/performance_metrics.csv", append = TRUE)
```

### Documentation Maintenance

**Automated Documentation:**
```r
# Generate function documentation
roxygen2::roxygenize()

# Update package documentation
pkgdown::build_site()
```

**Documentation Checklist:**
- [ ] README.md updated with new features
- [ ] WORKFLOW.md reflects current procedures  
- [ ] Function documentation complete
- [ ] Examples tested and working
- [ ] Performance implications documented

---

This comprehensive guide covers every aspect of the London Crime Data project. Use it as your reference for understanding, maintaining, and extending the system. The modular architecture and thorough documentation make it straightforward to customize the system for your specific needs.

For questions or issues not covered in this guide, refer to the troubleshooting section or create detailed error reports with system information and reproduction steps.