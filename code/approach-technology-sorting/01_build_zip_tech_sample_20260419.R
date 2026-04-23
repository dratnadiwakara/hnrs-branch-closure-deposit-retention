rm(list = ls())
gc()

library(data.table)
library(stringr)

dat_suffix <- format(Sys.time(), "%Y%m%d")

# ── Paths ──────────────────────────────────────────────────────────────────────
external_data_path <- "C:/Users/dimut/OneDrive/data/"

closure_path   <- file.path(external_data_path, "closure_opening_data_simple.rds")
app_panel_path <- file.path(external_data_path, "CH_full_app_reviews_panel.csv")
zip_demo_path  <- file.path(external_data_path, "nrs_branch_closure/zip_demographics_panel.rds")
mobile_path    <- "data/raw/perc_hh_wMobileSub.csv"

# ── Helpers ───────────────────────────────────────────────────────────────────
wins <- function(x, lo = 0.025, hi = 0.975) {
  q <- quantile(x, c(lo, hi), na.rm = TRUE)
  pmin(pmax(x, q[1]), q[2])
}

sum_safe <- function(x) if (all(is.na(x))) NA_real_ else as.numeric(sum(x, na.rm = TRUE))

# ── 1. Load closure panel ─────────────────────────────────────────────────────
raw <- setDT(readRDS(closure_path))
raw[, county := str_pad(as.integer(STCNTYBR), 5, "left", "0")]
raw[, zip    := str_pad(as.integer(ZIPBR),    5, "left", "0")]
raw[, YEAR   := as.integer(YEAR)]
raw[, closed := as.integer(fifelse(is.na(closed), 0L, closed))]
raw[, DEPSUMBR := as.numeric(DEPSUMBR)]

setorder(raw, UNINUMBR, YEAR)
raw[, dep_lag1  := shift(DEPSUMBR, 1L, type = "lag"),  by = UNINUMBR]
raw[, yr_lag1   := shift(YEAR,     1L, type = "lag"),  by = UNINUMBR]
raw[, dep_lead1 := shift(DEPSUMBR, 1L, type = "lead"), by = UNINUMBR]
raw[, yr_lead1  := shift(YEAR,     1L, type = "lead"), by = UNINUMBR]
raw[, dep_lag1_a  := fifelse(yr_lag1  == YEAR - 1L, dep_lag1,  NA_real_)]
raw[, dep_lead1_a := fifelse(yr_lead1 == YEAR + 1L, dep_lead1, NA_real_)]

# ── 2. Load app panel → bank-type lookup (CERT×YEAR) ─────────────────────────
app <- fread(app_panel_path)
app <- app[, .(
  CERT = as.integer(FDIC_certificate_id),
  YEAR = as.integer(year),
  has_app = as.integer(first_app_available == 1),
  tot_assets
)]
# Deduplicate (take first row per CERT×YEAR to avoid blowing up join)
app <- app[!duplicated(app[, .(CERT, YEAR)])]

# Extend to 2022-2025 using 2021 values (app panel ends at 2021)
app_2021 <- app[YEAR == 2021L]
if (nrow(app_2021) > 0) {
  app <- rbind(app, rbindlist(lapply(2022:2025, function(y) {
    out <- copy(app_2021); out[, YEAR := y]; out
  })))
}

# Bank-size classification (time-invariant: based on ever exceeding threshold in app panel)
top4_cert  <- c(628L, 3510L, 3511L, 7213L)
large_cert <- unique(app[!is.na(tot_assets) & tot_assets > 100000000L, CERT])

# ── 3. Zip-year panel: base aggregates (identical to main_regressions.qmd §2) ─
#
# Build from raw (not raw_a) to guarantee N matches baseline exactly.
# Type decompositions are computed separately and merged on top.

# Incumbent flag: bank with no closures in (zip, YEAR)
bank_zip <- raw[, .(n_closes = sum(closed, na.rm = TRUE)), by = .(CERT, zip, YEAR)]
bank_zip[, is_inc := as.integer(n_closes == 0L)]
raw_z <- merge(raw, bank_zip[, .(CERT, zip, YEAR, is_inc, n_closes)],
               by = c("CERT", "zip", "YEAR"), all.x = TRUE)
raw_z[is.na(is_inc), is_inc := 0L]

# Total zip-year deposits at t-1 and branch count
zt <- raw_z[!is.na(dep_lag1_a) & dep_lag1_a > 0, .(
  total_deps    = sum(dep_lag1_a),
  branches_lag1 = uniqueN(UNINUMBR),
  n_banks       = uniqueN(CERT)
), by = .(zip, YEAR)]

# Closure counts and aggregate closed deposits
z_events <- raw_z[, .(n_closed_zip = sum(closed, na.rm = TRUE)), by = .(zip, YEAR)]
zc_all <- raw_z[closed == 1L & !is.na(dep_lag1_a) & dep_lag1_a > 0,
  .(closed_deps = sum(dep_lag1_a)), by = .(zip, YEAR)]

# Incumbent deposit aggregates (current + lead)
zi_curr <- raw_z[is_inc == 1L & !is.na(DEPSUMBR) & DEPSUMBR > 0, .(
  inc_curr    = sum(as.numeric(DEPSUMBR)),
  n_inc_banks = uniqueN(CERT)
), by = .(zip, YEAR)]

zi_tp1 <- raw_z[is_inc == 1L & !is.na(dep_lead1_a), .(
  inc_tp1 = sum(dep_lead1_a)
), by = .(zip, YEAR)]

# ── 4. Zip-year decomposed closure shares ────────────────────────────────────
#
# Join bank-type indicators from app panel onto branch-level closure rows,
# then aggregate to zip×YEAR. Building from raw_z (not raw_a) keeps the
# zip panel construction identical to the baseline.
#
# Categories: top4 | large_but_not_top4 | small (mutually exclusive, sum = total)
# App split:  app (non-top4 with app) | noapp
#
raw_closed <- raw_z[closed == 1L & !is.na(dep_lag1_a) & dep_lag1_a > 0]
raw_closed <- merge(raw_closed, app[, .(CERT, YEAR, has_app, tot_assets)],
                    by = c("CERT", "YEAR"), all.x = TRUE)
raw_closed[is.na(has_app), has_app := 0L]
raw_closed[, is_top4  := as.integer(CERT %in% top4_cert)]
raw_closed[, is_large := as.integer(CERT %in% large_cert)]

zc_type <- raw_closed[, .(
  closed_deps_top4  = sum_safe(fifelse(is_top4 == 1L, dep_lag1_a, NA_real_)),
  closed_deps_large = sum_safe(fifelse(is_top4 == 0L & is_large == 1L, dep_lag1_a, NA_real_)),
  closed_deps_small = sum_safe(fifelse(is_large == 0L, dep_lag1_a, NA_real_)),
  closed_deps_app   = sum_safe(fifelse(has_app == 1L & is_top4 == 0L, dep_lag1_a, NA_real_)),
  closed_deps_noapp = sum_safe(fifelse(has_app == 0L, dep_lag1_a, NA_real_))
), by = .(zip, YEAR)]

# ── 5. Assemble zip panel ─────────────────────────────────────────────────────
zip_pan <- Reduce(
  function(x, y) merge(x, y, by = c("zip", "YEAR"), all.x = TRUE),
  list(zt, z_events, zc_all, zi_curr, zi_tp1, zc_type)
)

zip_pan[is.na(closed_deps),   closed_deps   := 0]
zip_pan[is.na(n_closed_zip),  n_closed_zip  := 0L]
zip_pan[is.na(closed_deps_top4),  closed_deps_top4  := 0]
zip_pan[is.na(closed_deps_large), closed_deps_large := 0]
zip_pan[is.na(closed_deps_small), closed_deps_small := 0]
zip_pan[is.na(closed_deps_app),   closed_deps_app   := 0]
zip_pan[is.na(closed_deps_noapp), closed_deps_noapp := 0]

# Shares (denominator = total zip deposits at t-1)
zip_pan[, share_deps_closed       := closed_deps       / pmax(total_deps, 1)]
zip_pan[, share_deps_closed_top4  := closed_deps_top4  / pmax(total_deps, 1)]
zip_pan[, share_deps_closed_large := closed_deps_large / pmax(total_deps, 1)]
zip_pan[, share_deps_closed_small := closed_deps_small / pmax(total_deps, 1)]
zip_pan[, share_deps_closed_app   := closed_deps_app   / pmax(total_deps, 1)]
zip_pan[, share_deps_closed_noapp := closed_deps_noapp / pmax(total_deps, 1)]

zip_pan[, log_n_branches  := log1p(branches_lag1)]
zip_pan[, log_n_inc_banks := log1p(n_inc_banks)]
zip_pan[, log_total_deps  := log1p(total_deps)]

# Deposit growth t-3 to t-1: shift total_deps (already t-1) by 2 more years
setorder(zip_pan, zip, YEAR)
zip_pan[, total_deps_3ya := shift(total_deps, 2L, type = "lag"), by = zip]
zip_pan[, dep_growth_t3t1 := fifelse(
  !is.na(total_deps_3ya) & total_deps_3ya > 0,
  (total_deps - total_deps_3ya) / total_deps_3ya,
  NA_real_
)]
zip_pan[!is.na(dep_growth_t3t1), dep_growth_t3t1 := wins(dep_growth_t3t1)]
zip_pan[, total_deps_3ya := NULL]

zip_pan[, outcome := fifelse(total_deps > 0, (inc_tp1 - inc_curr) / total_deps, NA_real_)]
zip_pan[!is.na(outcome), outcome := wins(outcome)]

# County identifier (zip → county map, first match)
zip_map <- unique(raw[, .(zip, county)])[!duplicated(zip)]
zip_pan <- merge(zip_pan, zip_map, by = "zip", all.x = TRUE)
zip_pan[, county_yr := paste0(county, "_", YEAR)]

# ── 6. Sample filters (match baseline) ───────────────────────────────────────
zip_pan <- zip_pan[
  YEAR %between% c(2000L, 2024L) &
  !is.na(n_inc_banks) & n_inc_banks >= 2L &
  branches_lag1 >= 2L &
  !is.na(outcome) &
  !is.na(county)
]

# ── 7. Merge zip demographics (sophisticated filter) ─────────────────────────
zip_demo <- setDT(readRDS(zip_demo_path))
zip_demo <- zip_demo[!is.na(zip), .(
  zip  = str_pad(as.integer(zip), 5, "left", "0"),
  YEAR = as.integer(yr),
  sophisticated
)]
zip_pan <- merge(zip_pan, zip_demo, by = c("zip", "YEAR"), all.x = TRUE)
zip_pan <- zip_pan[!is.na(sophisticated)]

# ── 8. Merge mobile subscription share (county×YEAR) ─────────────────────────
perc_mob <- fread(mobile_path)
setDT(perc_mob)
perc_mob[, county := str_pad(as.character(county_fips), 5, "left", "0")]
perc_mob[, YEAR   := as.integer(year)]
setorder(perc_mob, county, -YEAR)
perc_mob[, perc_hh_wMobileSub := nafill(perc_hh_wMobileSub, type = "locf"), by = county]

# Extend coverage past 2023 (raw source ends 2023). Synthesize rows for
# 2024–2025 per county, copying the county's 2023 value.
extend_years <- setdiff(2024L:2025L, unique(perc_mob$YEAR))
if (length(extend_years)) {
  mob_2023_tbl <- perc_mob[YEAR == 2023L, .(county, mob_2023 = perc_hh_wMobileSub)]
  extra <- CJ(county = mob_2023_tbl$county, YEAR = extend_years)
  extra <- merge(extra, mob_2023_tbl, by = "county", all.x = TRUE)
  extra[, perc_hh_wMobileSub := mob_2023][, mob_2023 := NULL]
  extra[, (setdiff(names(perc_mob), names(extra))) := NA]
  perc_mob <- rbind(perc_mob, extra, use.names = TRUE, fill = TRUE)
}

zip_pan <- merge(zip_pan, perc_mob[, .(county, YEAR, perc_hh_wMobileSub)],
                 by = c("county", "YEAR"), all.x = TRUE)
zip_pan[, high_mobile := as.integer(
  perc_hh_wMobileSub > median(perc_hh_wMobileSub, na.rm = TRUE)
), by = YEAR]

# ── 9. Verification checks ────────────────────────────────────────────────────
cat("\n=== Sample N by period ===\n")
cat("2000-07:", zip_pan[YEAR %between% c(2000, 2007), .N], "\n")
cat("2008-11:", zip_pan[YEAR %between% c(2008, 2011), .N], "\n")
cat("2012-19:", zip_pan[YEAR %between% c(2012, 2019), .N], "\n")
cat("2020-24:", zip_pan[YEAR %between% c(2020, 2024), .N], "\n")
cat("Expected (baseline Table 2): 70727 / 44953 / 89982 / 51601\n\n")

cat("=== Decomposition sum check (should be ~0) ===\n")
zip_pan[, sum_check := share_deps_closed_top4 + share_deps_closed_large + share_deps_closed_small - share_deps_closed]
cat("Max abs diff:", max(abs(zip_pan$sum_check), na.rm = TRUE), "\n\n")

cat("=== Share summaries ===\n")
print(zip_pan[, lapply(.SD, function(x) round(mean(x > 0, na.rm = TRUE), 3)),
              .SDcols = c("share_deps_closed", "share_deps_closed_top4",
                          "share_deps_closed_large", "share_deps_closed_small",
                          "share_deps_closed_app", "share_deps_closed_noapp")])

# ── 10. Save ──────────────────────────────────────────────────────────────────
out_path <- file.path("data", paste0("zip_tech_sample_", dat_suffix, ".rds"))
saveRDS(zip_pan, out_path)
cat("\nSaved:", out_path, "\n")
cat("Rows:", nrow(zip_pan), "\n")
