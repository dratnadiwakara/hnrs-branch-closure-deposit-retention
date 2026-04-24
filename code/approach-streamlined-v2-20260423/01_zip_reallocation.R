# 01_zip_reallocation.R — v2 sections 1-2.
# Zip-year incumbent reallocation with count and dep-weighted treatments.
# Uses HUD max-TOT_RATIO ZIP -> county (via S1); period split per v1 baseline.

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

# Source: data/constructed/zip_tech_sample_v2_YYYYMMDD.rds
# Built by:   sample-construction/S2_build_zip_tech_sample.R
# Contents:   zip-year panel with HUD-based county mapping and orthogonal
#             size x app decomposition. Core vars: outcome, share_deps_closed,
#             fraction_of_branches_closed, zip, county, county_yr.
ZTP <- resolve_latest("data/constructed", "^zip_tech_sample_v2_\\d{8}\\.rds$")
dt  <- setDT(load_exact(ZTP))
dt[, fraction_of_branches_closed := n_closed_zip / pmax(branches_lag1, 1)]

periods <- c("2000-07", "2008-11", "2012-19", "2020-22", "2023-24")
dsets   <- setNames(lapply(periods, period_filter, dt = dt), periods)

ctrls <- "log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1"
run <- function(d, treat) feols(
  as.formula(paste0("outcome ~ ", treat, " + ", ctrls, " | zip + county_yr")),
  data = d, vcov = ~zip)

mA <- lapply(dsets, run, treat = "fraction_of_branches_closed")
mB <- lapply(dsets, run, treat = "share_deps_closed")

write_md(etable(mA, headers = periods, tex = FALSE,
                extralines = footer_mean_sd(dsets, "outcome", "fraction_of_branches_closed")),
         md_out("T01_zip_count"))
write_md(etable(mB, headers = periods, tex = FALSE,
                extralines = footer_mean_sd(dsets, "outcome", "share_deps_closed")),
         md_out("T02_zip_depwt"))

register_outputs(c("T01_zip_count.md", "T02_zip_depwt.md"))

cat("=== T01 count ===\n"); etable(mA, headers = periods)
cat("=== T02 dep-weighted ===\n"); etable(mB, headers = periods)
