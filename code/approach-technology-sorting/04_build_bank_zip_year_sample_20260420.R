rm(list = ls())
library(data.table)
library(stringr)

set.seed(123)

data_path  <- "data"
ext_path   <- "C:/Users/dimut/OneDrive/data"
dat_suffix <- format(Sys.time(), "%Y%m%d")

sum_na_safe <- function(x) if (all(is.na(x))) NA_real_ else as.numeric(sum(x, na.rm = TRUE))
safe_max    <- function(x) { x <- x[!is.na(x)]; if (!length(x)) NA_real_ else max(x) }
winsor_dt   <- function(dt, v, p = c(0.025, 0.975)) {
  lo <- dt[, quantile(get(v), probs = p[1], na.rm = TRUE)]
  hi <- dt[, quantile(get(v), probs = p[2], na.rm = TRUE)]
  dt[get(v) < lo, (v) := lo]
  dt[get(v) > hi, (v) := hi]
  invisible(dt)
}

paths <- list(
  closure_rds = file.path(ext_path, "closure_opening_data_simple.rds"),
  app_csv     = file.path(ext_path, "CH_full_app_reviews_panel.csv"),
  zip_demo    = file.path(ext_path, "nrs_branch_closure", "zip_demographics_panel.rds"),
  mobile_csv  = file.path(data_path, "raw", "perc_hh_wMobileSub.csv")
)

params <- list(
  start_year             = 2001L,
  end_year               = 2024L,
  tail_p                 = 0.95,
  winsor_p               = c(0.025, 0.975),
  top4_cert              = c(628L, 3510L, 3511L, 7213L),
  assets_large_threshold = 100000000
)

cat("=== LOADING ===\n")
closure_raw <- readRDS(paths$closure_rds)
setDT(closure_raw)
closure_raw[, zip    := formatC(as.integer(ZIPBR), width = 5, flag = "0")]
closure_raw[, county := str_pad(STCNTYBR, 5, "left", "0")]
closure_raw[, YEAR   := as.integer(YEAR)]

app_panel <- data.table::fread(paths$app_csv)
setDT(app_panel)
app_panel <- app_panel[, .(
  CERT = FDIC_certificate_id,
  YEAR = as.integer(year),
  first_app_available,
  tot_assets
)]
app_panel[, has_app := fifelse(first_app_available == 1, 1L, 0L)]

closure_app <- merge(
  closure_raw,
  app_panel[, .(CERT, YEAR, has_app, tot_assets)],
  by = c("CERT", "YEAR"), all.x = TRUE
)
closure_app[is.na(has_app), has_app := 0L]
closure_app[, bank_id := CERT]

# zip→county crosswalk (first match per zip)
zip_county <- unique(closure_app[, .(zip, county)])[, .SD[1], by = zip]

cat("Branch-year obs:", nrow(closure_app), "\n")
cat("Years:", min(closure_app$YEAR), "-", max(closure_app$YEAR), "\n")

cat("=== TEMPORAL DEPOSITS ===\n")
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

cat("=== BRANCH STATUS ===\n")
closure_app[, is_closed_t         := (closed == 1L)]
closure_app[, is_remaining_branch := (!is_closed_t) & exists_t1 & exists_tp1]
closure_app[, is_closed_branch    := is_closed_t & exists_t1]

cat("Closed branches:", sum(closure_app$is_closed_branch, na.rm = TRUE), "\n")
cat("Remaining branches:", sum(closure_app$is_remaining_branch, na.rm = TRUE), "\n")

cat("=== AGGREGATE TO BANK-ZIP-YEAR ===\n")
bank_zip_yr <- closure_app[, .(
  deps_closed_t1       = sum_na_safe(fifelse(is_closed_branch,    dep_lag1_aligned,  NA_real_)),
  deps_remain_t1       = sum_na_safe(fifelse(is_remaining_branch, dep_lag1_aligned,  NA_real_)),
  deps_remain_tp1      = sum_na_safe(fifelse(is_remaining_branch, dep_lead1_aligned, NA_real_)),
  n_closed_branches    = sum(is_closed_branch,     na.rm = TRUE),
  n_remaining_branches = sum(is_remaining_branch,  na.rm = TRUE),
  has_app              = safe_max(has_app)
), by = .(bank_id, zip, YEAR)]

for (v in c("deps_closed_t1","deps_remain_t1","deps_remain_tp1"))
  bank_zip_yr[is.na(get(v)), (v) := 0]
bank_zip_yr[!is.finite(has_app), has_app := 0L]

cat("Bank-zip-year obs:", nrow(bank_zip_yr), "\n")

cat("=== LARGE BANK FLAG ===\n")
bank_level <- app_panel[, .(
  large_bank = as.integer(any(tot_assets > params$assets_large_threshold, na.rm = TRUE))
), by = .(bank_id = CERT)]
bank_zip_yr <- merge(bank_zip_yr, bank_level, by = "bank_id", all.x = TRUE)
bank_zip_yr[is.na(large_bank), large_bank := 0L]

cat("=== OUTCOMES AND MARKET SHARE ===\n")
bank_zip_yr[, total_deps_bank_zip_t1 := deps_closed_t1 + deps_remain_t1]
bank_zip_yr[, closure_share := fifelse(
  total_deps_bank_zip_t1 > 0, deps_closed_t1 / total_deps_bank_zip_t1, NA_real_)]
bank_zip_yr[, growth_on_total_t1 := fifelse(
  total_deps_bank_zip_t1 > 0,
  (deps_remain_tp1 - deps_remain_t1) / total_deps_bank_zip_t1, NA_real_)]

zip_deps_t1 <- bank_zip_yr[, .(
  total_zip_deps_t1 = sum(total_deps_bank_zip_t1, na.rm = TRUE)
), by = .(zip, YEAR)]
bank_zip_yr <- merge(bank_zip_yr, zip_deps_t1, by = c("zip", "YEAR"), all.x = TRUE)
bank_zip_yr[, mkt_share_zip_t1 := fifelse(
  total_zip_deps_t1 > 0, total_deps_bank_zip_t1 / total_zip_deps_t1, NA_real_)]

cat("=== CLOSURE FLAGS ===\n")
bank_zip_yr[, any_closure_t := as.integer(deps_closed_t1 > 0)]
setorder(bank_zip_yr, bank_id, zip, YEAR)

branch_counts <- closure_app[, .(n_branches_curr = uniqueN(UNINUMBR)), by = .(bank_id, zip, YEAR)]
bank_zip_yr <- merge(bank_zip_yr, branch_counts, by = c("bank_id","zip","YEAR"), all.x = TRUE)
bank_zip_yr[is.na(n_branches_curr), n_branches_curr := 0L]

branch_closed_counts <- closure_app[closed == 1L, .(
  n_closed_curr = uniqueN(UNINUMBR)
), by = .(bank_id, zip, YEAR)]
bank_zip_yr <- merge(bank_zip_yr, branch_closed_counts, by = c("bank_id","zip","YEAR"), all.x = TRUE)
bank_zip_yr[is.na(n_closed_curr), n_closed_curr := 0L]

setorder(bank_zip_yr, bank_id, zip, YEAR)
bank_zip_yr[, n_branches_tp1 := shift(n_branches_curr, 1L, type = "lead"), by = .(bank_id, zip)]
bank_zip_yr[is.na(n_branches_tp1), n_branches_tp1 := n_branches_curr]
bank_zip_yr[, delta_branches  := n_branches_tp1 - n_branches_curr]
bank_zip_yr[, any_closure_tp1 := shift(any_closure_t, 1L, type = "lead"), by = .(bank_id, zip)]
bank_zip_yr[is.na(any_closure_tp1), any_closure_tp1 := 0L]

bank_zip_yr[, clean_no_change_if_no_closure :=
  as.integer(any_closure_t == 0L & delta_branches == 0L)]

cat("=== M&A FLAG (prior owner within 3yr) ===\n")
bank_zip_yr[, any_closure_prev_owner_other_3y := 0L]
branch_owner <- unique(closure_app[, .(UNINUMBR, YEAR, bank_id)])
setorder(branch_owner, UNINUMBR, YEAR)
branch_owner[, had_other_owner_3y := {
  sapply(seq_len(.N), function(i) {
    cy <- YEAR[i]; co <- bank_id[i]
    past <- bank_id[YEAR >= cy - 3L & YEAR < cy]
    length(past) > 0 && any(past != co)
  })
}, by = UNINUMBR]

closed_with_hist <- merge(
  closure_app[is_closed_branch == TRUE, .(bank_id, zip, YEAR, UNINUMBR)],
  branch_owner[, .(UNINUMBR, YEAR, had_other_owner_3y)],
  by = c("UNINUMBR","YEAR"), all.x = TRUE
)
closed_with_hist[is.na(had_other_owner_3y), had_other_owner_3y := FALSE]
ma_flag <- closed_with_hist[, .(
  any_closure_prev_owner_other_3y = as.integer(any(had_other_owner_3y))
), by = .(bank_id, zip, YEAR)]
bank_zip_yr[ma_flag,
  any_closure_prev_owner_other_3y := i.any_closure_prev_owner_other_3y,
  on = .(bank_id, zip, YEAR)]
bank_zip_yr[is.na(any_closure_prev_owner_other_3y), any_closure_prev_owner_other_3y := 0L]
bank_zip_yr[any_closure_t == 0L, any_closure_prev_owner_other_3y := 0L]

cat("M&A-flagged closures:", sum(bank_zip_yr$any_closure_prev_owner_other_3y), "\n")

cat("=== EXTREME INTENSITY ===\n")
bank_zip_yr[, closure_intensity := fifelse(
  deps_closed_t1 > 0 & deps_remain_t1 > 0,
  deps_closed_t1 / deps_remain_t1, NA_real_)]
cut_intensity <- bank_zip_yr[
  deps_closed_t1 > 0 & !is.na(closure_intensity),
  quantile(closure_intensity, probs = params$tail_p, na.rm = TRUE)]
bank_zip_yr[, extreme_intensity_pctl := as.integer(
  deps_closed_t1 > 0 & !is.na(closure_intensity) &
  (closure_intensity >= cut_intensity | closure_intensity < 0.01))]
cat("Extreme intensity cutoff:", round(cut_intensity, 3), "\n")
cat("Flagged extreme obs:", sum(bank_zip_yr$extreme_intensity_pctl, na.rm = TRUE), "\n")

cat("=== ZIP DEMOGRAPHICS / SOPHISTICATED ===\n")
zip_demo <- readRDS(paths$zip_demo)
setDT(zip_demo)
zip_demo[, zip := as.character(zip)]

ntile2 <- function(x) as.integer(x >= median(x, na.rm=TRUE)) + 1L
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
  by = c("zip","YEAR"), all.x = TRUE)

cat("=== MOBILE SUBSCRIPTION (county-level) ===\n")
bank_zip_yr <- merge(bank_zip_yr, zip_county, by = "zip", all.x = TRUE)

perc_mobile <- data.table::fread(paths$mobile_csv)
setDT(perc_mobile)
perc_mobile[, county := str_pad(as.character(county_fips), 5, "left", "0")]
perc_mobile[, YEAR   := as.integer(year)]
setorder(perc_mobile, county, -YEAR)
perc_mobile[, perc_hh_wMobileSub := nafill(perc_hh_wMobileSub, type = "locf"), by = county]
perc_mobile[, v2023 := perc_hh_wMobileSub[YEAR == 2023L][1], by = county]
perc_mobile[YEAR > 2023L, perc_hh_wMobileSub := v2023]
perc_mobile[, v2023 := NULL]

bank_zip_yr <- merge(bank_zip_yr,
  perc_mobile[, .(county, YEAR, perc_hh_wMobileSub)],
  by = c("county","YEAR"), all.x = TRUE)

cat("=== REGRESSION SAMPLE ===\n")
bank_zip_yr[, top4_bank := as.integer(bank_id %in% params$top4_cert)]

reg_base <- bank_zip_yr[
  YEAR >= params$start_year & YEAR <= params$end_year &
  n_remaining_branches > 0 &
  total_deps_bank_zip_t1 > 0 &
  !is.na(growth_on_total_t1)
]

winsor_dt(reg_base, "growth_on_total_t1", params$winsor_p)

cat("Base sample:", nrow(reg_base), "\n")
cat("  - With closures:", sum(reg_base$any_closure_t), "\n")
cat("  - Without closures:", sum(reg_base$any_closure_t == 0L), "\n")

reg_main <- reg_base[extreme_intensity_pctl == 0L]
reg_main <- reg_main[
  (any_closure_t == 1L & any_closure_prev_owner_other_3y == 0L) |
  (any_closure_t == 0L & clean_no_change_if_no_closure == 1L)
]

cat("Main sample:", nrow(reg_main), "\n")
cat("  - With closures:", sum(reg_main$any_closure_t), "\n")
cat("  - Without closures:", sum(reg_main$any_closure_t == 0L), "\n")
cat("Sophisticated non-NA:", sum(!is.na(reg_main$sophisticated)), "\n")
cat("perc_hh_wMobileSub non-NA:", sum(!is.na(reg_main$perc_hh_wMobileSub)), "\n")
cat("Years:", min(reg_main$YEAR), "-", max(reg_main$YEAR), "\n")

out_file <- file.path(data_path, paste0("reg_main_zip_", dat_suffix, ".rds"))
saveRDS(reg_main, out_file)
cat("Saved:", out_file, "\n")
