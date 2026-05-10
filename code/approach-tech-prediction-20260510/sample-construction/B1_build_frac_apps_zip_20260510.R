# B1_build_frac_apps_zip_20260510.R
#
# Build branch-count weighted `frac_apps_zip` at (zip, YEAR):
#   numerator   = # branches in zip-YEAR whose owning bank has launched app
#   denominator = # branches in zip-YEAR (pool with dep_lag1_a > 0,
#                 same denominator that drives `total_deps` in the upstream
#                 zip_tech_sample build).
#
# Joins onto the existing zip_tech_sample and saves an enriched rds.

rm(list = ls())
gc()

source("code/approach-tech-prediction-20260510/00_common.R")

external_data_path <- "C:/Users/dimut/OneDrive/data/"
closure_path       <- file.path(external_data_path, "closure_opening_data_simple.rds")
app_panel_path     <- file.path(external_data_path, "CH_full_app_reviews_panel.csv")

# ── 1. Closure panel ─────────────────────────────────────────────────────────
# Source: ~/OneDrive/data/closure_opening_data_simple.rds (SOD branch panel)
# Built by:   external SOD pipeline (raw)
# Contents:   branch-year panel (UNINUMBR, CERT, YEAR, ZIPBR, STCNTYBR, DEPSUMBR, closed)
raw <- setDT(readRDS(closure_path))
raw[, county := str_pad(as.integer(STCNTYBR), 5, "left", "0")]
raw[, zip    := str_pad(as.integer(ZIPBR),    5, "left", "0")]
raw[, YEAR   := as.integer(YEAR)]
raw[, DEPSUMBR := as.numeric(DEPSUMBR)]

setorder(raw, UNINUMBR, YEAR)
raw[, dep_lag1 := shift(DEPSUMBR, 1L, type = "lag"), by = UNINUMBR]
raw[, yr_lag1  := shift(YEAR,     1L, type = "lag"), by = UNINUMBR]
raw[, dep_lag1_a := fifelse(yr_lag1 == YEAR - 1L, dep_lag1, NA_real_)]

# ── 2. App panel (same loader as upstream zip_tech_sample build) ─────────────
# Source: ~/OneDrive/data/CH_full_app_reviews_panel.csv
# Contents:   bank-year app launch indicator (FDIC_certificate_id, year, first_app_available)
app <- fread(app_panel_path)
app <- app[, .(
  CERT = as.integer(FDIC_certificate_id),
  YEAR = as.integer(year),
  has_app = as.integer(first_app_available == 1)
)]
app <- app[!duplicated(app[, .(CERT, YEAR)])]

# Extend 2022-2025 using 2021 (raw app panel ends 2021); matches upstream convention.
app_2021 <- app[YEAR == 2021L]
if (nrow(app_2021) > 0) {
  app <- rbind(app, rbindlist(lapply(2022:2025, function(y) {
    out <- copy(app_2021); out[, YEAR := y]; out
  })))
}

# ── 3. Branch-level merge of has_app ─────────────────────────────────────────
# Restrict to (UNINUMBR, YEAR) rows that are part of the denominator pool used
# by upstream `total_deps` (i.e., dep_lag1_a > 0). This is the same set that
# defines `branches_lag1` in zip_tech_sample.
raw_pool <- raw[!is.na(dep_lag1_a) & dep_lag1_a > 0]
raw_pool <- merge(raw_pool, app[, .(CERT, YEAR, has_app)],
                  by = c("CERT", "YEAR"), all.x = TRUE)
raw_pool[is.na(has_app), has_app := 0L]

# ── 4. Aggregate to (zip, YEAR) ──────────────────────────────────────────────
# Two weighting schemes:
#   frac_apps_zip_count = #branches with app / #branches            (count weighted)
#   frac_apps_zip_dep   = deposits at app-bank branches / total deposits
#                                                                   (deposit weighted)
# Deposit weighting uses dep_lag1_a (t-1 deposits), matching the
# denominator timing of `share_deps_closed`.
zip_apps <- raw_pool[, .(
  n_branches_zip       = uniqueN(UNINUMBR),
  n_branches_app_zip   = uniqueN(UNINUMBR[has_app == 1L]),
  total_deps_pool      = sum(dep_lag1_a, na.rm = TRUE),
  app_deps_pool        = sum(dep_lag1_a * (has_app == 1L), na.rm = TRUE)
), by = .(zip, YEAR)]
zip_apps[, frac_apps_zip_count := n_branches_app_zip / pmax(n_branches_zip, 1)]
zip_apps[, frac_apps_zip_dep   := app_deps_pool       / pmax(total_deps_pool, 1)]
# legacy alias retained for any downstream compatibility
zip_apps[, frac_apps_zip       := frac_apps_zip_count]

# ── 5. Sanity output: frac_apps_zip distribution by YEAR ────────────────────
cat("\n=== frac_apps_zip distribution by YEAR ===\n")
print(zip_apps[, .(
  n_zip_yrs   = .N,
  mean_count  = round(mean(frac_apps_zip_count, na.rm = TRUE), 3),
  mean_dep    = round(mean(frac_apps_zip_dep,   na.rm = TRUE), 3)
), by = YEAR][order(YEAR)])

# ── 6. Merge onto existing zip_tech_sample ───────────────────────────────────
# Source: data/zip_tech_sample_YYYYMMDD.rds
# Built by:   code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R
# Contents:   zip-year analysis panel (outcome, share_deps_closed, controls,
#             FE keys, mobile, sophisticated).
dt <- setDT(load_latest("data", "^zip_tech_sample_\\d{8}\\.rds$"))
n_pre <- nrow(dt)

dt <- merge(dt, zip_apps[, .(zip, YEAR, frac_apps_zip,
                             frac_apps_zip_count, frac_apps_zip_dep,
                             n_branches_zip, n_branches_app_zip)],
            by = c("zip", "YEAR"), all.x = TRUE)
dt[is.na(frac_apps_zip),       frac_apps_zip       := 0]
dt[is.na(frac_apps_zip_count), frac_apps_zip_count := 0]
dt[is.na(frac_apps_zip_dep),   frac_apps_zip_dep   := 0]

cat("\n=== Merge check ===\n")
cat("zip_tech_sample rows pre-merge:  ", n_pre, "\n")
cat("rows post-merge:                  ", nrow(dt), "\n")
cat("frac_apps_zip non-zero share:     ",
    round(mean(dt$frac_apps_zip > 0, na.rm = TRUE), 3), "\n")

cat("\ncor(count, dep)                          :",
    round(cor(dt$frac_apps_zip_count, dt$frac_apps_zip_dep, use = "complete.obs"), 3), "\n")
cat("cor(count, perc_hh_wMobileSub)           :",
    round(cor(dt$frac_apps_zip_count, dt$perc_hh_wMobileSub, use = "complete.obs"), 3), "\n")
cat("cor(dep,   perc_hh_wMobileSub)           :",
    round(cor(dt$frac_apps_zip_dep,   dt$perc_hh_wMobileSub, use = "complete.obs"), 3), "\n")

# ── 7. Save ──────────────────────────────────────────────────────────────────
out_path <- file.path(data_path, paste0("zip_tech_with_frac_apps_", dat_suffix, ".rds"))
saveRDS(dt, out_path)
cat("\nSaved:", out_path, "\n")
cat("Rows:", nrow(dt), "\n")
