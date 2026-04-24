# 00_common.R — shared helpers for approach-streamlined-v2-20260423.
#
# Design goals relative to v1 (approach-streamlined-20260423):
#   - Reproducibility-grade loaders (load_exact) replace mtime-based load_latest().
#   - Sample-flow attrition reporting baked in.
#   - Canonical ZIP->county mapping (max HUD TOT_RATIO) via S1.
#   - Orthogonal size x app partition for decompositions.
#   - CRA/HMDA outcomes produced for three explicit universes.
#   - Own-closure filters stored as flags, not applied at build time.
#   - Sun-Abraham era split on cohort, not observation YEAR.
#
# Lineage (consumed by 01..06):
#
#   data/constructed/zip_county_xwalk_v2.rds
#     <- sample-construction/S1_build_zip_county_xwalk.R
#        (HUD ZIP-COUNTY, max TOT_RATIO per ZIP)
#
#   data/constructed/zip_tech_sample_v2_YYYYMMDD.rds
#     <- sample-construction/S2_build_zip_tech_sample.R
#        (used by 01, 02)
#
#   data/constructed/bank_zip_sample_v2_YYYYMMDD.rds
#     <- sample-construction/S3_build_bank_zip_sample.R
#        (used by 05; filters as FLAGS, not drops)
#
#   data/constructed/cra_panels_v2_YYYYMMDD.rds
#     <- sample-construction/S4_build_cra_panels.R
#        (three universes: all / branch_present / incumbent)
#
#   data/constructed/hmda_panels_v2_YYYYMMDD.rds
#     <- sample-construction/S5_build_hmda_panels.R
#        (three universes x {purchase, refi, second-lien, jumbo})
#
#   data/constructed/sunab_panel_v2_YYYYMMDD.rds
#     <- sample-construction/S6_build_sunab_panel.R
#        (cohort_era labels attached at build time)
#
# External raw sources:
#   ~/OneDrive/data/ZIP_COUNTY_122019.xlsx                 HUD ZIP-COUNTY crosswalk
#   ~/OneDrive/data/closure_opening_data_simple.rds        SOD branch panel
#   ~/OneDrive/data/nrs_branch_closure/county_controls_panel.rds
#   ~/OneDrive/data/CH_full_app_reviews_panel.csv          bank app panel
#   C:/empirical-data-construction/hmda/hmda.duckdb         HMDA LAR
#   C:/empirical-data-construction/cra/cra.duckdb           CRA disclosure

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(stringr); library(ggplot2)
  library(readxl); library(here); library(digest)
})

setFixest_etable(signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.1), se.below = TRUE)

root         <- "code/approach-streamlined-v2-20260423"
tables_path  <- file.path(root, "tables")
figures_path <- file.path(root, "figures")
diag_path    <- file.path(root, "diagnostics")

dat_suffix <- format(Sys.time(), "%Y%m%d_%H%M%S")
DATE_TAG   <- format(Sys.time(), "%Y%m%d")

md_out  <- function(nm) file.path(tables_path,  paste0(nm, ".md"))
fig_out <- function(nm) file.path(figures_path, paste0(nm, ".png"))

write_md <- function(et, path) writeLines(as.character(knitr::kable(et, format = "pipe")), path)
rnd      <- function(x, k = 3) formatC(round(x, k), format = "f", digits = k)

# ---- Reproducibility-grade loader ------------------------------------------
# Asserts exact path exists. Optional row-count and sha256 checks.
# Paper-result scripts MUST use load_exact. load_latest_explore() remains
# available for interactive work only (not used by 01..06).
load_exact <- function(path, expect_rows = NA_integer_, expect_sha = NA_character_) {
  if (!file.exists(path)) stop("load_exact: file not found -> ", path)
  ext <- tolower(tools::file_ext(path))
  x <- switch(ext,
    rds = readRDS(path),
    csv = fread(path),
    xlsx = as.data.table(read_excel(path)),
    stop("load_exact: unsupported extension: ", ext))
  if (!is.na(expect_rows) && nrow(x) != expect_rows)
    stop(sprintf("load_exact: %s nrow=%d expected %d", path, nrow(x), expect_rows))
  if (!is.na(expect_sha)) {
    sha <- digest::digest(path, algo = "sha256", file = TRUE)
    if (sha != expect_sha) stop(sprintf("load_exact: %s sha256=%s expected %s", path, sha, expect_sha))
  }
  x
}

load_latest_explore <- function(folder, pattern) {
  files <- list.files(folder, pattern = pattern, full.names = TRUE)
  if (!length(files)) stop("load_latest_explore: no files matching ", pattern, " in ", folder)
  readRDS(files[which.max(file.mtime(files))])
}

# Resolve newest version of a pattern and assert match exists. Used by 01..06
# to pin the latest v2-tagged artifact produced by S2..S6.
resolve_latest <- function(folder, pattern) {
  files <- list.files(folder, pattern = pattern, full.names = TRUE)
  if (!length(files)) stop("resolve_latest: no files matching ", pattern, " in ", folder)
  files[which.max(file.mtime(files))]
}

# ---- Period filters ---------------------------------------------------------
period_filter <- function(dt, p) switch(p,
  "2000-07" = dt[YEAR %between% c(2000, 2007)],
  "2004-07" = dt[YEAR %between% c(2004, 2007)],
  "2008-11" = dt[YEAR %between% c(2008, 2011)],
  "2012-19" = dt[YEAR %between% c(2012, 2019)],
  "2020-22" = dt[YEAR %between% c(2020, 2022)],
  "2023-24" = dt[YEAR %between% c(2023, 2024)],
  "2020-23" = dt[YEAR %between% c(2020, 2023)])

# Cohort-era filter: used by Sun-Abraham (note this is on COHORT, not YEAR).
cohort_era_filter <- function(dt, era) switch(era,
  "Pre-2012"  = dt[cohort <  2012],
  "2012-2019" = dt[cohort %between% c(2012, 2019)],
  "2020-2024" = dt[cohort %between% c(2020, 2024)])

# ---- Footer helpers ---------------------------------------------------------
footer_mean_sd <- function(dsets, dv, treat) list(
  "Mean(outcome)" = sapply(dsets, function(d) rnd(mean(d[[dv]], na.rm = TRUE))),
  "SD(treatment)" = sapply(dsets, function(d) rnd(sd  (d[[treat]], na.rm = TRUE)))
)

# ---- Sample-flow diagnostic -------------------------------------------------
# Call during any builder at each filter step to log (step_name, n_rows,
# n_units, rows_dropped_pct). Final sample-flow table saved to diagnostics/.
sample_flow_init <- function(label) {
  list(label = label, steps = list(), t0 = Sys.time())
}
sample_flow_step <- function(flow, step_name, dt, unit_cols = NULL) {
  row <- list(step = step_name, n_rows = nrow(dt))
  if (!is.null(unit_cols)) {
    row[[paste0("n_", paste(unit_cols, collapse = "_"))]] <- uniqueN(dt, by = unit_cols)
  }
  flow$steps[[length(flow$steps) + 1]] <- row
  flow
}
sample_flow_save <- function(flow) {
  tbl <- rbindlist(flow$steps, fill = TRUE)
  prev <- c(NA_integer_, tbl$n_rows[-nrow(tbl)])
  tbl[, pct_dropped := ifelse(is.na(prev), NA_real_,
                               round(100 * (prev - n_rows) / prev, 2))]
  path <- file.path(diag_path, paste0("flow_", flow$label, "_", DATE_TAG, ".md"))
  writeLines(c(paste0("# Sample-flow: ", flow$label),
               paste0("Built ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
               "",
               as.character(knitr::kable(tbl, format = "pipe"))), path)
  cat("[sample-flow] saved:", path, "\n")
  tbl
}

# ---- Winsorize --------------------------------------------------------------
wins <- function(x, lo = 0.025, hi = 0.975) {
  q <- quantile(x, c(lo, hi), na.rm = TRUE)
  pmin(pmax(x, q[1]), q[2])
}

# ---- LOCF county-year extension --------------------------------------------
# Centralizes the extend-beyond-raw-endpoint logic for app and mobile data.
extend_county_year_locf <- function(dt, county_col, year_col, val_col,
                                    extend_through_year) {
  dt <- copy(dt); setorderv(dt, c(county_col, year_col))
  dt[, (val_col) := nafill(get(val_col), type = "locf"), by = county_col]
  present_years <- sort(unique(dt[[year_col]]))
  need_years    <- setdiff(seq(min(present_years), extend_through_year), present_years)
  if (!length(need_years)) return(dt)
  anchor <- dt[get(year_col) == max(present_years),
               c(county_col, val_col), with = FALSE]
  extra <- CJ(county = anchor[[county_col]], yr = need_years)
  setnames(extra, c("county", "yr"), c(county_col, year_col))
  extra <- merge(extra, anchor, by = county_col, all.x = TRUE)
  rbind(dt, extra, use.names = TRUE, fill = TRUE)
}

# ---- Output-manifest registry ----------------------------------------------
# Each analysis script registers its output filenames here before writing.
# diagnostics/output_manifest_check.R fails if tables/ contains files not in
# the union. Prevents stale-output drift.
OUTPUT_REGISTRY_PATH <- file.path(diag_path, "output_registry.txt")
register_outputs <- function(names) {
  existing <- if (file.exists(OUTPUT_REGISTRY_PATH)) readLines(OUTPUT_REGISTRY_PATH) else character()
  writeLines(sort(unique(c(existing, names))), OUTPUT_REGISTRY_PATH)
}
