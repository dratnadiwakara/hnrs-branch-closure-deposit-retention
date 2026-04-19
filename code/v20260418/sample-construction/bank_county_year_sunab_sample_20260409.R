rm(list = ls())

library(data.table)
library(stringr)
library(here)

set.seed(123)

data_path <- here::here("data")
external_data_path <- "C:/Users/dimut/OneDrive/data/"
dat_suffix <- format(Sys.time(), "%Y%m%d_%H%M%S")

#' Safely sum a numeric vector, returning NA if all entries are NA.
#'
#' @param x Numeric vector to be summed.
#' @return Scalar numeric sum or NA_real_ if all values are NA.
sum_na_safe <- function(x) {
  if (all(is.na(x))) NA_real_ else as.numeric(sum(x, na.rm = TRUE))
}

paths <- list(
  closure_rds = file.path(external_data_path, "closure_opening_data_simple.rds"),
  app_csv    = file.path(external_data_path, "CH_full_app_reviews_panel.csv")
)

params <- list(never_treated_share = 0.5)

cat("\n=== LOADING DATA ===\n")

closure_raw <- readRDS(paths$closure_rds)
setDT(closure_raw)
closure_raw[, county := str_pad(STCNTYBR, 5, "left", "0")]
closure_raw[, YEAR := as.integer(YEAR)]

app_panel <- data.table::fread(paths$app_csv)
setDT(app_panel)
app_panel <- app_panel[, .(CERT = FDIC_certificate_id, YEAR = as.integer(year))]

closure_app <- merge(
  closure_raw,
  app_panel,
  by = c("CERT", "YEAR"),
  all.x = TRUE
)
closure_app[, bank_id := CERT]

cat("Branch-year observations:", nrow(closure_app), "\n")

cat("\n=== CREATING TEMPORAL DEPOSIT VARIABLES ===\n")

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

cat("\n=== IDENTIFYING BRANCH STATUS ===\n")

closure_app[, is_closed_t := (closed == 1L)]
closure_app[, is_remaining_branch := (!is_closed_t) & exists_t1 & exists_tp1]
closure_app[, is_closed_branch := is_closed_t & exists_t1]

cat("\n=== AGGREGATING TO BANK-COUNTY-YEAR LEVEL ===\n")

bank_cty_yr <- closure_app[, .(
  deps_closed_t1       = sum_na_safe(fifelse(is_closed_branch,   dep_lag1_aligned, NA_real_)),
  deps_remain_t1       = sum_na_safe(fifelse(is_remaining_branch, dep_lag1_aligned, NA_real_)),
  n_remaining_branches = sum(is_remaining_branch, na.rm = TRUE)
), by = .(bank_id, county, YEAR)]

for (v in c("deps_closed_t1", "deps_remain_t1")) {
  bank_cty_yr[is.na(get(v)), (v) := 0]
}

bank_cty_yr[, total_deps_bank_county_t1 := deps_closed_t1 + deps_remain_t1]
bank_cty_yr[, any_closure_t := as.integer(deps_closed_t1 > 0)]

cat("\n=== IDENTIFYING CLOSURES OF RECENTLY ACQUIRED BRANCHES ===\n")

bank_cty_yr[, any_closure_prev_owner_other_3y := 0L]
bank_cty_yr[, all_closures_prev_owner_other_3y := 0L]

branch_owner <- unique(closure_app[, .(UNINUMBR, YEAR, bank_id)])
setorder(branch_owner, UNINUMBR, YEAR)

branch_owner[, had_other_owner_3y := {
  sapply(seq_len(.N), function(i) {
    current_year  <- YEAR[i]
    current_owner <- bank_id[i]
    past_owners   <- bank_id[YEAR >= current_year - 3L & YEAR < current_year]
    length(past_owners) > 0 && any(past_owners != current_owner)
  })
}, by = UNINUMBR]

closed_branches_with_history <- merge(
  closure_app[is_closed_branch == TRUE, .(bank_id, county, YEAR, UNINUMBR)],
  branch_owner[, .(UNINUMBR, YEAR, had_other_owner_3y)],
  by = c("UNINUMBR", "YEAR"),
  all.x = TRUE
)
closed_branches_with_history[is.na(had_other_owner_3y), had_other_owner_3y := FALSE]

ma_any <- closed_branches_with_history[, .(
  any_closure_prev_owner_other_3y = as.integer(any(had_other_owner_3y))
), by = .(bank_id, county, YEAR)]

ma_all <- closed_branches_with_history[, .(
  all_closures_prev_owner_other_3y = as.integer(all(had_other_owner_3y))
), by = .(bank_id, county, YEAR)]

bank_cty_yr[ma_any, any_closure_prev_owner_other_3y := i.any_closure_prev_owner_other_3y, on = .(bank_id, county, YEAR)]
bank_cty_yr[ma_all, all_closures_prev_owner_other_3y := i.all_closures_prev_owner_other_3y, on = .(bank_id, county, YEAR)]

bank_cty_yr[is.na(any_closure_prev_owner_other_3y), any_closure_prev_owner_other_3y := 0L]
bank_cty_yr[is.na(all_closures_prev_owner_other_3y), all_closures_prev_owner_other_3y := 0L]
bank_cty_yr[any_closure_t == 0L, `:=`(any_closure_prev_owner_other_3y = 0L, all_closures_prev_owner_other_3y = 0L)]

cat("Bank-county-years with any M&A-related closure:", sum(bank_cty_yr$any_closure_prev_owner_other_3y), "\n")
cat("Bank-county-years with all closures M&A-related:", sum(bank_cty_yr$all_closures_prev_owner_other_3y), "\n")

cat("\n=== SUN & ABRAHAM EVENT-STUDY PANELS ===\n")

# First closure year per bank-county (not all closures M&A-related)
first_closure <- bank_cty_yr[
  any_closure_t == 1L & all_closures_prev_owner_other_3y == 0L,
  .(cohort = min(YEAR)),
  by = .(bank_id, county)
]

# All-branch deposits and branch count by bank-county-year (current-year levels)
bank_cty_yr_total <- closure_app[, .(
  total_deps_all_branches = sum(DEPSUMBR, na.rm = TRUE),
  n_branches_all = uniqueN(UNINUMBR)
), by = .(bank_id, county, YEAR)]

sunab_panel_all <- merge(bank_cty_yr_total, first_closure, by = c("bank_id", "county"), all.x = TRUE)
never_bc <- unique(sunab_panel_all[is.na(cohort), .(bank_id, county)])
keep_never <- never_bc[sample(.N, max(1L, floor(.N * params$never_treated_share)))]
sunab_panel_all <- sunab_panel_all[
  (!is.na(cohort) & YEAR >= cohort - 3L & YEAR <= cohort + 3L) |
  (is.na(cohort) & paste(bank_id, county) %in% paste(keep_never$bank_id, keep_never$county))
]
sunab_panel_all[is.na(cohort), cohort := 10000L]
sunab_panel_all[, unit_id := .GRP, by = .(bank_id, county)]

cat("SunAb all-branch panel rows:", nrow(sunab_panel_all), "\n")

# Consistent branch set: exclude branches that close in the cohort year from all years
branch_status <- closure_app[, .(bank_id, county, YEAR, UNINUMBR, closes_now = (closed == 1L))]
branch_status <- merge(branch_status, first_closure, by = c("bank_id", "county"), all.x = TRUE)
branch_status[, closes_at_cohort := closes_now & YEAR == cohort]
branches_to_exclude <- unique(branch_status[closes_at_cohort == TRUE, .(bank_id, county, UNINUMBR)])
branches_to_exclude[, exclude := TRUE]
closure_app_consistent <- branches_to_exclude[closure_app, on = .(bank_id, county, UNINUMBR)]
closure_app_consistent <- closure_app_consistent[is.na(exclude)]
closure_app_consistent[, exclude := NULL]

bank_cty_yr_consistent <- closure_app_consistent[, .(
  deps_consistent = sum(DEPSUMBR, na.rm = TRUE),
  n_branches_consistent = uniqueN(UNINUMBR)
), by = .(bank_id, county, YEAR)]

sunab_panel_consistent <- merge(
  sunab_panel_all[, .(bank_id, county, YEAR, cohort, unit_id)],
  bank_cty_yr_consistent,
  by = c("bank_id", "county", "YEAR"),
  all.x = TRUE
)
cat("SunAb consistent-branch panel rows:", nrow(sunab_panel_consistent), "\n")

cat("\n=== SAVING OUTPUT OBJECTS TO data/ ===\n")

# Outputs consumed by code/v20260410/result-generation/bank_county_year_sunab_20260409.qmd
closure_app_out <- closure_app[, .(bank_id, county, YEAR, UNINUMBR, DEPSUMBR, closed)]
bank_cty_yr_out <- bank_cty_yr[, .(
  bank_id, county, YEAR,
  total_deps_bank_county_t1, n_remaining_branches,
  any_closure_t, all_closures_prev_owner_other_3y, any_closure_prev_owner_other_3y
)]

saveRDS(closure_app_out, file.path(data_path, paste0("sunab_closure_app_", dat_suffix, ".rds")))
saveRDS(bank_cty_yr_out, file.path(data_path, paste0("sunab_bank_cty_yr_", dat_suffix, ".rds")))
saveRDS(sunab_panel_all, file.path(data_path, paste0("sunab_panel_all_", dat_suffix, ".rds")))
saveRDS(sunab_panel_consistent, file.path(data_path, paste0("sunab_panel_consistent_", dat_suffix, ".rds")))

cat("Saved sunab_closure_app_", dat_suffix, ".rds, sunab_bank_cty_yr_", dat_suffix, ".rds, sunab_panel_all_", dat_suffix, ".rds, sunab_panel_consistent_", dat_suffix, ".rds\n", sep = "")
