# 00_common.R — shared helpers for approach-streamlined-20260423.
#
# Upstream data lineage (consumed by 01..06 scripts in this folder):
#
#   data/zip_tech_sample_YYYYMMDD.rds
#     ← code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R
#       (used by 01_zip_reallocation.R, 02_decompositions.R)
#
#   data/constructed/hmda_zip_panels_YYYYMMDD.rds
#     ← code/approach-streamlined-20260423/sample-construction/B1_hmda_zip_panels_20260423.R
#       (used by 03_hmda_zip.R)
#
#   data/constructed/cra_county_panels_YYYYMMDD.rds
#     ← code/approach-streamlined-20260423/sample-construction/B3_cra_county_panel_20260423.R
#       (used by 04_cra_county.R)
#
#   data/reg_main_zip_YYYYMMDD.rds
#     ← code/approach-technology-sorting/04_build_bank_zip_year_sample_20260420.R
#       (used by 05_own_closure.R)
#
#   data/sunab_panel_consistent_*.rds
#     ← code/v20260418/sample-construction/bank_county_year_sunab_sample_20260409.R
#       (used by 06_sunab_eventstudy.R)
#
# External (OneDrive) raw sources touched directly by 04_cra_county.R:
#   ~/OneDrive/data/closure_opening_data_simple.rds          (SOD branch panel)
#   ~/OneDrive/data/nrs_branch_closure/county_controls_panel.rds  (county controls)

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(stringr); library(ggplot2); library(here)
})

setFixest_etable(signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.1), se.below = TRUE)

root         <- "code/approach-streamlined-20260423"
tables_path  <- file.path(root, "tables")
figures_path <- file.path(root, "figures")
notes_path   <- file.path(root, "NOTES.md")

# Timestamp suffix for new output files (used by sample-construction/B*.R).
dat_suffix <- format(Sys.time(), "%Y%m%d_%H%M%S")

# Append dated block to NOTES.md — used by sample-construction/B*.R diagnostic logging.
append_note <- function(title, body) {
  if (!file.exists(notes_path)) file.create(notes_path)
  con <- file(notes_path, open = "a"); on.exit(close(con))
  writeLines(c("", paste0("## ", title, " — ", format(Sys.time(), "%Y-%m-%d %H:%M")),
               "", body), con)
}

md_out  <- function(nm) file.path(tables_path,  paste0(nm, ".md"))
fig_out <- function(nm) file.path(figures_path, paste0(nm, ".png"))

write_md <- function(et, path) writeLines(as.character(knitr::kable(et, format = "pipe")), path)
rnd      <- function(x, k = 3) formatC(round(x, k), format = "f", digits = k)

period_filter <- function(dt, p) switch(p,
  "2000-07" = dt[YEAR %between% c(2000, 2007)],
  "2004-07" = dt[YEAR %between% c(2004, 2007)],
  "2008-11" = dt[YEAR %between% c(2008, 2011)],
  "2012-19" = dt[YEAR %between% c(2012, 2019)],
  "2020-22" = dt[YEAR %between% c(2020, 2022)],
  "2023-24" = dt[YEAR %between% c(2023, 2024)],
  "2020-23" = dt[YEAR %between% c(2020, 2023)])

load_latest <- function(folder, pattern) {
  files <- list.files(folder, pattern = pattern, full.names = TRUE)
  readRDS(files[which.max(file.mtime(files))])
}

footer_mean_sd <- function(dsets, dv, treat) list(
  "Mean(outcome)" = sapply(dsets, function(d) rnd(mean(d[[dv]], na.rm = TRUE))),
  "SD(treatment)" = sapply(dsets, function(d) rnd(sd  (d[[treat]], na.rm = TRUE)))
)

# Winsorize at 2.5/97.5 (used by sample-construction/B*.R).
wins <- function(x, lo = 0.025, hi = 0.975) {
  q <- quantile(x, c(lo, hi), na.rm = TRUE)
  pmin(pmax(x, q[1]), q[2])
}
