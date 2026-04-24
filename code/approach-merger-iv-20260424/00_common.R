# 00_common.R — shared helpers for approach-merger-iv-20260424.
#
# Approach: Replicate streamlined results using Nguyen (2019) merger-overlap IV.
# First milestone: replicate Figure 2 + first/second stage from
#   r-utilities/Projects/deposits_closures_openings/Nguyen_instrument_v1.1.qmd
#
# Upstream data (read-only):
#   C:/empirical-data-construction/sod/sod.duckdb       (table `sod`, 1994-2025)
#   C:/empirical-data-construction/nic/nic.duckdb       (table `transformations`)
#   data/zip_tech_sample_YYYYMMDD.rds                   (zip-year analysis panel)
#       <- code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R
#
# All SOD-derived intermediates rebuilt from sod.duckdb and written inside
# code/approach-merger-iv-20260424/data/ (NOT data/constructed/).

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(stringr); library(ggplot2)
  library(DBI); library(duckdb); library(simplermarkdown)
})

setFixest_etable(signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.1), se.below = TRUE)

root         <- "code/approach-merger-iv-20260424"
data_path    <- file.path(root, "data")
logs_path    <- file.path(root, "logs")
tables_path  <- file.path(root, "tables")
figures_path <- file.path(root, "figures")
notes_path   <- file.path(root, "NOTES.md")

# External duckdb paths
sod_db <- "C:/empirical-data-construction/sod/sod.duckdb"
nic_db <- "C:/empirical-data-construction/nic/nic.duckdb"

md_out  <- function(nm) file.path(tables_path,  paste0(nm, ".md"))
fig_out <- function(nm) file.path(figures_path, paste0(nm, ".png"))
log_out <- function(nm) file.path(logs_path,    paste0(nm, ".md"))
dat_out <- function(nm) file.path(data_path,    paste0(nm, ".rds"))

write_md <- function(et, path) writeLines(as.character(knitr::kable(et, format = "pipe")), path)
rnd      <- function(x, k = 3) formatC(round(x, k), format = "f", digits = k)

load_latest <- function(folder, pattern) {
  files <- list.files(folder, pattern = pattern, full.names = TRUE)
  readRDS(files[which.max(file.mtime(files))])
}

footer_mean_sd <- function(dsets, dv, treat) list(
  "Mean(outcome)" = sapply(dsets, function(d) rnd(mean(d[[dv]], na.rm = TRUE))),
  "SD(treatment)" = sapply(dsets, function(d) rnd(sd  (d[[treat]], na.rm = TRUE)))
)

open_sod <- function() dbConnect(duckdb(), sod_db, read_only = TRUE)
open_nic <- function() dbConnect(duckdb(), nic_db, read_only = TRUE)
