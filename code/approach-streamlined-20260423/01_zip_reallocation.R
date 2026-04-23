# 01_zip_reallocation.R — snapshot §§1-2 (zip-year incumbent reallocation).
# Two treatments: count (fraction_of_branches_closed) and dep-weighted (share_deps_closed).
# 5-column period split: 2000-07, 2008-11, 2012-19, 2020-22, 2023-24.

rm(list = ls())
source("code/approach-streamlined-20260423/00_common.R")

# Source: data/zip_tech_sample_YYYYMMDD.rds
# Built by:   code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R
# Contents:   zip-year incumbent reallocation panel (outcome, share_deps_closed,
#             fraction_of_branches_closed, size/app decompositions, demographics,
#             perc_hh_wMobileSub, sophisticated flag, zip/county FE keys).
dt <- setDT(load_latest("data", "^zip_tech_sample_\\d{8}\\.rds$"))
dt[, fraction_of_branches_closed := n_closed_zip / pmax(branches_lag1, 1)]

periods <- c("2000-07", "2008-11", "2012-19", "2020-22", "2023-24")
dsets   <- setNames(lapply(periods, period_filter, dt = dt), periods)

ctrls <- "log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1"
run   <- function(d, treat) feols(
  as.formula(paste0("outcome ~ ", treat, " + ", ctrls, " | zip + county_yr")),
  data = d, vcov = ~zip)

mA <- lapply(dsets, run, treat = "fraction_of_branches_closed")
mB <- lapply(dsets, run, treat = "share_deps_closed")

write_md(etable(mA, headers = periods, tex = FALSE,
                extralines = footer_mean_sd(dsets, "outcome", "fraction_of_branches_closed")),
         md_out("T1_panelA_count"))
write_md(etable(mB, headers = periods, tex = FALSE,
                extralines = footer_mean_sd(dsets, "outcome", "share_deps_closed")),
         md_out("T1_panelB_depwt"))

cat("=== §1 Count ===\n");     etable(mA, headers = periods)
cat("=== §2 Dep-weighted ===\n"); etable(mB, headers = periods)
