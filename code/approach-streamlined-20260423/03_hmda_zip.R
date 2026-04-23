# 03_hmda_zip.R — snapshot §§8-10 (HMDA zip-year lending outcomes).
# Panel A: all purchase, Panel B: second-lien, Panel C: jumbo (2012+).
# Periods: 2000-07, 2008-11, 2012-19, 2020-23 (2024 dropped; needs 2025 LAR).

rm(list = ls())
source("code/approach-streamlined-20260423/00_common.R")

# Source: data/constructed/hmda_zip_panels_YYYYMMDD.rds
# Built by:   code/approach-streamlined-20260423/sample-construction/B1_hmda_zip_panels_20260423.R
# Contents:   zip-year HMDA outcomes — hmda_purch_gr_all, hmda_purch_gr_sl
#             (second-lien), hmda_purch_gr_jumbo (vs FHFA CLL, 2012+) plus
#             share_deps_closed + zip-year controls. Tract→zip via HUD
#             RES_RATIO crosswalk.
dt <- setDT(load_latest("data/constructed", "^hmda_zip_panels_\\d{8}\\.rds$"))

run <- function(d, dv) tryCatch(feols(
  as.formula(paste0(dv, " ~ share_deps_closed + log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1 | zip + county_yr")),
  data = d, vcov = ~zip),
  error = function(e) { cat("  !", conditionMessage(e), "\n"); NULL })

run_panel <- function(periods, dv, out_nm) {
  dsets <- setNames(lapply(periods, period_filter, dt = dt), periods)
  m     <- Filter(Negate(is.null), lapply(dsets, run, dv = dv))
  write_md(etable(m, headers = names(m), tex = FALSE,
                  extralines = footer_mean_sd(dsets[names(m)], dv, "share_deps_closed")),
           md_out(out_nm))
  cat("Wrote", out_nm, "\n"); m
}

run_panel(c("2000-07", "2008-11", "2012-19", "2020-23"), "hmda_purch_gr_all",   "T2_panelA1_purchase")
run_panel(c("2000-07", "2008-11", "2012-19", "2020-23"), "hmda_refi_gr_all",    "T2_panelA2_refi")
run_panel(c("2004-07", "2008-11", "2012-19", "2020-23"), "hmda_purch_gr_sl",    "T2_panelB_secondlien")
run_panel(c("2012-19", "2020-23"),                       "hmda_purch_gr_jumbo", "T2_panelC_jumbo")
