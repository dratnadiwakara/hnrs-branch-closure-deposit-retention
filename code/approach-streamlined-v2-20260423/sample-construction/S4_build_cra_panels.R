# S4_build_cra_panels.R
# V2 rebuild of county-year CRA small-business growth panels.
#
# Changes from v1 (code/approach-streamlined-20260423/sample-construction/B3_cra_county_panel_20260423.R):
#   V1 merged cra with inc_set BEFORE splitting into "unfiltered" and
#   "in-county" — so both panels silently carried the incumbent filter and
#   returned identical coefficients. V2 builds THREE explicit universes,
#   each with its own lag/lead growth computation:
#
#     cra_growth_all         all CRA respondents (CERT-mapped, no SOD filter)
#     cra_growth_branch      + has >= 1 SOD branch in county-YEAR
#     cra_growth_incumbent   + non-closer in county-YEAR (SOD inc_set)
#
# Output: data/constructed/cra_panels_v2_YYYYMMDD.rds
# Columns: county, YEAR, cra_growth_all, cra_growth_branch, cra_growth_incumbent.

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")
library(duckdb)

CLOSURE_PANEL <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
CRA_DB        <- "C:/empirical-data-construction/cra/cra.duckdb"

flow <- sample_flow_init("cra_v2")

# ---- 1. SOD branch presence + CERT<->RSSDID mapping + inc_set --------------
raw <- setDT(load_exact(CLOSURE_PANEL))
raw[, `:=`(
  county = str_pad(as.integer(STCNTYBR), 5, "left", "0"),
  YEAR   = as.integer(YEAR),
  CERT   = as.integer(CERT),
  RSSDID = suppressWarnings(as.numeric(RSSDID)),
  closed = as.integer(fifelse(is.na(closed), 0L, closed))
)]
branch_presence <- unique(raw[!is.na(CERT) & !is.na(county), .(CERT, county, YEAR)])
branch_presence[, has_branch := 1L]
cert_rssd <- raw[!is.na(RSSDID) & RSSDID != 0,
  .(RSSDID = as.integer(RSSDID[1])), by = .(CERT, YEAR)]

cty_closers <- unique(raw[closed == 1L, .(CERT, county, YEAR)])[, not_inc := TRUE]
raw_c <- merge(raw, cty_closers, by = c("CERT", "county", "YEAR"), all.x = TRUE)
raw_c[, inc := is.na(not_inc)]
inc_set <- unique(raw_c[inc == TRUE, .(CERT, county, YEAR)])
flow <- sample_flow_step(flow, "SOD branch presence rows", branch_presence,
                         unit_cols = c("CERT", "county", "YEAR"))

# ---- 2. CRA respondent x county x year aggregation -------------------------
con <- dbConnect(duckdb(), CRA_DB, read_only = TRUE)
cra <- setDT(dbGetQuery(con, "
  SELECT CAST(t.rssdid AS BIGINT) AS rssdid,
         d.county_fips            AS county,
         d.year                   AS YEAR,
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
  WHERE TRIM(d.table_id) = 'D1-1' AND TRIM(d.report_level) = '040'
    AND CAST(d.action_taken AS INTEGER) = 1 AND d.county_fips IS NOT NULL
  GROUP BY rssdid, d.county_fips, d.year"))
dbDisconnect(con)
cra <- cra[!is.na(rssdid) & rssdid != 0 & !is.na(county)]
cra <- cra[, .(cra_amt = sum(cra_amt)), by = .(rssdid, county, YEAR)]
cra <- merge(cra, cert_rssd, by.x = c("rssdid", "YEAR"),
             by.y = c("RSSDID", "YEAR"))
cra <- cra[!is.na(CERT), .(cra_amt = sum(cra_amt)),
           by = .(CERT, county, YEAR)]
flow <- sample_flow_step(flow, "CRA CERT x county x YEAR (all respondents)", cra,
                         unit_cols = c("CERT", "county", "YEAR"))

# ---- 3. Three universes ----------------------------------------------------
# UNIVERSE 1 — all respondents (NO SOD filter at all)
cra_all <- cra

# UNIVERSE 2 — respondents with >= 1 SOD branch in (county, YEAR)
cra_branch <- merge(cra, branch_presence,
                    by = c("CERT", "county", "YEAR"))  # inner join
cra_branch[, has_branch := NULL]

# UNIVERSE 3 — respondents that are SOD incumbents (did not close in county-YEAR)
cra_incumbent <- merge(cra, inc_set, by = c("CERT", "county", "YEAR"))

flow <- sample_flow_step(flow, "cra_all  rows", cra_all,
                         unit_cols = c("CERT", "county", "YEAR"))
flow <- sample_flow_step(flow, "cra_branch rows", cra_branch,
                         unit_cols = c("CERT", "county", "YEAR"))
flow <- sample_flow_step(flow, "cra_incumbent rows", cra_incumbent,
                         unit_cols = c("CERT", "county", "YEAR"))

# ---- 4. Independent 2-year growth per universe ------------------------------
compute_growth <- function(dt, label) {
  setorder(dt, CERT, county, YEAR)
  dt[, lag1  := shift(cra_amt, 1L, type = "lag"),  by = .(CERT, county)]
  dt[, yr_l1 := shift(YEAR,    1L, type = "lag"),  by = .(CERT, county)]
  dt[, lead1 := shift(cra_amt, 1L, type = "lead"), by = .(CERT, county)]
  dt[, yr_f1 := shift(YEAR,    1L, type = "lead"), by = .(CERT, county)]
  dt[, lag1  := fifelse(yr_l1 == YEAR - 1, lag1,  NA_real_)]
  dt[, lead1 := fifelse(yr_f1 == YEAR + 1, lead1, NA_real_)]
  dt <- dt[!is.na(lag1) & lag1 > 0 & !is.na(lead1)]
  cy <- dt[, .(c_lag1 = sum(lag1), c_lead1 = sum(lead1)),
           by = .(county, YEAR)]
  cy[, g := (c_lead1 - c_lag1) / c_lag1]
  cy[!is.na(g), g := wins(g)]
  setnames(cy, "g", paste0("cra_growth_", label))
  cy[, .SD, .SDcols = c("county", "YEAR", paste0("cra_growth_", label))]
}

g_all       <- compute_growth(copy(cra_all),       "all")
g_branch    <- compute_growth(copy(cra_branch),    "branch")
g_incumbent <- compute_growth(copy(cra_incumbent), "incumbent")

# ---- 5. Merge county x year panel ------------------------------------------
out <- Reduce(function(x, y) merge(x, y, by = c("county", "YEAR"), all = TRUE),
              list(g_all, g_branch, g_incumbent))
flow <- sample_flow_step(flow, "final county x YEAR panel", out,
                         unit_cols = c("county", "YEAR"))

# ---- 6. Save ---------------------------------------------------------------
out_path <- file.path("data/constructed", paste0("cra_panels_v2_", DATE_TAG, ".rds"))
saveRDS(out, out_path)
cat("\nSaved:", out_path, " | nrow =", nrow(out), "\n")
cat("sha256:", digest::digest(out_path, algo = "sha256", file = TRUE), "\n")
cat("\nN non-NA per growth:\n")
cat("  cra_growth_all:       ", sum(!is.na(out$cra_growth_all)),       "\n")
cat("  cra_growth_branch:    ", sum(!is.na(out$cra_growth_branch)),    "\n")
cat("  cra_growth_incumbent: ", sum(!is.na(out$cra_growth_incumbent)), "\n")

sample_flow_save(flow)
