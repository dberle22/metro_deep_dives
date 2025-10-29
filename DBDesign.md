*Database Design*
To build out a scalable analytics framework we will need a strong underlying database. I’m planning a medallion architecture database structure Bronze -> Silver ->. This will allow us to standardize our data models and keep different data formats in case we need later adjustments. We will then store this in a SQL database for easy querying.

*Bronze*
This is our raw data layer. We will store CSVs that we export from websites or the raw outputs of API calls here. This allows us to clean and adjust our data, while maintaining a chain of evidence for reproducibility.

*Silver*
This layer will have lightly treated and standardized data. We will clean any headers or footers from Bronze CSVs, standardize our naming conventions, build some straightforward variables such as consolidated population counts, etc. We will keep data in a wide format in this layer for easier data exploration.

*Gold*
This layer contains our most treated data. This is where we store our final KPIs that we’ve cleaned from our base tables, calculated KPIs such as Affordability Score, Overheat Index, growth rates, etc, and store our main crosswalks and dimensions so we can analyze between different levels.

*Granularities*
- US
- Region
- Division
- State
- CBSA
    - We will calculate this based on 2023 Census County membership, meaning we will rebase our County data to create CBSA level data.
- County
- Census Place
- Census Tract
- ZCTA

*Metrics*
These are the types of metrics and data sources we will consider. We will build individual tables for sources and granularities
- ACS
    - Age
    - Median Age
    - Population Age Buckets
    - Race
    - Race Buckets
    - Education
        - Education Buckets
        - Earnings by Education
    - Economics
        - Median Earnings
        - Median Income
        - Labor Force
        - Rents
    - Housing Stock
        - Total Housing
        - Vacancy Rates
- BEA
    - GDP
    - Income & Savings
    - Industries
    - Prices & Inflation
- BLS
    - CPS
    - CES
    - LAUS
    - QCEW
    - BPS
- FEMA
- FHFA
    - HPI
- HUD
    - CHAS
    - FMR
- IRS
    - Migration
- Zillow
    - ZHVI
    - ZHVF
    - ZORDI

*Dimensions*
These are the different dimensional tables we build for this analysis
- Crosswalks - These tables allow us to join between different granularities
    - State <> Region <> Division
    - State <> County
    - County <> CBSA
    - ZCTA <> County
- Dim CBSA - This table contains metadata and definitions about each CBSA
- Dim Variables - This table contains information about the variables we have in our Gold layer. The idea is to have a source of truth for KPIs and how they work
