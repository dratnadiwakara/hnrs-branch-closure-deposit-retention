# S3_build_bank_zip_sample.R
# V2 rebuild of bank-zip-year own-closure panel.
#
# Changes from v1 (code/approach-technology-sorting/04_build_bank_zip_year_sample_20260420.R):
#   1. ZIP -> county via HUD max-TOT_RATIO crosswalk (S1), NOT .SD[1].
#   2. Discretionary filters stored as FLAG COLUMNS on every row rather than
#      applied at build time:
#        - extreme_intensity_pctl  (top 5% OR <1% closure intensity)
#        - clean_no_change_if_no_closure  (non-closure obs with delta_branches=0)
#        - any_closure_prev_owner_other_3y (M&A closure)
#      Analysis script (05_own_closure.R) chooses which to apply per spec.
#   3. Sample-flow logged to diagnostics/.
#   4. Centralized mobile LOCF via extend_county_year_locf.
#
# Output: data/constructed/bank_zip_sample_v2_YYYYMMDD.rds
# Spec columns: growth_on_total_t1, closure_share, total_deps_bank_zip_t1,
#   n_remaining_branches, mkt_share_zip_t1, top4_bank, large_bank,
#   perc_hh_wMobileSub, sophisticated, YEAR, bank_id, zip, county,
#   {flag columns above}, any_closure_t.

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

CLOSURE_PANEL <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
APP_PANEL     <- "C:/Users/dimut/OneDrive/data/CH_full_app_reviews_panel.csv"
ZIP_DEMO      <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/zip_demographics_panel.rds"
MOBILE_PANEL  <- "data/raw/perc_hh_wMobileSub.csv"
ZIP_CTY_XW    <- "data/constructed/zip_county_xwalk_v2.rds"

params <- list(
  start_year = 2001L, end_year = 2024L,
  tail_p = 0.95, winsor_p = c(0.025, 0.975),
  top4_cert = c(628L, 3510L, 3511L, 7213L),
  assets_large_threshold = 100000000
)

sum_na_safe <- function(x) if (all(is.na(x))) NA_real_ else as.numeric(sum(x, na.rm = TRUE))
safe_max    <- function(x) { x <- x[!is.na(x)]; if (!length(x)) NA_real_ else max(x) }

flow <- sample_flow_init("bank_zip_v2")

# ---- 1. Closure + app merge -------------------------------------------------
closure_raw <- setDT(load_exact(CLOSURE_PANEL))
closure_raw[, `:=`(zip  = formatC(as.integer(ZIPBR), width = 5, flag = "0"),
                   YEAR = as.integer(YEAR))]
flow <- sample_flow_step(flow, "raw closure panel", closure_raw)

app <- load_exact(APP_PANEL)
app <- app[, .(CERT = FDIC_certificate_id, YEAR = as.integer(year),
               first_app_available, tot_assets)]
app[, has_app := fifelse(first_app_available == 1, 1L, 0L)]

closure_app <- merge(closure_raw, app[, .(CERT, YEAR, has_app, tot_assets)],
                     by = c("CERT", "YEAR"), all.x = TRUE)
closure_app[is.na(has_app), has_app := 0L]
closure_app[, bank_id := CERT]

# ---- 2. Temporal deposits ---------------------------------------------------
setorder(closure_app, UNINUMBR, YEAR)
closure_app[, `:=`(
  dep_lag1   = shift(DEPSUMBR, 1L, type = "lag"),
  year_lag1  = shift(YEAR,     1L, type = "lag"),
  dep_lead1  = shift(DEPSUMBR, 1L, type = "lead"),
  year_lead1 = shift(YEAR,     1L, type = "lead")
), by = UNINUMBR]
closure_app[, dep_lag1_aligned  := fifelse(year_lag1  == YEAR - 1L, dep_lag1,  NA_real_)]
closure_app[, dep_lead1_aligned := fifelse(year_lead1 == YEAR + 1L, dep_lead1, NA_real_)]
closure_app[, exists_t1  := !is.na(dep_lag1_aligned)  & dep_lag1_aligned  > 0]
closure_app[, exists_tp1 := !is.na(dep_lead1_aligned) & dep_lead1_aligned > 0]
closure_app[, is_closed_t         := (closed == 1L)]
closure_app[, is_remaining_branch := (!is_closed_t) & exists_t1 & exists_tp1]
closure_app[, is_closed_branch    := is_closed_t & exists_t1]

# ---- 3. Aggregate to bank-zip-year -----------------------------------------
bank_zip_yr <- closure_app[, .(
  deps_closed_t1  = sum_na_safe(fifelse(is_closed_branch,    dep_lag1_aligned,  NA_real_)),
  deps_remain_t1  = sum_na_safe(fifelse(is_remaining_branch, dep_lag1_aligned,  NA_real_)),
  deps_remain_tp1 = sum_na_safe(fifelse(is_remaining_branch, dep_lead1_aligned, NA_real_)),
  n_closed_branches    = sum(is_closed_branch, na.rm = TRUE),
  n_remaining_branches = sum(is_remaining_branch, na.rm = TRUE),
  has_app              = safe_max(has_app)
), by = .(bank_id, zip, YEAR)]
for (v in c("deps_closed_t1", "deps_remain_t1", "deps_remain_tp1"))
  bank_zip_yr[is.na(get(v)), (v) := 0]
bank_zip_yr[!is.finite(has_app), has_app := 0L]
flow <- sample_flow_step(flow, "bank-zip-year aggregate", bank_zip_yr,
                         unit_cols = c("bank_id", "zip", "YEAR"))

bank_level <- app[, .(
  large_bank = as.integer(any(tot_assets > params$assets_large_threshold, na.rm = TRUE))
), by = .(bank_id = CERT)]
bank_zip_yr <- merge(bank_zip_yr, bank_level, by = "bank_id", all.x = TRUE)
bank_zip_yr[is.na(large_bank), large_bank := 0L]

# ---- 4. Outcome + market share ---------------------------------------------
bank_zip_yr[, total_deps_bank_zip_t1 := deps_closed_t1 + deps_remain_t1]
bank_zip_yr[, closure_share := fifelse(
  total_deps_bank_zip_t1 > 0, deps_closed_t1 / total_deps_bank_zip_t1, NA_real_)]
bank_zip_yr[, growth_on_total_t1 := fifelse(
  total_deps_bank_zip_t1 > 0,
  (deps_remain_tp1 - deps_remain_t1) / total_deps_bank_zip_t1, NA_real_)]
zip_deps_t1 <- bank_zip_yr[, .(total_zip_deps_t1 = sum(total_deps_bank_zip_t1, na.rm = TRUE)),
                           by = .(zip, YEAR)]
bank_zip_yr <- merge(bank_zip_yr, zip_deps_t1, by = c("zip", "YEAR"), all.x = TRUE)
bank_zip_yr[, mkt_share_zip_t1 := fifelse(
  total_zip_deps_t1 > 0, total_deps_bank_zip_t1 / total_zip_deps_t1, NA_real_)]
bank_zip_yr[, any_closure_t := as.integer(deps_closed_t1 > 0)]

# ---- 5. Branch dynamics + closure flags ------------------------------------
setorder(bank_zip_yr, bank_id, zip, YEAR)
branch_counts <- closure_app[, .(n_branches_curr = uniqueN(UNINUMBR)),
                             by = .(bank_id, zip, YEAR)]
bank_zip_yr <- merge(bank_zip_yr, branch_counts,
                     by = c("bank_id", "zip", "YEAR"), all.x = TRUE)
bank_zip_yr[is.na(n_branches_curr), n_branches_curr := 0L]
bank_zip_yr[, n_branches_tp1 := shift(n_branches_curr, 1L, type = "lead"),
            by = .(bank_id, zip)]
bank_zip_yr[is.na(n_branches_tp1), n_branches_tp1 := n_branches_curr]
bank_zip_yr[, delta_branches := n_branches_tp1 - n_branches_curr]
bank_zip_yr[, any_closure_tp1 := shift(any_closure_t, 1L, type = "lead"),
            by = .(bank_id, zip)]
bank_zip_yr[is.na(any_closure_tp1), any_closure_tp1 := 0L]
bank_zip_yr[, clean_no_change_if_no_closure :=
              as.integer(any_closure_t == 0L & delta_branches == 0L)]

# ---- 6. M&A flag (prior owner in <=3y) -------------------------------------
branch_owner <- unique(closure_app[, .(UNINUMBR, YEAR, bank_id)])
setorder(branch_owner, UNINUMBR, YEAR)
branch_owner[, had_other_owner_3y := {
  sapply(seq_len(.N), function(i) {
    cy <- YEAR[i]; co <- bank_id[i]
    past <- bank_id[YEAR >= cy - 3L & YEAR < cy]
    length(past) > 0 && any(past != co)
  })
}, by = UNINUMBR]
closed_hist <- merge(
  closure_app[is_closed_branch == TRUE, .(bank_id, zip, YEAR, UNINUMBR)],
  branch_owner[, .(UNINUMBR, YEAR, had_other_owner_3y)],
  by = c("UNINUMBR", "YEAR"), all.x = TRUE)
closed_hist[is.na(had_other_owner_3y), had_other_owner_3y := FALSE]
ma_flag <- closed_hist[, .(
  any_closure_prev_owner_other_3y = as.integer(any(had_other_owner_3y))
), by = .(bank_id, zip, YEAR)]
bank_zip_yr[ma_flag, any_closure_prev_owner_other_3y := i.any_closure_prev_owner_other_3y,
            on = .(bank_id, zip, YEAR)]
bank_zip_yr[is.na(any_closure_prev_owner_other_3y), any_closure_prev_owner_other_3y := 0L]
bank_zip_yr[any_closure_t == 0L, any_closure_prev_owner_other_3y := 0L]

# ---- 7. Extreme-intensity flag ---------------------------------------------
bank_zip_yr[, closure_intensity := fifelse(
  deps_closed_t1 > 0 & deps_remain_t1 > 0, deps_closed_t1 / deps_remain_t1, NA_real_)]
cut_intensity <- bank_zip_yr[
  deps_closed_t1 > 0 & !is.na(closure_intensity),
  quantile(closure_intensity, probs = params$tail_p, na.rm = TRUE)]
bank_zip_yr[, extreme_intensity_pctl := as.integer(
  deps_closed_t1 > 0 & !is.na(closure_intensity) &
  (closure_intensity >= cut_intensity | closure_intensity < 0.01))]
cat("Extreme intensity cutoff:", round(cut_intensity, 3),
    " | flagged:", sum(bank_zip_yr$extreme_intensity_pctl, na.rm = TRUE), "\n")

# ---- 8. ZIP -> county via HUD (FIX vs v1 line 63) --------------------------
xw <- setDT(load_exact(ZIP_CTY_XW))
bank_zip_yr <- merge(bank_zip_yr, xw[, .(zip, county = primary_county,
                                          zip_n_counties = n_counties)],
                     by = "zip", all.x = TRUE)

# ---- 9. Zip demographics (sophisticated) -----------------------------------
zip_demo <- setDT(load_exact(ZIP_DEMO))
zip_demo[, zip := as.character(zip)]
ntile2 <- function(x) as.integer(x >= median(x, na.rm = TRUE)) + 1L
zip_demo[, pct_college_q  := ntile2(pct_college_educated), by = yr]
zip_demo[, dividend_q     := ntile2(dividend_frac),        by = yr]
zip_demo[, capital_gain_q := ntile2(capital_gain_frac),    by = yr]
zip_demo[, sophisticated := fifelse(
  !is.na(dividend_frac) & pct_college_q == 2L & (dividend_q == 2L | capital_gain_q == 2L),
  1L, fifelse(!is.na(dividend_frac), 0L, NA_integer_))]
setorder(zip_demo, zip, yr)
zip_demo[, sophisticated := nafill(sophisticated, type = "locf"), by = zip]
bank_zip_yr <- merge(bank_zip_yr,
  zip_demo[, .(zip, YEAR = as.integer(yr), sophisticated)],
  by = c("zip", "YEAR"), all.x = TRUE)

# ---- 10. Mobile subscription (LOCF-extended) -------------------------------
perc_mob <- load_exact(MOBILE_PANEL)
perc_mob[, `:=`(
  county = str_pad(as.character(county_fips), 5, "left", "0"),
  YEAR   = as.integer(year)
)]
setorder(perc_mob, county, YEAR)
perc_mob <- extend_county_year_locf(perc_mob, "county", "YEAR",
                                    "perc_hh_wMobileSub", 2025L)
bank_zip_yr <- merge(bank_zip_yr,
  perc_mob[, .(county, YEAR, perc_hh_wMobileSub)],
  by = c("county", "YEAR"), all.x = TRUE)

# ---- 11. Top-4 flag + final sanity -----------------------------------------
bank_zip_yr[, top4_bank := as.integer(bank_id %in% params$top4_cert)]

# Pre-drop sanity. Paper-result sample (for 05_own_closure.R) applies
# only the MINIMAL filter (n_remaining_branches > 0, positive total, non-NA
# outcome, year window). Discretionary filters applied at analysis time via
# flag columns — this decouples the build from the paper's final choices.
reg_base <- bank_zip_yr[
  YEAR >= params$start_year & YEAR <= params$end_year &
  n_remaining_branches > 0 &
  total_deps_bank_zip_t1 > 0 &
  !is.na(growth_on_total_t1)
]
flow <- sample_flow_step(flow, "minimal analysis filter (year/positive deps/outcome)",
                         reg_base, unit_cols = c("bank_id", "zip", "YEAR"))

# Winsorize the outcome once at build; spec scripts use as-is.
reg_base[, growth_on_total_t1 := wins(growth_on_total_t1)]

# ---- 12. Save ---------------------------------------------------------------
out_path <- file.path("data/constructed",
                      paste0("bank_zip_sample_v2_", DATE_TAG, ".rds"))
saveRDS(reg_base, out_path)
cat("\nSaved:", out_path, " | nrow =", nrow(reg_base), "\n")
cat("sha256:", digest::digest(out_path, algo = "sha256", file = TRUE), "\n")

flow <- sample_flow_step(flow, "final saved panel", reg_base,
                         unit_cols = c("bank_id", "zip", "YEAR"))
sample_flow_save(flow)

# ---- 13. Filter coverage report --------------------------------------------
cat("\n=== Discretionary-filter coverage (kept as FLAGS, not dropped) ===\n")
cat("With closures (any_closure_t):", sum(reg_base$any_closure_t), "\n")
cat("  of which extreme_intensity_pctl:", sum(reg_base[any_closure_t == 1L, extreme_intensity_pctl]), "\n")
cat("  of which any_closure_prev_owner_other_3y:", sum(reg_base[any_closure_t == 1L, any_closure_prev_owner_other_3y]), "\n")
cat("Without closures:", sum(reg_base$any_closure_t == 0L), "\n")
cat("  of which clean_no_change_if_no_closure:", sum(reg_base[any_closure_t == 0L, clean_no_change_if_no_closure]), "\n")
