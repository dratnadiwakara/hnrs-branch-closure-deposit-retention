# 06_iv_second_stage.R
# IV version of streamlined T1 Panel B (dep-weighted): one column per period,
# same outcome / controls / FE / cluster as approach-streamlined-20260423/01_zip_reallocation.R,
# but share_deps_closed is instrumented by Expose_Event (Nguyen merger overlap).

rm(list = ls())
source("code/approach-merger-iv-20260424/00_common.R")

# Source: data/zip_tech_sample_YYYYMMDD.rds
# Built by:   code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R
dt <- setDT(load_latest("data", "^zip_tech_sample_\\d{8}\\.rds$"))
dt[, zip := str_pad(as.character(zip), 5, "left", "0")]

# Source: code/approach-merger-iv-20260424/data/nguyen_instrument_zips_20260424.rds
# Built by:   code/approach-merger-iv-20260424/03_build_merger_instrument.R
inst <- setDT(readRDS(dat_out("nguyen_instrument_zips_20260424")))
inst_zy <- unique(inst[, .(zip = ZIPBR, YEAR = Event_Year, Expose_Event = 1L)])
dt <- merge(dt, inst_zy, by = c("zip", "YEAR"), all.x = TRUE)
dt[is.na(Expose_Event), Expose_Event := 0L]

# Match streamlined periods & period_filter exactly.
period_filter <- function(dt, p) switch(p,
  "2000-07" = dt[YEAR %between% c(2000, 2007)],
  "2008-11" = dt[YEAR %between% c(2008, 2011)],
  "2012-19" = dt[YEAR %between% c(2012, 2019)],
  "2020-22" = dt[YEAR %between% c(2020, 2022)],
  "2023-24" = dt[YEAR %between% c(2023, 2024)])

periods <- c("2000-07", "2008-11", "2012-19", "2020-22", "2023-24")
dsets   <- setNames(lapply(periods, period_filter, dt = dt), periods)

ctrls <- "log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1"
run_iv <- function(d) feols(
  as.formula(paste0("outcome ~ ", ctrls,
                    " | zip + county_yr | share_deps_closed ~ Expose_Event")),
  data = d, vcov = ~zip)

mIV <- lapply(dsets, run_iv)

et <- etable(mIV, headers = periods, tex = FALSE,
             fitstat = c("n", "r2", "ivf"),
             extralines = c(
               footer_mean_sd(dsets, "outcome", "share_deps_closed"),
               list("SD(Expose_Event)" =
                      sapply(dsets, function(d) rnd(sd(d$Expose_Event, na.rm = TRUE))))
             ))
write_md(et, md_out("T_iv_second_stage"))

cat("\n### IV second-stage (periods, Panel B format)\n\n")
cat("| Period | Coef (share_deps_closed) | SE | Sig | N | IV-F |\n",
    "|---|---|---|---|---|---|\n", sep = "")
for (p in periods) {
  m <- mIV[[p]]
  b <- coef(m)["fit_share_deps_closed"]; s <- se(m)["fit_share_deps_closed"]
  pv <- pvalue(m)["fit_share_deps_closed"]
  sig <- ifelse(pv < 0.01, "***", ifelse(pv < 0.05, "**", ifelse(pv < 0.1, "*", "")))
  f <- tryCatch(fitstat(m, "ivf")$ivf1$stat, error = function(e) NA_real_)
  cat(sprintf("| %s | %s | %s | %s | %s | %s |\n",
              p, rnd(b), rnd(s), sig,
              format(nobs(m), big.mark = ","),
              rnd(f, 1)))
}
