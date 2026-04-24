# S5_build_hmda_panels.R
# V2 rebuild of zip-year HMDA lending-outcome panels.
#
# Changes from v1 (code/approach-streamlined-20260423/sample-construction/B1_hmda_zip_panels_20260423.R):
#   V1 hardcoded the incumbent filter inside aggregate_zip() so every HMDA
#   outcome was "incumbent-bank lending growth" even when the paper text
#   said "local lending". V2 produces three named universes per outcome:
#
#     *_gr_all       total market (no SOD filter; tract -> zip via RES_RATIO
#                    then merged to a ZIP x YEAR total)
#     *_gr_branch    respondents with >= 1 SOD branch in (zip, YEAR)
#     *_gr_incumbent SOD incumbent (non-closer) in (zip, YEAR)
#
# Outcomes (per universe):
#   hmda_purch_gr_*     all purchase (loan_purpose='1')
#   hmda_refi_gr_*      refinances (pre-2018 purpose='3'; post-2018 '31'/'32')
#   hmda_sl_gr_*        second-lien purchase (lien_status='2')
#   hmda_jumbo_gr_*     jumbo purchase (loan_amount > CLL_1unit, 2012+)
#
# Merged onto v2 zip_tech_sample for regression inputs.
# Output: data/constructed/hmda_panels_v2_YYYYMMDD.rds

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")
library(duckdb)

HMDA_DB       <- "C:/empirical-data-construction/hmda/hmda.duckdb"
CLOSURE_PANEL <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
TRACT_ZIP_XW  <- here("data/raw/tract_zip_122019.xlsx")
CLL_PANEL     <- "data/constructed/cll_county_year_20260423.rds"
ZIP_CTY_XW    <- "data/constructed/zip_county_xwalk_v2.rds"

flow <- sample_flow_init("hmda_v2")

# ---- 1. SOD sets (zip x YEAR) ----------------------------------------------
raw <- setDT(load_exact(CLOSURE_PANEL))
raw[, `:=`(
  zip    = str_pad(as.integer(ZIPBR), 5, "left", "0"),
  county = str_pad(as.integer(STCNTYBR), 5, "left", "0"),
  YEAR   = as.integer(YEAR),
  CERT   = as.integer(CERT),
  RSSDID = suppressWarnings(as.numeric(RSSDID)),
  closed = as.integer(fifelse(is.na(closed), 0L, closed))
)]

# Branch-present (CERT has at least one branch in zip x YEAR)
zip_branch_set <- unique(raw[!is.na(CERT) & !is.na(zip), .(CERT, zip, YEAR)])
zip_branch_set[, has_branch := 1L]

# Incumbent = branch-present AND no closure in (CERT, zip, YEAR)
zip_closers <- raw[, .(n_closes = sum(closed, na.rm = TRUE)),
                   by = .(CERT, zip, YEAR)]
zip_inc_set <- zip_closers[n_closes == 0L, .(CERT, zip, YEAR)]

cert_rssd <- raw[!is.na(RSSDID) & RSSDID != 0,
  .(RSSDID = as.integer(RSSDID[1])), by = .(CERT, YEAR)]

# ---- 2. HUD tract -> zip crosswalk -----------------------------------------
xwalk <- as.data.table(read_excel(TRACT_ZIP_XW))
setnames(xwalk, tolower(names(xwalk)))
xwalk[, tract := str_pad(as.character(tract), 11, "left", "0")]
xwalk[, zip   := str_pad(as.character(zip),    5, "left", "0")]
xwalk[, RES_RATIO := as.numeric(res_ratio)]
xwalk <- xwalk[, .(TRACT = tract, ZIP = zip, RES_RATIO)]

# ---- 3. HMDA queries --------------------------------------------------------
join_pre <- "
  ON  l.respondent_id = a.respondent_id
  AND CAST(l.agency_code AS INTEGER) = CAST(a.agency_code AS INTEGER)
  AND l.year = a.activity_year"
join_post <- "
  ON l.lei = a.lei AND l.year = a.activity_year"

run_variant <- function(con, where_extra, min_year) {
  q_pre <- sprintf("
    SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
           l.census_tract AS tract, l.year AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM hmda.lar_panel l JOIN hmda.avery_crosswalk a %s
    WHERE l.action_taken='1'
      AND LENGTH(l.census_tract)=11 AND l.year < 2018 AND l.year >= %d %s
    GROUP BY rssdid, l.census_tract, l.year", join_pre, min_year, where_extra)
  q_post <- sprintf("
    SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
           l.census_tract AS tract, l.year AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM hmda.lar_panel l JOIN hmda.avery_crosswalk a %s
    WHERE l.action_taken='1'
      AND LENGTH(l.census_tract)=11 AND l.year >= 2018 AND l.year >= %d %s
    GROUP BY rssdid, l.census_tract, l.year", join_post, min_year, where_extra)
  rbind(dbGetQuery(con, q_pre), dbGetQuery(con, q_post))
}

con <- dbConnect(duckdb())
dbExecute(con, sprintf("ATTACH '%s' AS hmda (READ_ONLY)", HMDA_DB))

# All purchase
cat("[S5] querying HMDA purchase...\n")
purch_tract <- run_variant(con, "AND l.loan_purpose='1'", 2000)
flow <- sample_flow_step(flow, "HMDA purchase CERT x tract x YEAR rows",
                         setDT(copy(purch_tract)))

# Refinance (handle 2018 schema change in-query)
cat("[S5] querying HMDA refinance...\n")
refi_pre <- sprintf("
  SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
         l.census_tract AS tract, l.year AS YEAR,
         SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM hmda.lar_panel l JOIN hmda.avery_crosswalk a %s
  WHERE l.action_taken='1' AND l.loan_purpose='3'
    AND LENGTH(l.census_tract)=11 AND l.year < 2018 AND l.year >= 2000
  GROUP BY rssdid, l.census_tract, l.year", join_pre)
refi_post <- sprintf("
  SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
         l.census_tract AS tract, l.year AS YEAR,
         SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM hmda.lar_panel l JOIN hmda.avery_crosswalk a %s
  WHERE l.action_taken='1' AND l.loan_purpose IN ('31','32')
    AND LENGTH(l.census_tract)=11 AND l.year >= 2018
  GROUP BY rssdid, l.census_tract, l.year", join_post)
refi_tract <- rbind(dbGetQuery(con, refi_pre), dbGetQuery(con, refi_post))

# Second-lien
cat("[S5] querying HMDA second-lien...\n")
sl_tract <- run_variant(con, "AND l.loan_purpose='1' AND l.lien_status='2'", 2004)

# Jumbo (needs CLL panel registered)
cll <- setDT(load_exact(CLL_PANEL))
cll[, `:=`(county = str_pad(as.character(county), 5, "left", "0"),
           year = as.integer(year), cll_1unit = as.numeric(cll_1unit))]
duckdb_register(con, "cll_temp", cll)
cat("[S5] querying HMDA jumbo...\n")
q_jumbo_pre <- sprintf("
  SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
         l.census_tract AS tract, l.year AS YEAR,
         SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM hmda.lar_panel l
  JOIN hmda.avery_crosswalk a %s
  JOIN cll_temp c ON LEFT(l.census_tract,5) = c.county AND l.year = c.year
  WHERE l.action_taken='1' AND l.loan_purpose='1'
    AND LENGTH(l.census_tract)=11 AND l.year BETWEEN 2012 AND 2017
    AND CAST(l.loan_amount AS DOUBLE) * 1000 > c.cll_1unit
  GROUP BY rssdid, l.census_tract, l.year", join_pre)
q_jumbo_post <- sprintf("
  SELECT CAST(a.rssd_id AS BIGINT) AS rssdid,
         l.census_tract AS tract, l.year AS YEAR,
         SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
  FROM hmda.lar_panel l
  JOIN hmda.avery_crosswalk a %s
  JOIN cll_temp c ON LEFT(l.census_tract,5) = c.county AND l.year = c.year
  WHERE l.action_taken='1' AND l.loan_purpose='1'
    AND LENGTH(l.census_tract)=11 AND l.year >= 2018
    AND CAST(l.loan_amount AS DOUBLE) * 1000 > c.cll_1unit
  GROUP BY rssdid, l.census_tract, l.year", join_post)
jumbo_tract <- rbind(dbGetQuery(con, q_jumbo_pre), dbGetQuery(con, q_jumbo_post))
dbDisconnect(con, shutdown = TRUE)

# ---- 4. Aggregate to zip x YEAR at CERT level + three universes ------------
# aggregate_to_zip_cert:
#   tract_df -> CERT x zip x YEAR with hmda_amt, via RES_RATIO + cert_rssd.
aggregate_to_zip_cert <- function(tract_df) {
  dt <- setDT(copy(tract_df))
  dt <- dt[!is.na(rssdid) & rssdid != 0 & !is.na(tract)]
  dt[, tract := str_pad(as.character(tract), 11, "left", "0")]
  dt <- dt[, .(hmda_amt = sum(hmda_amt)), by = .(rssdid, tract, YEAR)]
  dz <- merge(dt, xwalk[, .(tract = TRACT, ZIP, RES_RATIO)],
              by = "tract", allow.cartesian = TRUE)
  dz[, hmda_amt_zip := hmda_amt * RES_RATIO]
  dz <- dz[, .(hmda_amt = sum(hmda_amt_zip, na.rm = TRUE)),
           by = .(rssdid, zip = ZIP, YEAR)]
  # rssdid -> CERT
  dz <- merge(dz, cert_rssd, by.x = c("rssdid", "YEAR"),
              by.y = c("RSSDID", "YEAR"))
  dz <- dz[!is.na(CERT),
           .(hmda_amt = sum(hmda_amt)), by = .(CERT, zip, YEAR)]
  dz
}

# Growth-at-zip (2-year symmetric) for a given universe.
growth_by_universe <- function(dz, universe = c("all", "branch", "incumbent")) {
  universe <- match.arg(universe)
  dz <- copy(dz)
  if (universe == "branch")    dz <- merge(dz, zip_branch_set,
                                           by = c("CERT", "zip", "YEAR"))
  if (universe == "incumbent") dz <- merge(dz, zip_inc_set,
                                           by = c("CERT", "zip", "YEAR"))
  setorder(dz, CERT, zip, YEAR)
  dz[, lag1  := shift(hmda_amt, 1L, type = "lag"),  by = .(CERT, zip)]
  dz[, yr_l1 := shift(YEAR,     1L, type = "lag"),  by = .(CERT, zip)]
  dz[, lead1 := shift(hmda_amt, 1L, type = "lead"), by = .(CERT, zip)]
  dz[, yr_f1 := shift(YEAR,     1L, type = "lead"), by = .(CERT, zip)]
  dz[, lag1  := fifelse(yr_l1 == YEAR - 1, lag1,  NA_real_)]
  dz[, lead1 := fifelse(yr_f1 == YEAR + 1, lead1, NA_real_)]
  dz <- dz[!is.na(lag1) & lag1 > 0 & !is.na(lead1)]
  cy <- dz[, .(h_lag1 = sum(lag1), h_lead1 = sum(lead1)), by = .(zip, YEAR)]
  cy[, g := (h_lead1 - h_lag1) / h_lag1]
  cy[!is.na(g), g := wins(g)]
  cy[, .(zip, YEAR, g)]
}

build_outcome <- function(tract_df, outcome_label) {
  dz <- aggregate_to_zip_cert(tract_df)
  out_list <- lapply(c("all", "branch", "incumbent"), function(u) {
    g <- growth_by_universe(dz, u)
    setnames(g, "g", paste0("hmda_", outcome_label, "_gr_", u))
    g
  })
  Reduce(function(x, y) merge(x, y, by = c("zip", "YEAR"), all = TRUE), out_list)
}

cat("[S5] aggregating four outcomes x three universes...\n")
ot_purch <- build_outcome(purch_tract, "purch")
ot_refi  <- build_outcome(refi_tract,  "refi")
ot_sl    <- build_outcome(sl_tract,    "sl")
ot_jumbo <- build_outcome(jumbo_tract, "jumbo")

all_out <- Reduce(function(x, y) merge(x, y, by = c("zip", "YEAR"), all = TRUE),
                  list(ot_purch, ot_refi, ot_sl, ot_jumbo))
flow <- sample_flow_step(flow, "combined HMDA zip x YEAR panel", all_out,
                         unit_cols = c("zip", "YEAR"))

# ---- 5. Merge onto zip_tech_sample (regression inputs + controls) ----------
ztp_path <- resolve_latest("data/constructed", "^zip_tech_sample_v2_\\d{8}\\.rds$")
ztp <- setDT(load_exact(ztp_path))
out <- merge(ztp, all_out, by = c("zip", "YEAR"), all.x = TRUE)

out_path <- file.path("data/constructed", paste0("hmda_panels_v2_", DATE_TAG, ".rds"))
saveRDS(out, out_path)
cat("\nSaved:", out_path, " | nrow =", nrow(out), "\n")
cat("sha256:", digest::digest(out_path, algo = "sha256", file = TRUE), "\n")

cat("\nNon-NA per outcome x universe:\n")
for (oc in c("purch", "refi", "sl", "jumbo")) {
  for (u in c("all", "branch", "incumbent")) {
    col <- paste0("hmda_", oc, "_gr_", u)
    cat(sprintf("  %-28s %d\n", col, sum(!is.na(out[[col]]))))
  }
}

sample_flow_save(flow)
