# London Crime Data Dashboard - Cloud Version
# Simplified for Posit Connect Cloud deployment

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

# Create sample data for demo purposes
create_sample_data <- function() {
  # Create sample London crime data for demonstration
  set.seed(123)
  
  # London boroughs (simplified list)
  boroughs <- c(
    "Westminster", "Camden", "Islington", "Hackney", "Tower Hamlets",
    "Greenwich", "Lewisham", "Southwark", "Lambeth", "Wandsworth",
    "Merton", "Kingston upon Thames", "Richmond upon Thames", 
    "Hounslow", "Hillingdon", "Ealing", "Brent", "Barnet"
  )
  
  # Crime categories
  categories <- c(
    "anti-social-behaviour", "burglary", "robbery", "theft-from-the-person",
    "vehicle-crime", "violence-and-sexual-offences", "criminal-damage-arson",
    "drugs", "other-theft", "public-order", "shoplifting"
  )
  
  # Generate sample data for last 6 months
  months <- seq(from = as.Date("2024-01-01"), to = as.Date("2024-06-01"), by = "month")
  month_strings <- format(months, "%Y-%m")
  
  # Create sample crime data
  sample_crimes <- map_dfr(month_strings, function(month) {
    n_crimes <- sample(800:1200, 1)  # Random crimes per month
    
    tibble(
      crime_id = paste0("crime_", seq_len(n_crimes)),
      category = sample(categories, n_crimes, replace = TRUE),
      month = month,
      date = as.Date(paste0(month, "-15")),  # Mid-month date
      year = as.numeric(substr(month, 1, 4)),
      month_num = as.numeric(substr(month, 6, 7)),
      quarter = ceiling(as.numeric(substr(month, 6, 7)) / 3),
      borough_name = sample(boroughs, n_crimes, replace = TRUE),
      latitude = runif(n_crimes, 51.28, 51.69),  # London lat range
      longitude = runif(n_crimes, -0.51, 0.33),  # London lng range
      location_type = sample(c("Force", "BTP"), n_crimes, replace = TRUE, prob = c(0.95, 0.05)),
      outcome_category = sample(
        c("investigation-complete", "under-investigation", "unable-to-prosecute", 
          "offender-cautioned", "local-resolution"),
        n_crimes, replace = TRUE,
        prob = c(0.4, 0.25, 0.15, 0.1, 0.1)
      ),
      lsoa_name = paste(borough_name, sample(1:20, n_crimes, replace = TRUE), "LSOA"),
      lsoa_code = paste0("E0", sample(1000:9999, n_crimes, replace = TRUE))
    )
  })
  
  # Convert to sf object
  sample_crimes_sf <- sample_crimes %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
  
  return(sample_crimes_sf)
}

# Create borough boundaries (simplified)
create_sample_boundaries <- function() {
  boroughs <- c(
    "Westminster", "Camden", "Islington", "Hackney", "Tower Hamlets",
    "Greenwich", "Lewisham", "Southwark", "Lambeth", "Wandsworth",
    "Merton", "Kingston upon Thames", "Richmond upon Thames", 
    "Hounslow", "Hillingdon", "Ealing", "Brent", "Barnet"
  )
  
  # Create simple rectangular boundaries for each borough
  set.seed(456)
  boundaries <- map_dfr(boroughs, function(borough) {
    center_lat <- runif(1, 51.35, 51.65)
    center_lng <- runif(1, -0.4, 0.2)
    
    # Create a simple square boundary
    coords <- matrix(c(
      center_lng - 0.05, center_lat - 0.03,
      center_lng + 0.05, center_lat - 0.03,
      center_lng + 0.05, center_lat + 0.03,
      center_lng - 0.05, center_lat + 0.03,
      center_lng - 0.05, center_lat - 0.03
    ), ncol = 2, byrow = TRUE)
    
    polygon <- st_polygon(list(coords))
    
    tibble(
      borough_name = borough,
      lsoa_count = sample(80:150, 1)
    ) %>%
      st_as_sf(geometry = st_sfc(polygon, crs = 4326))
  })
  
  return(boundaries)
}

# Initialize data
crime_data_sample <- create_sample_data()
borough_boundaries <- create_sample_boundaries()

# Extract metadata
available_months <- sort(unique(crime_data_sample$month))
crime_categories <- sort(unique(crime_data_sample$category))
borough_names <- sort(unique(crime_data_sample$borough_name))

# UI
ui <- dashboardPage(
  dashboardHeader(title = "London Crime Dashboard (Demo)"),
  
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
              selected = tail(available_months, 3),
              multiple = TRUE
            ),
            selectInput(
              "selected_boroughs",
              "Boroughs:",
              choices = borough_names,
              selected = borough_names[1:10],
              multiple = TRUE
            ),
            selectInput(
              "selected_categories",
              "Crime Types:",
              choices = crime_categories,
              selected = crime_categories[1:5],
              multiple = TRUE
            ),
            hr(),
            h5("Map Summary"),
            verbatimTextOutput("map_summary")
          ),
          box(
            title = "Interactive Crime Map", status = "primary", solidHeader = TRUE, width = 9,
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
              selected = tail(available_months, 3),
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
            )
          ),
          box(
            title = "Monthly Crime Trends", status = "primary", solidHeader = TRUE, width = 9,
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
              selected = tail(available_months, 2),
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
    
    crime_data_sample %>%
      filter(
        month %in% input$selected_months,
        borough_name %in% input$selected_boroughs,
        category %in% input$selected_categories
      )
  })
  
  # Reactive data for statistics
  stats_data <- reactive({
    req(input$stats_months, input$stats_categories)
    
    crime_data_sample %>%
      filter(
        month %in% input$stats_months,
        category %in% input$stats_categories
      )
  })
  
  # Reactive data for explorer
  explorer_data <- reactive({
    req(input$explorer_months)
    
    crime_data_sample %>%
      filter(month %in% input$explorer_months)
  })
  
  # Crime map
  output$crime_map <- renderLeaflet({
    req(map_data())
    
    if (nrow(map_data()) == 0) {
      return(
        leaflet() %>%
          addTiles() %>%
          setView(lng = -0.1278, lat = 51.5074, zoom = 10)
      )
    }
    
    # Borough level aggregation
    borough_crimes <- map_data() %>%
      st_drop_geometry() %>%
      count(borough_name, name = "crime_count")
    
    borough_map_data <- borough_boundaries %>%
      left_join(borough_crimes, by = "borough_name") %>%
      mutate(crime_count = replace_na(crime_count, 0))
    
    pal <- colorNumeric("YlOrRd", domain = borough_map_data$crime_count)
    
    leaflet(borough_map_data) %>%
      addTiles() %>%
      addPolygons(
        fillColor = ~ pal(crime_count),
        fillOpacity = 0.7,
        color = "white",
        weight = 2,
        popup = ~ paste(
          "<strong>", borough_name, "</strong><br/>",
          "Crimes: ", comma(crime_count), "<br/>",
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
        values = ~crime_count,
        title = "Crime Count",
        position = "bottomright"
      )
  })
  
  # Map summary
  output$map_summary <- renderText({
    req(map_data())
    
    paste(
      "Total Crimes:",
      comma(nrow(map_data())),
      "\nBoroughs:",
      n_distinct(map_data()$borough_name),
      "\nCrime Types:",
      n_distinct(map_data()$category)
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
      head(10)
  })
  
  # Top crimes chart
  output$top_crimes_chart <- renderPlotly({
    req(stats_data())
    
    top_crimes <- stats_data() %>%
      st_drop_geometry() %>%
      count(category, sort = TRUE) %>%
      head(8)
    
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
    req(input$trend_boroughs)
    
    data_for_trends <- crime_data_sample %>%
      st_drop_geometry() %>%
      filter(borough_name %in% input$trend_boroughs)
    
    if (input$trend_category != "all") {
      data_for_trends <- data_for_trends %>%
        filter(category == input$trend_category)
    }
    
    trends <- data_for_trends %>%
      group_by(borough_name, month) %>%
      summarise(count = n(), .groups = "drop") %>%
      mutate(date = ym(month))
    
    p <- ggplot(trends, aes(x = date, y = count, color = borough_name)) +
      geom_line(size = 1) +
      geom_point() +
      scale_x_date(date_labels = "%Y-%m") +
      labs(x = "Month", y = "Crime Count", color = "Borough") +
      theme_minimal()
    
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
        LSOA = lsoa_name,
        Outcome = outcome_category
      ) %>%
      arrange(desc(Month))
    
    DT::datatable(
      table_data,
      options = list(
        pageLength = 20,
        scrollX = TRUE
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
      "\nSize:",
      format(object.size(explorer_data()), units = "MB")
    )
  })
  
  # Download handler
  output$download_data <- downloadHandler(
    filename = function() {
      paste("london_crime_sample_", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      data_to_download <- map_data() %>%
        st_drop_geometry()
      
      write.csv(data_to_download, file, row.names = FALSE)
    }
  )
}

# Run the application
shinyApp(ui = ui, server = server)