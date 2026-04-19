rm(list = ls())
gc()

library(data.table)
library(stringr)
library(DescTools)
library(duckdb)
library(DBI)

# Data created by:
#   code/v20260410/sample-construction/build_branch_panel_regression_sample_20260409.R
# Produces:
#   data/constructed/lending_panel_YYYYMMDD_HHMMSS.rds
#
# Constructs a bank-county-year panel for incumbent banks with three parallel
# outcome variables — deposit growth, HMDA mortgage origination growth, and
# CRA small business loan growth — alongside the same treatment and county-year
# controls used in branch_year_regression_20260409.qmd.

dat_suffix         <- format(Sys.time(), "%Y%m%d_%H%M%S")
data_path          <- "data"
external_data_path <- "C:/Users/dimut/OneDrive/data/"
hmda_db_path       <- "C:/empirical-data-construction/hmda/hmda.duckdb"
cra_db_path        <- "C:/empirical-data-construction/cra/cra.duckdb"

closure_path <- file.path(external_data_path, "closure_opening_data_simple.rds")

# ── 1. Load branch panel ──────────────────────────────────────────────────────

branch_files <- list.files(
  data_path,
  pattern = "^branch_panel_regression_sample_\\d{8}\\.rds$",
  full.names = TRUE
)
if (!length(branch_files)) {
  stop("No branch_panel_regression_sample_*.rds in data/. Run the sample-construction script first.")
}
branch_file <- branch_files[which.max(file.mtime(branch_files))]
message("Loading branch panel: ", basename(branch_file))

bp <- readRDS(branch_file)
setDT(bp)

# Restrict to incumbents (same filter used in the qmd)
bp <- bp[incumbent_bank == 1L]

# ── 2. CERT → RSSDID crosswalk ────────────────────────────────────────────────
# We need a year-specific CERT→RSSDID mapping to link HMDA/CRA (which use RSSD)
# back to the FDIC cert numbers in our panel.

closure_raw <- readRDS(closure_path)
setDT(closure_raw)
closure_raw[, county := str_pad(STCNTYBR, 5, "left", "0")]
closure_raw[, YEAR   := as.integer(YEAR)]

# One row per (CERT, YEAR) with the most common RSSDID in that year
cert_rssd <- closure_raw[
  !is.na(RSSDID) & RSSDID != 0,
  .N,
  by = .(CERT, YEAR, RSSDID)
][
  order(-N)
][
  , .(RSSDID = RSSDID[1]),
  by = .(CERT, YEAR)
]
setDT(cert_rssd)

# ── 3. Bank-county-year deposit growth (aggregated from branch panel) ─────────
# Aggregate surviving-branch deposits at t-1 and t+1 within each bank-county-year.
# dep_growth = (total_dep_lead1 - total_dep_lag1) / total_dep_lag1
# This is the bank-county analog of gr_branch at the branch level.

dep_bcy <- bp[
  !is.na(dep_lag1_aligned) & dep_lag1_aligned > 0 &
    !is.na(dep_lead1_aligned) & dep_lead1_aligned > 0,
  .(
    dep_lag1_total  = sum(dep_lag1_aligned,  na.rm = TRUE),
    dep_lead1_total = sum(dep_lead1_aligned, na.rm = TRUE)
  ),
  by = .(CERT, county, YEAR)
]
dep_bcy[, dep_growth := (dep_lead1_total - dep_lag1_total) / dep_lag1_total]

# ── 4. County-level controls and treatment (one row per county-year in bp) ────

cy_controls_cols <- c(
  "county", "YEAR",
  "share_deps_closed",
  "banks_county_lag1",
  "county_dep_growth_t4_t1",
  "log_population_density",
  "lag_county_deposit_hhi",
  "lag_establishment_gr",
  "lag_payroll_gr",
  "lag_hmda_mtg_amt_gr",
  "lag_cra_loan_amount_amt_lt_1m_gr",
  "lmi"
)

cy_controls <- unique(bp[, ..cy_controls_cols])

# ── 5. Query HMDA DuckDB ─────────────────────────────────────────────────────
# Aggregate mortgage originations (action_taken = '1') by (rssd, county_fips, year).
# Pre-2018: join lar_panel to avery_crosswalk on (respondent_id, agency_code) to get rssd.
# 2018+:    join lar_panel to avery_crosswalk on lei to get rssd.
# county_fips = LEFT(census_tract, 5).
# loan_amount is already in whole dollars (ETL converts pre-2018 thousands to dollars).

message("Connecting to HMDA DuckDB: ", hmda_db_path)
con_hmda <- dbConnect(duckdb(), dbdir = hmda_db_path, read_only = TRUE)

# Inspect avery_crosswalk columns for reference
message("avery_crosswalk columns: ",
        paste(dbListFields(con_hmda, "avery_crosswalk"), collapse = ", "))

# Pre-2018: link via respondent_id + agency_code
# NOTE: adjust column name (rssd / rssd_id / rssdid) if avery_crosswalk uses a different name
hmda_pre2018 <- dbGetQuery(con_hmda, "
  SELECT
    CAST(a.rssd_id AS VARCHAR) AS rssdid,
    LEFT(l.census_tract, 5)    AS county_fips,
    l.year,
    SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM lar_panel l
  JOIN avery_crosswalk a
    ON  l.respondent_id = a.respondent_id
    AND CAST(l.agency_code AS INTEGER) = CAST(a.agency_code AS INTEGER)
    AND l.year = a.activity_year
  WHERE l.action_taken = '1'
    AND l.year < 2018
    AND LENGTH(l.census_tract) >= 5
  GROUP BY rssdid, county_fips, l.year
")
setDT(hmda_pre2018)

# 2018+: link via lei
hmda_post2018 <- dbGetQuery(con_hmda, "
  SELECT
    CAST(a.rssd_id AS VARCHAR) AS rssdid,
    LEFT(l.census_tract, 5)    AS county_fips,
    l.year,
    SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM lar_panel l
  JOIN avery_crosswalk a
    ON  l.lei = a.lei
    AND l.year = a.activity_year
  WHERE l.action_taken = '1'
    AND l.year >= 2018
    AND LENGTH(l.census_tract) >= 5
  GROUP BY rssdid, county_fips, l.year
")
setDT(hmda_post2018)

dbDisconnect(con_hmda, shutdown = TRUE)

hmda_raw <- rbindlist(list(hmda_pre2018, hmda_post2018), use.names = TRUE)
hmda_raw <- hmda_raw[!is.na(rssdid) & rssdid != "0" & !is.na(county_fips)]
hmda_raw[, YEAR    := as.integer(year)]
hmda_raw[, rssdid  := as.integer(rssdid)]
hmda_raw[, year    := NULL]

# Aggregate across lenders with the same rssdid-county-year (in case of duplicates)
hmda_raw <- hmda_raw[, .(hmda_amt = sum(hmda_amt, na.rm = TRUE)),
                     by = .(rssdid, county_fips, YEAR)]

# Map rssdid → CERT via year-specific crosswalk
hmda_raw <- merge(
  hmda_raw,
  cert_rssd[, .(CERT, YEAR, RSSDID)],
  by.x = c("rssdid", "YEAR"),
  by.y = c("RSSDID", "YEAR"),
  all.x = TRUE
)
hmda_raw <- hmda_raw[!is.na(CERT)]

# Aggregate to (CERT, county, YEAR) — a CERT can map to one RSSDID per year
hmda_bcy <- hmda_raw[, .(hmda_amt = sum(hmda_amt, na.rm = TRUE)),
                     by = .(CERT, county = county_fips, YEAR)]

# ── 6. Query CRA DuckDB ───────────────────────────────────────────────────────
# Use disclosure_panel: table_id = 'D1-1' (SBL originations), report_level = '040'
# (county total — avoids double-counting sub-county rows).
# Amounts are in thousands of dollars; multiply by 1000.

message("Connecting to CRA DuckDB: ", cra_db_path)
con_cra <- dbConnect(duckdb(), dbdir = cra_db_path, read_only = TRUE)

message("transmittal_panel columns: ",
        paste(dbListFields(con_cra, "transmittal_panel"), collapse = ", "))

cra_raw <- dbGetQuery(con_cra, "
  SELECT
    CAST(t.rssdid AS VARCHAR) AS rssdid,
    d.county_fips,
    d.year,
    SUM(
      (COALESCE(CAST(d.amt_loans_lt_100k   AS DOUBLE), 0) +
       COALESCE(CAST(d.amt_loans_100k_250k AS DOUBLE), 0) +
       COALESCE(CAST(d.amt_loans_250k_1m   AS DOUBLE), 0)) * 1000
    ) AS cra_amt
  FROM disclosure_panel d
  JOIN transmittal_panel t
    ON  d.respondent_id = t.respondent_id
    AND d.agency_code   = t.agency_code
    AND d.year          = t.year
  WHERE TRIM(d.table_id)     = 'D1-1'
    AND TRIM(d.report_level) = '040'
    AND CAST(d.action_taken AS INTEGER) = 1
    AND d.county_fips IS NOT NULL
  GROUP BY rssdid, d.county_fips, d.year
")
setDT(cra_raw)

dbDisconnect(con_cra, shutdown = TRUE)

cra_raw <- cra_raw[!is.na(rssdid) & rssdid != "0"]
cra_raw[, YEAR   := as.integer(year)]
cra_raw[, rssdid := as.integer(rssdid)]
cra_raw[, year   := NULL]

# Map rssdid → CERT
cra_raw <- merge(
  cra_raw,
  cert_rssd[, .(CERT, YEAR, RSSDID)],
  by.x = c("rssdid", "YEAR"),
  by.y = c("RSSDID", "YEAR"),
  all.x = TRUE
)
cra_raw <- cra_raw[!is.na(CERT)]

cra_bcy <- cra_raw[, .(cra_amt = sum(cra_amt, na.rm = TRUE)),
                   by = .(CERT, county = county_fips, YEAR)]

# ── 7. Build lending growth variables ─────────────────────────────────────────
# For each (CERT, county), compute t-1 and t+1 lending amounts, then compute
# the 2-year growth rate (from t-1 to t+1), parallel to gr_branch.

build_growth <- function(dt, amt_col, growth_col) {
  dt <- copy(dt)
  setorder(dt, CERT, county, YEAR)

  dt[, amt_lag1  := shift(get(amt_col), 1L, type = "lag"),  by = .(CERT, county)]
  dt[, yr_lag1   := shift(YEAR,         1L, type = "lag"),  by = .(CERT, county)]
  dt[, amt_lead1 := shift(get(amt_col), 1L, type = "lead"), by = .(CERT, county)]
  dt[, yr_lead1  := shift(YEAR,         1L, type = "lead"), by = .(CERT, county)]

  # Require consecutive years at both ends
  dt[, amt_lag1_aligned  := fifelse(yr_lag1  == YEAR - 1L, amt_lag1,  NA_real_)]
  dt[, amt_lead1_aligned := fifelse(yr_lead1 == YEAR + 1L, amt_lead1, NA_real_)]

  dt[, (growth_col) := fifelse(
    !is.na(amt_lag1_aligned) & amt_lag1_aligned > 0 & !is.na(amt_lead1_aligned),
    (amt_lead1_aligned - amt_lag1_aligned) / amt_lag1_aligned,
    NA_real_
  )]
  dt[, c("amt_lag1", "yr_lag1", "amt_lead1", "yr_lead1",
         "amt_lag1_aligned", "amt_lead1_aligned") := NULL]
  dt
}

hmda_bcy <- build_growth(hmda_bcy, "hmda_amt", "hmda_growth")
cra_bcy  <- build_growth(cra_bcy,  "cra_amt",  "cra_growth")

# ── 8. Assemble the panel ─────────────────────────────────────────────────────
# Start from the distinct bank-county-years in the incumbent branch panel
# (so the sample definition mirrors the deposit analysis exactly).

bcy_grid <- unique(bp[, .(CERT, county, YEAR)])

panel <- merge(bcy_grid, dep_bcy,                     by = c("CERT", "county", "YEAR"), all.x = TRUE)
panel <- merge(panel,    hmda_bcy[, .(CERT, county, YEAR, hmda_growth)],
               by = c("CERT", "county", "YEAR"), all.x = TRUE)
panel <- merge(panel,    cra_bcy[, .(CERT, county, YEAR, cra_growth)],
               by = c("CERT", "county", "YEAR"), all.x = TRUE)
panel <- merge(panel,    cy_controls,                 by = c("county", "YEAR"), all.x = TRUE)

# ── 9. Winsorize ──────────────────────────────────────────────────────────────

winsor_var <- function(dt, col) {
  vals <- dt[[col]]
  if (sum(!is.na(vals)) < 10L) return(invisible(NULL))
  dt[, (col) := Winsorize(vals, val = quantile(vals, probs = c(0.025, 0.975), na.rm = TRUE))]
}

winsor_var(panel, "dep_growth")
winsor_var(panel, "hmda_growth")
winsor_var(panel, "cra_growth")

# ── 10. Fixed-effects identifiers ────────────────────────────────────────────

panel[, bank_county_id := paste0(CERT, "_", county)]
panel[, state_yr       := paste0(substr(county, 1L, 2L), YEAR)]
panel[, bank_yr        := paste0(CERT, YEAR)]

# ── 11. Save ──────────────────────────────────────────────────────────────────

out_path <- file.path(data_path, paste0("lending_panel_", dat_suffix, ".rds"))
saveRDS(panel, out_path)
message("Saved: ", out_path)
message("Rows: ", nrow(panel))
message("Distinct bank-counties: ", uniqueN(panel[, .(CERT, county)]))
message("dep_growth  non-NA: ", sum(!is.na(panel$dep_growth)))
message("hmda_growth non-NA: ", sum(!is.na(panel$hmda_growth)))
message("cra_growth  non-NA: ", sum(!is.na(panel$cra_growth)))
