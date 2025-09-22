# Metro Deep Dive

This repository contains a modular R workflow for producing metro-level deep dive analyses. The project splits data preparation, metrics, plotting, and reporting into reusable components that can be orchestrated from parameterised scripts.

## Repository Structure

```
metro_deep_dives/
├── R/                     # Reusable R functions used across the pipeline
├── scripts/               # Step-by-step scripts that compose the workflow
├── notebooks/             # Exploratory and refactored R Markdown notebooks
├── config/                # Project configuration files (YAML)
├── schemas/               # Data schema documentation for Bronze/Silver/Gold layers
├── tests/                 # Optional tests leveraging testthat
├── .github/workflows/     # Continuous integration configuration
├── .gitignore             # Ignored files and directories
├── LICENSE                # Project license
└── README.md              # Project overview (this file)
```

## Getting Started

1. Review and update `config/project.yml` with the GEOID, year range, and feature toggles for your metro area of interest.
2. Populate the `data/` directory with the required Bronze layer CSVs described in `schemas/bronze_schema.csv`.
3. Execute the pipeline scripts in order:
   ```bash
   Rscript scripts/00_params.R
   Rscript scripts/01_utils.R
   ...
   Rscript scripts/08_driver.R
   ```
4. Generated outputs will be written to the location defined in `config/project.yml` (default `outputs/`).

## Testing

Run the automated checks locally with:

```bash
Rscript tests/testthat.R
```

The GitHub Actions workflow defined in `.github/workflows/ci.yml` runs the same test harness on each push or pull request targeting `main`.

## Contributing

* Document any new data fields in the appropriate schema CSV.
* Keep reusable logic within `R/` and reference it from scripts and notebooks.
* Update tests to cover new functionality when possible.