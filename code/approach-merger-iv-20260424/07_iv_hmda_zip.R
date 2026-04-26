# 07_iv_hmda_zip.R
# IV version of approach-streamlined-20260423/03_hmda_zip.R.
# Same outcome / controls / FE / cluster, but share_deps_closed instrumented
# by Expose_Event (Nguyen merger overlap), one column per period.

rm(list = ls())
source("code/approach-merger-iv-20260424/00_common.R")

# Source: data/constructed/hmda_zip_panels_YYYYMMDD.rds
# Built by:   code/approach-streamlined-20260423/sample-construction/B1_hmda_zip_panels_20260423.R
# Contents:   zip-year HMDA outcomes (purch_all, refi_all, purch_sl, purch_jumbo)
#             plus share_deps_closed + zip-year controls + county_yr.
dt <- setDT(load_latest("data/constructed", "^hmda_zip_panels_\\d{8}\\.rds$"))
dt[, zip := str_pad(as.character(zip), 5, "left", "0")]

# Source: code/approach-merger-iv-20260424/data/nguyen_instrument_zips_20260424.rds
# Built by:   code/approach-merger-iv-20260424/03_build_merger_instrument.R
inst <- setDT(readRDS(dat_out("nguyen_instrument_zips_20260424")))
inst_zy <- unique(inst[, .(zip = ZIPBR, YEAR = Event_Year, Expose_Event = 1L)])
dt <- merge(dt, inst_zy, by = c("zip", "YEAR"), all.x = TRUE)
dt[is.na(Expose_Event), Expose_Event := 0L]

period_filter <- function(dt, p) switch(p,
  "2000-07" = dt[YEAR %between% c(2000, 2007)],
  "2004-07" = dt[YEAR %between% c(2004, 2007)],
  "2008-11" = dt[YEAR %between% c(2008, 2011)],
  "2012-19" = dt[YEAR %between% c(2012, 2019)],
  "2020-22" = dt[YEAR %between% c(2020, 2022)],
  "2023-24" = dt[YEAR %between% c(2023, 2024)])

ctrls <- "log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1"

run_iv <- function(d, dv) tryCatch(feols(
  as.formula(paste0(dv, " ~ ", ctrls,
                    " | zip + county_yr | share_deps_closed ~ Expose_Event")),
  data = d, vcov = ~zip),
  error = function(e) { cat("  !", conditionMessage(e), "\n"); NULL })

run_panel <- function(periods, dv, out_nm, panel_label) {
  dsets <- setNames(lapply(periods, period_filter, dt = dt), periods)
  dsets <- lapply(dsets, function(d) d[!is.na(get(dv))])
  m     <- Filter(Negate(is.null), lapply(dsets, run_iv, dv = dv))
  if (length(m) == 0L) { cat("No models fit for", out_nm, "\n"); return(invisible(NULL)) }

  dsets_kept <- dsets[names(m)]
  et <- etable(m, headers = names(m), tex = FALSE,
               fitstat = c("n", "r2", "ivf"),
               extralines = c(
                 footer_mean_sd(dsets_kept, dv, "share_deps_closed"),
                 list("SD(Expose_Event)" =
                        sapply(dsets_kept, function(d) rnd(sd(d$Expose_Event, na.rm = TRUE))))
               ))
  write_md(et, md_out(out_nm))
  cat("Wrote", out_nm, "\n")

  cat("\n###", panel_label, "(IV) — outcome:", dv, "\n\n")
  cat("| Period | Coef (share_deps_closed) | SE | Sig | N | IV-F |\n",
      "|---|---|---|---|---|---|\n", sep = "")
  for (p in names(m)) {
    mm <- m[[p]]
    b <- coef(mm)["fit_share_deps_closed"]; s <- se(mm)["fit_share_deps_closed"]
    pv <- pvalue(mm)["fit_share_deps_closed"]
    sig <- ifelse(pv < 0.01, "***", ifelse(pv < 0.05, "**", ifelse(pv < 0.1, "*", "")))
    f <- tryCatch(fitstat(mm, "ivf")$ivf1$stat, error = function(e) NA_real_)
    cat(sprintf("| %s | %s | %s | %s | %s | %s |\n",
                p, rnd(b), rnd(s), sig,
                format(nobs(mm), big.mark = ","),
                rnd(f, 1)))
  }
  invisible(m)
}

run_panel(c("2000-07", "2008-11", "2012-19", "2020-22", "2023-24"),
          "hmda_purch_gr_all",   "T_iv_hmda_panelA1_purchase",   "Panel A1 — purchase")
run_panel(c("2000-07", "2008-11", "2012-19", "2020-22", "2023-24"),
          "hmda_refi_gr_all",    "T_iv_hmda_panelA2_refi",       "Panel A2 — refi")
run_panel(c("2004-07", "2008-11", "2012-19", "2020-22", "2023-24"),
          "hmda_purch_gr_sl",    "T_iv_hmda_panelB_secondlien",  "Panel B — second-lien")
run_panel(c("2012-19", "2020-22", "2023-24"),
          "hmda_purch_gr_jumbo", "T_iv_hmda_panelC_jumbo",       "Panel C — jumbo")
