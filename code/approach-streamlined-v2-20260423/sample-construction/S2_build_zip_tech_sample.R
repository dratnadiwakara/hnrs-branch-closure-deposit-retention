# S2_build_zip_tech_sample.R
# V2 rebuild of zip-year incumbent reallocation panel.
#
# Changes from v1 (code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R):
#   1. ZIP -> county via HUD max-TOT_RATIO crosswalk (S1 output), NOT first-match.
#   2. Orthogonal size x app decomposition: five mutually exclusive groups
#      {top4, large_app, large_noapp, small_app, small_noapp} summing to total.
#      Legacy (top4/large/small, app/noapp) kept as aggregates for comparison.
#   3. Sample-flow diagnostic written to diagnostics/flow_zip_tech_v2_*.md.
#   4. LOCF for mobile/app centralized (extend_county_year_locf helper).
#   5. load_exact() with explicit paths; no mtime lookups.
#   6. Decomposition identity asserted (sum of orthogonal = total, |err|<1e-8).
#
# Output: data/constructed/zip_tech_sample_v2_YYYYMMDD.rds

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

CLOSURE_PANEL  <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
APP_PANEL      <- "C:/Users/dimut/OneDrive/data/CH_full_app_reviews_panel.csv"
ZIP_DEMO       <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/zip_demographics_panel.rds"
MOBILE_PANEL   <- "data/raw/perc_hh_wMobileSub.csv"
ZIP_CTY_XW     <- "data/constructed/zip_county_xwalk_v2.rds"

sum_safe <- function(x) if (all(is.na(x))) NA_real_ else as.numeric(sum(x, na.rm = TRUE))

flow <- sample_flow_init("zip_tech_v2")

# ---- 1. Closure panel -------------------------------------------------------
raw <- setDT(load_exact(CLOSURE_PANEL))
raw[, `:=`(
  county   = str_pad(as.integer(STCNTYBR), 5, "left", "0"),
  zip      = str_pad(as.integer(ZIPBR),    5, "left", "0"),
  YEAR     = as.integer(YEAR),
  closed   = as.integer(fifelse(is.na(closed), 0L, closed)),
  DEPSUMBR = as.numeric(DEPSUMBR)
)]
setorder(raw, UNINUMBR, YEAR)
raw[, dep_lag1   := shift(DEPSUMBR, 1L, type = "lag"),  by = UNINUMBR]
raw[, yr_lag1    := shift(YEAR,     1L, type = "lag"),  by = UNINUMBR]
raw[, dep_lead1  := shift(DEPSUMBR, 1L, type = "lead"), by = UNINUMBR]
raw[, yr_lead1   := shift(YEAR,     1L, type = "lead"), by = UNINUMBR]
raw[, dep_lag1_a  := fifelse(yr_lag1  == YEAR - 1L, dep_lag1,  NA_real_)]
raw[, dep_lead1_a := fifelse(yr_lead1 == YEAR + 1L, dep_lead1, NA_real_)]
flow <- sample_flow_step(flow, "raw closure panel", raw, unit_cols = c("zip", "YEAR"))

# ---- 2. Bank-app panel (extended) ------------------------------------------
app <- load_exact(APP_PANEL)
app <- app[, .(
  CERT = as.integer(FDIC_certificate_id),
  YEAR = as.integer(year),
  has_app = as.integer(first_app_available == 1),
  tot_assets = as.numeric(tot_assets)
)]
app <- unique(app, by = c("CERT", "YEAR"))
# LOCF per CERT to 2025 (raw ends 2021). Uses the same carry-forward scheme as v1.
setorder(app, CERT, YEAR)
app_2021 <- app[YEAR == 2021L]
if (nrow(app_2021)) {
  app <- rbind(app, rbindlist(lapply(2022:2025, function(y) {
    out <- copy(app_2021); out[, YEAR := y]; out
  })))
}

top4_cert  <- c(628L, 3510L, 3511L, 7213L)
large_cert <- unique(app[!is.na(tot_assets) & tot_assets > 100000000L, CERT])

# ---- 3. Incumbent flag and zip-year aggregates -----------------------------
bank_zip <- raw[, .(n_closes = sum(closed, na.rm = TRUE)), by = .(CERT, zip, YEAR)]
bank_zip[, is_inc := as.integer(n_closes == 0L)]
raw_z <- merge(raw, bank_zip[, .(CERT, zip, YEAR, is_inc, n_closes)],
               by = c("CERT", "zip", "YEAR"), all.x = TRUE)
raw_z[is.na(is_inc), is_inc := 0L]
flow <- sample_flow_step(flow, "after incumbent flag", raw_z, unit_cols = c("zip", "YEAR"))

zt <- raw_z[!is.na(dep_lag1_a) & dep_lag1_a > 0, .(
  total_deps    = sum(dep_lag1_a),
  branches_lag1 = uniqueN(UNINUMBR),
  n_banks       = uniqueN(CERT)
), by = .(zip, YEAR)]
z_events <- raw_z[, .(n_closed_zip = sum(closed, na.rm = TRUE)), by = .(zip, YEAR)]
zc_all   <- raw_z[closed == 1L & !is.na(dep_lag1_a) & dep_lag1_a > 0,
  .(closed_deps = sum(dep_lag1_a)), by = .(zip, YEAR)]
zi_curr  <- raw_z[is_inc == 1L & !is.na(DEPSUMBR) & DEPSUMBR > 0, .(
  inc_curr    = sum(as.numeric(DEPSUMBR)),
  n_inc_banks = uniqueN(CERT)
), by = .(zip, YEAR)]
zi_tp1   <- raw_z[is_inc == 1L & !is.na(dep_lead1_a),
  .(inc_tp1 = sum(dep_lead1_a)), by = .(zip, YEAR)]

# ---- 4. Orthogonal size x app decomposition --------------------------------
# Five mutually exclusive groups:
#   top4                (all top-4 closures, app ignored; regulatory scale class)
#   large_app           (large non-top4, has_app==1)
#   large_noapp         (large non-top4, has_app==0)
#   small_app           (small, has_app==1)
#   small_noapp         (small, has_app==0)
# Sum == share_deps_closed_total. Legacy aggregates kept for compatibility.
raw_closed <- raw_z[closed == 1L & !is.na(dep_lag1_a) & dep_lag1_a > 0]
raw_closed <- merge(raw_closed, app[, .(CERT, YEAR, has_app)],
                    by = c("CERT", "YEAR"), all.x = TRUE)
raw_closed[is.na(has_app), has_app := 0L]
raw_closed[, is_top4    := as.integer(CERT %in% top4_cert)]
raw_closed[, is_large   := as.integer(CERT %in% large_cert & is_top4 == 0L)]
raw_closed[, is_small   := as.integer(is_top4 == 0L & is_large == 0L)]
raw_closed[, grp := fcase(
  is_top4 == 1L,                         "top4",
  is_large == 1L & has_app == 1L,        "large_app",
  is_large == 1L & has_app == 0L,        "large_noapp",
  is_small == 1L & has_app == 1L,        "small_app",
  is_small == 1L & has_app == 0L,        "small_noapp",
  default = NA_character_)]
stopifnot(!any(is.na(raw_closed$grp)))

zc_type <- dcast(raw_closed, zip + YEAR ~ grp, value.var = "dep_lag1_a", fun.aggregate = sum, fill = 0)
# Ensure all five columns exist even if empty.
for (g in c("top4", "large_app", "large_noapp", "small_app", "small_noapp")) {
  if (!g %in% names(zc_type)) zc_type[[g]] <- 0
}
setnames(zc_type,
  c("top4", "large_app", "large_noapp", "small_app", "small_noapp"),
  c("closed_deps_top4", "closed_deps_large_app", "closed_deps_large_noapp",
    "closed_deps_small_app", "closed_deps_small_noapp"))

# ---- 5. Assemble zip panel -------------------------------------------------
zip_pan <- Reduce(
  function(x, y) merge(x, y, by = c("zip", "YEAR"), all.x = TRUE),
  list(zt, z_events, zc_all, zi_curr, zi_tp1, zc_type)
)
decomp_cols <- c("closed_deps_top4", "closed_deps_large_app", "closed_deps_large_noapp",
                 "closed_deps_small_app", "closed_deps_small_noapp")
for (cc in c("closed_deps", "n_closed_zip", decomp_cols)) {
  zip_pan[is.na(get(cc)), (cc) := 0]
}

# Shares
zip_pan[, share_deps_closed := closed_deps / pmax(total_deps, 1)]
for (g in c("top4", "large_app", "large_noapp", "small_app", "small_noapp")) {
  src <- paste0("closed_deps_", g)
  dst <- paste0("share_deps_closed_", g)
  zip_pan[, (dst) := get(src) / pmax(total_deps, 1)]
}

# Legacy aggregates (so v1-style decomposition regressions still run for
# comparison): top4 + large + small = total; app/noapp overlap.
zip_pan[, closed_deps_large := closed_deps_large_app + closed_deps_large_noapp]
zip_pan[, closed_deps_small := closed_deps_small_app + closed_deps_small_noapp]
zip_pan[, closed_deps_app   := closed_deps_large_app + closed_deps_small_app]
zip_pan[, closed_deps_noapp := closed_deps_top4 + closed_deps_large_noapp + closed_deps_small_noapp]
for (g in c("large", "small", "app", "noapp")) {
  src <- paste0("closed_deps_", g); dst <- paste0("share_deps_closed_", g)
  zip_pan[, (dst) := get(src) / pmax(total_deps, 1)]
}

# Decomposition identity: five orthogonal shares must sum to share_deps_closed.
sum_check <- zip_pan[, max(abs(
  share_deps_closed_top4 + share_deps_closed_large_app + share_deps_closed_large_noapp +
    share_deps_closed_small_app + share_deps_closed_small_noapp - share_deps_closed),
  na.rm = TRUE)]
cat("Orthogonal partition max identity error:", sum_check, "\n")
stopifnot(sum_check < 1e-8)

zip_pan[, log_n_branches  := log1p(branches_lag1)]
zip_pan[, log_n_inc_banks := log1p(n_inc_banks)]
zip_pan[, log_total_deps  := log1p(total_deps)]
setorder(zip_pan, zip, YEAR)
zip_pan[, total_deps_3ya := shift(total_deps, 2L, type = "lag"), by = zip]
zip_pan[, dep_growth_t3t1 := fifelse(
  !is.na(total_deps_3ya) & total_deps_3ya > 0,
  (total_deps - total_deps_3ya) / total_deps_3ya, NA_real_)]
zip_pan[!is.na(dep_growth_t3t1), dep_growth_t3t1 := wins(dep_growth_t3t1)]
zip_pan[, total_deps_3ya := NULL]

zip_pan[, outcome := fifelse(total_deps > 0, (inc_tp1 - inc_curr) / total_deps, NA_real_)]
zip_pan[!is.na(outcome), outcome := wins(outcome)]

# ---- 6. ZIP -> county via HUD max-TOT_RATIO (v1 FIX) -----------------------
xw <- setDT(load_exact(ZIP_CTY_XW))
zip_pan <- merge(zip_pan, xw[, .(zip, county = primary_county, max_tot_ratio, n_counties)],
                 by = "zip", all.x = TRUE)
zip_pan[, county_yr := paste0(county, "_", YEAR)]
flow <- sample_flow_step(flow, "after HUD ZIP->county merge", zip_pan, unit_cols = c("zip", "YEAR"))

# ---- 7. Sample filters ------------------------------------------------------
zip_pan <- zip_pan[
  YEAR %between% c(2000L, 2024L) &
  !is.na(n_inc_banks) & n_inc_banks >= 2L &
  branches_lag1 >= 2L &
  !is.na(outcome) &
  !is.na(county)
]
flow <- sample_flow_step(flow, "after baseline filters (n_inc>=2, branches>=2, outcome!=NA)",
                         zip_pan, unit_cols = c("zip", "YEAR"))

# ---- 8. Zip demographics (sophisticated) -----------------------------------
zip_demo <- setDT(load_exact(ZIP_DEMO))
zip_demo <- zip_demo[!is.na(zip), .(
  zip  = str_pad(as.integer(zip), 5, "left", "0"),
  YEAR = as.integer(yr),
  sophisticated)]
zip_pan <- merge(zip_pan, zip_demo, by = c("zip", "YEAR"), all.x = TRUE)
zip_pan <- zip_pan[!is.na(sophisticated)]
flow <- sample_flow_step(flow, "after sophistication filter", zip_pan,
                         unit_cols = c("zip", "YEAR"))

# ---- 9. Mobile subscription merge (LOCF to 2025) ---------------------------
perc_mob <- load_exact(MOBILE_PANEL)
perc_mob[, `:=`(
  county = str_pad(as.character(county_fips), 5, "left", "0"),
  YEAR   = as.integer(year)
)]
setorder(perc_mob, county, YEAR)
perc_mob <- extend_county_year_locf(perc_mob, "county", "YEAR",
                                    "perc_hh_wMobileSub", 2025L)
zip_pan <- merge(zip_pan, perc_mob[, .(county, YEAR, perc_hh_wMobileSub)],
                 by = c("county", "YEAR"), all.x = TRUE)
zip_pan[, high_mobile := as.integer(
  perc_hh_wMobileSub > median(perc_hh_wMobileSub, na.rm = TRUE)), by = YEAR]

# ---- 10. Save ---------------------------------------------------------------
out_path <- file.path("data/constructed",
                      paste0("zip_tech_sample_v2_", DATE_TAG, ".rds"))
saveRDS(zip_pan, out_path)
cat("\nSaved:", out_path, " | nrow =", nrow(zip_pan), "\n")
cat("sha256:", digest::digest(out_path, algo = "sha256", file = TRUE), "\n")

# ---- 11. Sample flow --------------------------------------------------------
flow <- sample_flow_step(flow, "final saved panel", zip_pan, unit_cols = c("zip", "YEAR"))
sample_flow_save(flow)

# ---- 12. Period-N sanity ----------------------------------------------------
cat("\n=== Period N ===\n")
for (p in c("2000-07", "2008-11", "2012-19", "2020-22", "2023-24")) {
  cat(sprintf("%s: %d\n", p, nrow(period_filter(zip_pan, p))))
}
