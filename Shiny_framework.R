################################################################################ 
# This script calibrates the Sick-Sicker state-transition model (STM) to       #
# epidemiological targets using a Bayesian approach with the Incremental       #
# Mixture Importance Samping (IMIS) algorithm                                  #
#                                                                              # 
# Depends on:                                                                  #
#   00_general_functions.R                                                     #
# Authors:                                                                     #
#     - Fernando Alarid-Escudero, PhD, <fernando.alarid@cide.edu>              # 
#     - Eline Krijkamp, MS                                                     #
#     - Petros Pechlivanoglou, PhD                                             #
#     - Hawre Jalal, MD, PhD                                                   #
#     - Eva A. Enns, PhD                                                       # 
################################################################################ 
# The structure of this code is according to the DARTH framework               #
# https://github.com/DARTH-git/Decision-Modeling-Framework                     #
################################################################################ 

library(shiny)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) # set the working directory 

###Function
ui <- fluidPage(
  # App title ----
  titlePanel("Sick-Sicker Markov Model"),
  
  # Sidebar layout with input and output definitions ----
  sidebarLayout(
    
    # Sidebar panel for inputs ----
    sidebarPanel(width=5,
                 tabsetPanel(id = "input",type="tabs",
                             tabPanel("Component selection",
                                      # Input: which components should run? ----
                                      checkboxInput("calib", " Model Calibration ",            FALSE),
                                      checkboxInput("valid", " Model Validation ",             FALSE),
                                      checkboxInput("deter", "Deterministic analysis",          TRUE),
                                      checkboxInput("psa",   "Probabilistic  analysis",        FALSE),
                                      checkboxInput("voi",   "Value of Information  analysis", FALSE)
                                      
                             ),
                             tabPanel("Model Structure",
                                      # Input: Age ----
                                      sliderInput(inputId = "age",
                                                  label = "Cohort Age",value=c(25,100),
                                                  min = 0, max = 100, step = 1),
                                      # Input: Discount Rate ----
                                      numericInput(inputId = "Dis",
                                                   label = "Discount Rate",
                                                   value = 0.03,
                                                   min=0,
                                                   step=0.0001)
                                      ),
                             tabPanel("Probabilities", 
                                      # Input: Probabilities----
                                      numericInput(inputId = "p.HS1",
                                                   label = "Probability of Transition Healthy to Sick",
                                                   value = 0.15,
                                                   min=0,max=1),
                                      
                                      numericInput(inputId = "p.S1H",
                                                   label = "Probability of Transition Sick to Healthy",
                                                   value = 0.5,
                                                   min=0,max=1),
                                      
                                      numericInput(inputId = "p.S1S2",
                                                   label = "Probability of Transition Sick to Sicker",
                                                   value = 0.105,
                                                   min=0,max=1),
                                      
                                      # Input: Rate Ratio ----
                                      numericInput(inputId = "hr.S1",
                                                   label = "Hazard Ratio of Sick to Dead compared to Healthy",
                                                   value = 3,
                                                   min=0),
                                      numericInput(inputId = "hr.S2",
                                                   label = "Hazard Ratio of Sicker to Dead compared to Healthy",
                                                   value = 10,
                                                   min=0)
                                      ),
                             tabPanel("Utilities",                # Input: Utilities ----
                                      
                                      numericInput(inputId = "u.H",
                                                   label = "Utility when Healthy",
                                                   value = 1,
                                                   max=1,
                                                   min=0),
                                      numericInput(inputId = "u.S1",
                                                   label = "Utility when Sick",
                                                   value = 0.75,
                                                   max=1,
                                                   min=0),
                                      
                                      numericInput(inputId = "u.S2",
                                                   label = "Utility when Sicker",
                                                   value = 0.5,
                                                   max=1,
                                                   min=0),
                                      
                                      numericInput(inputId = "u.Trt",
                                                   label = "Utility of Sick Patients when on Treatment",
                                                   value = 0.95,
                                                   max=1,
                                                   min=0),
                                      numericInput(inputId = "u.D",
                                                   label = "Utility when Dead",
                                                   value = 0,
                                                   max=1,
                                                   min=0)
                                      ),
                             tabPanel("Costs",                # Input: Costs ----
                                      numericInput(inputId = "c.H",
                                                   label = "Cost when Healthy",
                                                   value = 2000,
                                                   min=0),
                                      
                                      numericInput(inputId = "c.S1",
                                                   label = "Cost when Sick",
                                                   value = 4000,
                                                   min=0),
                                      
                                      numericInput(inputId = "c.S2",
                                                   label = "Cost when Sicker",
                                                   value = 15000,
                                                   min=0),
                                      
                                      numericInput(inputId = "c.Trt",
                                                   label = "Cost when on Treatment",
                                                   value = 12000,
                                                   min=0),
                                      
                                       numericInput(inputId = "c.D",
                                                  label = "Cost when Dead",
                                                  value = 0,
                                                  min=0)
                 )
                   
                 ),
                 actionButton("button", "Run")
    ),
    # Main panel for displaying outputs ----
    mainPanel(width=7,
              p("Evalulating the Cost-Effectiveness of a Treatment to Improve Quality of Life for Sick Patients using a Sick-Sicker  Model"),
              tabsetPanel(id = "output", type="tabs",
                          tabPanel("Decision Model",  
                                   #Output: Matplot ----
                                   imageOutput("modeldiagram"),
                                   htmlOutput("diagramtext"),
                                   imageOutput("traceplot"),
                                   htmlOutput("traceplottext")
                                   
                          )
                          
              )
    )
  )
)
                          

server <- function(input, output) {
  
  # Histogram of the Old Faithful Geyser Data ----
  # with requested number of bins
  # This expression that generates a histogram is wrapped in a call
  # to renderPlot to indicate that:
  #
  # 1. It is "reactive" and therefore should be automatically
  #    re-executed when inputs (input$bins) change
  # 2. Its output type is a plot
  
  
  observeEvent(input$psa,{
    if(input$psa == TRUE) {
         insertTab(inputId = "input",
                tabPanel("Probabilistic analysis"
                         ),
                target   = "Costs",
                position = c("after")
         )
    }else{
      removeTab(inputId = "input",target =  "Probabilistic analysis")
                
    }
    
    
  })
  
  
  observeEvent(input$button, {
    withProgress(message = 'Performing Health Economic Analysis', value = 0, {
      input.file <- paste(getwd(),"/data/01_basecase-params.csv", sep="")
      calib.file <- paste(getwd(),"/data/01_init-params.csv", sep="")
      
      #print(input.file)
      input.arrange<-c(input$c.H,
                       input$c.S1,
                       input$c.S2,
                       input$c.D,
                       input$c.Trt,
                       input$u.H,
                       input$u.S1,
                       input$u.S2,
                       input$u.D,
                       input$u.Trt,
                       input$p.HS1,
                       input$p.S1H,
                       input$p.S1S2,
                       input$hr.S1,
                       input$hr.S2,
                       as.numeric(input$age)[1],
                       as.numeric(input$age)[2]-as.numeric(input$age)[1],
                       input$Dis,
                       input$Dis)
      names(input.arrange)<-c("c.H",
                              "c.S1",
                              "c.S2",
                              "c.D",
                              "c.Trt",
                              "u.H",
                              "u.S1",
                              "u.S2",
                              "u.D",
                              "u.Trt",
                              "p.HS1",
                              "p.S1H",
                              "p.S1S2",
                              "hr.S1",
                              "hr.S2",
                              "n.age.init",
                              "n.t",
                              "d.c",
                              "d.e")
      input.mat<-as.matrix(input.arrange)
      calib.mat<-t(input.mat)
      #input.list <- shiny::reactiveValuesToList(input)
      #input.mat <- rbind(unlist(input.list))
      #calib.mat <- rbind(unlist(input.list))
      
      write.csv(input.mat, input.file,row.names = F)
      write.csv(calib.mat, calib.file, row.names = F)
      
      #### 00 Install and load packages ####
      #source("R/app0_packages-setup.R", echo = TRUE)
      
       
      # #### 02 Load simulation model and test it ####
       source("R/02_simulation-model.R", echo = TRUE)
      #
      
      
      # #### 05c Conduct value of information analysis ####
      if(input$voi == TRUE) {
        source("R/05c_value-of-information.R", echo = TRUE )        
        
        insertTab(inputId = "output",
                  tabPanel("Value of information",
                           #Output: Matplot ----
                           imageOutput("evpi"),
                           htmlOutput("evpitext")
                  ), target = "Decision Model",
                  position = c("after")
        )
      }
      
      # 
      # #### 05b Conduct probabilistic analysis ####
      if(input$psa == TRUE) {
        source("R/05b_probabilistic-analysis.R", echo = TRUE )
        insertTab(inputId = "output",
                  tabPanel("Probabilistic analysis",
                           #Output: Matplot ----
                           tableOutput("psaresults"),
                           imageOutput("scatter"),
                           htmlOutput("psascattertext"),
                           imageOutput("ceaf"),
                           htmlOutput("psaceaftext"),
                           imageOutput("elc"),
                           htmlOutput("psaelctext")
                  ), target = "Decision Model",
                  position = c("after")
                  
        )
      }
      # 
      # 
      # #### 05a Conduct deterministic analysis ####
      if(input$deter == TRUE) {
        source("R/05a_deterministic-analysis.R", echo = TRUE)
        insertTab(inputId = "output",
                  tabPanel("Deterministic analysis",
                           #Output: Matplot ----
                           tableOutput("cearesults"),
                           imageOutput("cefrontier")
                  ), target = "Decision Model",
                  position = c("after")
        )
      }
      
      # 
      # #### 04 Validate simulation model ####
      if(input$valid == TRUE) {
        source("R/04_validation.R", echo = TRUE)
        insertTab(inputId = "output",
                  tabPanel("Model Validation",
                           #Output: Matplot ----
                           imageOutput("validsicker"),
                           htmlOutput("validsickertext"),
                           imageOutput("validsurv"),
                           htmlOutput("validsurvtext"),
                           imageOutput("validprev"),
                           htmlOutput("validprevtext")
                  ), target = "Decision Model",
                  position = c("after")
        )
      }
      
      # #### 03 Calibrate simulation model ####
      if(input$calib == TRUE){
        source("R/03_calibration.R", echo = TRUE)
        insertTab(inputId = "output",
                  tabPanel(" Model Calibration",
                           #Output: Matplot ----
                           tableOutput("calibsummary"),
                           htmlOutput("calibsumtext"),
                           imageOutput("jointposterior"),
                           htmlOutput("calibjointtext"),
                           imageOutput("jointmarginal"),
                           htmlOutput("calibmargtext")
                  ), target = "Decision Model",
                  position = c("after")
        )
      }
      

      
      
      })
    
    output$cearesults <- renderTable({
      read.csv("./tables/05a_deterministic-cea-results.csv")
     },digits=2)

    output$psaresults <- renderTable({
      read.csv("./tables/05b_probabilistic-cea-results.csv")
    },digits=2)
    
    output$calibsummary <- renderTable({
      read.csv("./tables/03_summary-posterior.csv")
    },digits=2)
    
    
    
    
   output$modeldiagram  <-renderImage({
      filename = normalizePath(file.path('./figs/02_model-diagram.png'))
      list(src=filename, width = 400, height = 400)
      },
      deleteFile = FALSE)

    output$traceplot    <-renderImage({
      filename = normalizePath(file.path('./figs/02_trace-plot.png'))
      list(src=filename,
           width = 400, height = 400
          )},
      deleteFile = FALSE)
    
    output$jointposterior<-renderImage({
      filename = normalizePath(file.path('./figs/03_posterior-distribution-joint.png'))
      list(src=filename,
           width = 400, height = 400
          )},
      deleteFile = FALSE)
    
    output$jointmarginal<-renderImage({
      filename = normalizePath(file.path('./figs/03_posterior-distribution-marginal.png'))
      list(src=filename,
           width = 400, height = 400
          )},
      deleteFile = FALSE)
    
    
    output$validprev<-renderImage({
      filename = normalizePath(file.path('./figs/04_posterior-vs-targets-prevalence.png'))
      list(src=filename,
           width = 400, height = 400
      )},
      deleteFile = FALSE)
    
    output$validsurv<-renderImage({
      filename = normalizePath(file.path('./figs/04_posterior-vs-targets-survival.png'))
      list(src=filename,
           width = 400, height = 400
      )},
      deleteFile = FALSE)
    
    output$validsicker<-renderImage({
      filename = normalizePath(file.path('./figs/04_posterior-vs-targets-proportion-sicker.png'))
      list(src=filename,
           width = 400, height = 400
      )},
      deleteFile = FALSE)
    
    output$cefrontier<-renderImage({
      filename = normalizePath(file.path('./figs/05a_cea-frontier.png'))
      list(src=filename,
           width = 400, height = 400
          )},
      deleteFile = FALSE)
    
    output$scatter<-renderImage({
      filename = normalizePath(file.path('./figs/05b_cea-plane-scatter.png'))
      list(src=filename,
           width = 400, height = 400
          )},
      deleteFile = FALSE)
    
    output$ceaf<-renderImage({
      filename = normalizePath(file.path('./figs/05b_ceac-ceaf.png'))
      list(src=filename,
           width = 400, height = 400
      )},
      deleteFile = FALSE)
    
    output$elc<-renderImage({
      filename = normalizePath(file.path('./figs/05b_elc.png'))
      list(src=filename,
           width = 400, height = 400
      )},
      deleteFile = FALSE)
    
    output$evpi<-renderImage({
      filename = normalizePath(file.path('./figs/05c_evpi.png'))
      list(src=filename,
           width = 400, height = 400
          )},
      deleteFile = FALSE)
    
    
    
    output$evpitext        <- renderUI({  HTML("Expected value of perfect information.")})
    output$diagramtext     <- renderUI({  HTML("State-transition diagram of the Sick-Sicker model. Healthy individuals can get Sick, die or stay healthy. Sick individuals can recover, transitioning back to healthy, can die, or stay sick. Once individuals are Sicker, they stay Sicker until they die.")})
    output$traceplottext   <- renderUI({  HTML("Cohort trace of the Sick-Sicker cohort model.")})
    output$calibsumtext    <- renderUI({  HTML("Summary statistics of the posterior distribution.")})
    output$calibjointtext  <- renderUI({HTML("Joint posterior distribution.")})
    output$calibmargtext   <- renderUI({ HTML("Pairwise posterior distribution of calibrated parameters.")})
    output$validsurvtext   <- renderUI({ HTML("Survival data: Model-predicted outputs vs targets.")})
    output$validprevtext    <- renderUI({ HTML("Prevalence data of sick individuals: Model-predicted output vs targets.")})
    output$validsickertext    <- renderUI({ HTML("Proportion who are Sicker, among all those afflicted (Sick + Sicker): Model-predicted output.")})
    output$psascattertext  <- renderUI({ HTML("The cost-effectiveness plane graph showing the results of the probabilistic sensitivity analysis for
the Sick-Sicker case-study.")})
    output$psaceaftext  <- renderUI({ HTML("Cost-effectiveness acceptability curves (CEACs) and frontier (CEAF).")})
    output$psaelctext   <- renderUI({ HTML("Expected Loss Curves.")})
    
    
  })
  
  
}

#tags$div(img(src = "www/images/image.png"))


shinyApp(ui = ui, server = server)
