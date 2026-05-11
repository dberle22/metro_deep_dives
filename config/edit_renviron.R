# Edit Renviron

# Load Package
library(usethis)

# Get working directly and set if needed 
getwd()
setwd("projects/metro_deep_dive")

# Load the Renviron to set it
edit_r_environ(scope = "project")
