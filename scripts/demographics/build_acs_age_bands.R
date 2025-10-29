# SILVER: AGE BANDS + SHARES (TRACT -> CBSA)
# Input:
#   - tract_nc_acs_age_raw: wide B01001 pull (2012–2023) with *_E columns
#   - cbsa_county_crosswalk: county_fips -> CBSA mapping (current vintage)
# Output:
#   - age_bands_tract: tract-level bands + share %
#   - age_bands_cbsa : CBSA-level bands + share %, frozen membership


# Read in Raw Data (if not already in environment) ----

library(tidyverse)
library(stringr)

# Set paths for our environments
# Make sure we're reading from the project Renviron
if (file.exists(".Renviron")) readRenviron(".Renviron")

# Set paths
silver_acs <- get_env_path("DATA_DEMO_SILVER")
silver_xwalk <- get_env_path("GOLD_XWALK")

# Import CBSA <> County Crosswalk
county_cbsa_xwalk <- read_csv(paste0(silver_xwalk, "/cbsa_county_crosswalk.csv"))

county_cbsa_xwalk <- county_cbsa_xwalk %>%
  mutate(cbsa_code = as.character(cbsa_code))

# 0) Prep: ensure numeric for all *_E columns ----

tract_age_wide <- tract_nc_acs_age_raw
num_cols <- grep("_E$", names(tract_age_wide), value = TRUE)
tract_age_wide <- tract_age_wide %>%
  mutate(across(all_of(num_cols), as.numeric))


# 1) Define which columns go into each age band (M/F) ----

m_0_14      <- c("pop_age_male_under5E","pop_age_male_5_9E","pop_age_male_10_14E")
f_0_14      <- c("pop_age_female_under5E","pop_age_female_5_9E","pop_age_female_10_14E")

m_15_24     <- c("pop_age_male_15_17E","pop_age_male_18_19E","pop_age_male_20E",
                 "pop_age_male_21E","pop_age_male_22_24E")
f_15_24     <- c("pop_age_female_15_17E","pop_age_female_18_19E","pop_age_female_20E",
                 "pop_age_female_21E","pop_age_female_22_24E")

m_25_44     <- c("pop_age_male_25_29E","pop_age_male_30_34E","pop_age_male_35_39E","pop_age_male_40_44E")
f_25_44     <- c("pop_age_female_25_29E","pop_age_female_30_34E","pop_age_female_35_39E","pop_age_female_40_44E")

m_45_64     <- c("pop_age_male_45_49E","pop_age_male_50_54E","pop_age_male_55_59E",
                 "pop_age_male_60_61E","pop_age_male_62_64E")
f_45_64     <- c("pop_age_female_45_49E","pop_age_female_50_54E","pop_age_female_55_59E",
                 "pop_age_female_60_61E","pop_age_female_62_64E")

m_65_plus   <- c("pop_age_male_65_66E","pop_age_male_67_69E","pop_age_male_70_74E",
                 "pop_age_male_75_79E","pop_age_male_80_84E","pop_age_male_85_plusE")
f_65_plus   <- c("pop_age_female_65_66E","pop_age_female_67_69E","pop_age_female_70_74E",
                 "pop_age_female_75_79E","pop_age_female_80_84E","pop_age_female_85_plusE")


# 2) TRACT: build band counts and percentage shares ----
# We only have NC for now, but we'll get the rest later

age_bands_tract <- tract_age_wide %>%
  transmute(
    GEOID,
    year,
    pop_total = pop_totalE,
    
    band_0_14    = rowSums(across(all_of(m_0_14)), na.rm = TRUE) +
      rowSums(across(all_of(f_0_14)), na.rm = TRUE),
    band_15_24   = rowSums(across(all_of(m_15_24)), na.rm = TRUE) +
      rowSums(across(all_of(f_15_24)), na.rm = TRUE),
    band_25_44   = rowSums(across(all_of(m_25_44)), na.rm = TRUE) +
      rowSums(across(all_of(f_25_44)), na.rm = TRUE),
    band_45_64   = rowSums(across(all_of(m_45_64)), na.rm = TRUE) +
      rowSums(across(all_of(f_45_64)), na.rm = TRUE),
    band_65_plus = rowSums(across(all_of(m_65_plus)), na.rm = TRUE) +
      rowSums(across(all_of(f_65_plus)), na.rm = TRUE)
  ) %>%
  mutate(
    total_banded = band_0_14 + band_15_24 + band_25_44 + band_45_64 + band_65_plus,
    # Use official ACS total when present; otherwise fall back to the banded sum
    denom       = if_else(!is.na(pop_total) & pop_total > 0, pop_total, total_banded),
    pct_0_14    = 100 * band_0_14    / denom,
    pct_15_24   = 100 * band_15_24   / denom,
    pct_25_44   = 100 * band_25_44   / denom,
    pct_45_64   = 100 * band_45_64   / denom,
    pct_65_plus = 100 * band_65_plus / denom
  )

# 3) QA Tracts ----
# Making sure Bands add up to 100
qa_tract <- age_bands_tract %>%
  transmute(GEOID, year,
            sum_pct = pct_0_14 + pct_15_24 + pct_25_44 + pct_45_64 + pct_65_plus)

# 4) Write to CSV ----
write_csv(age_bands_tract, paste0(silver_acs, "/age_bands/age_bands_tract.csv"))

# County ----
county_age_wide <- county_acs_age_raw
num_cols <- grep("_E$", names(tract_age_wide), value = TRUE)
county_age_wide <- county_age_wide %>%
  mutate(across(all_of(num_cols), as.numeric))


age_bands_county <- county_age_wide %>%
  transmute(
    GEOID,
    year,
    pop_total = pop_totalE,
    
    band_0_14    = rowSums(across(all_of(m_0_14)), na.rm = TRUE) +
      rowSums(across(all_of(f_0_14)), na.rm = TRUE),
    band_15_24   = rowSums(across(all_of(m_15_24)), na.rm = TRUE) +
      rowSums(across(all_of(f_15_24)), na.rm = TRUE),
    band_25_44   = rowSums(across(all_of(m_25_44)), na.rm = TRUE) +
      rowSums(across(all_of(f_25_44)), na.rm = TRUE),
    band_45_64   = rowSums(across(all_of(m_45_64)), na.rm = TRUE) +
      rowSums(across(all_of(f_45_64)), na.rm = TRUE),
    band_65_plus = rowSums(across(all_of(m_65_plus)), na.rm = TRUE) +
      rowSums(across(all_of(f_65_plus)), na.rm = TRUE)
  ) %>%
  mutate(
    total_banded = band_0_14 + band_15_24 + band_25_44 + band_45_64 + band_65_plus,
    # Use official ACS total when present; otherwise fall back to the banded sum
    denom       = if_else(!is.na(pop_total) & pop_total > 0, pop_total, total_banded),
    pct_0_14    = 100 * band_0_14    / denom,
    pct_15_24   = 100 * band_15_24   / denom,
    pct_25_44   = 100 * band_25_44   / denom,
    pct_45_64   = 100 * band_45_64   / denom,
    pct_65_plus = 100 * band_65_plus / denom
  )

write_csv(age_bands_county, paste0(silver_acs, "/age_bands/age_bands_county.csv"))

# CBSA ----
# We will aggregate our Counties to their most recent CBSA so we don't have any strange time series results if a CBSA changes
# We will start by adding the CBSA code to our Counties DF based on our XWalk
county_age_wide_cbsa_xwalk <- county_age_wide %>%
  left_join(county_cbsa_xwalk %>% select(cbsa_code, cbsa_name, county_geoid), by = c("GEOID" = "county_geoid")) %>%
  filter(!is.na(cbsa_code))

county_age_bands_cbsa <- county_age_wide_cbsa_xwalk %>%
  transmute(
    GEOID, cbsa_code, cbsa_name, year,
    pop_total = pop_totalE,
    
    band_0_14    = rowSums(across(all_of(m_0_14)),  na.rm = TRUE) +
      rowSums(across(all_of(f_0_14)),  na.rm = TRUE),
    band_15_24   = rowSums(across(all_of(m_15_24)), na.rm = TRUE) +
      rowSums(across(all_of(f_15_24)), na.rm = TRUE),
    band_25_44   = rowSums(across(all_of(m_25_44)), na.rm = TRUE) +
      rowSums(across(all_of(f_25_44)), na.rm = TRUE),
    band_45_64   = rowSums(across(all_of(m_45_64)), na.rm = TRUE) +
      rowSums(across(all_of(f_45_64)), na.rm = TRUE),
    band_65_plus = rowSums(across(all_of(m_65_plus)), na.rm = TRUE) +
      rowSums(across(all_of(f_65_plus)), na.rm = TRUE)
  ) %>%
  mutate(total_banded = band_0_14 + band_15_24 + band_25_44 + band_45_64 + band_65_plus)


age_bands_cbsa <- county_age_bands_cbsa %>%
  group_by(cbsa_code, cbsa_name, year) %>%
  summarise(
    pop_total    = sum(pop_total,    na.rm = TRUE),
    total_banded = sum(total_banded, na.rm = TRUE),
    band_0_14    = sum(band_0_14,    na.rm = TRUE),
    band_15_24   = sum(band_15_24,   na.rm = TRUE),
    band_25_44   = sum(band_25_44,   na.rm = TRUE),
    band_45_64   = sum(band_45_64,   na.rm = TRUE),
    band_65_plus = sum(band_65_plus, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    denom        = if_else(pop_total > 0, pop_total, total_banded),
    pct_0_14     = 100 * band_0_14    / denom,
    pct_15_24    = 100 * band_15_24   / denom,
    pct_25_44    = 100 * band_25_44   / denom,
    pct_45_64    = 100 * band_45_64   / denom,
    pct_65_plus  = 100 * band_65_plus / denom
  )

# Quick QA
age_bands_cbsa %>%
  mutate(sum_pct = pct_0_14 + pct_15_24 + pct_25_44 + pct_45_64 + pct_65_plus) %>%
  summarise(all_good = all(abs(sum_pct - 100) < 0.6 | is.na(sum_pct)))

write_csv(age_bands_cbsa, paste0(silver_acs, "/age_bands/age_bands_cbsa.csv"))

# State ----
state_age_wide <- state_acs_age_raw
num_cols <- grep("_E$", names(tract_age_wide), value = TRUE)
state_age_wide <- state_age_wide %>%
  mutate(across(all_of(num_cols), as.numeric))


age_bands_state <- state_age_wide %>%
  transmute(
    GEOID,
    year,
    pop_total = pop_totalE,
    
    band_0_14    = rowSums(across(all_of(m_0_14)), na.rm = TRUE) +
      rowSums(across(all_of(f_0_14)), na.rm = TRUE),
    band_15_24   = rowSums(across(all_of(m_15_24)), na.rm = TRUE) +
      rowSums(across(all_of(f_15_24)), na.rm = TRUE),
    band_25_44   = rowSums(across(all_of(m_25_44)), na.rm = TRUE) +
      rowSums(across(all_of(f_25_44)), na.rm = TRUE),
    band_45_64   = rowSums(across(all_of(m_45_64)), na.rm = TRUE) +
      rowSums(across(all_of(f_45_64)), na.rm = TRUE),
    band_65_plus = rowSums(across(all_of(m_65_plus)), na.rm = TRUE) +
      rowSums(across(all_of(f_65_plus)), na.rm = TRUE)
  ) %>%
  mutate(
    total_banded = band_0_14 + band_15_24 + band_25_44 + band_45_64 + band_65_plus,
    # Use official ACS total when present; otherwise fall back to the banded sum
    denom       = if_else(!is.na(pop_total) & pop_total > 0, pop_total, total_banded),
    pct_0_14    = 100 * band_0_14    / denom,
    pct_15_24   = 100 * band_15_24   / denom,
    pct_25_44   = 100 * band_25_44   / denom,
    pct_45_64   = 100 * band_45_64   / denom,
    pct_65_plus = 100 * band_65_plus / denom
  )

write_csv(age_bands_state, paste0(silver_acs, "/age_bands/age_bands_state.csv"))


# Division ----
division_age_wide <- division_acs_age_raw
num_cols <- grep("_E$", names(tract_age_wide), value = TRUE)
division_age_wide <- division_age_wide %>%
  mutate(across(all_of(num_cols), as.numeric))


age_bands_division <- division_age_wide %>%
  transmute(
    GEOID,
    year,
    pop_total = pop_totalE,
    
    band_0_14    = rowSums(across(all_of(m_0_14)), na.rm = TRUE) +
      rowSums(across(all_of(f_0_14)), na.rm = TRUE),
    band_15_24   = rowSums(across(all_of(m_15_24)), na.rm = TRUE) +
      rowSums(across(all_of(f_15_24)), na.rm = TRUE),
    band_25_44   = rowSums(across(all_of(m_25_44)), na.rm = TRUE) +
      rowSums(across(all_of(f_25_44)), na.rm = TRUE),
    band_45_64   = rowSums(across(all_of(m_45_64)), na.rm = TRUE) +
      rowSums(across(all_of(f_45_64)), na.rm = TRUE),
    band_65_plus = rowSums(across(all_of(m_65_plus)), na.rm = TRUE) +
      rowSums(across(all_of(f_65_plus)), na.rm = TRUE)
  ) %>%
  mutate(
    total_banded = band_0_14 + band_15_24 + band_25_44 + band_45_64 + band_65_plus,
    # Use official ACS total when present; otherwise fall back to the banded sum
    denom       = if_else(!is.na(pop_total) & pop_total > 0, pop_total, total_banded),
    pct_0_14    = 100 * band_0_14    / denom,
    pct_15_24   = 100 * band_15_24   / denom,
    pct_25_44   = 100 * band_25_44   / denom,
    pct_45_64   = 100 * band_45_64   / denom,
    pct_65_plus = 100 * band_65_plus / denom
  )

write_csv(age_bands_division, paste0(silver_acs, "/age_bands/age_bands_division.csv"))


# Region ----
region_age_wide <- region_acs_age_raw
num_cols <- grep("_E$", names(tract_age_wide), value = TRUE)
region_age_wide <- region_age_wide %>%
  mutate(across(all_of(num_cols), as.numeric))


age_bands_region <- region_age_wide %>%
  transmute(
    GEOID,
    year,
    pop_total = pop_totalE,
    
    band_0_14    = rowSums(across(all_of(m_0_14)), na.rm = TRUE) +
      rowSums(across(all_of(f_0_14)), na.rm = TRUE),
    band_15_24   = rowSums(across(all_of(m_15_24)), na.rm = TRUE) +
      rowSums(across(all_of(f_15_24)), na.rm = TRUE),
    band_25_44   = rowSums(across(all_of(m_25_44)), na.rm = TRUE) +
      rowSums(across(all_of(f_25_44)), na.rm = TRUE),
    band_45_64   = rowSums(across(all_of(m_45_64)), na.rm = TRUE) +
      rowSums(across(all_of(f_45_64)), na.rm = TRUE),
    band_65_plus = rowSums(across(all_of(m_65_plus)), na.rm = TRUE) +
      rowSums(across(all_of(f_65_plus)), na.rm = TRUE)
  ) %>%
  mutate(
    total_banded = band_0_14 + band_15_24 + band_25_44 + band_45_64 + band_65_plus,
    # Use official ACS total when present; otherwise fall back to the banded sum
    denom       = if_else(!is.na(pop_total) & pop_total > 0, pop_total, total_banded),
    pct_0_14    = 100 * band_0_14    / denom,
    pct_15_24   = 100 * band_15_24   / denom,
    pct_25_44   = 100 * band_25_44   / denom,
    pct_45_64   = 100 * band_45_64   / denom,
    pct_65_plus = 100 * band_65_plus / denom
  )

write_csv(age_bands_region, paste0(silver_acs, "/age_bands/age_bands_region.csv"))


# US ----
us_age_wide <- us_acs_age_raw
num_cols <- grep("_E$", names(tract_age_wide), value = TRUE)
us_age_wide <- us_age_wide %>%
  mutate(across(all_of(num_cols), as.numeric))


age_bands_us <- us_age_wide %>%
  transmute(
    GEOID,
    year,
    pop_total = pop_totalE,
    
    band_0_14    = rowSums(across(all_of(m_0_14)), na.rm = TRUE) +
      rowSums(across(all_of(f_0_14)), na.rm = TRUE),
    band_15_24   = rowSums(across(all_of(m_15_24)), na.rm = TRUE) +
      rowSums(across(all_of(f_15_24)), na.rm = TRUE),
    band_25_44   = rowSums(across(all_of(m_25_44)), na.rm = TRUE) +
      rowSums(across(all_of(f_25_44)), na.rm = TRUE),
    band_45_64   = rowSums(across(all_of(m_45_64)), na.rm = TRUE) +
      rowSums(across(all_of(f_45_64)), na.rm = TRUE),
    band_65_plus = rowSums(across(all_of(m_65_plus)), na.rm = TRUE) +
      rowSums(across(all_of(f_65_plus)), na.rm = TRUE)
  ) %>%
  mutate(
    total_banded = band_0_14 + band_15_24 + band_25_44 + band_45_64 + band_65_plus,
    # Use official ACS total when present; otherwise fall back to the banded sum
    denom       = if_else(!is.na(pop_total) & pop_total > 0, pop_total, total_banded),
    pct_0_14    = 100 * band_0_14    / denom,
    pct_15_24   = 100 * band_15_24   / denom,
    pct_25_44   = 100 * band_25_44   / denom,
    pct_45_64   = 100 * band_45_64   / denom,
    pct_65_plus = 100 * band_65_plus / denom
  )

write_csv(age_bands_us, paste0(silver_acs, "/age_bands/age_bands_us.csv"))
