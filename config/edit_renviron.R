# Edit Renviron

# Load Package
library(usethis)

# Get working directy and set if needed 
getwd()
setwd("/Users/danberle/Documents/projects/metro_deep_dive")

# Load the Renviron to set it
edit_r_environ(scope = "project")