# ============================================================
# 09_anchored_regressions.R
#
# Progression anchored to NRS (2026) Table 14 (established result),
# then incrementally extending with deposit-weighted treatment and
# county-level lending outcomes.
#
# Table 1  — NRS (2026) Table 14 replication (partial)
#   LHS : Δ incumbent deposits (zip, t → t+1) / total zip deposits (t-1)
#   RHS : fraction_of_branches_closed
#   Unit: zip-year | FE: zip + county×year | SE: clustered at zip
#   Incumbent: bank with NO closes in (zip, YEAR)
#   Periods: 2000-07, 2008-11, 2012-19, 2020-24
#
# Table 2  — Deposit-weighted treatment, zip-year
#   LHS : same as Table 1
#   RHS : share_deps_closed = Σ closed_dep_{t-1} / total_zip_dep_{t-1}
#   Same FE/SE/periods as Table 1
#
# Table 3  — Deposit-weighted treatment, county-year deposits
#   LHS : (inc_county_deps_{t+1} − inc_county_deps_{t-1}) / inc_county_deps_{t-1}
#   RHS : share_deps_closed (county-level)
#   Unit: county-year | FE: county + state×year | SE: clustered at county
#   Incumbent: bank with NO closes in (county, YEAR)  [no-open filter not applied]
#   Periods: pre-2012, 2012-19, 2020-24
#
# Table 4  — HMDA purchase mortgage growth, county-year
#   LHS : (inc_purch_hmda_{t+1} − inc_purch_hmda_{t-1}) / inc_purch_hmda_{t-1}
#   RHS : share_deps_closed (county-level)
#   Same FE/SE/periods as Table 3
#   Restricted to: action_taken = '1' AND loan_purpose = '1'
#
# Table 5  — CRA small-business lending growth, county-year
#   LHS : (inc_cra_{t+1} − inc_cra_{t-1}) / inc_cra_{t-1}
#   RHS : share_deps_closed (county-level)
#   Same FE/SE/periods as Table 3
# ============================================================

rm(list = ls())
library(data.table)
library(fixest)
library(duckdb)
library(stringr)
library(readxl)

# ── paths ─────────────────────────────────────────────────────────────────────
CLOSURE_PANEL  <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
HMDA_DB        <- "C:/empirical-data-construction/hmda/hmda.duckdb"
CRA_DB         <- "C:/empirical-data-construction/cra/cra.duckdb"
COUNTY_CTRL    <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/county_controls_panel.rds"
ZIP_DEMO       <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/zip_demographics_panel.rds"
TRACT_ZIP_XW   <- "C:/Users/dimut/OneDrive/github/hnrs-branch-closure-deposit-retention/data/raw/tract_zip_122019.xlsx"

# ── helpers ───────────────────────────────────────────────────────────────────
wins <- function(x, lo = 0.025, hi = 0.975) {
  q <- quantile(x, c(lo, hi), na.rm = TRUE)
  pmin(pmax(x, q[1]), q[2])
}
sum_na_safe <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  as.numeric(sum(x, na.rm = TRUE))
}

# ── 1. load & prep closure panel ──────────────────────────────────────────────
cat("Loading closure panel...\n")
raw <- setDT(readRDS(CLOSURE_PANEL))
raw[, county   := formatC(as.integer(STCNTYBR), width = 5, flag = "0")]
raw[, zip      := formatC(as.integer(ZIPBR),    width = 5, flag = "0")]
raw[, YEAR     := as.integer(YEAR)]
raw[, closed   := as.integer(fifelse(is.na(closed), 0, closed))]
raw[, DEPSUMBR := as.numeric(DEPSUMBR)]
raw[, RSSDID   := suppressWarnings(as.numeric(RSSDID))]
cat(sprintf("  rows: %s | branches: %s\n",
    format(nrow(raw), big.mark=","), format(uniqueN(raw$UNINUMBR), big.mark=",")))

# ── 2. branch-level lag/lead deposits ─────────────────────────────────────────
setorder(raw, UNINUMBR, YEAR)
raw[, dep_lag1  := shift(DEPSUMBR, n=1L, type="lag"),  by = UNINUMBR]
raw[, yr_lag1   := shift(YEAR,     n=1L, type="lag"),  by = UNINUMBR]
raw[, dep_lead1 := shift(DEPSUMBR, n=1L, type="lead"), by = UNINUMBR]
raw[, yr_lead1  := shift(YEAR,     n=1L, type="lead"), by = UNINUMBR]
raw[, dep_lag1_a  := fifelse(yr_lag1  == YEAR - 1, dep_lag1,  NA_real_)]
raw[, dep_lead1_a := fifelse(yr_lead1 == YEAR + 1, dep_lead1, NA_real_)]

# CERT→RSSDID crosswalk (for HMDA/CRA matching)
cert_rssd <- raw[!is.na(RSSDID) & RSSDID != 0,
  .(RSSDID = as.integer(RSSDID[1])), by = .(CERT, YEAR)]

# ── 3. zip-year panel (Tables 1 & 2) ──────────────────────────────────────────
# Incumbent definition: bank with NO closes in this (zip, YEAR)
# Outcome window: 1-year (t → t+1), denominator = total zip deposits at t-1
cat("Building zip-year panel...\n")

bank_zip <- raw[, .(
  n_closes = sum(closed, na.rm = TRUE)
), by = .(CERT, zip, YEAR)]
bank_zip[, is_inc := as.integer(n_closes == 0)]

raw_z <- merge(raw, bank_zip[, .(CERT, zip, YEAR, is_inc, n_closes)],
               by = c("CERT","zip","YEAR"), all.x = TRUE)
raw_z[is.na(is_inc), is_inc := 0L]

# zip totals at t-1 (all branches — denominator)
zt <- raw_z[!is.na(dep_lag1_a) & dep_lag1_a > 0, .(
  total_deps    = sum(dep_lag1_a),
  branches_lag1 = uniqueN(UNINUMBR),
  n_banks       = uniqueN(CERT)
), by = .(zip, YEAR)]

# zip event counts at t
z_events <- raw_z[, .(
  n_closed_zip = sum(closed, na.rm = TRUE)
), by = .(zip, YEAR)]

# closed branch deposits at t-1 (deposit-weighted treatment numerator)
zc <- raw_z[closed == 1 & !is.na(dep_lag1_a) & dep_lag1_a > 0,
  .(closed_deps = sum(dep_lag1_a)), by = .(zip, YEAR)]

# incumbent deposits: t (DEPSUMBR) and t+1 (dep_lead1_a)
zi_curr <- raw_z[is_inc == 1L & !is.na(DEPSUMBR) & DEPSUMBR > 0, .(
  inc_curr    = sum(as.numeric(DEPSUMBR)),
  n_inc_banks = uniqueN(CERT)
), by = .(zip, YEAR)]

zi_tp1 <- raw_z[is_inc == 1L & !is.na(dep_lead1_a), .(
  inc_tp1 = sum(dep_lead1_a)
), by = .(zip, YEAR)]

zip_pan <- Reduce(function(x, y) merge(x, y, by = c("zip","YEAR"), all.x = TRUE),
  list(zt, z_events, zc, zi_curr, zi_tp1))
zip_pan[is.na(closed_deps),  closed_deps  := 0]
zip_pan[is.na(n_closed_zip), n_closed_zip := 0L]

# treatments
zip_pan[, fraction_of_branches_closed := n_closed_zip / pmax(branches_lag1, 1)]
zip_pan[, share_deps_closed           := closed_deps  / pmax(total_deps, 1)]

# controls
zip_pan[, log_n_branches  := log1p(branches_lag1)]
zip_pan[, log_n_inc_banks := log1p(n_inc_banks)]

# outcome: (inc_t+1 - inc_t) / total_zip_deps_t-1
zip_pan[, outcome := fifelse(total_deps > 0, (inc_tp1 - inc_curr) / total_deps, NA_real_)]

# county FE identifier
zip_map <- unique(raw[, .(zip, county)])[!duplicated(zip)]
zip_pan <- merge(zip_pan, zip_map, by = "zip", all.x = TRUE)
zip_pan[, county_yr := paste0(county, "_", YEAR)]

zip_pan[!is.na(outcome), outcome := wins(outcome)]
zip_pan <- zip_pan[YEAR %between% c(2000,2024) &
                   !is.na(n_inc_banks) & n_inc_banks >= 2 & branches_lag1 >= 2 &
                   !is.na(outcome) & !is.na(county)]

# demographics filter (matches reference sample restriction)
zip_demo <- setDT(readRDS(ZIP_DEMO))
zip_demo <- zip_demo[!is.na(zip), .(
  zip  = formatC(as.integer(zip), width = 5, flag = "0"),
  YEAR = as.integer(yr),
  sophisticated
)]
zip_pan <- merge(zip_pan, zip_demo, by = c("zip","YEAR"), all.x = TRUE)
zip_pan <- zip_pan[!is.na(sophisticated)]
cat(sprintf("  rows: %s | zips: %s\n",
    format(nrow(zip_pan), big.mark=","), uniqueN(zip_pan$zip)))

# ── 4. county-year panel (Tables 3–5) ─────────────────────────────────────────
# Incumbent definition: bank with NO closes in (county, YEAR)
# Outcome window: 2-year (t-1 → t+1), denominator = incumbent own t-1 deposits
cat("Building county-year panel...\n")

cty_closers <- unique(raw[closed == 1, .(CERT, county, YEAR)])[, not_inc := TRUE]
raw_c <- merge(raw, cty_closers, by = c("CERT","county","YEAR"), all.x = TRUE)
raw_c[, inc := is.na(not_inc)]

ct <- raw_c[!is.na(dep_lag1_a) & dep_lag1_a > 0, .(
  total_deps = sum(dep_lag1_a),
  n_branches = uniqueN(UNINUMBR),
  n_banks    = uniqueN(CERT)
), by = .(county, YEAR)]

cc_dep <- raw_c[closed == 1 & !is.na(dep_lag1_a) & dep_lag1_a > 0,
  .(closed_deps = sum(dep_lag1_a)), by = .(county, YEAR)]

ci <- raw_c[inc == TRUE & !is.na(dep_lag1_a) & dep_lag1_a > 0 & !is.na(dep_lead1_a), .(
  inc_tm1 = sum(dep_lag1_a),
  inc_tp1 = sum(dep_lead1_a)
), by = .(county, YEAR)]

cty_pan <- merge(ct, cc_dep, by = c("county","YEAR"), all.x = TRUE)
cty_pan <- merge(cty_pan, ci, by = c("county","YEAR"), all.x = TRUE)
cty_pan[is.na(closed_deps), closed_deps := 0]

cty_pan[, share_deps_closed := closed_deps / pmax(total_deps, 1)]
cty_pan[, log_n_branches    := log1p(n_branches)]
cty_pan[, log_n_banks       := log1p(n_banks)]
cty_pan[, dep_outcome       := fifelse(inc_tm1 > 0, (inc_tp1 - inc_tm1) / inc_tm1, NA_real_)]
cty_pan[, state_yr          := paste0(substr(county, 1, 2), "_", YEAR)]

cty_pan[!is.na(dep_outcome), dep_outcome := wins(dep_outcome)]
cty_pan <- cty_pan[YEAR %between% c(2000,2024) & n_banks >= 2 & n_branches >= 2 &
                   !is.na(dep_outcome) & !is.na(county)]

# incumbent set for HMDA/CRA filtering
inc_set <- unique(raw_c[inc == TRUE, .(CERT, county, YEAR)])
cat(sprintf("  rows: %s | counties: %s\n",
    format(nrow(cty_pan), big.mark=","), uniqueN(cty_pan$county)))

# ── 5. HMDA purchase mortgages — incumbent banks, county-year ──────────────────
cat("Querying HMDA (purchase originations only)...\n")
con <- dbConnect(duckdb(), HMDA_DB, read_only = TRUE)
hmda_purch_raw <- rbind(
  dbGetQuery(con, "
    SELECT CAST(a.rssd_id AS BIGINT)   AS rssdid,
           LEFT(l.census_tract, 5)     AS county,
           l.year                      AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM lar_panel l
    JOIN avery_crosswalk a
      ON  l.respondent_id = a.respondent_id
      AND CAST(l.agency_code AS INTEGER) = CAST(a.agency_code AS INTEGER)
      AND l.year = a.activity_year
    WHERE l.action_taken = '1' AND l.loan_purpose = '1'
      AND l.year < 2018 AND LENGTH(l.census_tract) >= 5
    GROUP BY rssdid, county, l.year"),
  dbGetQuery(con, "
    SELECT CAST(a.rssd_id AS BIGINT)   AS rssdid,
           LEFT(l.census_tract, 5)     AS county,
           l.year                      AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM lar_panel l
    JOIN avery_crosswalk a ON l.lei = a.lei AND l.year = a.activity_year
    WHERE l.action_taken = '1' AND l.loan_purpose = '1'
      AND l.year >= 2018 AND LENGTH(l.census_tract) >= 5
    GROUP BY rssdid, county, l.year")
)
dbDisconnect(con)

setDT(hmda_purch_raw)
hmda_purch_raw <- hmda_purch_raw[!is.na(rssdid) & rssdid != 0 & nchar(county) == 5]
hmda_purch_raw <- hmda_purch_raw[, .(hmda_amt = sum(hmda_amt)), by = .(rssdid, county, YEAR)]
hmda_purch_raw <- merge(hmda_purch_raw, cert_rssd, by.x = c("rssdid","YEAR"), by.y = c("RSSDID","YEAR"))
hmda_purch_raw <- hmda_purch_raw[!is.na(CERT), .(hmda_amt = sum(hmda_amt)), by = .(CERT, county, YEAR)]
hmda_inc <- merge(hmda_purch_raw, inc_set, by = c("CERT","county","YEAR"))

setorder(hmda_inc, CERT, county, YEAR)
hmda_inc[, lag1  := shift(hmda_amt, n=1L, type="lag"),  by = .(CERT, county)]
hmda_inc[, yr_l1 := shift(YEAR,     n=1L, type="lag"),  by = .(CERT, county)]
hmda_inc[, lead1 := shift(hmda_amt, n=1L, type="lead"), by = .(CERT, county)]
hmda_inc[, yr_f1 := shift(YEAR,     n=1L, type="lead"), by = .(CERT, county)]
hmda_inc[, lag1  := fifelse(yr_l1 == YEAR - 1, lag1,  NA_real_)]
hmda_inc[, lead1 := fifelse(yr_f1 == YEAR + 1, lead1, NA_real_)]
hmda_inc <- hmda_inc[!is.na(lag1) & lag1 > 0 & !is.na(lead1)]

hmda_cy <- hmda_inc[, .(h_lag1 = sum(lag1), h_lead1 = sum(lead1)), by = .(county, YEAR)]
hmda_cy[, hmda_purch_growth := (h_lead1 - h_lag1) / h_lag1]
cat(sprintf("  county-year rows: %s\n", format(nrow(hmda_cy), big.mark=",")))

# ── 5b. HMDA purchase mortgages — incumbent banks, ZIP-year (tract crosswalk) ──
cat("Loading tract-zip crosswalk...\n")
xwalk <- setDT(read_excel(TRACT_ZIP_XW))
xwalk[, ZIP   := formatC(as.integer(ZIP),   width = 5, flag = "0")]
xwalk[, TRACT := as.character(TRACT)]
cat(sprintf("  crosswalk: %s rows | %s tracts | %s zips\n",
    format(nrow(xwalk), big.mark=","), uniqueN(xwalk$TRACT), uniqueN(xwalk$ZIP)))

cat("Querying HMDA at tract level (purchase originations)...\n")
con <- dbConnect(duckdb(), HMDA_DB, read_only = TRUE)
hmda_tract_raw <- rbind(
  dbGetQuery(con, "
    SELECT CAST(a.rssd_id AS BIGINT)   AS rssdid,
           l.census_tract              AS tract,
           l.year                      AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM lar_panel l
    JOIN avery_crosswalk a
      ON  l.respondent_id = a.respondent_id
      AND CAST(l.agency_code AS INTEGER) = CAST(a.agency_code AS INTEGER)
      AND l.year = a.activity_year
    WHERE l.action_taken = '1' AND l.loan_purpose = '1'
      AND l.year < 2018 AND LENGTH(l.census_tract) = 11
    GROUP BY rssdid, l.census_tract, l.year"),
  dbGetQuery(con, "
    SELECT CAST(a.rssd_id AS BIGINT)   AS rssdid,
           l.census_tract              AS tract,
           l.year                      AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM lar_panel l
    JOIN avery_crosswalk a ON l.lei = a.lei AND l.year = a.activity_year
    WHERE l.action_taken = '1' AND l.loan_purpose = '1'
      AND l.year >= 2018 AND LENGTH(l.census_tract) = 11
    GROUP BY rssdid, l.census_tract, l.year")
)
dbDisconnect(con)

setDT(hmda_tract_raw)
hmda_tract_raw <- hmda_tract_raw[!is.na(rssdid) & rssdid != 0 & !is.na(tract)]
hmda_tract_raw <- hmda_tract_raw[, .(hmda_amt = sum(hmda_amt)), by = .(rssdid, tract, YEAR)]
cat(sprintf("  tract-bank-year rows: %s\n", format(nrow(hmda_tract_raw), big.mark=",")))

# apportion tract → zip using RES_RATIO
hmda_zip_raw <- merge(hmda_tract_raw,
                      xwalk[, .(tract = TRACT, ZIP, RES_RATIO)],
                      by = "tract", allow.cartesian = TRUE)
hmda_zip_raw[, hmda_amt_zip := hmda_amt * RES_RATIO]
hmda_zip_raw <- hmda_zip_raw[, .(hmda_amt = sum(hmda_amt_zip, na.rm = TRUE)),
                               by = .(rssdid, zip = ZIP, YEAR)]

# RSSDID → CERT
hmda_zip_raw <- merge(hmda_zip_raw, cert_rssd, by.x = c("rssdid","YEAR"), by.y = c("RSSDID","YEAR"))
hmda_zip_raw <- hmda_zip_raw[!is.na(CERT), .(hmda_amt = sum(hmda_amt)), by = .(CERT, zip, YEAR)]

# filter to zip-level incumbents (no closes in zip-year)
zip_inc_set <- bank_zip[is_inc == 1L, .(CERT, zip, YEAR)]
hmda_zip_inc <- merge(hmda_zip_raw, zip_inc_set, by = c("CERT","zip","YEAR"))

# 2-year growth: (t+1 - t-1) / t-1
setorder(hmda_zip_inc, CERT, zip, YEAR)
hmda_zip_inc[, lag1  := shift(hmda_amt, n=1L, type="lag"),  by = .(CERT, zip)]
hmda_zip_inc[, yr_l1 := shift(YEAR,     n=1L, type="lag"),  by = .(CERT, zip)]
hmda_zip_inc[, lead1 := shift(hmda_amt, n=1L, type="lead"), by = .(CERT, zip)]
hmda_zip_inc[, yr_f1 := shift(YEAR,     n=1L, type="lead"), by = .(CERT, zip)]
hmda_zip_inc[, lag1  := fifelse(yr_l1 == YEAR - 1, lag1,  NA_real_)]
hmda_zip_inc[, lead1 := fifelse(yr_f1 == YEAR + 1, lead1, NA_real_)]
hmda_zip_inc <- hmda_zip_inc[!is.na(lag1) & lag1 > 0 & !is.na(lead1)]

hmda_zip_cy <- hmda_zip_inc[, .(h_lag1 = sum(lag1), h_lead1 = sum(lead1)), by = .(zip, YEAR)]
hmda_zip_cy[, hmda_purch_growth_zip := (h_lead1 - h_lag1) / h_lag1]
cat(sprintf("  zip-year rows: %s\n", format(nrow(hmda_zip_cy), big.mark=",")))

# ── 6. CRA small-business lending — incumbent banks, county-year ───────────────
cat("Querying CRA...\n")
con <- dbConnect(duckdb(), CRA_DB, read_only = TRUE)
cra <- setDT(dbGetQuery(con, "
  SELECT CAST(t.rssdid AS BIGINT)  AS rssdid,
         d.county_fips             AS county,
         d.year                    AS YEAR,
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
cra <- merge(cra, cert_rssd, by.x = c("rssdid","YEAR"), by.y = c("RSSDID","YEAR"))
cra <- cra[!is.na(CERT), .(cra_amt = sum(cra_amt)), by = .(CERT, county, YEAR)]
cra_inc <- merge(cra, inc_set, by = c("CERT","county","YEAR"))

setorder(cra_inc, CERT, county, YEAR)
cra_inc[, lag1  := shift(cra_amt, n=1L, type="lag"),  by = .(CERT, county)]
cra_inc[, yr_l1 := shift(YEAR,    n=1L, type="lag"),  by = .(CERT, county)]
cra_inc[, lead1 := shift(cra_amt, n=1L, type="lead"), by = .(CERT, county)]
cra_inc[, yr_f1 := shift(YEAR,    n=1L, type="lead"), by = .(CERT, county)]
cra_inc[, lag1  := fifelse(yr_l1 == YEAR - 1, lag1,  NA_real_)]
cra_inc[, lead1 := fifelse(yr_f1 == YEAR + 1, lead1, NA_real_)]
cra_inc <- cra_inc[!is.na(lag1) & lag1 > 0 & !is.na(lead1)]

cra_cy <- cra_inc[, .(c_lag1 = sum(lag1), c_lead1 = sum(lead1)), by = .(county, YEAR)]
cra_cy[, cra_growth := (c_lead1 - c_lag1) / c_lag1]
cat(sprintf("  county-year rows: %s\n", format(nrow(cra_cy), big.mark=",")))

# ── 7. merge lending into county panel ────────────────────────────────────────
cty_pan <- merge(cty_pan, hmda_cy[, .(county, YEAR, hmda_purch_growth)],
                 by = c("county","YEAR"), all.x = TRUE)
cty_pan <- merge(cty_pan, cra_cy[,  .(county, YEAR, cra_growth)],
                 by = c("county","YEAR"), all.x = TRUE)
cty_pan[!is.na(hmda_purch_growth), hmda_purch_growth := wins(hmda_purch_growth)]
cty_pan[!is.na(cra_growth),        cra_growth        := wins(cra_growth)]

# ── 8. county economic controls ───────────────────────────────────────────────
cat("Loading county controls...\n")
cc <- setDT(readRDS(COUNTY_CTRL))
if (!"county" %in% names(cc) && "county_code" %in% names(cc)) setnames(cc, "county_code", "county")
if (!"YEAR"   %in% names(cc) && "year"        %in% names(cc)) setnames(cc, "year", "YEAR")
cc[, county := formatC(as.integer(county), width = 5, flag = "0")]
cc[, YEAR   := as.integer(YEAR)]

ctrl_vars <- c("log_population_density","lag_county_deposit_hhi",
               "lag_establishment_gr","lag_payroll_gr",
               "lag_hmda_mtg_amt_gr","lag_cra_loan_amount_amt_lt_1m_gr","lmi")
ctrl_vars <- ctrl_vars[ctrl_vars %in% names(cc)]

# county dep growth trend (t-4 to t-1)
cty_deps_yr <- raw[!is.na(DEPSUMBR) & DEPSUMBR > 0,
  .(total_dep_county = sum(as.numeric(DEPSUMBR))), by = .(county, YEAR)]
setorder(cty_deps_yr, county, YEAR)
cty_deps_yr[, dep_lag4 := shift(total_dep_county, n=4L, type="lag"), by = county]
cty_deps_yr[, yr_lag4  := shift(YEAR,             n=4L, type="lag"), by = county]
cty_deps_yr[, county_dep_growth_t4_t1 := fifelse(
  yr_lag4 == YEAR - 4 & dep_lag4 > 0,
  (total_dep_county - dep_lag4) / dep_lag4, NA_real_
)]

cc_sel <- unique(cc[, c("county","YEAR", ctrl_vars), with = FALSE], by = c("county","YEAR"))
cty_pan <- merge(cty_pan, cty_deps_yr[, .(county, YEAR, county_dep_growth_t4_t1)],
                 by = c("county","YEAR"), all.x = TRUE)
cty_pan <- merge(cty_pan, cc_sel, by = c("county","YEAR"), all.x = TRUE)
cty_pan[, log1p_total_deps := log1p(total_deps)]

cat(sprintf("  county panel: %s rows\n", format(nrow(cty_pan), big.mark=",")))

# merge zip-level HMDA into zip panel
zip_pan <- merge(zip_pan,
                 hmda_zip_cy[, .(zip, YEAR, hmda_purch_growth_zip)],
                 by = c("zip","YEAR"), all.x = TRUE)
zip_pan[!is.na(hmda_purch_growth_zip),
        hmda_purch_growth_zip := wins(hmda_purch_growth_zip)]

# ── 9. regression formulas ────────────────────────────────────────────────────

# Table 1 & 2: zip controls match NRS (2026) Table 14
ctrl_zip <- ~ log_n_branches + log_n_inc_banks

# Tables 3–5: county controls (full suite)
ctrl_cty <- ~ log_n_branches + log_n_banks + log1p_total_deps + county_dep_growth_t4_t1 +
              log_population_density + lag_county_deposit_hhi + lag_establishment_gr +
              lag_payroll_gr + lag_hmda_mtg_amt_gr + lag_cra_loan_amount_amt_lt_1m_gr + lmi

# period subsets
zip_00_07 <- zip_pan[YEAR %between% c(2000,2007)]
zip_08_11 <- zip_pan[YEAR %between% c(2008,2011)]
zip_12_19 <- zip_pan[YEAR %between% c(2012,2019)]
zip_20_24 <- zip_pan[YEAR >= 2020]

cty_pre  <- cty_pan[YEAR <  2012]
cty_mid  <- cty_pan[YEAR %between% c(2012,2019)]
cty_post <- cty_pan[YEAR >= 2020]

# ── TABLE 1: NRS (2026) Table 14 replication ──────────────────────────────────
cat("\n", strrep("=",70), "\n")
cat("TABLE 1 — NRS (2026) Table 14 replication (count-based treatment)\n")
cat("LHS : (inc_deps_{t+1} - inc_deps_t) / total_zip_deps_{t-1}   [1-yr window]\n")
cat("RHS : fraction_of_branches_closed\n")
cat("FE  : zip + county×year | SE: clustered at zip\n")
cat("Note: incumbent = bank with NO closes in (zip, YEAR)\n")
cat(strrep("=",70), "\n\n")

m1 <- list(
  feols(outcome ~ fraction_of_branches_closed + .[ctrl_zip] | zip + county_yr, zip_00_07, vcov = ~zip),
  feols(outcome ~ fraction_of_branches_closed + .[ctrl_zip] | zip + county_yr, zip_08_11, vcov = ~zip),
  feols(outcome ~ fraction_of_branches_closed + .[ctrl_zip] | zip + county_yr, zip_12_19, vcov = ~zip),
  feols(outcome ~ fraction_of_branches_closed + .[ctrl_zip] | zip + county_yr, zip_20_24, vcov = ~zip)
)
etable(m1, headers = c("2000-07","2008-11","2012-19","2020-24"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)

# ── TABLE 2: deposit-weighted treatment, zip-year ─────────────────────────────
cat("\n", strrep("=",70), "\n")
cat("TABLE 2 — Deposit-weighted treatment, zip-year\n")
cat("LHS : same as Table 1\n")
cat("RHS : share_deps_closed = sum(closed_dep_{t-1}) / total_zip_dep_{t-1}\n")
cat("FE  : zip + county×year | SE: clustered at zip\n")
cat(strrep("=",70), "\n\n")

m2 <- list(
  feols(outcome ~ share_deps_closed + .[ctrl_zip] | zip + county_yr, zip_00_07, vcov = ~zip),
  feols(outcome ~ share_deps_closed + .[ctrl_zip] | zip + county_yr, zip_08_11, vcov = ~zip),
  feols(outcome ~ share_deps_closed + .[ctrl_zip] | zip + county_yr, zip_12_19, vcov = ~zip),
  feols(outcome ~ share_deps_closed + .[ctrl_zip] | zip + county_yr, zip_20_24, vcov = ~zip)
)
etable(m2, headers = c("2000-07","2008-11","2012-19","2020-24"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)

# ── TABLE 3: deposit-weighted treatment, county-year deposits ─────────────────
cat("\n", strrep("=",70), "\n")
cat("TABLE 3 — Deposit-weighted treatment, county-year deposits\n")
cat("LHS : (inc_county_deps_{t+1} - inc_county_deps_{t-1}) / inc_county_deps_{t-1}  [2-yr]\n")
cat("RHS : share_deps_closed (county-level)\n")
cat("FE  : county + state×year | SE: clustered at county\n")
cat("Note: incumbent = bank with NO closes in (county, YEAR)\n")
cat(strrep("=",70), "\n\n")

m3 <- list(
  feols(dep_outcome ~ share_deps_closed + .[ctrl_cty] | county + state_yr, cty_pre,  vcov = ~county),
  feols(dep_outcome ~ share_deps_closed + .[ctrl_cty] | county + state_yr, cty_mid,  vcov = ~county),
  feols(dep_outcome ~ share_deps_closed + .[ctrl_cty] | county + state_yr, cty_post, vcov = ~county)
)
etable(m3, headers = c("pre-2012","2012-2019","2020-2024"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)

# ── TABLE 4: HMDA purchase mortgage growth, county-year ───────────────────────
cat("\n", strrep("=",70), "\n")
cat("TABLE 4 — HMDA purchase mortgage growth, county-year\n")
cat("LHS : (inc_purch_hmda_{t+1} - inc_purch_hmda_{t-1}) / inc_purch_hmda_{t-1}  [2-yr]\n")
cat("RHS : share_deps_closed (county-level)\n")
cat("FE  : county + state×year | SE: clustered at county\n")
cat("Note: HMDA filtered to action_taken='1' (originated) AND loan_purpose='1' (purchase)\n")
cat(strrep("=",70), "\n\n")

m4 <- list(
  feols(hmda_purch_growth ~ share_deps_closed + .[ctrl_cty] | county + state_yr, cty_pre,  vcov = ~county),
  feols(hmda_purch_growth ~ share_deps_closed + .[ctrl_cty] | county + state_yr, cty_mid,  vcov = ~county),
  feols(hmda_purch_growth ~ share_deps_closed + .[ctrl_cty] | county + state_yr, cty_post, vcov = ~county)
)
etable(m4, headers = c("pre-2012","2012-2019","2020-2024"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)

# ── TABLE 5: CRA small-business lending growth, county-year ───────────────────
cat("\n", strrep("=",70), "\n")
cat("TABLE 5 — CRA small-business lending growth, county-year\n")
cat("LHS : (inc_cra_{t+1} - inc_cra_{t-1}) / inc_cra_{t-1}  [2-yr window]\n")
cat("RHS : share_deps_closed (county-level)\n")
cat("FE  : county + state×year | SE: clustered at county\n")
cat("Note: CRA = amt_loans_lt_100k + amt_loans_100k_250k + amt_loans_250k_1m (table D1-1)\n")
cat(strrep("=",70), "\n\n")

m5 <- list(
  feols(cra_growth ~ share_deps_closed + .[ctrl_cty] | county + state_yr, cty_pre,  vcov = ~county),
  feols(cra_growth ~ share_deps_closed + .[ctrl_cty] | county + state_yr, cty_mid,  vcov = ~county),
  feols(cra_growth ~ share_deps_closed + .[ctrl_cty] | county + state_yr, cty_post, vcov = ~county)
)
etable(m5, headers = c("pre-2012","2012-2019","2020-2024"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)

# ── TABLE 6: HMDA purchase mortgage growth, zip-year ──────────────────────────
cat("\n", strrep("=",70), "\n")
cat("TABLE 6 — HMDA purchase mortgage growth, zip-year\n")
cat("LHS : (inc_purch_hmda_{t+1} - inc_purch_hmda_{t-1}) / inc_purch_hmda_{t-1}  [2-yr]\n")
cat("RHS : share_deps_closed (zip-level)\n")
cat("FE  : zip + county×year | SE: clustered at zip\n")
cat("Note: HMDA apportioned tract→zip by RES_RATIO (HUD crosswalk Dec 2019)\n")
cat("      Incumbent = bank with NO closes in (zip, YEAR)\n")
cat(strrep("=",70), "\n\n")

m6 <- list(
  feols(hmda_purch_growth_zip ~ share_deps_closed + .[ctrl_zip] | zip + county_yr,
        zip_00_07, vcov = ~zip),
  feols(hmda_purch_growth_zip ~ share_deps_closed + .[ctrl_zip] | zip + county_yr,
        zip_08_11, vcov = ~zip),
  feols(hmda_purch_growth_zip ~ share_deps_closed + .[ctrl_zip] | zip + county_yr,
        zip_12_19, vcov = ~zip),
  feols(hmda_purch_growth_zip ~ share_deps_closed + .[ctrl_zip] | zip + county_yr,
        zip_20_24, vcov = ~zip)
)
etable(m6, headers = c("2000-07","2008-11","2012-19","2020-24"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)
