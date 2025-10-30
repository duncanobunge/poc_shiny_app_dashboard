# Load required libraries
# library(shiny)
# library(shinydashboard)
# library(shinyjs)
# library(pool)
# library(DBI)
# library(RPostgres)
# library(digest)  # For password hashing
# library(DT)
# library(plotly)
if (!require("pacman")) install.packages("pacman")
pacman::p_load(shiny, shinydashboard, shinyjs, dplyr, tidyr, reshape2, plotly, DT, tools,pool,DBI,RPostgres,
               digest)

# Create a connection pool
pool <- dbPool(
  drv = RPostgres::Postgres(),
  dbname = "postgres",
  host = "127.0.0.1",
  user = "postgres",
  password ="test",
  port = 5432
)

# Initialize database tables for users if they don't exist
initialize_db <- function(pool) {
  # Create users table if it doesn't exist
  dbExecute(pool, "
    CREATE TABLE IF NOT EXISTS users (
      user_id SERIAL PRIMARY KEY,
      username VARCHAR(255) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      role VARCHAR(50) NOT NULL,
      email VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      last_login TIMESTAMP,
      is_active BOOLEAN DEFAULT TRUE
    );
  ")
  
  # Create session log table
  dbExecute(pool, "
    CREATE TABLE IF NOT EXISTS user_sessions (
      session_id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(user_id),
      login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      logout_time TIMESTAMP,
      ip_address VARCHAR(50)
    );
  ")
  
  # Check if admin user exists, create if not
  admin_exists <- dbGetQuery(pool, "SELECT COUNT(*) FROM users WHERE username = 'admin'")
  if (admin_exists$count == 0) {
    admin_hash <- digest("admin123", algo = "sha256")
    dbExecute(pool, "
      INSERT INTO users (username, password_hash, role, email) 
      VALUES ('admin', $1, 'admin', 'admin@example.com')
    ", params = list(admin_hash))
  }
}

# Call initialization function
initialize_db(pool)

# Authentication functions
hash_password <- function(password) {
  digest(password, algo = "sha256")
}

verify_user <- function(username, password) {
  # Query to find user
  user_data <- dbGetQuery(pool, "
    SELECT user_id, username, password_hash, role, is_active 
    FROM users 
    WHERE username = $1
  ", params = list(username))
  
  # Check if user exists and is active
  if (nrow(user_data) == 0 || !user_data$is_active) {
    return(NULL)
  }
  
  # Verify password
  if (user_data$password_hash == hash_password(password)) {
    # Update last login time
    dbExecute(pool, "
      UPDATE users 
      SET last_login = CURRENT_TIMESTAMP 
      WHERE user_id = $1
    ", params = list(user_data$user_id))
    
    # Log session
    dbExecute(pool, "
      INSERT INTO user_sessions (user_id, ip_address) 
      VALUES ($1, $2)
    ", params = list(user_data$user_id, "127.0.0.1"))  # In a real app, get actual IP
    
    # Return user info without password hash
    return(list(
      user_id = user_data$user_id,
      username = user_data$username,
      role = user_data$role
    ))
  } else {
    return(NULL)
  }
}

# User management functions
get_users <- function() {
  dbGetQuery(pool, "
    SELECT user_id, username, role, email, created_at, last_login, is_active 
    FROM users 
    ORDER BY username
  ")
}

add_user <- function(username, password, role, email) {
  password_hash <- hash_password(password)
  tryCatch({
    dbExecute(pool, "
      INSERT INTO users (username, password_hash, role, email) 
      VALUES ($1, $2, $3, $4)
    ", params = list(username, password_hash, role, email))
    return(TRUE)
  }, error = function(e) {
    return(FALSE)
  })
}

update_user <- function(user_id, role, email, is_active) {
  tryCatch({
    dbExecute(pool, "
      UPDATE users 
      SET role = $1, email = $2, is_active = $3 
      WHERE user_id = $4
    ", params = list(role, email, is_active, user_id))
    return(TRUE)
  }, error = function(e) {
    return(FALSE)
  })
}

change_password <- function(user_id, new_password) {
  password_hash <- hash_password(new_password)
  dbExecute(pool, "
    UPDATE users 
    SET password_hash = $1 
    WHERE user_id = $2
  ", params = list(password_hash, user_id))
}

# Define the fixed directory path
DIRECTORY_PATH <- "poc"  # Define the fixed path hereget
# Add this new function for merging CSV files
merge_csv_files <- function(directory_path = DIRECTORY_PATH) {
  # List all CSV files in the directory
  csv_files <- list.files(path = directory_path, 
                          pattern = "\\.csv$", 
                          full.names = TRUE)
  
  if (length(csv_files) == 0) {
    return(NULL)
  }
  
  # Read the first file to get column count
  first_df <- read.csv(csv_files[1])
  expected_cols <- ncol(first_df)
  
  # Initialize list to store valid dataframes
  valid_dfs <- list()
  invalid_files <- character()
  
  # Process each CSV file
  for (file in csv_files) {
    tryCatch({
      current_df <- read.csv(file)
      
      # Check if column count matches
      if (ncol(current_df) == expected_cols) {
        # Check if column names match
        if (all(colnames(current_df) == colnames(first_df))) {
          valid_dfs[[length(valid_dfs) + 1]] <- current_df
        } else {
          invalid_files <- c(invalid_files, 
                             paste(basename(file), "- Column names don't match"))
        }
      } else {
        invalid_files <- c(invalid_files, 
                           paste(basename(file), "- Different number of columns"))
      }
    }, error = function(e) {
      invalid_files <- c(invalid_files, 
                         paste(basename(file), "- Error reading file:", e$message))
    })
  }
  
  if (length(valid_dfs) == 0) {
    return(NULL)
  }
  
  # Combine all valid dataframes
  merged_data <- do.call(rbind, valid_dfs)
  
  # Add attribute to store invalid files information
  attr(merged_data, "invalid_files") <- invalid_files
  
  return(merged_data)
}

# UI definition
ui <- dashboardPage(
  dashboardHeader(title = "EMR Module Uptake Dashboard"),
  
  dashboardSidebar(
    uiOutput("sidebar")
  ),
  
  dashboardBody(
    useShinyjs(),
    uiOutput("main_content")
  )
)

# Server logic
server <- function(input, output, session) {
  pool <- dbPool(
    drv = RPostgres::Postgres(),
    dbname = "postgres",
    host = "127.0.0.1",
    user = "postgres",
    password ="test",
    port = 5432
  )
  
  # Initialize database
  initialize_db(pool)
  
  # Reactive values
  rv <- reactiveValues(
    logged_in = FALSE,
    current_user = NULL,
    login_attempts = 0,
    data =NULL
  )
  
  # Session timeout tracking
  session_start_time <- reactiveVal(NULL)
  session_timeout <- 30 * 60  # 30 minutes
  
  # Observe session timeout
  observe({
    req(rv$logged_in)
    invalidateLater(60000)  # Check every minute
    
    if (!is.null(session_start_time())) {
      elapsed_time <- as.numeric(difftime(Sys.time(), session_start_time(), units = "secs"))
      
      if (elapsed_time > session_timeout) {
        # Log logout in database
        if (!is.null(rv$current_user)) {
          dbExecute(pool, "
            UPDATE user_sessions 
            SET logout_time = CURRENT_TIMESTAMP 
            WHERE user_id = $1 AND logout_time IS NULL
          ", params = list(rv$current_user$user_id))
        }
        
        rv$logged_in <- FALSE
        rv$current_user <- NULL
        session$reload()
        output$login_msg <- renderText("Session expired. Please log in again.")
      }
    }
  })
  
  # Dynamic Sidebar
  output$sidebar <- renderUI({
    if (!rv$logged_in) {
      return(NULL)
    }
    
    menu_items <- list(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard"))
    )
    
    if (rv$current_user$role %in% c("admin", "manager")) {
      menu_items <- c(menu_items, list(
        menuItem("Data Management", tabName = "data", icon = icon("database"))
      ))
    }
    
    if (rv$current_user$role == "admin") {
      menu_items <- c(menu_items, list(
        menuItem("User Management", tabName = "users", icon = icon("users"))
      ))
    }
    
    menu_items <- c(menu_items, list(
      menuItem("Change Password", tabName = "password", icon = icon("key")),
      menuItem("Logout", tabName = "logout", icon = icon("sign-out-alt"),
               onclick = sprintf("Shiny.setInputValue('logout_btn', %f)", as.numeric(Sys.time())))
    ))
    
    do.call(sidebarMenu, menu_items)
  })
  
  # Dynamic Main Content
  output$main_content <- renderUI({
    if (!rv$logged_in) {
      # Login Screen
      fluidRow(
        column(width = 4, offset = 4,
               box(width = NULL, 
                   status = "primary",
                   title = "EMR Module Uptake Dashboard Login",
                   textInput("username", "Username"),
                   passwordInput("password", "Password"),
                   actionButton("login_btn", "Login", 
                                class = "btn-primary", 
                                style = "width: 100%"),
                   br(), br(),
                   textOutput("login_msg")
               )
        )
      )
    } else {
      # Main Dashboard Content with tabItems
      tabItems(
        # Dashboard Tab
        tabItem(tabName = "dashboard",
                fluidRow(
                  box(width = 12,
                      selectizeInput("site_filter", "Filter by Site Code:",
                                     choices = unique(rv$as.factor(unique_site_data$siteCode)),
                                     multiple = TRUE,
                                     options = list(placeholder = "Select sites..."))
                  )
                ),
                fluidRow(
                  valueBoxOutput("total_sites_box", width = 3),
                  valueBoxOutput("avg_uptake_box", width = 3),
                  valueBoxOutput("high_perform_box", width = 3),
                  valueBoxOutput("low_perform_box", width = 3)
                ),
                
                fluidRow(
                  box(width = 8, height = "600px",
                      title = "Module Uptake Heatmap",
                      plotlyOutput("heatmap", height = "520px")
                  ),
                  box(width = 4,
                      title = "Performance Summary",
                      plotlyOutput("performance_chart", height = "250px")
                  )
                )
        ),
        
        # Data Management Tab
        tabItem(tabName = "data",
                fluidRow(
                  box(
                    width = 12,
                    title = "Data Preview",
                    status = "primary",
                    solidHeader = TRUE,
                    downloadButton('download_data', 'Download Data'),
                    DTOutput('full_data')
                  )
                )
        ),
        
        # User Management Tab
        tabItem(tabName = "users",
                fluidRow(
                  box(width = 12, title = "User Management",
                      tabsetPanel(
                        tabPanel("Users List",
                                 br(),
                                 DTOutput("users_table"),
                                 hr(),
                                 fluidRow(
                                   column(3, actionButton("add_user_btn", "Add New User", 
                                                          class = "btn-success")),
                                   column(3, actionButton("edit_user_btn", "Edit Selected User", 
                                                          class = "btn-info")),
                                   column(3, actionButton("reset_pwd_btn", "Reset Password", 
                                                          class = "btn-warning")),
                                   column(3, actionButton("toggle_active_btn", "Toggle Active Status",
                                                          class = "btn-danger"))
                                 )
                        ),
                        tabPanel("Add New User",
                                 br(),
                                 textInput("new_username", "Username"),
                                 passwordInput("new_password", "Password"),
                                 passwordInput("confirm_password", "Confirm Password"),
                                 selectInput("new_role", "Role",
                                             choices = c("admin", "manager", "user")),
                                 textInput("new_email", "Email"),
                                 actionButton("save_new_user", "Save", class = "btn-primary"),
                                 actionButton("cancel_new_user", "Cancel", class = "btn-default"),
                                 br(), br(),
                                 textOutput("new_user_msg")
                        ),
                        tabPanel("Edit User",
                                 br(),
                                 uiOutput("edit_user_ui"),
                                 br(), br(),
                                 textOutput("edit_user_msg")
                        )
                      )
                  )
                )
        ),
        
        # Change Password Tab
        tabItem(tabName = "password",
                fluidRow(
                  box(width = 6, offset = 3,
                      title = "Change Your Password",
                      passwordInput("current_password", "Current Password"),
                      passwordInput("new_password1", "New Password"),
                      passwordInput("new_password2", "Confirm New Password"),
                      br(),
                      actionButton("change_pwd_btn", "Update Password", 
                                   class = "btn-primary"),
                      br(), br(),
                      textOutput("pwd_change_msg")
                  )
                )
        )
      )
    }
  })
  
  # Login Handler
  observeEvent(input$login_btn, {
    req(input$username, input$password)
    
    # Reset login attempts if too many
    if (rv$login_attempts >= 3) {
      output$login_msg <- renderText("Too many failed attempts. Please try again later.")
      return()
    }
    
    # Verify user against database
    user <- verify_user(input$username, input$password)
    
    if (!is.null(user)) {
      # Successful login
      rv$logged_in <- TRUE
      rv$current_user <- user
      rv$login_attempts <- 0
      session_start_time(Sys.time())
      
      output$login_msg <- renderText("Login successful!")
    } else {
      # Failed login
      rv$login_attempts <- rv$login_attempts + 1
      rv$logged_in <- FALSE
      rv$current_user <- NULL
      
      output$login_msg <- renderText("Invalid username or password!")
    }
  })
  
  # Logout Handler
  observeEvent(input$logout_btn, {
    # Log logout in database
    if (!is.null(rv$current_user)) {
      dbExecute(pool, "
        UPDATE user_sessions 
        SET logout_time = CURRENT_TIMESTAMP 
        WHERE user_id = $1 AND logout_time IS NULL
      ", params = list(rv$current_user$user_id))
    }
    
    rv$logged_in <- FALSE
    rv$current_user <- NULL
    session_start_time(NULL)
    session$reload()
  })
  
  # User Management - Get users
  output$users_table <- renderDT({
    req(rv$logged_in, rv$current_user$role == "admin")
    
    users_data <- get_users()
    users_data$created_at <- format(users_data$created_at, "%Y-%m-%d %H:%M")
    users_data$last_login <- format(users_data$last_login, "%Y-%m-%d %H:%M")
    
    datatable(users_data,
              selection = 'single',
              options = list(
                pageLength = 10,
                lengthMenu = c(5, 10, 15, 20)
              )) %>%
      formatStyle('is_active',
                  backgroundColor = styleEqual(
                    c(TRUE, FALSE), 
                    c('lightgreen', 'lightcoral')
                  ))
  })
  
  # User Management - Add new user
  observeEvent(input$save_new_user, {
    req(rv$logged_in, rv$current_user$role == "admin")
    
    # Validate inputs
    if (input$new_username == "" || input$new_password == "" || 
        input$confirm_password == "" || input$new_email == "") {
      output$new_user_msg <- renderText("All fields are required")
      return()
    }
    
    if (input$new_password != input$confirm_password) {
      output$new_user_msg <- renderText("Passwords do not match")
      return()
    }
    
    # Add user to database
    success <- add_user(
      input$new_username,
      input$new_password,
      input$new_role,
      input$new_email
    )
    
    if (success) {
      output$new_user_msg <- renderText("User added successfully")
      # Reset form
      updateTextInput(session, "new_username", value = "")
      updateTextInput(session, "new_password", value = "")
      updateTextInput(session, "confirm_password", value = "")
      updateTextInput(session, "new_email", value = "")
    } else {
      output$new_user_msg <- renderText("Error adding user. Username may be taken.")
    }
  })
  
  # User Management - Edit user UI
  output$edit_user_ui <- renderUI({
    req(rv$logged_in, rv$current_user$role == "admin")
    
    # Get selected user
    selected <- input$users_table_rows_selected
    
    if (length(selected) == 0) {
      return(p("Please select a user to edit from the Users List tab."))
    }
    
    users_data <- get_users()
    selected_user <- users_data[selected, ]
    
    tagList(
      h4(paste("Editing user:", selected_user$username)),
      selectInput("edit_role", "Role",
                  choices = c("admin", "manager", "user"),
                  selected = selected_user$role),
      textInput("edit_email", "Email", value = selected_user$email),
      checkboxInput("edit_is_active", "Account Active", value = selected_user$is_active),
      actionButton("save_edit_user", "Save Changes", class = "btn-primary"),
      actionButton("cancel_edit_user", "Cancel", class = "btn-default")
    )
  })
  
  # User Management - Save edited user
  observeEvent(input$save_edit_user, {
    req(rv$logged_in, rv$current_user$role == "admin")
    
    selected <- input$users_table_rows_selected
    
    if (length(selected) == 0) {
      output$edit_user_msg <- renderText("No user selected")
      return()
    }
    
    users_data <- get_users()
    user_id <- users_data$user_id[selected]
    
    success <- update_user(
      user_id,
      input$edit_role,
      input$edit_email,
      input$edit_is_active
    )
    
    if (success) {
      output$edit_user_msg <- renderText("User updated successfully")
    } else {
      output$edit_user_msg <- renderText("Error updating user")
    }
  })
  
  # User Management - Reset password
  observeEvent(input$reset_pwd_btn, {
    req(rv$logged_in, rv$current_user$role == "admin")
    
    selected <- input$users_table_rows_selected
    
    if (length(selected) == 0) {
      showModal(modalDialog(
        title = "Error",
        "Please select a user first",
        easyClose = TRUE
      ))
      return()
    }
    
    users_data <- get_users()
    user_id <- users_data$user_id[selected]
    username <- users_data$username[selected]
    
    # Show reset password modal
    showModal(modalDialog(
      title = paste("Reset Password for", username),
      passwordInput("reset_password", "New Password"),
      passwordInput("confirm_reset_password", "Confirm New Password"),
      footer = tagList(
        actionButton("do_reset_pwd", "Reset Password", class = "btn-warning"),
        modalButton("Cancel")
      )
    ))
  })
  
  # User Management - Execute password reset
  observeEvent(input$do_reset_pwd, {
    req(rv$logged_in, rv$current_user$role == "admin")
    
    if (input$reset_password != input$confirm_reset_password) {
      showModal(modalDialog(
        title = "Error",
        "Passwords do not match",
        easyClose = TRUE
      ))
      return()
    }
    
    selected <- input$users_table_rows_selected
    users_data <- get_users()
    user_id <- users_data$user_id[selected]
    
    change_password(user_id, input$reset_password)
    
    removeModal()
    showModal(modalDialog(
      title = "Success",
      "Password has been reset",
      easyClose = TRUE
    ))
  })
  
  # User Management - Toggle active status
  observeEvent(input$toggle_active_btn, {
    req(rv$logged_in, rv$current_user$role == "admin")
    
    selected <- input$users_table_rows_selected
    
    if (length(selected) == 0) {
      showModal(modalDialog(
        title = "Error",
        "Please select a user first",
        easyClose = TRUE
      ))
      return()
    }
    
    users_data <- get_users()
    user_id <- users_data$user_id[selected]
    username <- users_data$username[selected]
    current_status <- users_data$is_active[selected]
    new_status <- !current_status
    
    # Confirm before deactivating admin users
    if (users_data$role[selected] == "admin" && new_status == FALSE) {
      showModal(modalDialog(
        title = "Warning",
        "Are you sure you want to deactivate an admin user?",
        footer = tagList(
          actionButton("confirm_toggle", "Yes, Deactivate", class = "btn-danger"),
          modalButton("Cancel")
        )
      ))
    } else {
      update_user(
        user_id,
        users_data$role[selected],
        users_data$email[selected],
        new_status
      )
    }
  })
  
  # User Management - Confirm toggle for admin users
  observeEvent(input$confirm_toggle, {
    req(rv$logged_in, rv$current_user$role == "admin")
    
    selected <- input$users_table_rows_selected
    users_data <- get_users()
    user_id <- users_data$user_id[selected]
    
    update_user(
      user_id,
      users_data$role[selected],
      users_data$email[selected],
      FALSE  # deactivate
    )
    
    removeModal()
  })
  
  # Change Password
  observeEvent(input$change_pwd_btn, {
    req(rv$logged_in)
    
    # Verify current password
    user_id <- rv$current_user$user_id
    username <- rv$current_user$username
    
    user_data <- dbGetQuery(pool, "
      SELECT password_hash FROM users WHERE user_id = $1
    ", params = list(user_id))
    
    if (hash_password(input$current_password) != user_data$password_hash) {
      output$pwd_change_msg <- renderText("Current password is incorrect")
      return()
    }
    
    # Verify new passwords match
    if (input$new_password1 != input$new_password2) {
      output$pwd_change_msg <- renderText("New passwords do not match")
      return()
    }
    
    # Change password
    change_password(user_id, input$new_password1)
    
    # Clear inputs
    updateTextInput(session, "current_password", value = "")
    updateTextInput(session, "new_password1", value = "")
    updateTextInput(session, "new_password2", value = "")
    
    output$pwd_change_msg <- renderText("Password updated successfully")
  })
  
  
  # Load data in observe block to ensure proper reactivity
  observe({
    # Only load data if it hasn't been loaded yet
    if (is.null(rv$data)) {
      tryCatch({
        data <- merge_csv_files()
        if (!is.null(data)) {
          rv$data <- data
          rv$unique_site_data <- data %>%
            group_by(siteCode) %>%
            ungroup()
          
          message("Data loaded successfully. Total sites: ", nrow(rv$unique_site_data))
          # Print debugging information
          message("Data loaded successfully. Dimensions: ", paste(dim(rv$unique_site_data), collapse = " x "))
        }
      }, error = function(e) {
        warning("Error loading data: ", e$message)
      })
    }
  })
  
  
  # When the app closes, close the pool
  onStop(function() {
    poolClose(pool)
  })
  
  # Existing code remains the same...
  # Filtered Data
  filtered_data <- reactive({
    req(rv$data)
    data <- rv$data
    if (!is.null(input$site_filter) && length(input$site_filter) > 0) {
      data <- data[data$siteCode %in% input$site_filter,]
    }
    return(data)
  })
  #visualization
  observe({
    req(rv$logged_in)
    
    # Heatmap
    output$heatmap <- renderPlotly({
      req(filtered_data())
      
      plot_data <- filtered_data() %>%
        select(-c(siteCode, total_encounters, average_score, FacilityPoCStatus)) %>%
        gather(key = "Module", value = "Uptake") %>%
        group_by(Module) %>%
        summarise(Uptake = mean(Uptake, na.rm = TRUE))
      
      plot_ly(
        data = plot_data,
        y = ~Module,
        x = ~1,
        type = "heatmap",
        z = matrix(plot_data$Uptake, ncol = 1),
        colorscale = list(
          list(0, "#FF0000"),
          list(0.8, "#FFD700"),
          list(0.95, "#00CC00")
        ),
        text = ~sprintf("%.1f%%", Uptake * 100),
        hoverinfo = "text",
        showscale = TRUE
      ) %>%
        layout(
          xaxis = list(showticklabels = FALSE, title = ""),
          yaxis = list(title = ""),
          margin = list(l = 200)
        )
    })
    
    # Performance Chart
    output$performance_chart <- renderPlotly({
      req(filtered_data())
      
      plot_data <- filtered_data() %>%
        group_by(siteCode) %>%
        summarise(avg_score = mean(average_score, na.rm = TRUE))
      
      plot_ly(data = plot_data,
              x = ~siteCode,
              y = ~avg_score,
              type = "bar") %>%
        layout(
          title = "Site Performance",
          xaxis = list(title = "Site Code"),
          yaxis = list(title = "Average Score",
                       range = c(0, 1))
        )
    })
    # Trend Chart
    output$trend_chart <- renderPlotly({
      req(filtered_data())
      
      plot_data <- filtered_data() %>%
        select(-c(total_encounters, FacilityPoCStatus)) %>%
        gather(key = "Module", value = "Uptake", -siteCode, -average_score) %>%
        group_by(Module) %>%
        summarise(avg_uptake = mean(Uptake, na.rm = TRUE)) %>%
        arrange(desc(avg_uptake))
      
      plot_ly(data = plot_data,
              x = ~avg_uptake,
              y = ~Module,
              type = "bar",
              orientation = "h") %>%
        layout(
          title = "Module Performance",
          xaxis = list(title = "Average Uptake"),
          yaxis = list(title = "")
        )
    })
    
    # Summary Boxes
    output$total_sites_box <- renderValueBox({
      valueBox(
        length(unique(filtered_data()$siteCode)),
        "Total Sites",
        icon = icon("hospital"),
        color = "blue"
      )
    })
    
    output$avg_uptake_box <- renderValueBox({
      avg <- mean(filtered_data()$average_score, na.rm = TRUE)
      valueBox(
        sprintf("%.1f%%", avg * 100),
        "Average Uptake",
        icon = icon("chart-line"),
        color = "yellow"
      )
    })
    
    output$high_perform_box <- renderValueBox({
      high_perf <- sum(filtered_data()$average_score >= 0.95, na.rm = TRUE)
      valueBox(
        high_perf,
        "High Performing Sites",
        icon = icon("arrow-up"),
        color = "green"
      )
    })
    
    output$low_perform_box <- renderValueBox({
      low_perf <- sum(filtered_data()$average_score < 0.80, na.rm = TRUE)
      valueBox(
        low_perf,
        "Low Performing Sites",
        icon = icon("arrow-down"),
        color = "red"
      )
    })
    
    # Data Tables
    output$data_preview <- renderDT({
      head(filtered_data(), 10)
    })
    # Add a download handler for the data
    output$download_data <- downloadHandler(
      filename = function() {
        paste("data-", Sys.Date(), ".csv", sep="")
      },
      content = function(file) {
        write.csv(rv$unique_site_data, file, row.names = FALSE)
      }
    )
    output$full_data <- renderDT({
      #filtered_data()
      # Create datatable with improved options
      datatable(
        rv$unique_site_data,
        options = list(
          pageLength = 10,
          scrollX = TRUE,
          scrollY = "400px",
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf', 'print'),
          searchHighlight = TRUE,
          processing = TRUE
        ),
        filter = 'top',
        selection = 'single',
        rownames = FALSE,
        class = 'cell-border stripe'
      ) %>%
        formatStyle(
          names(rv$unique_site_data),
          backgroundColor = 'white',
          color = 'black'
        )
    })
  })
  
}

# Run the application
shinyApp(ui = ui, server = server)
