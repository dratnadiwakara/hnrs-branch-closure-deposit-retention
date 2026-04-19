rm(list=ls())
gc()
library(data.table)
library(stringr)
library(DescTools)
library(lubridate)

#' Safely sum a numeric vector, returning NA if all entries are NA.
#'
#' @param x Numeric vector to be summed.
#' @return A scalar numeric sum or NA_real_ if all values are NA.
sum_na_safe <- function(x) {
  if (all(is.na(x))) {
    NA_real_
  } else {
    as.numeric(sum(x, na.rm = TRUE))
  }
}

dat_suffix <- format(Sys.time(), "%Y%m%d")

# Base paths ---------------------------------------------------------------

# Processed data produced by this project live under the project data/ folder.
data_path <- "data"

# External raw data are stored in a sibling OneDrive data folder
# (relative to the project root).
external_data_path <- "C:/Users/dimut/OneDrive/data/"

closure_path   <- file.path(external_data_path, "closure_opening_data_simple.rds")
app_panel_path <- file.path(external_data_path, "CH_full_app_reviews_panel.csv")
fdic_path      <- file.path(external_data_path, "fdic_sod_2000_2025_simple.rds")

data_dir_visits <- file.path(external_data_path, "nrs_branch_closure")
data_dir_nrs    <- file.path(external_data_path, "nrs_branch_closure")

start_year <- 2001L
end_year   <- 2025L

# 0) Load data -------------------------------------------------------------

closure_raw <- readRDS(closure_path)
setDT(closure_raw)
closure_raw[, county := str_pad(STCNTYBR, 5, "left", "0")]
closure_raw[, YEAR := as.integer(YEAR)]

app_panel <- fread(app_panel_path)
setDT(app_panel)
app_panel <- app_panel[, .(
  CERT = FDIC_certificate_id,
  YEAR = as.integer(year),
  first_app_available,
  reviews_available,
  yearly_rating,
  tot_assets
)]

app_panel[, has_app := fifelse(first_app_available == 1, 1L, 0L)]

# Extend panel: app_panel stops at 2021; carry forward 2021 values to 2022-2025
app_2021 <- app_panel[YEAR == 2021]
if (nrow(app_2021) > 0) {
  app_extended <- rbindlist(lapply(2022:2025, function(y) {
    out <- copy(app_2021)
    out[, YEAR := y]
    out
  }))
  app_panel <- rbind(app_panel, app_extended)
}

# 1) Branch-level lags/leads for growth -----------------------------------

setorder(closure_raw, UNINUMBR, YEAR)

closure_raw[, `:=`(
  dep_lag1   = shift(DEPSUMBR, 1L, type = "lag"),
  year_lag1  = shift(YEAR,    1L, type = "lag"),
  dep_lag2   = shift(DEPSUMBR, 2L, type = "lag"),
  year_lag2  = shift(YEAR,    2L, type = "lag"),
  dep_lag3   = shift(DEPSUMBR, 3L, type = "lag"),
  year_lag3  = shift(YEAR,    3L, type = "lag"),
  dep_lead1  = shift(DEPSUMBR, 1L, type = "lead"),
  year_lead1 = shift(YEAR,    1L, type = "lead"),
  dep_lead2  = shift(DEPSUMBR, 2L, type = "lead"),
  year_lead2 = shift(YEAR,    2L, type = "lead"),
  dep_lead3  = shift(DEPSUMBR, 3L, type = "lead"),
  year_lead3 = shift(YEAR,    3L, type = "lead")
), by = UNINUMBR]

closure_raw[, dep_lag1_aligned  := fifelse(year_lag1  == YEAR - 1L, dep_lag1,  NA_real_)]
closure_raw[, dep_lag2_aligned  := fifelse(year_lag2  == YEAR - 2L, dep_lag2,  NA_real_)]
closure_raw[, dep_lag3_aligned  := fifelse(year_lag3  == YEAR - 3L, dep_lag3,  NA_real_)]
closure_raw[, dep_lead1_aligned := fifelse(year_lead1 == YEAR + 1L, dep_lead1, NA_real_)]
closure_raw[, dep_lead2_aligned := fifelse(year_lead2 == YEAR + 2L, dep_lead2, NA_real_)]
closure_raw[, dep_lead3_aligned := fifelse(year_lead3 == YEAR + 3L, dep_lead3, NA_real_)]

closure_raw[, gr_branch := fifelse(
  !is.na(dep_lag1_aligned) & dep_lag1_aligned > 0,
  (dep_lead1_aligned - dep_lag1_aligned) / dep_lag1_aligned,
  NA_real_
)]

closure_raw[, gr_branch_m3_m1 := fifelse(
  !is.na(dep_lag3_aligned) & dep_lag3_aligned > 0 & !is.na(dep_lag1_aligned),
  (dep_lag1_aligned - dep_lag3_aligned) / dep_lag3_aligned,
  NA_real_
)]

closure_raw[, gr_branch_1_2 := fifelse(
  !is.na(dep_lead1_aligned) & dep_lead1_aligned > 0 & !is.na(dep_lead2_aligned),
  (dep_lead2_aligned - dep_lead1_aligned) / dep_lead1_aligned,
  NA_real_
)]

closure_raw[, gr_branch_1_3 := fifelse(
  !is.na(dep_lead1_aligned) & dep_lead1_aligned > 0 & !is.na(dep_lead3_aligned),
  (dep_lead3_aligned - dep_lead1_aligned) / dep_lead1_aligned,
  NA_real_
)]

closure_raw[, gr_branch_2_3 := fifelse(
  !is.na(dep_lead2_aligned) & dep_lead2_aligned > 0 & !is.na(dep_lead3_aligned),
  (dep_lead3_aligned - dep_lead2_aligned) / dep_lead2_aligned,
  NA_real_
)]

# 2) Merge bank-year app indicator onto branch-year -----------------------

closure_app <- merge(
  closure_raw,
  app_panel[, .(CERT, YEAR, has_app, yearly_rating, tot_assets)],
  by = c("CERT", "YEAR"),
  all.x = TRUE
)
closure_app[is.na(has_app), has_app := 0L]
closure_app[, own_bank_has_app := has_app]
closure_app[, own_bank_app_rating := fifelse(
  !is.na(yearly_rating) & is.finite(yearly_rating),
  yearly_rating,
  0
)]

# 3) County-year closure shares and absolute amounts ----------------------

top4_cert <- c(628L, 3510L, 3511L, 7213L)

county_totals <- closure_app[, .(
  total_deps_county_lag1 = sum_na_safe(dep_lag1_aligned)
), by = .(county, YEAR)]

# Large bank: >$100B assets (tot_assets in thousands, same as bank_county_year_regression)
large_cert <- unique(closure_app[!is.na(tot_assets) & tot_assets > 100000000, CERT])

# Four mutually exclusive categories: top4, large_but_not_top4, small
closed_by_app <- closure_app[closed == 1L, .(
  cl_closed_top4 = sum_na_safe(
    fifelse(CERT %in% top4_cert, dep_lag1_aligned, NA_real_)
  ),
  cl_closed_large_but_not_top4 = sum_na_safe(
    fifelse(!(CERT %in% top4_cert) & CERT %in% large_cert, dep_lag1_aligned, NA_real_)
  ),
  cl_closed_small = sum_na_safe(
    fifelse(!(CERT %in% large_cert), dep_lag1_aligned, NA_real_)
  ),
  cl_closed_app = sum_na_safe(
    fifelse(has_app == 1L & !(CERT %in% top4_cert), dep_lag1_aligned, NA_real_)
  ),
  cl_closed_noapp = sum_na_safe(
    fifelse(has_app == 0L, dep_lag1_aligned, NA_real_)
  )
), by = .(county, YEAR)]

county_closure_shares <- merge(
  county_totals,
  closed_by_app,
  by = c("county", "YEAR"),
  all.x = TRUE
)

county_closure_shares[is.na(cl_closed_top4),  cl_closed_top4  := 0]
county_closure_shares[is.na(cl_closed_large_but_not_top4), cl_closed_large_but_not_top4 := 0]
county_closure_shares[is.na(cl_closed_small), cl_closed_small := 0]
county_closure_shares[is.na(cl_closed_app),   cl_closed_app   := 0]
county_closure_shares[is.na(cl_closed_noapp), cl_closed_noapp := 0]

county_closure_shares[, share_deps_closed_top4 := fifelse(
  total_deps_county_lag1 > 0,
  cl_closed_top4 / total_deps_county_lag1,
  0
)]
county_closure_shares[, share_deps_closed_large_but_not_top4 := fifelse(
  total_deps_county_lag1 > 0,
  cl_closed_large_but_not_top4 / total_deps_county_lag1,
  0
)]
county_closure_shares[, share_deps_closed_small := fifelse(
  total_deps_county_lag1 > 0,
  cl_closed_small / total_deps_county_lag1,
  0
)]
county_closure_shares[, share_deps_closed :=
  share_deps_closed_top4 +
    share_deps_closed_large_but_not_top4 +
    share_deps_closed_small]

county_closure_shares[, share_deps_closed_app := fifelse(
  total_deps_county_lag1 > 0,
  cl_closed_app / total_deps_county_lag1,
  0
)]
county_closure_shares[, share_deps_closed_noapp := fifelse(
  total_deps_county_lag1 > 0,
  cl_closed_noapp / total_deps_county_lag1,
  0
)]
county_closure_shares[, share_deps_closed_nontop4 :=
  share_deps_closed_large_but_not_top4 + share_deps_closed_small]

# 4) County-year total deposits at t-1 and t+1 ----------------------------

county_deps_all_years <- closure_app[, .(
  total_county_deps = sum_na_safe(DEPSUMBR)
), by = .(county, YEAR)]

# Mark branches that exist at each time point
closure_app[, exists_t1 := !is.na(dep_lag1_aligned) & dep_lag1_aligned > 0]
closure_app[, exists_lead1 := !is.na(dep_lead1_aligned) & dep_lead1_aligned > 0]

county_deps_t1 <- closure_app[exists_t1 == TRUE, .(
  total_county_deps_t1 = sum_na_safe(dep_lag1_aligned)
), by = .(county, YEAR)]

county_deps_lead1 <- closure_app[exists_lead1 == TRUE, .(
  total_county_deps_lead1 = sum_na_safe(dep_lead1_aligned)
), by = .(county, YEAR)]

# 5) Minimal county controls -----------------------------------------------

bank_cty_yr <- closure_app[, .(
  deps_curr = sum_na_safe(DEPSUMBR),
  deps_lag1 = sum_na_safe(dep_lag1_aligned),
  n_close   = sum(closed == 1L, na.rm = TRUE)
), by = .(RSSDID, county, YEAR)]

bank_cty_yr[, bank_type := fifelse(n_close > 0L, "CLOSER", "INCUMBENT")]

county_bankcounts <- bank_cty_yr[, .(
  banks_county_curr = .N
), by = .(county, YEAR)]
setorder(county_bankcounts, county, YEAR)
county_bankcounts[, banks_county_lag1 := shift(banks_county_curr, 1L, type = "lag"), by = county]

fdic_all <- readRDS(fdic_path)
setDT(fdic_all)
fdic_all[, county := str_pad(STCNTYBR, 5, "left", "0")]
fdic_all[, YEAR := as.integer(YEAR)]

market_totals <- fdic_all[, .(
  total_deps = sum(DEPSUMBR, na.rm = TRUE)
), by = .(county, YEAR)]

complete_grid <- CJ(
  county = unique(market_totals$county),
  YEAR   = min(market_totals$YEAR):max(market_totals$YEAR)
)

market_bal <- merge(
  complete_grid,
  market_totals,
  by = c("county", "YEAR"),
  all.x = TRUE
)
market_bal[is.na(total_deps), total_deps := 0]
setorder(market_bal, county, YEAR)

market_bal[, deps_lag1 := shift(total_deps, 1L, type = "lag"), by = county]
market_bal[, deps_lag4 := shift(total_deps, 4L, type = "lag"), by = county]
market_bal[, county_dep_growth_t4_t1 := fifelse(
  deps_lag4 > 0,
  (deps_lag1 - deps_lag4) / deps_lag4,
  NA_real_
)]

controls_cy <- merge(
  county_bankcounts[, .(county, YEAR, banks_county_lag1)],
  market_bal[, .(county, YEAR, deps_lag1, county_dep_growth_t4_t1)],
  by = c("county", "YEAR"),
  all.x = TRUE
)

controls_cy <- merge(
  controls_cy,
  county_totals[, .(county, YEAR, total_deps_county_lag1)],
  by = c("county", "YEAR"),
  all.x = TRUE
)

# 6) Build regression branch panel ----------------------------------------

branch_panel <- closure_app[!is.na(gr_branch)]
branch_panel[, gr_branch := Winsorize(
  gr_branch,
  val = quantile(gr_branch, probs = c(0.025, 0.975), na.rm = FALSE)
)]
branch_panel[, gr_branch_m3_m1 := Winsorize(
  gr_branch_m3_m1,
  val = quantile(gr_branch_m3_m1, probs = c(0.025, 0.975), na.rm = TRUE)
)]
branch_panel[, gr_branch_1_2 := Winsorize(
  gr_branch_1_2,
  val = quantile(gr_branch_1_2, probs = c(0.025, 0.975), na.rm = TRUE)
)]
branch_panel[, gr_branch_1_3 := Winsorize(
  gr_branch_1_3,
  val = quantile(gr_branch_1_3, probs = c(0.025, 0.975), na.rm = TRUE)
)]
branch_panel[, gr_branch_2_3 := Winsorize(
  gr_branch_2_3,
  val = quantile(gr_branch_2_3, probs = c(0.025, 0.975), na.rm = TRUE)
)]
branch_panel[, state_yr := paste0(substr(county, 1, 2), YEAR)]
branch_panel[, bank_yr := paste0(RSSDID, YEAR)]

branch_panel <- merge(
  branch_panel,
  county_closure_shares[, .(
    county,
    YEAR,
    share_deps_closed,
    share_deps_closed_top4,
    share_deps_closed_large_but_not_top4,
    share_deps_closed_small,
    share_deps_closed_nontop4,
    share_deps_closed_app,
    share_deps_closed_noapp,
    cl_closed_top4,
    cl_closed_app,
    cl_closed_noapp
  )],
  by = c("county", "YEAR"),
  all.x = TRUE
)

branch_panel <- merge(
  branch_panel,
  controls_cy[, .(
    county,
    YEAR,
    banks_county_lag1,
    county_dep_growth_t4_t1,
    deps_lag1
  )],
  by = c("county", "YEAR"),
  all.x = TRUE
)

branch_panel <- merge(
  branch_panel,
  county_deps_t1[, .(county, YEAR, total_county_deps_t1)],
  by = c("county", "YEAR"),
  all.x = TRUE
)

branch_panel <- merge(
  branch_panel,
  county_deps_lead1[, .(county, YEAR, total_county_deps_lead1)],
  by = c("county", "YEAR"),
  all.x = TRUE
)

branch_panel <- merge(
  branch_panel,
  bank_cty_yr[, .(RSSDID, county, YEAR, bank_type)],
  by = c("RSSDID", "county", "YEAR"),
  all.x = TRUE
)
branch_panel[, incumbent_bank := fifelse(bank_type == "INCUMBENT", 1L, 0L)]

branch_panel[, top4_bank := fifelse(CERT %in% top4_cert, 1L, 0L)]
branch_panel[, large_but_not_top4_bank := fifelse(
  !(CERT %in% top4_cert) & CERT %in% large_cert,
  1L,
  0L
)]
branch_panel[, small_bank := fifelse(
  !(CERT %in% top4_cert) & !(CERT %in% large_cert),
  1L,
  0L
)]

# 7) Market share changes --------------------------------------------------

branch_panel <- branch_panel[
  !is.na(dep_lag1_aligned) & dep_lag1_aligned > 0 &
    !is.na(dep_lead1_aligned) & dep_lead1_aligned > 0
]

branch_panel[, mkt_share_t1 := fifelse(
  total_county_deps_t1 > 0,
  dep_lag1_aligned / total_county_deps_t1,
  NA_real_
)]
branch_panel[, mkt_share_lead1 := fifelse(
  total_county_deps_lead1 > 0,
  dep_lead1_aligned / total_county_deps_lead1,
  NA_real_
)]
branch_panel[, delta_mkt_share := mkt_share_lead1 - mkt_share_t1]

branch_panel[, delta_mkt_share_win := Winsorize(
  delta_mkt_share,
  val = quantile(
    delta_mkt_share,
    probs = c(0.01, 0.99),
    na.rm = TRUE
  )
)]

# 7b) Drop in visits (2019 vs 2021) ---------------------------------------

branch_visits <- readRDS(file.path(data_dir_visits, "bank_branch_visits_count_2019_2022.rds"))
setDT(branch_visits)
branch_visits[, yr := year(DATE_RANGE_START)]
branch_visits <- branch_visits[yr %in% c(2019, 2021)]

branch_bank <- closure_app[
  order(UNINUMBR, -YEAR)
][
  , .SD[1],
  by = UNINUMBR
][
  , .(UNINUMBR, CERT, county)
]

branch_visits <- merge(branch_visits, branch_bank, by = "UNINUMBR", all.x = TRUE)

bank_change <- branch_visits[, .(
  total_visits = sum(RAW_VISIT_COUNTS, na.rm = TRUE)
), by = .(CERT, yr)]

bank_change <- dcast(bank_change, CERT ~ yr, value.var = "total_visits")
bank_change[, drop_in_visits := (`2019` - `2021`) / `2019`]
bank_change[, drop_in_visits := Winsorize(
  drop_in_visits,
  quantile(
    drop_in_visits,
    probs = c(0.01, 0.99),
    na.rm = TRUE
  )
)]
bank_change[, high_drop_visits := as.integer(
  drop_in_visits > median(drop_in_visits, na.rm = TRUE)
)]

branch_panel <- merge(
  branch_panel,
  bank_change[, .(CERT, drop_in_visits, high_drop_visits)],
  by = "CERT",
  all.x = TRUE
)

county_change <- branch_visits[!is.na(county), .(
  total_visits = sum(RAW_VISIT_COUNTS, na.rm = TRUE)
), by = .(county, yr)]

county_change <- dcast(county_change, county ~ yr, value.var = "total_visits")
county_change[, drop_in_visits_county := (`2019` - `2021`) / `2019`]
county_change[, drop_in_visits_county := Winsorize(
  drop_in_visits_county,
  quantile(
    drop_in_visits_county,
    probs = c(0.01, 0.99),
    na.rm = TRUE
  )
)]
county_change[, high_drop_visits_county := as.integer(
  drop_in_visits_county > median(drop_in_visits_county, na.rm = TRUE)
)]

branch_panel <- merge(
  branch_panel,
  county_change[, .(county, drop_in_visits_county, high_drop_visits_county)],
  by = "county",
  all.x = TRUE
)

# 7c) App quality vs other banks in county --------------------------------

bank_cy_rating <- unique(closure_app[, .(
  CERT,
  county,
  YEAR,
  rating = own_bank_app_rating
)])

cy_stats <- bank_cy_rating[, .(
  max_rating = max(rating, na.rm = TRUE),
  med_rating = median(rating, na.rm = TRUE)
), by = .(county, YEAR)]

bank_cy_rating <- merge(
  bank_cy_rating,
  cy_stats,
  by = c("county", "YEAR")
)

bank_cy_rating[, best_app_in_county := as.integer(rating >= max_rating)]
bank_cy_rating[, above_median_app_in_county := as.integer(rating > med_rating)]

app_quality_cy <- bank_cy_rating[, .(
  CERT,
  county,
  YEAR,
  best_app_in_county,
  above_median_app_in_county
)]

branch_panel <- merge(
  branch_panel,
  app_quality_cy,
  by = c("CERT", "county", "YEAR"),
  all.x = TRUE
)

# 8) Final regression sample ----------------------------------------------

branch_panel[, closer_remaining_branch := 1L - incumbent_bank]

county_controls_panel <- readRDS(file.path(data_dir_nrs, "county_controls_panel.rds"))
setDT(county_controls_panel)

branch_panel <- merge(
  branch_panel,
  county_controls_panel,
  by.x = c("county", "YEAR"),
  by.y = c("county_code", "year"),
  all.x = TRUE
)

# 8a) Household mobile subscription (fill missing with closest future by county)
perc_mobile <- fread(file.path(data_path, "raw", "perc_hh_wMobileSub.csv"))
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

branch_panel <- merge(
  branch_panel,
  perc_mobile[, .(county, YEAR, perc_hh_wMobileSub)],
  by = c("county", "YEAR"),
  all.x = TRUE
)

branch_panel[, high_perc_hh_wMobileSub := as.integer(
  perc_hh_wMobileSub > median(perc_hh_wMobileSub, na.rm = TRUE)
), by = YEAR]

reg_dt <- branch_panel[
  YEAR >= start_year & YEAR <= end_year &
    banks_county_lag1 >= 3
]

reg_dt[, bank_type_fct := factor(
  fcase(
    top4_bank == 1L, "top4",
    large_but_not_top4_bank == 1L, "large_but_not_top4",
    default = "other"
  ),
  levels = c("other", "top4", "large_but_not_top4")
)]

reg_dt[, county_yr := paste0(county, YEAR)]

branch_panel_regression_sample <- reg_dt

saveRDS(
  branch_panel_regression_sample,
  file.path(data_path, paste0("branch_panel_regression_sample_",dat_suffix,".rds"))
)
