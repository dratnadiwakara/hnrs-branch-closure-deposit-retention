# 04_cra_county.R — v2 section 12.
# CRA small-business growth at county x YEAR, three explicit universes:
#   all        all CRA respondents
#   branch     respondents with >= 1 SOD branch in (county, YEAR)
#   incumbent  SOD incumbent (non-closer) in (county, YEAR)
#
# Timing audit for RHS variables (addresses audit comment 8):
#   share_deps_closed         deps in closing branches / total county deps at t-1
#   log_n_branches            SOD branch count at t-1
#   log_n_banks               SOD bank count at t-1
#   log1p_total_deps          log1p(total county deposits at t-1)
#   county_dep_growth_lag4_l1 (total_dep_county_{t-1} - total_dep_county_{t-4})
#                               / total_dep_county_{t-4}
#   log_population_density    t (time-varying from county_controls)
#   lag_county_deposit_hhi    t-1
#   lag_establishment_gr      t-1
#   lag_payroll_gr            t-1
#   lag_hmda_mtg_amt_gr       t-1
#   lag_cra_loan_amount_amt_lt_1m_gr  t-1
#   lmi                       t (time-invariant-ish)
#
# All controls except log_population_density and lmi are pre-treatment.
# Last column 2020-23 (2025 CRA unreleased => 2024 growth NA).

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

# Source: data/constructed/cra_panels_v2_YYYYMMDD.rds
# Built by:   sample-construction/S4_build_cra_panels.R
# Contents:   county x YEAR panel with cra_growth_{all, branch, incumbent}.
CRA           <- resolve_latest("data/constructed", "^cra_panels_v2_\\d{8}\\.rds$")
CLOSURE_PANEL <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
COUNTY_CTRL   <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/county_controls_panel.rds"

cra <- setDT(load_exact(CRA))

# Build county x YEAR treatment panel (share_deps_closed + controls) fresh.
raw <- setDT(load_exact(CLOSURE_PANEL))
raw[, `:=`(county = str_pad(as.integer(STCNTYBR), 5, "left", "0"),
           YEAR = as.integer(YEAR),
           closed = as.integer(fifelse(is.na(closed), 0L, closed)),
           DEPSUMBR = as.numeric(DEPSUMBR))]
setorder(raw, UNINUMBR, YEAR)
raw[, dep_lag1 := shift(DEPSUMBR, 1L, type = "lag"), by = UNINUMBR]
raw[, yr_lag1  := shift(YEAR,     1L, type = "lag"), by = UNINUMBR]
raw[, dep_lag1 := fifelse(yr_lag1 == YEAR - 1L, dep_lag1, NA_real_)]

ct     <- raw[!is.na(dep_lag1) & dep_lag1 > 0, .(
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

# Pre-treatment county deposit growth: (deps_{t-1} - deps_{t-4}) / deps_{t-4}.
cty_yr <- raw[!is.na(DEPSUMBR) & DEPSUMBR > 0,
  .(total_dep_county = sum(DEPSUMBR)), by = .(county, YEAR)]
setorder(cty_yr, county, YEAR)
cty_yr[, dep_lag1 := shift(total_dep_county, 1L, type = "lag"), by = county]
cty_yr[, dep_lag4 := shift(total_dep_county, 4L, type = "lag"), by = county]
cty_yr[, yr_l1    := shift(YEAR, 1L, type = "lag"), by = county]
cty_yr[, yr_l4    := shift(YEAR, 4L, type = "lag"), by = county]
cty_yr[, county_dep_growth_lag4_l1 := fifelse(
  yr_l1 == YEAR - 1 & yr_l4 == YEAR - 4 & dep_lag4 > 0,
  (dep_lag1 - dep_lag4) / dep_lag4, NA_real_)]
cty <- merge(cty, cty_yr[, .(county, YEAR, county_dep_growth_lag4_l1)],
             by = c("county", "YEAR"), all.x = TRUE)

cc <- setDT(load_exact(COUNTY_CTRL))
if (!"county" %in% names(cc) && "county_code" %in% names(cc)) setnames(cc, "county_code", "county")
if (!"YEAR"   %in% names(cc) && "year"        %in% names(cc)) setnames(cc, "year", "YEAR")
cc[, `:=`(county = str_pad(as.integer(county), 5, "left", "0"),
          YEAR   = as.integer(YEAR))]
ctrl_vars <- intersect(c("log_population_density", "lag_county_deposit_hhi",
                         "lag_establishment_gr", "lag_payroll_gr",
                         "lag_hmda_mtg_amt_gr", "lag_cra_loan_amount_amt_lt_1m_gr", "lmi"),
                       names(cc))
cty <- merge(cty, unique(cc[, c("county", "YEAR", ctrl_vars), with = FALSE]),
             by = c("county", "YEAR"), all.x = TRUE)
cty <- merge(cty, cra, by = c("county", "YEAR"), all.x = TRUE)

ctrl <- ~ log_n_branches + log_n_banks + log1p_total_deps + county_dep_growth_lag4_l1 +
          log_population_density + lag_county_deposit_hhi + lag_establishment_gr +
          lag_payroll_gr + lag_hmda_mtg_amt_gr + lag_cra_loan_amount_amt_lt_1m_gr + lmi

periods <- c("2000-07", "2008-11", "2012-19", "2020-23")
dsets   <- setNames(lapply(periods, period_filter, dt = cty), periods)

run <- function(d, dv) tryCatch(
  feols(as.formula(paste0(dv, " ~ share_deps_closed + .[ctrl] | county + state_yr")),
        data = d, vcov = ~county),
  error = function(e) { cat("  !", conditionMessage(e), "\n"); NULL })

for (u in c("all", "branch", "incumbent")) {
  dv <- paste0("cra_growth_", u)
  m  <- Filter(Negate(is.null), lapply(dsets, run, dv = dv))
  if (!length(m)) next
  write_md(etable(m, headers = names(m), tex = FALSE,
                  extralines = footer_mean_sd(dsets[names(m)], dv, "share_deps_closed")),
           md_out(paste0("T12_cra_", u)))
}

register_outputs(c("T12_cra_all.md", "T12_cra_branch.md", "T12_cra_incumbent.md"))
cat("Wrote CRA x {all, branch, incumbent} to tables/\n")
