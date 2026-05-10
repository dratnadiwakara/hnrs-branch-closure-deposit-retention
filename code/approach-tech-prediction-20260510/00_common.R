# 00_common.R — approach-tech-prediction-20260510
#
# Implements Phil's "predict zip-year closures directly" idea
# (May 5 2026, 1:33 PM email): build a tech-driven closure prediction
# at zip-year using `frac_apps_zip × perc_hh_wMobileSub` + same controls
# as main spec; decompose actual closure variable into
# predicted (tech-driven) + residual (non-tech) components.
#
# Upstream data lineage:
#
#   data/zip_tech_sample_YYYYMMDD.rds
#     <- code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R
#
#   ~/OneDrive/data/closure_opening_data_simple.rds  (SOD branch panel)
#   ~/OneDrive/data/CH_full_app_reviews_panel.csv    (bank app launches)
#
# Pipeline:
#   sample-construction/B1_build_frac_apps_zip_20260510.R
#     -> data/zip_tech_with_frac_apps_<YYYYMMDD>.rds
#   01_first_stage_20260510.R
#     -> data/zip_tech_with_pred_resid_<YYYYMMDD>.rds
#     -> tables/T0_first_stage_*.md
#   02_second_stage_20260510.R
#     -> tables/T1_decomp_*.md

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(stringr); library(ggplot2); library(here)
})

setFixest_etable(signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.1), se.below = TRUE)

root          <- "code/approach-tech-prediction-20260510"
tables_path   <- file.path(root, "tables")
figures_path  <- file.path(root, "figures")
data_path     <- file.path(root, "data")
notes_path    <- file.path(root, "NOTES.md")

dat_suffix    <- format(Sys.time(), "%Y%m%d")

md_out  <- function(nm) file.path(tables_path,  paste0(nm, ".md"))
fig_out <- function(nm) file.path(figures_path, paste0(nm, ".png"))

write_md <- function(et, path) writeLines(as.character(knitr::kable(et, format = "pipe")), path)
rnd      <- function(x, k = 3) formatC(round(x, k), format = "f", digits = k)

period_filter <- function(dt, p) switch(p,
  "2012-19" = dt[YEAR %between% c(2012, 2019)],
  "2020+"   = dt[YEAR >= 2020])

load_latest <- function(folder, pattern) {
  files <- list.files(folder, pattern = pattern, full.names = TRUE)
  if (!length(files)) stop("No files match pattern '", pattern, "' in '", folder, "'")
  readRDS(files[which.max(file.mtime(files))])
}

footer_mean_sd <- function(dsets, dv, treat) list(
  "Mean(outcome)" = sapply(dsets, function(d) rnd(mean(d[[dv]],   na.rm = TRUE))),
  "SD(treatment)" = sapply(dsets, function(d) rnd(sd  (d[[treat]], na.rm = TRUE)))
)

wins <- function(x, lo = 0.025, hi = 0.975) {
  q <- quantile(x, c(lo, hi), na.rm = TRUE)
  pmin(pmax(x, q[1]), q[2])
}
