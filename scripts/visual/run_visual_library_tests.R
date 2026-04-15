#!/usr/bin/env Rscript

if (file.exists(".Renviron")) readRenviron(".Renviron")

# Compatibility wrapper: active visual-library development now lives under
# visual_library/ so the library can be worked on in isolation.
source("visual_library/run_visual_library_tests.R")
