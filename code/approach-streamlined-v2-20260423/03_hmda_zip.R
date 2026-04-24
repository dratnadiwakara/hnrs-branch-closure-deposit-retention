# 03_hmda_zip.R — v2 sections 8-11.
# Four outcomes (purchase / refinance / second-lien / jumbo), each reported
# for THREE explicit universes:
#   all        total-market (no SOD filter)
#   branch     CRA respondents with >=1 SOD branch in (zip, YEAR)
#   incumbent  SOD incumbent (non-closer) in (zip, YEAR)
#
# Last column pooled 2020-23 (2024 HMDA growth needs 2025 LAR, unreleased).

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

# Source: data/constructed/hmda_panels_v2_YYYYMMDD.rds
# Built by:   sample-construction/S5_build_hmda_panels.R
# Contents:   zip-year panel with 12 growth columns
#             hmda_{purch,refi,sl,jumbo}_gr_{all,branch,incumbent}
#             merged onto v2 zip_tech_sample base (controls + FE keys).
HMDA <- resolve_latest("data/constructed", "^hmda_panels_v2_\\d{8}\\.rds$")
dt   <- setDT(load_exact(HMDA))

run <- function(d, dv) tryCatch(feols(
  as.formula(paste0(dv, " ~ share_deps_closed + log_n_branches + log_n_inc_banks ",
                    "+ log_total_deps + dep_growth_t3t1 | zip + county_yr")),
  data = d, vcov = ~zip),
  error = function(e) { cat("  !", conditionMessage(e), "\n"); NULL })

run_panel <- function(periods, dv, out_nm) {
  dsets <- setNames(lapply(periods, period_filter, dt = dt), periods)
  m     <- Filter(Negate(is.null), lapply(dsets, run, dv = dv))
  if (!length(m)) { cat("  no estimable periods for", dv, "\n"); return() }
  write_md(etable(m, headers = names(m), tex = FALSE,
                  extralines = footer_mean_sd(dsets[names(m)], dv, "share_deps_closed")),
           md_out(out_nm))
}

periods_pooled <- c("2000-07", "2008-11", "2012-19", "2020-23")
periods_sl     <- c("2004-07", "2008-11", "2012-19", "2020-23")
periods_jumbo  <- c("2012-19", "2020-23")

outcomes <- list(
  list(label = "purch", periods = periods_pooled),
  list(label = "refi",  periods = periods_pooled),
  list(label = "sl",    periods = periods_sl),
  list(label = "jumbo", periods = periods_jumbo)
)
universes <- c("all", "branch", "incumbent")

registered <- character()
for (oc in outcomes) {
  for (u in universes) {
    tbl <- sprintf("T08_hmda_%s_%s", oc$label, u)
    dv  <- sprintf("hmda_%s_gr_%s", oc$label, u)
    run_panel(oc$periods, dv, tbl)
    registered <- c(registered, paste0(tbl, ".md"))
  }
}
register_outputs(registered)
cat("Wrote HMDA x {purch, refi, sl, jumbo} x {all, branch, incumbent} to tables/\n")
