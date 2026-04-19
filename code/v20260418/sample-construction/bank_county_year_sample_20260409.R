rm(list = ls())

library(data.table)
library(stringr)
library(lubridate)
library(DescTools)
library(readxl)
library(dplyr)
library(here)

set.seed(123)

data_path <- here::here("data")
external_data_path <- "C:/Users/dimut/OneDrive/data/"
dat_suffix <- format(Sys.time(), "%Y%m%d")

#' Safely sum a numeric vector, returning NA if all entries are NA.
#'
#' @param x Numeric vector to be summed.
#' @return Scalar numeric sum or NA_real_ if all values are NA.
sum_na_safe <- function(x) {
  if (all(is.na(x))) NA_real_ else as.numeric(sum(x, na.rm = TRUE))
}

#' Safely take the maximum of a numeric vector, ignoring NA values.
#'
#' @param x Numeric vector.
#' @return Scalar numeric maximum or NA_real_ if all values are NA.
safe_max <- function(x) {
  x <- x[!is.na(x)]
  if (!length(x)) NA_real_ else max(x)
}

#' Winsorize a column of a data.table in place between given quantiles.
#'
#' @param dt A data.table.
#' @param v  Column name (string) to winsorize.
#' @param p  Length-2 numeric vector of lower and upper quantiles.
winsor_dt <- function(dt, v, p = c(0.025, 0.975)) {
  lo <- dt[, quantile(get(v), probs = p[1], na.rm = TRUE)]
  hi <- dt[, quantile(get(v), probs = p[2], na.rm = TRUE)]
  dt[get(v) < lo, (v) := lo]
  dt[get(v) > hi, (v) := hi]
  invisible(dt)
}

paths <- list(
  closure_rds     = file.path(external_data_path, "closure_opening_data_simple.rds"),
  app_csv         = file.path(external_data_path, "CH_full_app_reviews_panel.csv"),
  visits_rds      = file.path(external_data_path, "nrs_branch_closure", "bank_branch_visits_count_2019_2022.rds"),
  county_zip      = file.path(external_data_path, "county_zip_122019.xlsx"),
  zip_demo        = file.path(external_data_path, "nrs_branch_closure", "zip_demographics_panel.rds"),
  perc_mobile_csv = file.path(data_path, "raw", "perc_hh_wMobileSub.csv")
)

params <- list(
  start_year = 2001L,
  end_year   = 2024L,
  tail_p     = 0.95,      # top 5% closure_intensity flagged as extreme
  never_treated_share = 0.5,
  winsor_p   = c(0.025, 0.975),
  top4_cert  = c(628L, 3510L, 3511L, 7213L),
  assets_large_threshold = 100000000
)

cat("\n=== LOADING DATA ===\n")

closure_raw <- readRDS(paths$closure_rds)
setDT(closure_raw)
closure_raw[, county := str_pad(STCNTYBR, 5, "left", "0")]
closure_raw[, YEAR := as.integer(YEAR)]

app_panel <- data.table::fread(paths$app_csv)
setDT(app_panel)

app_panel <- app_panel[, .(
  CERT = FDIC_certificate_id,
  YEAR = as.integer(year),
  first_app_available,
  tot_assets,
  reviews_available,
  yearly_rating,
  cumulative_rating
)]
app_panel[, has_app := fifelse(first_app_available == 1, 1L, 0L)]

closure_app <- merge(
  closure_raw,
  app_panel[, .(CERT, YEAR, has_app, tot_assets, reviews_available, yearly_rating, cumulative_rating)],
  by = c("CERT", "YEAR"),
  all.x = TRUE
)

# Defaults
closure_app[is.na(has_app), has_app := 0L]
closure_app[is.na(reviews_available), reviews_available := 0L]

# Bank identifier
closure_app[, bank_id := CERT]

cat("Total branch-year observations:", nrow(closure_app), "\n")
cat("Years covered:", min(closure_app$YEAR), "-", max(closure_app$YEAR), "\n")
cat("Unique banks:", uniqueN(closure_app$bank_id), "\n")
cat("Unique counties:", uniqueN(closure_app$county), "\n")

cat("\n=== CREATING TEMPORAL DEPOSIT VARIABLES ===\n")

setorder(closure_app, UNINUMBR, YEAR)

closure_app[, `:=`(
  dep_lag1   = shift(DEPSUMBR, 1L, type = "lag"),
  year_lag1  = shift(YEAR,     1L, type = "lag"),
  dep_lag3   = shift(DEPSUMBR, 3L, type = "lag"),
  year_lag3  = shift(YEAR,     3L, type = "lag"),
  dep_lead1  = shift(DEPSUMBR, 1L, type = "lead"),
  year_lead1 = shift(YEAR,     1L, type = "lead"),
  dep_lead3  = shift(DEPSUMBR, 3L, type = "lead"),
  year_lead3 = shift(YEAR,     3L, type = "lead")
), by = UNINUMBR]

# Align only if consecutive years exist
closure_app[, dep_lag1_aligned  := fifelse(year_lag1  == YEAR - 1L, dep_lag1,  NA_real_)]
closure_app[, dep_lag3_aligned  := fifelse(year_lag3  == YEAR - 3L, dep_lag3,  NA_real_)]
closure_app[, dep_lead1_aligned := fifelse(year_lead1 == YEAR + 1L, dep_lead1, NA_real_)]
closure_app[, dep_lead3_aligned := fifelse(year_lead3 == YEAR + 3L, dep_lead3, NA_real_)]

closure_app[, exists_t1  := !is.na(dep_lag1_aligned)  & dep_lag1_aligned  > 0]
closure_app[, exists_t3  := !is.na(dep_lag3_aligned)  & dep_lag3_aligned  > 0]
closure_app[, exists_tp1 := !is.na(dep_lead1_aligned) & dep_lead1_aligned > 0]
closure_app[, exists_tp3 := !is.na(dep_lead3_aligned) & dep_lead3_aligned > 0]

cat("\n=== IDENTIFYING BRANCH STATUS ===\n")

closure_app[, is_closed_t := (closed == 1L)]

# Remaining branches: survive t and exist at t-1 and t+1 (or t+3 for longer horizon)
closure_app[, is_remaining_branch    := (!is_closed_t) & exists_t1 & exists_tp1]
closure_app[, is_remaining_branch_t3 := (!is_closed_t) & exists_t1 & exists_tp3]

# Closed branches: close in t but existed at t-1
closure_app[, is_closed_branch := is_closed_t & exists_t1]

# Same set of branches for all growth horizons: survive at t and have positive deposits at t-3, t-1, t+1, t+3
closure_app[, constant_survivor := (!is_closed_t) & exists_t3 & exists_t1 & exists_tp1 & exists_tp3]

cat("Closed branches (with t-1 deposits):", sum(closure_app$is_closed_branch, na.rm = TRUE), "\n")
cat("Remaining branches (t-1 & t+1):",     sum(closure_app$is_remaining_branch, na.rm = TRUE), "\n")

cat("\n=== AGGREGATING TO BANK-COUNTY-YEAR LEVEL ===\n")

bank_cty_yr <- closure_app[, .(
  deps_closed_t1      = sum_na_safe(fifelse(is_closed_branch,        dep_lag1_aligned,  NA_real_)),
  deps_remain_t1      = sum_na_safe(fifelse(is_remaining_branch,     dep_lag1_aligned,  NA_real_)),
  deps_remain_t       = sum_na_safe(fifelse(is_remaining_branch,     DEPSUMBR,          NA_real_)),
  deps_remain_tp1     = sum_na_safe(fifelse(is_remaining_branch,     dep_lead1_aligned, NA_real_)),
  deps_remain_t1_t3   = sum_na_safe(fifelse(is_remaining_branch_t3,  dep_lag1_aligned,  NA_real_)),
  deps_remain_tp3     = sum_na_safe(fifelse(is_remaining_branch_t3,  dep_lead3_aligned, NA_real_)),

  n_closed_branches    = sum(is_closed_branch,     na.rm = TRUE),
  n_remaining_branches = sum(is_remaining_branch,  na.rm = TRUE),

  has_app           = safe_max(has_app),
  reviews_available = safe_max(reviews_available),
  yearly_rating     = safe_max(yearly_rating),
  cumulative_rating = safe_max(cumulative_rating)
), by = .(bank_id, county, YEAR)]

# Constant-survivor aggregates (same branch set for t-3, t-1, t+1, t+3) for multi-horizon growth
bank_cty_yr_const <- closure_app[constant_survivor == TRUE, .(
  deps_const_t3m = sum_na_safe(dep_lag3_aligned),
  deps_const_t1m = sum_na_safe(dep_lag1_aligned),
  deps_const_tp1 = sum_na_safe(dep_lead1_aligned),
  deps_const_tp3 = sum_na_safe(dep_lead3_aligned)
), by = .(bank_id, county, YEAR)]

bank_cty_yr <- merge(
  bank_cty_yr,
  bank_cty_yr_const,
  by = c("bank_id", "county", "YEAR"),
  all.x = TRUE
)

# Constant-set growth (same branch set for all horizons): gr_m3_m1, gr, gr_1_3
bank_cty_yr[, gr_m3_m1 := fifelse(
  !is.na(deps_const_t3m) & deps_const_t3m > 0 & !is.na(deps_const_t1m),
  (deps_const_t1m - deps_const_t3m) / deps_const_t3m,
  NA_real_
)]
bank_cty_yr[, gr := fifelse(
  !is.na(deps_const_t1m) & deps_const_t1m > 0 & !is.na(deps_const_tp1),
  (deps_const_tp1 - deps_const_t1m) / deps_const_t1m,
  NA_real_
)]
bank_cty_yr[, gr_1_3 := fifelse(
  !is.na(deps_const_tp1) & deps_const_tp1 > 0 & !is.na(deps_const_tp3),
  (deps_const_tp3 - deps_const_tp1) / deps_const_tp1,
  NA_real_
)]

# Replace NA sums with 0
sum_vars <- c("deps_closed_t1","deps_remain_t1","deps_remain_t","deps_remain_tp1","deps_remain_t1_t3","deps_remain_tp3")
for (v in sum_vars) bank_cty_yr[is.na(get(v)), (v) := 0]

# Clean max outputs
bank_cty_yr[!is.finite(has_app), has_app := 0L]
bank_cty_yr[!is.finite(reviews_available) | reviews_available < 0, reviews_available := 0L]
bank_cty_yr[!is.finite(yearly_rating), yearly_rating := NA_real_]
bank_cty_yr[!is.finite(cumulative_rating), cumulative_rating := NA_real_]

# Bank-level: large bank flag (time-invariant)
bank_level <- app_panel[, .(
  large_bank = as.integer(any(tot_assets > params$assets_large_threshold, na.rm = TRUE))
), by = .(bank_id = CERT)]
bank_cty_yr <- merge(bank_cty_yr, bank_level, by = "bank_id", all.x = TRUE)
bank_cty_yr[is.na(large_bank), large_bank := 0L]

# Convenience indicators
bank_cty_yr[, large_bank_has_app := as.integer(large_bank == 1L & has_app == 1L)]
bank_cty_yr[, large_bank_no_app  := as.integer(large_bank == 1L & has_app == 0L)]

# Large good/bad app (yearly rating): median by YEAR among large banks with reviews
rating_med_by_year <- bank_cty_yr[
  large_bank == 1L & reviews_available == 1L & !is.na(yearly_rating),
  .(med_rating = median(yearly_rating, na.rm = TRUE)),
  by = YEAR
]
bank_cty_yr <- merge(bank_cty_yr, rating_med_by_year, by = "YEAR", all.x = TRUE)
bank_cty_yr[, large_good_app := as.integer(large_bank == 1L & reviews_available == 1L &
                                             !is.na(yearly_rating) & !is.na(med_rating) & yearly_rating > med_rating)]
bank_cty_yr[, large_bad_app  := as.integer(large_bank == 1L & large_good_app == 0L)]
bank_cty_yr[, med_rating := NULL]

# Large good/bad app (cumulative rating): median by YEAR among large banks with reviews
rating_cum_med_by_year <- bank_cty_yr[
  large_bank == 1L & reviews_available == 1L & !is.na(cumulative_rating),
  .(med_rating_cum = median(cumulative_rating, na.rm = TRUE)),
  by = YEAR
]
bank_cty_yr <- merge(bank_cty_yr, rating_cum_med_by_year, by = "YEAR", all.x = TRUE)
bank_cty_yr[, large_good_app_cumulative := as.integer(large_bank == 1L & reviews_available == 1L &
                                                        !is.na(cumulative_rating) & !is.na(med_rating_cum) &
                                                        cumulative_rating > med_rating_cum)]
bank_cty_yr[, large_bad_app_cumulative  := as.integer(large_bank == 1L & large_good_app_cumulative == 0L)]
bank_cty_yr[, med_rating_cum := NULL]

cat("\n=== CREATING OUTCOME VARIABLES ===\n")

bank_cty_yr[, total_deps_bank_county_t1 := deps_closed_t1 + deps_remain_t1]

# Intensity / shares
bank_cty_yr[, closure_share := fifelse(total_deps_bank_county_t1 > 0, deps_closed_t1 / total_deps_bank_county_t1, NA_real_)]

# Growth normalized by total initial deposits
bank_cty_yr[, growth_on_total_t1 := fifelse(
  total_deps_bank_county_t1 > 0,
  (deps_remain_tp1 - deps_remain_t1) / total_deps_bank_county_t1,
  NA_real_
)]
bank_cty_yr[, growth_on_total_t3 := fifelse(
  total_deps_bank_county_t1 > 0,
  (deps_remain_tp3 - deps_remain_t1_t3) / total_deps_bank_county_t1,
  NA_real_
)]

# County totals for market share at t-1
county_deps_t1 <- bank_cty_yr[, .(
  total_county_deps_t1 = sum(total_deps_bank_county_t1, na.rm = TRUE)
), by = .(county, YEAR)]
bank_cty_yr <- merge(bank_cty_yr, county_deps_t1, by = c("county", "YEAR"), all.x = TRUE)
bank_cty_yr[, mkt_share_county_t1 := fifelse(total_county_deps_t1 > 0, total_deps_bank_county_t1 / total_county_deps_t1, NA_real_)]

cat("\n=== CREATING CLOSURE AND NETWORK CHANGE FLAGS ===\n")

bank_cty_yr[, any_closure_t := as.integer(deps_closed_t1 > 0)]
setorder(bank_cty_yr, bank_id, county, YEAR)

bank_cty_yr[, any_closure_tp1 := shift(any_closure_t, 1L, type = "lead"), by = .(bank_id, county)]
bank_cty_yr[, any_closure_tm1 := shift(any_closure_t, 1L, type = "lag"),  by = .(bank_id, county)]
bank_cty_yr[is.na(any_closure_tp1), any_closure_tp1 := 0L]
bank_cty_yr[is.na(any_closure_tm1), any_closure_tm1 := 0L]

# Current-year branch counts (all branches)
bank_cty_branches <- closure_app[, .(
  n_branches_curr = uniqueN(UNINUMBR)
), by = .(bank_id, county, YEAR)]

bank_cty_closed_counts <- closure_app[closed == 1L, .(
  n_closed_curr = uniqueN(UNINUMBR)
), by = .(bank_id, county, YEAR)]

bank_cty_yr <- merge(bank_cty_yr, bank_cty_branches,      by = c("bank_id","county","YEAR"), all.x = TRUE)
bank_cty_yr <- merge(bank_cty_yr, bank_cty_closed_counts, by = c("bank_id","county","YEAR"), all.x = TRUE)
bank_cty_yr[is.na(n_branches_curr), n_branches_curr := 0L]
bank_cty_yr[is.na(n_closed_curr),   n_closed_curr   := 0L]

# Next-year branch count + delta
setorder(bank_cty_yr, bank_id, county, YEAR)
bank_cty_yr[, n_branches_tp1 := shift(n_branches_curr, 1L, type = "lead"), by = .(bank_id, county)]
bank_cty_yr[is.na(n_branches_tp1), n_branches_tp1 := n_branches_curr]
bank_cty_yr[, delta_branches_t_to_tp1 := n_branches_tp1 - n_branches_curr]

# "Clean" flags
bank_cty_yr[, clean_no_change_if_no_closure :=
              as.integer(any_closure_t == 0L & delta_branches_t_to_tp1 == 0L)]

bank_cty_yr[, clean_only_current_closures :=
              as.integer(any_closure_t == 1L &
                         delta_branches_t_to_tp1 == -n_closed_curr &
                         any_closure_tp1 == 0L)]

bank_cty_yr[, clean_next_year_network :=
              as.integer((any_closure_t == 0L & clean_no_change_if_no_closure == 1L) |
                         (any_closure_t == 1L & clean_only_current_closures == 1L))]

cat("\n=== IDENTIFYING ANY CLOSURE OF RECENTLY ACQUIRED BRANCHES ===\n")

# Initialize flag
bank_cty_yr[, any_closure_prev_owner_other_3y := 0L]

# Branch-level ownership history (one row per branch-year)
branch_owner <- unique(closure_app[, .(UNINUMBR, YEAR, bank_id)])
setorder(branch_owner, UNINUMBR, YEAR)

# For each branch-year, check if it had a different owner in the past 3 years
branch_owner[, had_other_owner_3y := {
  sapply(seq_len(.N), function(i) {
    current_year <- YEAR[i]
    current_owner <- bank_id[i]
    past_owners <- bank_id[YEAR >= current_year - 3L & YEAR < current_year]
    length(past_owners) > 0 && any(past_owners != current_owner)
  })
}, by = UNINUMBR]

# Merge this flag to closed branches
closed_branches_with_history <- merge(
  closure_app[is_closed_branch == TRUE, .(bank_id, county, YEAR, UNINUMBR)],
  branch_owner[, .(UNINUMBR, YEAR, had_other_owner_3y)],
  by = c("UNINUMBR", "YEAR"),
  all.x = TRUE
)

# Fill NA as FALSE (no prior ownership found)
closed_branches_with_history[is.na(had_other_owner_3y), had_other_owner_3y := FALSE]

# Aggregate to bank-county-year level: flag = 1 if ANY closing branch had other owner in prior 3y
ma_flag <- closed_branches_with_history[, .(
  any_closure_prev_owner_other_3y = as.integer(any(had_other_owner_3y))
), by = .(bank_id, county, YEAR)]

bank_cty_yr[ma_flag,
            any_closure_prev_owner_other_3y := i.any_closure_prev_owner_other_3y,
            on = .(bank_id, county, YEAR)]

# Ensure NA -> 0 and restrict to closure years only
bank_cty_yr[is.na(any_closure_prev_owner_other_3y), any_closure_prev_owner_other_3y := 0L]
bank_cty_yr[any_closure_t == 0L, any_closure_prev_owner_other_3y := 0L]

cat("Bank-county-years where ANY closure was a previously acquired branch:",
    sum(bank_cty_yr$any_closure_prev_owner_other_3y), "\n")

cat("\n=== IDENTIFYING EXTREME CLOSURE INTENSITY ===\n")

bank_cty_yr[, closure_intensity := fifelse(
  deps_closed_t1 > 0 & deps_remain_t1 > 0,
  deps_closed_t1 / deps_remain_t1,
  NA_real_
)]

cut_intensity <- bank_cty_yr[
  deps_closed_t1 > 0 & !is.na(closure_intensity),
  quantile(closure_intensity, probs = params$tail_p, na.rm = TRUE)
]

bank_cty_yr[, extreme_intensity_pctl := as.integer(
  deps_closed_t1 > 0 &
    !is.na(closure_intensity) &
    (closure_intensity >= cut_intensity | closure_intensity < 0.01)
)]

cat("Extreme intensity cutoff (", params$tail_p*100, "th pct): ", round(cut_intensity, 3), "\n", sep = "")
cat("Flagged extreme observations:", sum(bank_cty_yr$extreme_intensity_pctl, na.rm = TRUE), "\n")

cat("\n=== CHANGE_VISITS: BANK-LEVEL (2019 vs 2021) ===\n")

branch_visits <- readRDS(paths$visits_rds)
setDT(branch_visits)

branch_visits[, yr := year(DATE_RANGE_START)]
branch_visits <- branch_visits[yr %in% c(2019, 2021)]

# Attach bank_id to each branch using most recent mapping in closure_app
branch_bank <- closure_app[order(UNINUMBR, -YEAR)][, .SD[1], by = UNINUMBR][, .(UNINUMBR, bank_id)]
branch_visits <- merge(branch_visits, branch_bank, by = "UNINUMBR", all.x = TRUE)

# Attach county to each branch (same mapping)
branch_county <- closure_app[order(UNINUMBR, -YEAR)][, .SD[1], by = UNINUMBR][, .(UNINUMBR, county)]
branch_visits <- merge(branch_visits, branch_county, by = "UNINUMBR", all.x = TRUE)

bank_change <- branch_visits[, .(
  total_visits = sum(RAW_VISITOR_COUNTS, na.rm = TRUE)
), by = .(bank_id, yr)]
bank_change <- dcast(bank_change, bank_id ~ yr, value.var = "total_visits")

bank_change[, drop_in_visits := (`2019` - `2021`) / `2019`]

# Winsorize once
bank_change[, drop_in_visits := Winsorize(
  drop_in_visits,
  val = quantile(drop_in_visits, probs = c(0.01, 0.99), na.rm = TRUE)
)]

bank_change[, high_drop_visits := as.integer(drop_in_visits > median(drop_in_visits, na.rm = TRUE))]

cat("Computed visit decline for", nrow(bank_change), "banks.\n")

cat("\n=== CHANGE_VISITS: COUNTY-LEVEL (2019 vs 2021) ===\n")

county_change <- branch_visits[, .(
  total_visits = sum(RAW_VISITOR_COUNTS, na.rm = TRUE)
), by = .(county, yr)]
county_change <- dcast(county_change, county ~ yr, value.var = "total_visits")

county_change[, drop_in_visits_county := (`2019` - `2021`) / `2019`]

county_change[, drop_in_visits_county := Winsorize(
  drop_in_visits_county,
  val = quantile(
    drop_in_visits_county,
    probs = c(0.01, 0.99),
    na.rm = TRUE
  )
)]

county_change[, high_drop_visits_county := as.integer(
  drop_in_visits_county > median(drop_in_visits_county, na.rm = TRUE)
)]

bank_cty_yr <- merge(
  bank_cty_yr,
  county_change[, .(county, drop_in_visits_county, high_drop_visits_county)],
  by = "county",
  all.x = TRUE
)

cat("\n=== COUNTY-LEVEL DEMOGRAPHICS AND SOPHISTICATION ===\n")

county_zip_122019 <- as.data.table(readxl::read_excel(paths$county_zip))
zip_demo <- readRDS(paths$zip_demo)
setDT(zip_demo)

# Align keys: county as 5-digit character, ZIP/zip for merge
county_zip_122019[, county := str_pad(as.character(COUNTY), 5, "left", "0")]
county_zip_122019[, ZIP := as.character(ZIP)]
zip_demo[, zip := as.character(zip)]

# Join zip_demo to crosswalk on ZIP (each zip replicated per county with TOT_RATIO)
zip_demo_cw <- merge(
  zip_demo,
  county_zip_122019[, .(ZIP, county, TOT_RATIO)],
  by.x = "zip", by.y = "ZIP",
  allow.cartesian = TRUE
)

# Numeric columns to aggregate to county-year using TOT_RATIO as weight
key_chars <- c("median_income", "median_age", "pct_college_educated", "capital_gain_frac", "dividend_frac")
key_chars <- intersect(key_chars, names(zip_demo_cw))
num_cols <- key_chars

county_demo <- zip_demo_cw[
  ,
  lapply(.SD, function(x) sum(as.numeric(x) * TOT_RATIO, na.rm = TRUE)),
  by = .(county, yr),
  .SDcols = num_cols
]
setnames(county_demo, "yr", "YEAR")

# Create bins by year (median split) and sophistication indicators in county_demo
county_demo[, paste0(key_chars, "_q") := lapply(.SD, function(x) ntile(x, 2)), by = YEAR, .SDcols = key_chars]

# Sophistication (education + investment income only)
county_demo[, sophisticated := fifelse(
  !is.na(dividend_frac) & pct_college_educated_q == 2L &
    (dividend_frac_q == 2L | capital_gain_frac_q == 2L), 1L,
  fifelse(!is.na(dividend_frac), 0L, NA_integer_)
)]

# Above-median dummies (by year)
county_demo[, above_median_age := as.integer(median_age > median(median_age, na.rm = TRUE)), by = YEAR]
county_demo[, above_median_income := as.integer(median_income > median(median_income, na.rm = TRUE)), by = YEAR]

# Merge county-level demographics (and sophistication) into bank_cty_yr
bank_cty_yr <- merge(bank_cty_yr, county_demo, by = c("county", "YEAR"), all.x = TRUE)

cat("\n=== COUNTY-LEVEL MOBILE SUBSCRIPTION ===\n")

perc_mobile <- data.table::fread(paths$perc_mobile_csv)
setDT(perc_mobile)

perc_mobile[, county := str_pad(as.character(county_fips), 5, "left", "0")]
perc_mobile[, YEAR := as.integer(year)]

# Within each county, fill NA with next year's value (sort desc so locf = closest future)
setorder(perc_mobile, county, -YEAR)
perc_mobile[, perc_hh_wMobileSub := nafill(perc_hh_wMobileSub, type = "locf"), by = county]

# For years after 2023, hold perc_hh_wMobileSub constant at the 2023 value within county
perc_mobile[, perc_hh_wMobileSub_2023 := perc_hh_wMobileSub[YEAR == 2023L][1], by = county]
perc_mobile[YEAR > 2023L, perc_hh_wMobileSub := perc_hh_wMobileSub_2023]
perc_mobile[, perc_hh_wMobileSub_2023 := NULL]

perc_mobile[, high_perc_hh_wMobileSub := as.integer(
  perc_hh_wMobileSub > median(perc_hh_wMobileSub, na.rm = TRUE)
), by = YEAR]

bank_cty_yr <- merge(
  bank_cty_yr,
  perc_mobile[, .(county, YEAR, perc_hh_wMobileSub, high_perc_hh_wMobileSub)],
  by = c("county", "YEAR"),
  all.x = TRUE
)

cat("\n=== DEFINING REGRESSION SAMPLES ===\n")

# Add top4 flag (time-invariant)
bank_cty_yr[, top4_bank := as.integer(bank_id %in% params$top4_cert)]
bank_cty_yr[, family_income := median_income]

reg_base <- bank_cty_yr[
  YEAR >= params$start_year & YEAR <= params$end_year &
    n_remaining_branches > 0 &
    total_deps_bank_county_t1 > 0 &
    !is.na(growth_on_total_t1)
]

reg_base[, state := substr(county, 1, 2)]
reg_base <- merge(reg_base, bank_change, by = "bank_id", all.x = TRUE)

# Winsorize depvars
winsor_dt(reg_base, "growth_on_total_t3", params$winsor_p)
winsor_dt(reg_base, "growth_on_total_t1", params$winsor_p)
winsor_dt(reg_base, "gr_m3_m1", params$winsor_p)
winsor_dt(reg_base, "gr", params$winsor_p)
winsor_dt(reg_base, "gr_1_3", params$winsor_p)

cat("Base sample size:", nrow(reg_base), "\n")
cat("  - With closures:", sum(reg_base$any_closure_t), "\n")
cat("  - Without closures:", sum(reg_base$any_closure_t == 0), "\n")

reg_base[, include_main := extreme_intensity_pctl == 0L ]

reg_main <- reg_base[include_main == 1L]
reg_main <- reg_main[
  (any_closure_t == 1L & any_closure_prev_owner_other_3y == 0L) |
    (any_closure_t == 0L & clean_no_change_if_no_closure == 1L)
]

cat("Main sample size:", nrow(reg_main), "\n")
cat("  - With closures:", sum(reg_main$any_closure_t), "\n")
cat("  - Without closures:", sum(reg_main$any_closure_t == 0), "\n")

cat("\n=== SAVING OUTPUT OBJECTS TO data/ ===\n")

saveRDS(reg_main, file.path(data_path, paste0("reg_main_", dat_suffix, ".rds")))

cat("All outputs saved with suffix:", dat_suffix, "\n")
