# 04_cra_county.R — snapshot §11 (CRA small-business, county-year).
# Builds county-year incumbent reallocation panel from SOD + county controls,
# merges CRA growth (in-county-branch respondents, Phil #2; already implicit via inc_set).
# Periods: 2000-07, 2008-11, 2012-19, 2020-23.

rm(list = ls())
source("code/approach-streamlined-20260423/00_common.R")

# External raw sources (OneDrive, not in repo):
#   CLOSURE_PANEL = SOD branch-level panel with `closed` indicator. Origin:
#                   ~/OneDrive/data/closure_opening_data_simple.rds
#   COUNTY_CTRL   = county-year control variables (HHI, payroll, HMDA/CRA lag
#                   growth, LMI). Origin:
#                   ~/OneDrive/data/nrs_branch_closure/county_controls_panel.rds
CLOSURE_PANEL <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
COUNTY_CTRL   <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/county_controls_panel.rds"

# Source: data/constructed/cra_county_panels_YYYYMMDD.rds
# Built by:   code/approach-streamlined-20260423/sample-construction/B3_cra_county_panel_20260423.R
# Contents:   county-year CRA small-business growth outcomes
#             (cra_growth_incty, cra_growth_all — identical because inc_set
#             inner-join already requires ≥1 branch in county). Source DB:
#             C:/empirical-data-construction/cra/cra.duckdb (D1-1 rows, action=1).
cra <- setDT(load_latest("data/constructed", "^cra_county_panels_\\d{8}\\.rds$"))

# Build county-year panel (closed deposits / total, county controls).
raw <- setDT(readRDS(CLOSURE_PANEL))
raw[, `:=`(county = str_pad(as.integer(STCNTYBR), 5, "left", "0"),
           YEAR = as.integer(YEAR),
           closed = as.integer(fifelse(is.na(closed), 0L, closed)),
           DEPSUMBR = as.numeric(DEPSUMBR))]
setorder(raw, UNINUMBR, YEAR)
raw[, dep_lag1  := shift(DEPSUMBR, 1L, type = "lag"), by = UNINUMBR]
raw[, yr_lag1   := shift(YEAR,     1L, type = "lag"), by = UNINUMBR]
raw[, dep_lag1  := fifelse(yr_lag1 == YEAR - 1L, dep_lag1, NA_real_)]

ct <- raw[!is.na(dep_lag1) & dep_lag1 > 0, .(
  total_deps = sum(dep_lag1), n_branches = uniqueN(UNINUMBR), n_banks = uniqueN(CERT)
), by = .(county, YEAR)]
cc_dep <- raw[closed == 1 & !is.na(dep_lag1) & dep_lag1 > 0,
  .(closed_deps = sum(dep_lag1)), by = .(county, YEAR)]
cty <- merge(ct, cc_dep, by = c("county", "YEAR"), all.x = TRUE)
cty[is.na(closed_deps), closed_deps := 0]
cty[, `:=`(share_deps_closed = closed_deps / pmax(total_deps, 1),
           log_n_branches    = log1p(n_branches),
           log_n_banks       = log1p(n_banks),
           log1p_total_deps  = log1p(total_deps),
           state_yr          = paste0(substr(county, 1, 2), "_", YEAR))]

cty_yr <- raw[!is.na(DEPSUMBR) & DEPSUMBR > 0, .(total_dep_county = sum(DEPSUMBR)),
              by = .(county, YEAR)]
setorder(cty_yr, county, YEAR)
cty_yr[, dep_lag4 := shift(total_dep_county, 4L, type = "lag"), by = county]
cty_yr[, yr_lag4  := shift(YEAR, 4L, type = "lag"), by = county]
cty_yr[, county_dep_growth_t4_t1 := fifelse(
  yr_lag4 == YEAR - 4 & dep_lag4 > 0,
  (total_dep_county - dep_lag4) / dep_lag4, NA_real_)]
cty <- merge(cty, cty_yr[, .(county, YEAR, county_dep_growth_t4_t1)],
             by = c("county", "YEAR"), all.x = TRUE)

cc <- setDT(readRDS(COUNTY_CTRL))
if (!"county" %in% names(cc) && "county_code" %in% names(cc)) setnames(cc, "county_code", "county")
if (!"YEAR"   %in% names(cc) && "year"        %in% names(cc)) setnames(cc, "year", "YEAR")
cc[, `:=`(county = str_pad(as.integer(county), 5, "left", "0"),
          YEAR   = as.integer(YEAR))]
ctrls_vars <- intersect(c("log_population_density", "lag_county_deposit_hhi",
                          "lag_establishment_gr", "lag_payroll_gr",
                          "lag_hmda_mtg_amt_gr", "lag_cra_loan_amount_amt_lt_1m_gr", "lmi"),
                        names(cc))
cty <- merge(cty, unique(cc[, c("county", "YEAR", ctrls_vars), with = FALSE]),
             by = c("county", "YEAR"), all.x = TRUE)
cty <- merge(cty, cra, by = c("county", "YEAR"), all.x = TRUE)

ctrl <- ~ log_n_branches + log_n_banks + log1p_total_deps + county_dep_growth_t4_t1 +
          log_population_density + lag_county_deposit_hhi + lag_establishment_gr +
          lag_payroll_gr + lag_hmda_mtg_amt_gr + lag_cra_loan_amount_amt_lt_1m_gr + lmi

periods <- c("2000-07", "2008-11", "2012-19", "2020-23")
dsets   <- setNames(lapply(periods, period_filter, dt = cty), periods)

m <- Filter(Negate(is.null), lapply(dsets, function(d) tryCatch(
  feols(cra_growth_incty ~ share_deps_closed + .[ctrl] | county + state_yr,
        data = d, vcov = ~county),
  error = function(e) { cat("  !", conditionMessage(e), "\n"); NULL })))

write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets[names(m)], "cra_growth_incty", "share_deps_closed")),
         md_out("T3_cra_county"))

cat("=== §11 CRA ===\n"); etable(m, headers = names(m))
