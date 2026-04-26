# B1_hmda_zip_panels_20260423.R
# Build zip-year HMDA panel with three outcomes side-by-side:
#   (A) all purchase originations (replicates T2 Panel A = snapshot §4)
#   (B) second-lien purchase originations only    [Phil #3]
#   (C) jumbo purchase originations only (2012+)  [Rajesh]
#
# Structure mirrors main_regressions.qmd §HMDA Zip-Year (Tract Crosswalk).
# Incumbent aggregation identical: zip_inc_set = banks with is_inc==1 in (zip,YEAR).
# 2-year growth: (lead1 - lag1) / lag1, winsorized 2.5/97.5.

rm(list = ls())
source("code/approach-streamlined-20260423/00_common.R")

library(duckdb)
library(readxl)

HMDA_DB       <- "C:/empirical-data-construction/hmda/hmda.duckdb"
CLOSURE_PANEL <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
TRACT_ZIP_XW  <- here("data/raw/tract_zip_122019.xlsx")
CLL_PANEL     <- "data/constructed/cll_county_year_20260423.rds"

# ── 1. Build bank_zip is_inc and CERT↔RSSDID (replicate main_regressions.qmd) ─
raw <- setDT(readRDS(CLOSURE_PANEL))
raw[, county := str_pad(as.integer(STCNTYBR), 5, "left", "0")]
raw[, zip    := str_pad(as.integer(ZIPBR),    5, "left", "0")]
raw[, YEAR   := as.integer(YEAR)]
raw[, closed := as.integer(fifelse(is.na(closed), 0L, closed))]
raw[, RSSDID := suppressWarnings(as.numeric(RSSDID))]

bank_zip <- raw[, .(n_closes = sum(closed, na.rm = TRUE)), by = .(CERT, zip, YEAR)]
bank_zip[, is_inc := as.integer(n_closes == 0L)]
zip_inc_set <- bank_zip[is_inc == 1L, .(CERT, zip, YEAR)]

cert_rssd <- raw[!is.na(RSSDID) & RSSDID != 0,
  .(RSSDID = as.integer(RSSDID[1])), by = .(CERT, YEAR)]

# ── 2. Load tract→zip crosswalk ────────────────────────────────────────────
xwalk <- setDT(read_excel(TRACT_ZIP_XW))
xwalk[, ZIP   := str_pad(as.integer(ZIP), 5, "left", "0")]
xwalk[, TRACT := as.character(TRACT)]

# ── 3. Load CLL panel (for jumbo flag) ─────────────────────────────────────
cll <- setDT(readRDS(CLL_PANEL))

# ── 4. HMDA queries: all, second-lien, jumbo ────────────────────────────────
# Two query branches per variant for the 2018 LAR schema change (respondent_id → LEI).
# All variants: action_taken='1', loan_purpose='1', census_tract length=11.

build_q <- function(where_extra, year_cond) sprintf("
  SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
         l.census_tract             AS tract,
         LEFT(l.census_tract, 5)    AS county,
         l.year                     AS YEAR,
         SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM lar_panel l
  JOIN avery_crosswalk a
    %s
  WHERE l.action_taken = '1' AND l.loan_purpose = '1'
    AND LENGTH(l.census_tract) = 11
    %s
    AND %s
  GROUP BY rssdid, l.census_tract, l.year",
  "", where_extra, year_cond)

join_pre  <- "
    ON  l.respondent_id = a.respondent_id
    AND CAST(l.agency_code AS INTEGER) = CAST(a.agency_code AS INTEGER)
    AND l.year = a.activity_year"
join_post <- "
    ON l.lei = a.lei AND l.year = a.activity_year"

run_variant <- function(con, where_extra, min_year) {
  q_pre <- sprintf("
    SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
           l.census_tract AS tract, LEFT(l.census_tract,5) AS county, l.year AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM hmda.lar_panel l JOIN hmda.avery_crosswalk a %s
    WHERE l.action_taken='1' AND l.loan_purpose='1'
      AND LENGTH(l.census_tract)=11 AND l.year < 2018 AND l.year >= %d %s
    GROUP BY rssdid, l.census_tract, l.year", join_pre, min_year, where_extra)
  q_post <- sprintf("
    SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
           l.census_tract AS tract, LEFT(l.census_tract,5) AS county, l.year AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM hmda.lar_panel l JOIN hmda.avery_crosswalk a %s
    WHERE l.action_taken='1' AND l.loan_purpose='1'
      AND LENGTH(l.census_tract)=11 AND l.year >= 2018 AND l.year >= %d %s
    GROUP BY rssdid, l.census_tract, l.year", join_post, min_year, where_extra)
  rbind(dbGetQuery(con, q_pre), dbGetQuery(con, q_post))
}

aggregate_zip <- function(tract_df) {
  dt <- setDT(tract_df)
  dt <- dt[!is.na(rssdid) & rssdid != 0 & !is.na(tract)]
  dt <- dt[, .(hmda_amt = sum(hmda_amt)), by = .(rssdid, tract, county, YEAR)]
  # tract → zip
  dz <- merge(dt, xwalk[, .(tract = TRACT, ZIP, RES_RATIO)],
              by = "tract", allow.cartesian = TRUE)
  dz[, hmda_amt_zip := hmda_amt * RES_RATIO]
  dz <- dz[, .(hmda_amt = sum(hmda_amt_zip, na.rm = TRUE)),
           by = .(rssdid, zip = ZIP, YEAR)]
  # RSSDID → CERT
  dz <- merge(dz, cert_rssd, by.x = c("rssdid", "YEAR"),
              by.y = c("RSSDID", "YEAR"))
  dz <- dz[!is.na(CERT), .(hmda_amt = sum(hmda_amt)), by = .(CERT, zip, YEAR)]
  # Incumbent filter
  dz <- merge(dz, zip_inc_set, by = c("CERT", "zip", "YEAR"))
  # 2-year growth
  setorder(dz, CERT, zip, YEAR)
  dz[, lag1  := shift(hmda_amt, 1L, type = "lag"),  by = .(CERT, zip)]
  dz[, yr_l1 := shift(YEAR,     1L, type = "lag"),  by = .(CERT, zip)]
  dz[, lead1 := shift(hmda_amt, 1L, type = "lead"), by = .(CERT, zip)]
  dz[, yr_f1 := shift(YEAR,     1L, type = "lead"), by = .(CERT, zip)]
  dz[, lag1  := fifelse(yr_l1 == YEAR - 1, lag1,  NA_real_)]
  dz[, lead1 := fifelse(yr_f1 == YEAR + 1, lead1, NA_real_)]
  dz <- dz[!is.na(lag1) & lag1 > 0 & !is.na(lead1)]
  dz_cy <- dz[, .(h_lag1 = sum(lag1), h_lead1 = sum(lead1)), by = .(zip, YEAR)]
  dz_cy[, gr := (h_lead1 - h_lag1) / h_lag1]
  dz_cy[!is.na(gr), gr := wins(gr)]
  dz_cy[, .(zip, YEAR, gr)]
}

# ── Variant queries ─────────────────────────────────────────────────────────
# Use an in-memory writable DuckDB connection, ATTACH hmda read-only, and
# register the CLL panel so the jumbo filter can join it per-loan.
con <- dbConnect(duckdb())
dbExecute(con, sprintf("ATTACH '%s' AS hmda (READ_ONLY)", HMDA_DB))
duckdb_register(con, "cll_temp", cll)

cat("Running HMDA (all purchase) query ...\n")
all_tract <- run_variant(con, "", 2000)

cat("Running HMDA (second-lien) query ...\n")
sl_tract <- run_variant(con, "AND l.lien_status='2'", 2004)

cat("Running HMDA (refinance) query ...\n")
# Pre-2018 LAR: loan_purpose='3' (refinance).
# 2018+ LAR schema: '31' (refinance), '32' (cash-out refinance).
q_refi_pre <- sprintf("
  SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
         l.census_tract AS tract, LEFT(l.census_tract,5) AS county, l.year AS YEAR,
         SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM hmda.lar_panel l JOIN hmda.avery_crosswalk a %s
  WHERE l.action_taken='1' AND l.loan_purpose='3'
    AND LENGTH(l.census_tract)=11 AND l.year < 2018 AND l.year >= 2000
  GROUP BY rssdid, l.census_tract, l.year", join_pre)
q_refi_post <- sprintf("
  SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
         l.census_tract AS tract, LEFT(l.census_tract,5) AS county, l.year AS YEAR,
         SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM hmda.lar_panel l JOIN hmda.avery_crosswalk a %s
  WHERE l.action_taken='1' AND l.loan_purpose IN ('31','32')
    AND LENGTH(l.census_tract)=11 AND l.year >= 2018
  GROUP BY rssdid, l.census_tract, l.year", join_post)
refi_tract <- rbind(dbGetQuery(con, q_refi_pre), dbGetQuery(con, q_refi_post))

cat("Running HMDA (jumbo) query ...\n")
q_jumbo_pre <- "
  SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
         l.census_tract AS tract, LEFT(l.census_tract,5) AS county, l.year AS YEAR,
         SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM hmda.lar_panel l
  JOIN hmda.avery_crosswalk a
    ON l.respondent_id = a.respondent_id
    AND CAST(l.agency_code AS INTEGER) = CAST(a.agency_code AS INTEGER)
    AND l.year = a.activity_year
  JOIN cll_temp c
    ON LEFT(l.census_tract,5) = c.county AND l.year = c.year
  WHERE l.action_taken='1' AND l.loan_purpose='1'
    AND LENGTH(l.census_tract)=11 AND l.year BETWEEN 2012 AND 2017
    AND CAST(l.loan_amount AS DOUBLE) > c.cll_1unit
  GROUP BY rssdid, l.census_tract, l.year"
q_jumbo_post <- "
  SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
         l.census_tract AS tract, LEFT(l.census_tract,5) AS county, l.year AS YEAR,
         SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM hmda.lar_panel l
  JOIN hmda.avery_crosswalk a ON l.lei = a.lei AND l.year = a.activity_year
  JOIN cll_temp c
    ON LEFT(l.census_tract,5) = c.county AND l.year = c.year
  WHERE l.action_taken='1' AND l.loan_purpose='1'
    AND LENGTH(l.census_tract)=11 AND l.year >= 2018
    AND CAST(l.loan_amount AS DOUBLE) > c.cll_1unit
  GROUP BY rssdid, l.census_tract, l.year"
jumbo_tract <- rbind(dbGetQuery(con, q_jumbo_pre), dbGetQuery(con, q_jumbo_post))

dbDisconnect(con, shutdown = TRUE)

# ── Aggregate to zip-year ──────────────────────────────────────────────────
cat("Aggregating to zip-year ...\n")
all_zy   <- aggregate_zip(all_tract);   setnames(all_zy,   "gr", "hmda_purch_gr_all")
sl_zy    <- aggregate_zip(sl_tract);    setnames(sl_zy,    "gr", "hmda_purch_gr_sl")
jumbo_zy <- aggregate_zip(jumbo_tract); setnames(jumbo_zy, "gr", "hmda_purch_gr_jumbo")
refi_zy  <- aggregate_zip(refi_tract);  setnames(refi_zy,  "gr", "hmda_refi_gr_all")

cat("N(all)   =", nrow(all_zy), "\n")
cat("N(sl)    =", nrow(sl_zy),  "\n")
cat("N(jumbo) =", nrow(jumbo_zy), "\n")
cat("N(refi)  =", nrow(refi_zy), "\n")

# ── 5. Merge onto zip_tech_sample for regression inputs ───────────────────
ztp <- setDT(load_latest("data", "^zip_tech_sample_\\d{8}\\.rds$"))
ztp <- merge(ztp, all_zy,   by = c("zip", "YEAR"), all.x = TRUE)
ztp <- merge(ztp, sl_zy,    by = c("zip", "YEAR"), all.x = TRUE)
ztp <- merge(ztp, jumbo_zy, by = c("zip", "YEAR"), all.x = TRUE)
ztp <- merge(ztp, refi_zy,  by = c("zip", "YEAR"), all.x = TRUE)

out_path <- file.path("data/constructed",
                      paste0("hmda_zip_panels_", format(Sys.time(), "%Y%m%d"), ".rds"))
saveRDS(ztp, out_path)
cat("\nSaved:", out_path, "\n")
cat("Rows with hmda_purch_gr_all:", sum(!is.na(ztp$hmda_purch_gr_all)), "\n")
cat("Rows with hmda_purch_gr_sl:",  sum(!is.na(ztp$hmda_purch_gr_sl)), "\n")
cat("Rows with hmda_purch_gr_jumbo (2012+):",
    sum(!is.na(ztp$hmda_purch_gr_jumbo) & ztp$YEAR >= 2012), "\n")
cat("Rows with hmda_refi_gr_all:", sum(!is.na(ztp$hmda_refi_gr_all)), "\n")

append_note("B1 — HMDA zip-year panels",
  c(paste0("Built combined panel with four HMDA outcomes at zip-year: all purchase, second-lien, jumbo, refinance."),
    paste0("Saved: `", out_path, "`."),
    paste0("N(all): ", sum(!is.na(ztp$hmda_purch_gr_all)),
           " | N(second-lien): ", sum(!is.na(ztp$hmda_purch_gr_sl)),
           " | N(jumbo, 2012+): ", sum(!is.na(ztp$hmda_purch_gr_jumbo) & ztp$YEAR >= 2012),
           " | N(refi): ", sum(!is.na(ztp$hmda_refi_gr_all)))))
