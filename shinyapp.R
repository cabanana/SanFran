
library(shiny)
library(leaflet)
library(RColorBrewer)
library(lazyeval)
library(dplyr)

train <- read.csv("~/SanFranCrime/data/train.csv", stringsAsFactors = FALSE)

train$Dates = as.POSIXct(train$Dates, tz ="UTC")


ui <- bootstrapPage(
  tags$style(type = "text/css", "html, body {width:100%;height:100%}"),
  leafletOutput("map", width = "100%", height = "100%"),
  absolutePanel(top = 10, right = 10, draggable = TRUE,
                dateRangeInput('dateRange',
                               label = '2003-01-06 to 2015-05-13',
                               start = "2013-01-01", end = "2015-12-31"),
                selectInput('cats', 'Categories', unique(train$Category), multiple=TRUE, 
                            selectize=TRUE,selected = c("ARSON","ROBBERY")),
                checkboxInput("legend", "Show legend", TRUE)
  )
)

server <- function(input, output, session) {

  pal <- colorFactor(
    palette = "Set1",
    domain = train$Category
  )

    
    filteredData <- reactive({   
      
      train %>% 
        filter_(interp(~ Dates >= as.POSIXct(input$dateRange[1], tz = "UTC"), Dates = as.name("Dates"))) %>% 
        filter_(interp(~ Dates <= as.POSIXct(input$dateRange[2], tz = "UTC"), Dates = as.name("Dates"))) %>%
        filter_(interp(~ Category == input$cats, Category = as.name("Category")))%>%
        group_by_(~X,~Y, ~ Category) %>%
        summarise_(n = interp(~(mean(X)/sum(X))^-1, X=as.name("X")),
                     popup = interp(~paste0(Dates,": ", Descript," - ", Resolution, "<br>" ,collapse=""), 
                                  Descript= as.name("Descript"), 
                                  Resolution = as.name("Resolution")))
  })

 output$dateRangeText <- renderPrint(({input$dateRange}))
  output$map <- renderLeaflet({
    leaflet(filteredData()) %>% addTiles()%>% setView(-122.41,37.77,  zoom=14)
  })
  
  observe({
    leafletProxy("map", data = filteredData()) %>%
      clearShapes() %>% 
      addCircles(~X, ~Y, 
                 popup = ~popup, 
                 color=~pal(Category), 
                 radius= ~sqrt(n)*10,
                 opacity = 1)%>%
      addProviderTiles("OpenStreetMap.BlackAndWhite", group = "OpenStreetMap.BlackAndWhite") %>%
      addProviderTiles("MapQuestOpen.Aerial", group = "MapQuestOpen.Aerial") %>%
      addLayersControl(
        baseGroups = c("MapQuestOpen.Aerial", "OpenStreetMap.BlackAndWhite"),
        options = layersControlOptions(collapsed = FALSE),
        position = "bottomleft"
      )
  })
  
  # Use a separate observer to recreate the legend as needed.
  observe({
    proxy <- leafletProxy("map", data = filteredData())
    pal <- colorFactor(
      palette = "Set1",
      domain = train$Category
    )
    # Remove any existing legend, and only if the legend is
    # enabled, create a new one.
    proxy %>% clearControls()
    if (input$legend) {
      proxy %>% addLegend(position = "bottomright",
                          pal = pal, values = ~Category
      )
    }
  })
}

shinyApp(ui, server)
