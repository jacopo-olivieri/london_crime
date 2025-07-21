# London Crime Data Dashboard - Production Version
# Uses real crime data from 2023-01 to 2025-06

# Load required libraries
library(shiny)
library(shinydashboard)
library(DT)
library(plotly)
library(leaflet)
library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(glue)
library(scales)
library(purrr)
library(stringr)
library(arrow)
library(here)

# Load data functions
load_multiple_months <- function(months_to_load) {
  if (length(months_to_load) == 0) {
    return(data.frame())
  }
  
  # Try to load each month's data
  all_data <- list()
  
  for (month in months_to_load) {
    file_path <- paste0("data/processed/crime_data_", month, ".parquet")
    if (file.exists(file_path)) {
      monthly_data <- read_parquet(file_path)
      all_data[[month]] <- monthly_data
    }
  }
  
  if (length(all_data) == 0) {
    return(data.frame())
  }
  
  # Combine all months
  combined_data <- bind_rows(all_data)
  
  return(combined_data)
}

# Initialize data - all available months from 2023-01 to 2025-06
available_months <- c(
  paste0("2023-", sprintf("%02d", 1:12)),
  paste0("2024-", sprintf("%02d", 1:12)),
  paste0("2025-", sprintf("%02d", 1:6))
)

# Filter to only months that actually exist
existing_months <- c()
for (month in available_months) {
  if (file.exists(paste0("data/processed/crime_data_", month, ".parquet"))) {
    existing_months <- c(existing_months, month)
  }
}
available_months <- existing_months

# Load borough boundaries
if (file.exists("data/borough_boundaries_deployment.rds")) {
  borough_boundaries <- readRDS("data/borough_boundaries_deployment.rds")
} else {
  stop("Borough boundaries file not found. Please ensure data/borough_boundaries_deployment.rds exists.")
}

# Extract metadata from a sample to get categories and boroughs
if (length(available_months) > 0) {
  sample_data <- load_multiple_months(available_months[length(available_months)])
  crime_categories <- sort(unique(sample_data$category))
  borough_names <- sort(unique(sample_data$borough_name))
} else {
  stop("No crime data files found. Please ensure data/processed/ contains parquet files.")
}

# Default date range (last 12 months or all available)
default_months <- if(length(available_months) > 12) tail(available_months, 12) else available_months

# UI
ui <- dashboardPage(
  dashboardHeader(title = "London Crime Dashboard"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Crime Map", tabName = "map", icon = icon("map")),
      menuItem("Statistics", tabName = "stats", icon = icon("chart-bar")),
      menuItem("Trends", tabName = "trends", icon = icon("line-chart")),
      menuItem("Data Explorer", tabName = "explorer", icon = icon("table"))
    )
  ),
  
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .content-wrapper, .right-side {
          background-color: #f7f7f7;
        }
      "))
    ),
    
    tabItems(
      # Crime Map Tab
      tabItem(
        tabName = "map",
        fluidRow(
          box(
            title = "Map Controls", status = "primary", solidHeader = TRUE, width = 3,
            selectInput(
              "selected_months",
              "Select Months:",
              choices = setNames(available_months, paste(month.abb[as.numeric(str_sub(available_months, 6, 7))], str_sub(available_months, 1, 4))),
              selected = tail(available_months, 6),
              multiple = TRUE
            ),
            selectInput(
              "selected_boroughs",
              "Boroughs:",
              choices = borough_names,
              selected = borough_names,
              multiple = TRUE
            ),
            selectInput(
              "selected_categories",
              "Crime Types:",
              choices = crime_categories,
              selected = crime_categories[1:5],
              multiple = TRUE
            ),
            radioButtons(
              "crime_metric",
              "Display Metric:",
              choices = list(
                "Crime Count" = "count",
                "Crime Rate (per 1000)" = "rate"
              ),
              selected = "count"
            ),
            hr(),
            h5("Map Summary"),
            verbatimTextOutput("map_summary")
          ),
          box(
            title = "London Crime Distribution", status = "primary", solidHeader = TRUE, width = 9,
            leafletOutput("crime_map", height = "600px")
          )
        )
      ),
      
      # Statistics Tab
      tabItem(
        tabName = "stats",
        fluidRow(
          box(
            title = "Statistics Controls", status = "primary", solidHeader = TRUE, width = 3,
            selectInput(
              "stats_months",
              "Select Months:",
              choices = setNames(available_months, paste(month.abb[as.numeric(str_sub(available_months, 6, 7))], str_sub(available_months, 1, 4))),
              selected = tail(available_months, 6),
              multiple = TRUE
            ),
            selectInput(
              "stats_categories",
              "Crime Types:",
              choices = crime_categories,
              selected = crime_categories,
              multiple = TRUE
            )
          ),
          box(
            title = "Crime Statistics", status = "primary", solidHeader = TRUE, width = 5,
            tableOutput("crime_stats")
          ),
          box(
            title = "Top Crimes Chart", status = "primary", solidHeader = TRUE, width = 4,
            plotlyOutput("top_crimes_chart", height = "400px")
          )
        )
      ),
      
      # Trends Tab
      tabItem(
        tabName = "trends",
        fluidRow(
          box(
            title = "Trend Controls", status = "primary", solidHeader = TRUE, width = 3,
            selectInput(
              "trend_boroughs",
              "Compare Boroughs:",
              choices = borough_names,
              selected = borough_names[1:3],
              multiple = TRUE
            ),
            selectInput(
              "trend_category",
              "Focus Crime Type:",
              choices = c("All Crimes" = "all", crime_categories),
              selected = "all"
            ),
            radioButtons(
              "trend_aggregation",
              "Time Period:",
              choices = list(
                "Monthly" = "month",
                "Quarterly" = "quarter",
                "Yearly" = "year"
              ),
              selected = "month"
            )
          ),
          box(
            title = "Crime Trends Over Time", status = "primary", solidHeader = TRUE, width = 9,
            plotlyOutput("trends_chart", height = "500px")
          )
        )
      ),
      
      # Data Explorer Tab
      tabItem(
        tabName = "explorer",
        fluidRow(
          box(
            title = "Data Controls", status = "primary", solidHeader = TRUE, width = 3,
            selectInput(
              "explorer_months",
              "Select Months:",
              choices = available_months,
              selected = tail(available_months, 3),
              multiple = TRUE
            ),
            downloadButton(
              "download_data",
              "Download Data",
              class = "btn btn-success",
              style = "width: 100%; margin-top: 10px;"
            ),
            hr(),
            h5("Data Info"),
            verbatimTextOutput("data_info")
          ),
          box(
            title = "Crime Data Table", status = "primary", solidHeader = TRUE, width = 9,
            DT::dataTableOutput("crime_table")
          )
        )
      )
    )
  )
)

# Server
server <- function(input, output, session) {
  
  # Reactive data for map
  map_data <- reactive({
    req(input$selected_months, input$selected_boroughs, input$selected_categories)
    
    data <- load_multiple_months(input$selected_months)
    
    if (nrow(data) == 0) {
      return(data.frame())
    }
    
    data %>%
      filter(
        borough_name %in% input$selected_boroughs,
        category %in% input$selected_categories
      )
  })
  
  # Reactive data for statistics
  stats_data <- reactive({
    req(input$stats_months, input$stats_categories)
    
    data <- load_multiple_months(input$stats_months)
    
    if (nrow(data) == 0) {
      return(data.frame())
    }
    
    data %>%
      filter(category %in% input$stats_categories)
  })
  
  # Reactive data for explorer
  explorer_data <- reactive({
    req(input$explorer_months)
    load_multiple_months(input$explorer_months)
  })
  
  # Reactive data for trends
  trend_data <- reactive({
    req(input$trend_boroughs)
    
    # Load all data for trend analysis
    data <- load_multiple_months(available_months)
    
    if (nrow(data) == 0) {
      return(data.frame())
    }
    
    filtered_data <- data %>%
      filter(borough_name %in% input$trend_boroughs)
    
    if (input$trend_category != "all") {
      filtered_data <- filtered_data %>%
        filter(category == input$trend_category)
    }
    
    return(filtered_data)
  })
  
  # Crime map
  output$crime_map <- renderLeaflet({
    req(map_data())
    
    if (nrow(map_data()) == 0) {
      return(
        leaflet() %>%
          addTiles() %>%
          setView(lng = -0.1278, lat = 51.5074, zoom = 10) %>%
          addControl("No crimes found for selected filters", position = "topright")
      )
    }
    
    # Borough level aggregation
    borough_crimes <- map_data() %>%
      st_drop_geometry() %>%
      count(borough_name, name = "crime_count")
    
    borough_map_data <- borough_boundaries %>%
      left_join(borough_crimes, by = "borough_name") %>%
      mutate(crime_count = replace_na(crime_count, 0))
    
    # Calculate crime rate if selected
    if (input$crime_metric == "rate") {
      # Use estimated population: LSOA count * 1500
      borough_map_data <- borough_map_data %>%
        mutate(
          estimated_population = lsoa_count * 1500,
          display_value = round((crime_count / estimated_population) * 1000, 2)
        )
      
      metric_title <- "Crime Rate (per 1000)"
      popup_metric <- "Rate"
      popup_unit <- " per 1000"
    } else {
      borough_map_data <- borough_map_data %>%
        mutate(display_value = crime_count)
      
      metric_title <- "Crime Count"
      popup_metric <- "Crimes"
      popup_unit <- ""
    }
    
    # Filter out boroughs with 0 crimes for better color scale
    if (max(borough_map_data$display_value) == 0) {
      return(
        leaflet() %>%
          addTiles() %>%
          setView(lng = -0.1278, lat = 51.5074, zoom = 10) %>%
          addControl("No crimes found for selected filters", position = "topright")
      )
    }
    
    pal <- colorNumeric("YlOrRd", domain = borough_map_data$display_value)
    
    leaflet(borough_map_data) %>%
      addTiles() %>%
      addPolygons(
        fillColor = ~ pal(display_value),
        fillOpacity = 0.7,
        color = "white",
        weight = 2,
        popup = ~ paste(
          "<strong>", borough_name, "</strong><br/>",
          popup_metric, ": ", comma(ifelse(input$crime_metric == "rate", display_value, crime_count)), popup_unit, "<br/>",
          "LSOAs: ", lsoa_count
        ),
        highlightOptions = highlightOptions(
          weight = 3,
          color = "#666",
          fillOpacity = 0.9,
          bringToFront = TRUE
        )
      ) %>%
      addLegend(
        pal = pal,
        values = ~display_value,
        title = metric_title,
        position = "bottomright"
      ) %>%
      setView(lng = -0.1278, lat = 51.5074, zoom = 10)
  })
  
  # Map summary
  output$map_summary <- renderText({
    req(map_data())
    
    total_crimes <- nrow(map_data())
    unique_boroughs <- n_distinct(map_data()$borough_name)
    unique_categories <- n_distinct(map_data()$category)
    
    paste(
      "Total Crimes:",
      comma(total_crimes),
      "\nBoroughs:",
      unique_boroughs,
      "\nCrime Types:",
      unique_categories
    )
  })
  
  # Crime statistics table
  output$crime_stats <- renderTable({
    req(stats_data())
    
    stats_data() %>%
      st_drop_geometry() %>%
      group_by(category) %>%
      summarise(
        Count = n(),
        `% of Total` = round(n() / nrow(stats_data()) * 100, 1),
        .groups = "drop"
      ) %>%
      arrange(desc(Count)) %>%
      head(15)
  })
  
  # Top crimes chart
  output$top_crimes_chart <- renderPlotly({
    req(stats_data())
    
    top_crimes <- stats_data() %>%
      st_drop_geometry() %>%
      count(category, sort = TRUE) %>%
      head(10)
    
    p <- ggplot(top_crimes, aes(x = reorder(category, n), y = n)) +
      geom_col(fill = "steelblue") +
      coord_flip() +
      labs(x = "", y = "Number of Crimes") +
      theme_minimal() +
      theme(axis.text.y = element_text(size = 8))
    
    ggplotly(p, tooltip = c("y"))
  })
  
  # Trends chart
  output$trends_chart <- renderPlotly({
    req(trend_data())
    
    if (nrow(trend_data()) == 0) {
      return(plotly_empty())
    }
    
    if (input$trend_aggregation == "month") {
      trends <- trend_data() %>%
        st_drop_geometry() %>%
        group_by(borough_name, month) %>%
        summarise(count = n(), .groups = "drop") %>%
        mutate(date = ym(month))
    } else if (input$trend_aggregation == "quarter") {
      trends <- trend_data() %>%
        st_drop_geometry() %>%
        group_by(borough_name, year, quarter) %>%
        summarise(count = n(), .groups = "drop") %>%
        mutate(date = as.Date(paste(year, (quarter - 1) * 3 + 1, "01", sep = "-")))
    } else {
      trends <- trend_data() %>%
        st_drop_geometry() %>%
        group_by(borough_name, year) %>%
        summarise(count = n(), .groups = "drop") %>%
        mutate(date = as.Date(paste(year, "01", "01", sep = "-")))
    }
    
    p <- ggplot(trends, aes(x = date, y = count, color = borough_name)) +
      geom_line(size = 1) +
      geom_point() +
      scale_x_date(date_labels = "%Y-%m") +
      labs(x = "Time", y = "Crime Count", color = "Borough") +
      theme_minimal() +
      theme(legend.position = "bottom")
    
    ggplotly(p)
  })
  
  # Crime data table
  output$crime_table <- DT::renderDataTable({
    req(explorer_data())
    
    table_data <- explorer_data() %>%
      st_drop_geometry() %>%
      select(
        Month = month,
        Borough = borough_name,
        `Crime Type` = category,
        `Location Type` = location_type,
        Outcome = outcome_category,
        Year = year,
        Quarter = quarter
      ) %>%
      arrange(desc(Month))
    
    DT::datatable(
      table_data,
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        search = list(search = "", smart = TRUE)
      ),
      filter = "top",
      rownames = FALSE
    )
  })
  
  # Data info
  output$data_info <- renderText({
    req(explorer_data())
    
    paste(
      "Records:",
      comma(nrow(explorer_data())),
      "\nMonths:",
      length(input$explorer_months),
      "\nDate Range:", 
      min(explorer_data()$month), "to", max(explorer_data()$month),
      "\nSize:",
      format(object.size(explorer_data()), units = "MB")
    )
  })
  
  # Download handler
  output$download_data <- downloadHandler(
    filename = function() {
      paste("london_crime_data_", paste(input$explorer_months, collapse = "_"), "_", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      data_to_download <- explorer_data() %>%
        st_drop_geometry()
      
      write.csv(data_to_download, file, row.names = FALSE)
    }
  )
}

# Run the application
shinyApp(ui = ui, server = server)