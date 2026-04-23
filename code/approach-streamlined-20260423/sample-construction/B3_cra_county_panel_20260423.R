# B3_cra_county_panel_20260423.R
# Build county-year CRA growth panels at two filter levels:
#   (U) unfiltered — all CRA respondents (snapshot §6)
#   (F) filtered   — only banks with >=1 branch in county that year (Phil #2)
#
# Produces a county-year data frame with both outcomes; T3 regressions filter
# to the incumbent-bank (cty_pan-matched) subset.

rm(list = ls())
source("code/approach-streamlined-20260423/00_common.R")

library(duckdb)

CLOSURE_PANEL <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
CRA_DB        <- "C:/empirical-data-construction/cra/cra.duckdb"

# ── 1. Branch presence + CERT↔RSSDID ───────────────────────────────────────
raw <- setDT(readRDS(CLOSURE_PANEL))
raw[, county := str_pad(as.integer(STCNTYBR), 5, "left", "0")]
raw[, YEAR   := as.integer(YEAR)]
raw[, CERT   := as.integer(CERT)]
raw[, RSSDID := suppressWarnings(as.numeric(RSSDID))]
raw[, closed := as.integer(fifelse(is.na(closed), 0L, closed))]

branch_presence <- unique(raw[!is.na(CERT) & !is.na(county), .(CERT, county, YEAR)])
branch_presence[, has_branch := 1L]

cert_rssd <- raw[!is.na(RSSDID) & RSSDID != 0,
  .(RSSDID = as.integer(RSSDID[1])), by = .(CERT, YEAR)]

# County-level incumbent set (no closures in county,YEAR) — matches main_regressions §3
cty_closers <- unique(raw[closed == 1, .(CERT, county, YEAR)])[, not_inc := TRUE]
raw_c <- merge(raw, cty_closers, by = c("CERT", "county", "YEAR"), all.x = TRUE)
raw_c[, inc := is.na(not_inc)]
inc_set <- unique(raw_c[inc == TRUE, .(CERT, county, YEAR)])

# ── 2. CRA respondent × county × year aggregation ──────────────────────────
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
cra <- cra[!is.na(CERT), .(cra_amt = sum(cra_amt)), by = .(CERT, county, YEAR)]

# Merge incumbent flag (inc_set) to restrict to banks that did not close in county-YEAR
cra_inc <- merge(cra, inc_set, by = c("CERT", "county", "YEAR"))

# Flag in-county branch (F variant)
cra_inc <- merge(cra_inc, branch_presence,
                 by = c("CERT", "county", "YEAR"), all.x = TRUE)
cra_inc[is.na(has_branch), has_branch := 0L]

# ── 3. Two parallel growth panels ──────────────────────────────────────────
compute_growth <- function(dt) {
  setorder(dt, CERT, county, YEAR)
  dt[, lag1  := shift(cra_amt, 1L, type = "lag"),  by = .(CERT, county)]
  dt[, yr_l1 := shift(YEAR,    1L, type = "lag"),  by = .(CERT, county)]
  dt[, lead1 := shift(cra_amt, 1L, type = "lead"), by = .(CERT, county)]
  dt[, yr_f1 := shift(YEAR,    1L, type = "lead"), by = .(CERT, county)]
  dt[, lag1  := fifelse(yr_l1 == YEAR - 1, lag1,  NA_real_)]
  dt[, lead1 := fifelse(yr_f1 == YEAR + 1, lead1, NA_real_)]
  dt <- dt[!is.na(lag1) & lag1 > 0 & !is.na(lead1)]
  dt[, .(c_lag1 = sum(lag1), c_lead1 = sum(lead1)), by = .(county, YEAR)][
    , cra_growth := (c_lead1 - c_lag1) / c_lag1][
    !is.na(cra_growth), cra_growth := wins(cra_growth)][
    , .(county, YEAR, cra_growth)]
}

cra_U <- compute_growth(copy(cra_inc))               # unfiltered
cra_F <- compute_growth(cra_inc[has_branch == 1L])   # filtered to in-county
setnames(cra_U, "cra_growth", "cra_growth_all")
setnames(cra_F, "cra_growth", "cra_growth_incty")

out <- merge(cra_U, cra_F, by = c("county", "YEAR"), all = TRUE)

out_path <- file.path("data/constructed",
                      paste0("cra_county_panels_", format(Sys.time(), "%Y%m%d"), ".rds"))
saveRDS(out, out_path)
cat("Saved:", out_path, "\n")
cat("N all    =", sum(!is.na(out$cra_growth_all)),   "\n")
cat("N incty  =", sum(!is.na(out$cra_growth_incty)), "\n")

append_note("B3 — CRA county-year panels",
  c("Built both unfiltered and in-county-branch-filtered CRA growth at county-year.",
    paste0("Saved: `", out_path, "`."),
    paste0("N(unfiltered): ", sum(!is.na(out$cra_growth_all)),
           " | N(in-county): ", sum(!is.na(out$cra_growth_incty)))))
