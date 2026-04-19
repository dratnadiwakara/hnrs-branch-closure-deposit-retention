# ============================================================
# Main deposit-reallocation regressions
#
# 4 outcomes:
#   (1) Incumbent deposits   — zip-year
#   (2) Incumbent deposits   — county-year
#   (3) HMDA mortgages       — county-year, incumbent banks
#   (4) CRA small-business   — county-year, incumbent banks
#
# Treatment : share_deps_closed
#             = sum(closed-branch dep_{t-1}) / total dep_{t-1}
#               in the geographic unit (zip or county)
#
# Outcome   : (dep_{t+1} - dep_{t-1}) / dep_{t-1}
#             aggregated over incumbent branches/banks in unit
#             normalized by own t-1 baseline (not total, to avoid
#             mechanical denominator bias from closed-branch deposits)
#
# Incumbent : bank has NO closed branch in (geo-unit, YEAR)
#
# FE        : zip + county×year  for zip regressions
#             county + state×year for county regressions
# SE        : clustered at zip / county
# Periods   : pre-2012 | 2012-2019 | 2020-2024
# ============================================================

rm(list = ls())
library(data.table)
library(fixest)
library(duckdb)
library(stringr)

# ── paths ─────────────────────────────────────────────────────────────────────
CLOSURE_PANEL <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
HMDA_DB       <- "C:/empirical-data-construction/hmda/hmda.duckdb"
CRA_DB        <- "C:/empirical-data-construction/cra/cra.duckdb"

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
    format(nrow(raw), big.mark = ","), format(uniqueN(raw$UNINUMBR), big.mark = ",")))

# ── 2. branch-level lag/lead deposits (2-year window: t-1 to t+1) ────────────
setorder(raw, UNINUMBR, YEAR)
raw[, dep_lag1  := shift(DEPSUMBR, n=1L, type="lag"),  by = UNINUMBR]
raw[, yr_lag1   := shift(YEAR,     n=1L, type="lag"),  by = UNINUMBR]
raw[, dep_lead1 := shift(DEPSUMBR, n=1L, type="lead"), by = UNINUMBR]
raw[, yr_lead1  := shift(YEAR,     n=1L, type="lead"), by = UNINUMBR]
# NA out non-consecutive years (gaps in panel)
raw[, dep_lag1_a  := fifelse(yr_lag1  == YEAR - 1, dep_lag1,  NA_real_)]
raw[, dep_lead1_a := fifelse(yr_lead1 == YEAR + 1, dep_lead1, NA_real_)]

# CERT→RSSDID crosswalk (used later for HMDA/CRA bank matching)
cert_rssd <- raw[!is.na(RSSDID) & RSSDID != 0,
  .(RSSDID = as.integer(RSSDID[1])), by = .(CERT, YEAR)]

# ── helper: winsorize at [p_lo, p_hi] ─────────────────────────────────────────
wins <- function(x, lo = 0.025, hi = 0.975) {
  q <- quantile(x, c(lo, hi), na.rm = TRUE)
  pmin(pmax(x, q[1]), q[2])
}

# ── 3. zip-year panel (mirrors 15_incumbent_reallocation.qmd — Table 14) ──────
# Outcome  : gr_1yr = (inc_deps_{t+1} - inc_deps_t) / total_zip_deps_{t-1}
#            1-year window; denominator is total pre-closure market (all branches)
# Treatment: fraction_of_branches_closed = n_closed / branches_{t-1}  [count-based]
#            share_deps_closed = sum(closed dep_{t-1}) / total_dep_{t-1} [deposit-weighted]
# Incumbent: bank with NO opens AND NO closes in this (zip, YEAR)
cat("Building zip-year panel...\n")

# new_branch flag: first appearance of branch (no lagged year)
raw[, new_branch := as.integer(is.na(shift(YEAR, n=1L, type="lag"))), by = UNINUMBR]

# classify each bank-zip-year as INCUMBENT or CHURNER
bank_zip <- raw[, .(
  n_opens  = sum(new_branch, na.rm = TRUE),
  n_closes = sum(closed,     na.rm = TRUE)
), by = .(CERT, zip, YEAR)]
bank_zip[, is_inc := as.integer(n_opens == 0 & n_closes == 0)]

raw_z <- merge(raw,
               bank_zip[, .(CERT, zip, YEAR, is_inc, n_opens, n_closes)],
               by = c("CERT","zip","YEAR"), all.x = TRUE)
raw_z[is.na(is_inc), is_inc := 0L]

# zip totals at t-1: all branches (denominator for outcome and treatments)
zt <- raw_z[!is.na(dep_lag1_a) & dep_lag1_a > 0, .(
  total_deps    = sum(dep_lag1_a),      # total zip deposits at t-1
  branches_lag1 = uniqueN(UNINUMBR),    # total branches at t-1
  n_banks       = uniqueN(CERT)
), by = .(zip, YEAR)]

# zip-level event counts at t (for count-based treatments)
z_events <- raw_z[, .(
  n_closed_zip = sum(closed,     na.rm = TRUE),
  n_opened_zip = sum(new_branch, na.rm = TRUE)
), by = .(zip, YEAR)]

# closed branch deposits at t-1 (deposit-weighted treatment numerator)
zc <- raw_z[closed == 1 & !is.na(dep_lag1_a) & dep_lag1_a > 0,
  .(closed_deps = sum(dep_lag1_a)), by = .(zip, YEAR)]

# incumbent deposits — 1-year window (t → t+1):
#   inc_curr: ALL incumbent branches at t  (DEPSUMBR, including those closing t+1)
#   inc_tp1 : incumbent branches at t+1    (dep_lead1_a, NA for branches that closed)
# This mirrors reference: incumbent_deps_curr and incumbent_deps_lead1
zi_curr <- raw_z[is_inc == 1L & !is.na(DEPSUMBR) & DEPSUMBR > 0, .(
  inc_curr    = sum(as.numeric(DEPSUMBR)),
  n_inc_banks = uniqueN(CERT)
), by = .(zip, YEAR)]

zi_tp1 <- raw_z[is_inc == 1L & !is.na(dep_lead1_a), .(
  inc_tp1 = sum(dep_lead1_a)
), by = .(zip, YEAR)]

# assemble zip panel
zip_pan <- Reduce(function(x, y) merge(x, y, by = c("zip","YEAR"), all.x = TRUE),
  list(zt, z_events, zc, zi_curr, zi_tp1))
zip_pan[is.na(closed_deps),  closed_deps  := 0]
zip_pan[is.na(n_closed_zip), n_closed_zip := 0L]
zip_pan[is.na(n_opened_zip), n_opened_zip := 0L]

# treatments
zip_pan[, fraction_of_branches_closed := n_closed_zip / pmax(branches_lag1, 1)]
zip_pan[, fraction_of_new_branches    := n_opened_zip / pmax(branches_lag1, 1)]
zip_pan[, share_deps_closed           := closed_deps  / pmax(total_deps, 1)]

# controls (matches reference Table 14: log branches + log incumbent banks)
zip_pan[, log_n_branches  := log1p(branches_lag1)]
zip_pan[, log_n_banks     := log1p(n_banks)]
zip_pan[, log_n_inc_banks := log1p(n_inc_banks)]   # incumbent banks only (reference spec)

# outcome: (inc_deps_{t+1} - inc_deps_t) / total_zip_deps_{t-1}
zip_pan[, outcome := fifelse(total_deps > 0, (inc_tp1 - inc_curr) / total_deps, NA_real_)]

# county identifier for FE
zip_map <- unique(raw[, .(zip, county)])[!duplicated(zip)]
zip_pan <- merge(zip_pan, zip_map, by = "zip", all.x = TRUE)
zip_pan[, county_yr := paste0(county, "_", YEAR)]

zip_pan[!is.na(outcome), outcome := wins(outcome)]
zip_pan <- zip_pan[YEAR %between% c(2000,2024) &
                   !is.na(n_inc_banks) & n_inc_banks >= 2 & branches_lag1 >= 2 &
                   !is.na(outcome) & !is.na(county)]
cat(sprintf("  rows (pre-demo filter): %s | zips: %s\n",
    format(nrow(zip_pan), big.mark = ","), uniqueN(zip_pan$zip)))

# ── 4. county-year panel (deposits) ───────────────────────────────────────────
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
# 2-year window; normalize by own t-1 incumbent base to avoid mechanical denominator bias
# (total_deps includes closed-branch deposits, inflating denominator for high-closure counties)
cty_pan[, dep_outcome       := fifelse(inc_tm1 > 0, (inc_tp1 - inc_tm1) / inc_tm1, NA_real_)]
cty_pan[, state_yr          := paste0(substr(county, 1, 2), "_", YEAR)]

cty_pan[!is.na(dep_outcome), dep_outcome := wins(dep_outcome)]
cty_pan <- cty_pan[YEAR %between% c(2000,2024) & n_banks >= 2 & n_branches >= 2 &
                   !is.na(dep_outcome) & !is.na(county)]
cat(sprintf("  rows: %s | counties: %s\n",
    format(nrow(cty_pan), big.mark = ","), uniqueN(cty_pan$county)))

# incumbent (CERT, county, YEAR) set — used to filter HMDA/CRA below
inc_set <- unique(raw_c[inc == TRUE, .(CERT, county, YEAR)])

# ── 5. HMDA — incumbent banks aggregated to county-year ───────────────────────
cat("Querying HMDA...\n")
con <- dbConnect(duckdb(), HMDA_DB, read_only = TRUE)

# pre-2018: match on respondent_id + agency_code; post-2018: match on LEI
hmda <- rbind(
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
    WHERE l.action_taken = '1' AND l.year < 2018 AND LENGTH(l.census_tract) >= 5
    GROUP BY rssdid, county, l.year"),
  dbGetQuery(con, "
    SELECT CAST(a.rssd_id AS BIGINT)   AS rssdid,
           LEFT(l.census_tract, 5)     AS county,
           l.year                      AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM lar_panel l
    JOIN avery_crosswalk a ON l.lei = a.lei AND l.year = a.activity_year
    WHERE l.action_taken = '1' AND l.year >= 2018 AND LENGTH(l.census_tract) >= 5
    GROUP BY rssdid, county, l.year")
)
dbDisconnect(con)

setDT(hmda)
hmda <- hmda[!is.na(rssdid) & rssdid != 0 & nchar(county) == 5]
hmda <- hmda[, .(hmda_amt = sum(hmda_amt)), by = .(rssdid, county, YEAR)]
# RSSDID → CERT
hmda <- merge(hmda, cert_rssd, by.x = c("rssdid","YEAR"), by.y = c("RSSDID","YEAR"))
hmda <- hmda[!is.na(CERT), .(hmda_amt = sum(hmda_amt)), by = .(CERT, county, YEAR)]
# keep only incumbent banks
hmda_inc <- merge(hmda, inc_set, by = c("CERT","county","YEAR"))
cat(sprintf("  bank-county rows (incumbent): %s\n", format(nrow(hmda_inc), big.mark=",")))

# 2-year window at bank×county level, then aggregate amounts to county
setorder(hmda_inc, CERT, county, YEAR)
hmda_inc[, lag1  := shift(hmda_amt, n=1L, type="lag"),  by = .(CERT, county)]
hmda_inc[, yr_l1 := shift(YEAR,     n=1L, type="lag"),  by = .(CERT, county)]
hmda_inc[, lead1 := shift(hmda_amt, n=1L, type="lead"), by = .(CERT, county)]
hmda_inc[, yr_f1 := shift(YEAR,     n=1L, type="lead"), by = .(CERT, county)]
hmda_inc[, lag1  := fifelse(yr_l1 == YEAR - 1, lag1,  NA_real_)]
hmda_inc[, lead1 := fifelse(yr_f1 == YEAR + 1, lead1, NA_real_)]
hmda_inc <- hmda_inc[!is.na(lag1) & lag1 > 0 & !is.na(lead1)]

hmda_cy <- hmda_inc[, .(h_lag1 = sum(lag1), h_lead1 = sum(lead1)), by = .(county, YEAR)]
hmda_cy[, hmda_growth := (h_lead1 - h_lag1) / h_lag1]
cat(sprintf("  county-year rows after 2yr window: %s\n", format(nrow(hmda_cy), big.mark=",")))

# ── 5b. HMDA purchase-only (loan_purpose = '1', action_taken = '1') ───────────
# Excludes refinancings and home-improvement loans; isolates new home purchases
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
hmda_purch_inc <- merge(hmda_purch_raw, inc_set, by = c("CERT","county","YEAR"))
cat(sprintf("  bank-county rows (incumbent, purchase): %s\n", format(nrow(hmda_purch_inc), big.mark=",")))

setorder(hmda_purch_inc, CERT, county, YEAR)
hmda_purch_inc[, lag1  := shift(hmda_amt, n=1L, type="lag"),  by = .(CERT, county)]
hmda_purch_inc[, yr_l1 := shift(YEAR,     n=1L, type="lag"),  by = .(CERT, county)]
hmda_purch_inc[, lead1 := shift(hmda_amt, n=1L, type="lead"), by = .(CERT, county)]
hmda_purch_inc[, yr_f1 := shift(YEAR,     n=1L, type="lead"), by = .(CERT, county)]
hmda_purch_inc[, lag1  := fifelse(yr_l1 == YEAR - 1, lag1,  NA_real_)]
hmda_purch_inc[, lead1 := fifelse(yr_f1 == YEAR + 1, lead1, NA_real_)]
hmda_purch_inc <- hmda_purch_inc[!is.na(lag1) & lag1 > 0 & !is.na(lead1)]

hmda_purch_cy <- hmda_purch_inc[, .(p_lag1 = sum(lag1), p_lead1 = sum(lead1)), by = .(county, YEAR)]
hmda_purch_cy[, hmda_purch_growth := (p_lead1 - p_lag1) / p_lag1]
cat(sprintf("  county-year rows after 2yr window: %s\n", format(nrow(hmda_purch_cy), big.mark=",")))

# ── 6. CRA — incumbent banks aggregated to county-year ────────────────────────
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
cat(sprintf("  bank-county rows (incumbent): %s\n", format(nrow(cra_inc), big.mark=",")))

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
cat(sprintf("  county-year rows after 2yr window: %s\n", format(nrow(cra_cy), big.mark=",")))

# ── 7. merge HMDA + CRA into county panel ─────────────────────────────────────
cty_pan <- merge(cty_pan, hmda_cy[,       .(county, YEAR, hmda_growth)],       by = c("county","YEAR"), all.x = TRUE)
cty_pan <- merge(cty_pan, hmda_purch_cy[, .(county, YEAR, hmda_purch_growth)], by = c("county","YEAR"), all.x = TRUE)
cty_pan <- merge(cty_pan, cra_cy[,        .(county, YEAR, cra_growth)],        by = c("county","YEAR"), all.x = TRUE)
cty_pan[!is.na(hmda_growth),       hmda_growth       := wins(hmda_growth)]
cty_pan[!is.na(hmda_purch_growth), hmda_purch_growth := wins(hmda_purch_growth)]
cty_pan[!is.na(cra_growth),        cra_growth        := wins(cra_growth)]

cat(sprintf("\nFinal county panel: %s rows\n", format(nrow(cty_pan), big.mark=",")))
cat(sprintf("  hmda_growth       non-NA: %s\n", format(sum(!is.na(cty_pan$hmda_growth)),       big.mark=",")))
cat(sprintf("  hmda_purch_growth non-NA: %s\n", format(sum(!is.na(cty_pan$hmda_purch_growth)), big.mark=",")))
cat(sprintf("  cra_growth        non-NA: %s\n", format(sum(!is.na(cty_pan$cra_growth)),        big.mark=",")))

# ── 7a. county deposit growth trend (4-yr window: t-4 to t-1) ────────────────
# Used as a control for pre-existing trends in local deposit activity
cat("Computing county deposit growth trend...\n")
cty_deps_yr <- raw[!is.na(DEPSUMBR) & DEPSUMBR > 0,
  .(total_dep_county = sum(as.numeric(DEPSUMBR))), by = .(county, YEAR)]
setorder(cty_deps_yr, county, YEAR)
cty_deps_yr[, dep_lag4 := shift(total_dep_county, n=4L, type="lag"), by = county]
cty_deps_yr[, yr_lag4  := shift(YEAR,             n=4L, type="lag"), by = county]
cty_deps_yr[, county_dep_growth_t4_t1 := fifelse(
  yr_lag4 == YEAR - 4 & dep_lag4 > 0,
  (total_dep_county - dep_lag4) / dep_lag4,
  NA_real_
)]
cty_growth <- cty_deps_yr[, .(county, YEAR, county_dep_growth_t4_t1)]

# merge county trend onto both panels (zip_pan has county column via zip_map)
zip_pan <- merge(zip_pan, cty_growth, by = c("county","YEAR"), all.x = TRUE)
cty_pan <- merge(cty_pan, cty_growth, by = c("county","YEAR"), all.x = TRUE)
cat(sprintf("  county_dep_growth_t4_t1 non-NA: zip=%s  county=%s\n",
    format(sum(!is.na(zip_pan$county_dep_growth_t4_t1)), big.mark=","),
    format(sum(!is.na(cty_pan$county_dep_growth_t4_t1)), big.mark=",")))

# ── 7b. log1p(total_deps) ─────────────────────────────────────────────────────
# Controls for overall market size in the geo-unit
zip_pan[, log1p_total_deps := log1p(total_deps)]
cty_pan[, log1p_total_deps := log1p(total_deps)]

# ── 7c. county economic controls (county_controls_panel.rds) ──────────────────
# Demographics, HHI, and local economic conditions — one obs per county-year
COUNTY_CONTROLS <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/county_controls_panel.rds"
cat("Loading county controls...\n")
cc <- setDT(readRDS(COUNTY_CONTROLS))
if (!"county" %in% names(cc) && "county_code" %in% names(cc)) setnames(cc, "county_code", "county")
if (!"YEAR"   %in% names(cc) && "year"        %in% names(cc)) setnames(cc, "year", "YEAR")
cc[, county := formatC(as.integer(county), width = 5, flag = "0")]
cc[, YEAR   := as.integer(YEAR)]

ctrl_vars <- c("log_population_density","lag_county_deposit_hhi",
               "lag_establishment_gr","lag_payroll_gr",
               "lag_hmda_mtg_amt_gr","lag_cra_loan_amount_amt_lt_1m_gr","lmi")
ctrl_vars <- ctrl_vars[ctrl_vars %in% names(cc)]
cat(sprintf("  County control vars found: %s\n", paste(ctrl_vars, collapse=", ")))

cc_sel <- unique(cc[, c("county","YEAR", ctrl_vars), with = FALSE], by = c("county","YEAR"))
zip_pan <- merge(zip_pan, cc_sel, by = c("county","YEAR"), all.x = TRUE)
cty_pan <- merge(cty_pan, cc_sel, by = c("county","YEAR"), all.x = TRUE)
cat(sprintf("  zip_pan after merge: %s rows | cty_pan: %s rows\n",
    format(nrow(zip_pan),big.mark=","), format(nrow(cty_pan),big.mark=",")))

# ── 7d. zip demographics — restrict to zips with demographics data ─────────────
# Mirrors reference sample restriction: dt_combined[!is.na(sophisticated)]
# zip_demographics_panel.rds contains: zip, yr, sophisticated, age_bin, median_income
ZIP_DEMO <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/zip_demographics_panel.rds"
cat("Loading zip demographics...\n")
zip_demo <- setDT(readRDS(ZIP_DEMO))
zip_demo <- zip_demo[!is.na(zip), .(zip = as.character(str_pad(zip, 5, "left", "0")),
                                    YEAR = as.integer(yr),
                                    sophisticated)]
zip_pan <- merge(zip_pan, zip_demo, by = c("zip","YEAR"), all.x = TRUE)
zip_pan <- zip_pan[!is.na(sophisticated)]
cat(sprintf("  zip_pan after demographics filter: %s rows | zips: %s\n",
    format(nrow(zip_pan), big.mark=","), uniqueN(zip_pan$zip)))

# ── 8. descriptive statistics ─────────────────────────────────────────────────
cat("\n", strrep("=",70), "\n")
cat("DESCRIPTIVE STATISTICS\n")
cat(strrep("=",70), "\n")

desc <- function(dt, vars, panel_label) {
  cat(sprintf("\n--- %s ---\n", panel_label))
  # inline period filters (avoids eval() scoping issues)
  p_list <- list(
    "pre-2012"  = dt[YEAR <  2012],
    "2012-2019" = dt[YEAR %between% c(2012,2019)],
    "2020-2024" = dt[YEAR %between% c(2020,2024)]
  )
  hdr <- sprintf("%-30s", "Variable")
  for (nm in names(p_list)) hdr <- paste0(hdr, sprintf(" %18s", nm))
  cat(hdr, "\n")
  cat(strrep("-", 30 + 19 * length(p_list)), "\n")
  for (v in vars) {
    if (!v %in% names(dt)) next
    row <- sprintf("%-30s", v)
    for (nm in names(p_list)) {
      sub <- p_list[[nm]][[v]]
      sub <- sub[!is.na(sub)]
      if (length(sub) == 0) { row <- paste0(row, sprintf(" %18s", "—")); next }
      row <- paste0(row, sprintf(" %8.4f/%8.4f", mean(sub), median(sub)))
    }
    cat(row, "  [mean/median]\n")
  }
  n_row <- sprintf("%-30s", "N")
  for (nm in names(p_list)) n_row <- paste0(n_row, sprintf(" %18s", format(nrow(p_list[[nm]]), big.mark=",")))
  cat(n_row, "\n")
}

desc(zip_pan, c("outcome","fraction_of_branches_closed","fraction_of_new_branches",
                "share_deps_closed","log_n_branches","log_n_inc_banks","log_n_banks"),
     "Zip-year panel — LHS: incumbent deposit growth (1-yr window / total_deps denom)")
desc(cty_pan, c("dep_outcome","hmda_growth","hmda_purch_growth","cra_growth","share_deps_closed",
                "log_n_branches","log_n_banks","log1p_total_deps","county_dep_growth_t4_t1",
                "log_population_density","lag_county_deposit_hhi",
                "lag_establishment_gr","lag_payroll_gr",
                "lag_hmda_mtg_amt_gr","lag_cra_loan_amount_amt_lt_1m_gr","lmi"),
     "County-year panel — LHS: deposits / HMDA / CRA growth")

# sanity check: quantile distribution of outcomes (check for outlier issues)
cat("\n--- Outcome quantiles (post-winsorize) ---\n")
probs <- c(0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99)
for (v in c("outcome","dep_outcome","hmda_growth","cra_growth")) {
  dt <- if (v == "outcome") zip_pan else cty_pan
  if (!v %in% names(dt)) next
  x  <- dt[[v]]
  x  <- x[!is.na(x)]
  q  <- round(quantile(x, probs), 4)
  cat(sprintf("\n%s (N=%s, sd=%.4f):\n  ", v, format(length(x),big.mark=","), sd(x)))
  cat(paste(sprintf("P%s=%.4f", as.integer(probs*100), q), collapse="  "), "\n")
}

# extreme treatment check
cat(sprintf("\nshare_deps_closed > 0.50: %s zip-years, %s county-years\n",
    format(sum(zip_pan$share_deps_closed > 0.50), big.mark=","),
    format(sum(cty_pan$share_deps_closed > 0.50), big.mark=",")))
cat(sprintf("share_deps_closed > 0.25: %s zip-years, %s county-years\n",
    format(sum(zip_pan$share_deps_closed > 0.25), big.mark=","),
    format(sum(cty_pan$share_deps_closed > 0.25), big.mark=",")))

# raw correlation check
for (nm in c("2000-2007","2008-2011","2012-2019","2020-2024")) {
  sub_z <- switch(nm,
    "2000-2007" = zip_pan[YEAR %between% c(2000,2007)],
    "2008-2011" = zip_pan[YEAR %between% c(2008,2011)],
    "2012-2019" = zip_pan[YEAR %between% c(2012,2019)],
    "2020-2024" = zip_pan[YEAR >= 2020])
  sub_c <- switch(nm,
    "2000-2007" = cty_pan[YEAR %between% c(2000,2007)],
    "2008-2011" = cty_pan[YEAR %between% c(2008,2011)],
    "2012-2019" = cty_pan[YEAR %between% c(2012,2019)],
    "2020-2024" = cty_pan[YEAR >= 2020])
  r_z <- cor(sub_z$fraction_of_branches_closed, sub_z$outcome,     use = "complete.obs")
  r_c <- cor(sub_c$share_deps_closed,           sub_c$dep_outcome, use = "complete.obs")
  cat(sprintf("Raw corr(treatment, outcome) [%s]: zip(frac_closed)=%.4f  county(share_deps)=%.4f\n", nm, r_z, r_c))
}

# ── 9. regressions ─────────────────────────────────────────────────────────────
cat("\n", strrep("=",70), "\n")
cat("REGRESSIONS\n")
cat(strrep("=",70), "\n")

# period subsets — zip uses 4 periods matching reference Table 14
zip_00_07 <- zip_pan[YEAR %between% c(2000,2007)]
zip_08_11 <- zip_pan[YEAR %between% c(2008,2011)]
zip_12_19 <- zip_pan[YEAR %between% c(2012,2019)]
zip_20_24 <- zip_pan[YEAR >= 2020]

cty_pre  <- cty_pan[YEAR <  2012]
cty_mid  <- cty_pan[YEAR %between% c(2012,2019)]
cty_post <- cty_pan[YEAR >= 2020]

# zip controls: log(branches) + log(incumbent banks) — matches reference Table 14
ctrl_zip <- ~ log_n_branches + log_n_inc_banks

# county/lending controls: full suite
ctrl <- ~ log_n_branches + log_n_banks + log1p_total_deps + county_dep_growth_t4_t1 +
          log_population_density + lag_county_deposit_hhi + lag_establishment_gr +
          lag_payroll_gr + lag_hmda_mtg_amt_gr + lag_cra_loan_amount_amt_lt_1m_gr + lmi

# (1) zip-year deposits — mirrors reference Table 14
# Treatment: fraction_of_branches_closed (count-based), fraction_of_new_branches
# Outcome:   (inc_deps_{t+1} - inc_deps_t) / total_zip_deps_{t-1}
# FE:        zip + county×year | SE: clustered at zip
cat("\n--- (1) Incumbent deposits — zip-year (Table 14 spec) ---\n")
cat("FE: zip + county×year | SE: clustered at zip\n\n")
m_zip <- list(
  feols(outcome ~ fraction_of_branches_closed + fraction_of_new_branches + .[ctrl_zip] | zip + county_yr, zip_00_07, vcov = ~zip),
  feols(outcome ~ fraction_of_branches_closed + fraction_of_new_branches + .[ctrl_zip] | zip + county_yr, zip_08_11, vcov = ~zip),
  feols(outcome ~ fraction_of_branches_closed + fraction_of_new_branches + .[ctrl_zip] | zip + county_yr, zip_12_19, vcov = ~zip),
  feols(outcome ~ fraction_of_branches_closed + fraction_of_new_branches + .[ctrl_zip] | zip + county_yr, zip_20_24, vcov = ~zip)
)
etable(m_zip, headers = c("2000-07","2008-11","2012-19","2020-24"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)

# (2) county-year deposits: FE = county + state×year
cat("\n--- (2) Incumbent deposits — county-year ---\n")
cat("FE: county + state×year | SE: clustered at county\n\n")
m_cty <- list(
  feols(dep_outcome ~ share_deps_closed + .[ctrl] | county + state_yr, cty_pre,  vcov = ~county),
  feols(dep_outcome ~ share_deps_closed + .[ctrl] | county + state_yr, cty_mid,  vcov = ~county),
  feols(dep_outcome ~ share_deps_closed + .[ctrl] | county + state_yr, cty_post, vcov = ~county)
)
etable(m_cty, headers = c("pre-2012","2012-2019","2020-2024"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)

# (3) HMDA mortgages — county-year, incumbent banks
cat("\n--- (3) HMDA mortgage growth — county-year (incumbent banks) ---\n")
cat("FE: county + state×year | SE: clustered at county\n\n")
m_hmda <- list(
  feols(hmda_growth ~ share_deps_closed + .[ctrl] | county + state_yr, cty_pre,  vcov = ~county),
  feols(hmda_growth ~ share_deps_closed + .[ctrl] | county + state_yr, cty_mid,  vcov = ~county),
  feols(hmda_growth ~ share_deps_closed + .[ctrl] | county + state_yr, cty_post, vcov = ~county)
)
etable(m_hmda, headers = c("pre-2012","2012-2019","2020-2024"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)

# (4) CRA small-business lending — county-year, incumbent banks
cat("\n--- (4) CRA SBL growth — county-year (incumbent banks) ---\n")
cat("FE: county + state×year | SE: clustered at county\n\n")
m_cra <- list(
  feols(cra_growth ~ share_deps_closed + .[ctrl] | county + state_yr, cty_pre,  vcov = ~county),
  feols(cra_growth ~ share_deps_closed + .[ctrl] | county + state_yr, cty_mid,  vcov = ~county),
  feols(cra_growth ~ share_deps_closed + .[ctrl] | county + state_yr, cty_post, vcov = ~county)
)
etable(m_cra, headers = c("pre-2012","2012-2019","2020-2024"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)

# (5) HMDA purchase-only mortgages — county-year, incumbent banks
# Excludes refinancings; isolates new home purchase originations (loan_purpose = '1')
cat("\n--- (5) HMDA purchase mortgage growth — county-year (incumbent banks, purchase only) ---\n")
cat("FE: county + state×year | SE: clustered at county\n\n")
m_hmda_purch <- list(
  feols(hmda_purch_growth ~ share_deps_closed + .[ctrl] | county + state_yr, cty_pre,  vcov = ~county),
  feols(hmda_purch_growth ~ share_deps_closed + .[ctrl] | county + state_yr, cty_mid,  vcov = ~county),
  feols(hmda_purch_growth ~ share_deps_closed + .[ctrl] | county + state_yr, cty_post, vcov = ~county)
)
etable(m_hmda_purch, headers = c("pre-2012","2012-2019","2020-2024"),
       signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below = TRUE)
