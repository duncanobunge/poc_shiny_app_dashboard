# EMR Module Uptake Dashboard (PoC)

Lightweight Shiny dashboard for aggregating facility CSV reports and visualizing module uptake across sites.

## Overview

This project:
- Loads CSV reports from the `poc/` folder and merges them into a dataset (see [`merge_csv_files`]).
- Provides a Shiny dashboard with authentication, user management, data preview, downloads and visualizations.
- Implements simple DB-backed user management via a connection pool (functions: [`initialize_db`](poc_script_dashboard_v1.R), [`verify_user`](poc_script_dashboard_v1.R), [`hash_password`](poc_script_dashboard_v1.R), [`add_user`](poc_script_dashboard_v1.R), [`change_password`](poc_script_dashboard_v1.R)).

## Quickstart

Prerequisites:
- R >= 4.0
- PostgreSQL for user/session store (or update code to use another DB)
- Dev packages will be installed by the app using `pacman::p_load(...)` in [`poc_script_dashboard_v1.R`](poc_script_dashboard_v1.R).

Run locally from project root in R/RStudio:
- Install packages (optional - the script auto-installs via pacman):
  ```r
  install.packages("pacman")
  pacman::p_load(shiny, shinydashboard, shinyjs, dplyr, tidyr, reshape2, plotly, DT, tools, pool, DBI, RPostgres, digest)
