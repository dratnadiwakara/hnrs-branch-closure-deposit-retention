# S6_build_sunab_panel.R
# V2 Sun-Abraham panel: attaches a cohort_era label keyed off COHORT (first
# closure year), NOT observation YEAR. This fixes the v1 bug where
# 06_sunab_eventstudy.R sliced by `YEAR %between% c(...)` — which mixes
# pre-period observations from later cohorts into earlier era panels.
#
# Upstream: data/sunab_panel_consistent_*.rds
#   Built by: code/v20260418/sample-construction/bank_county_year_sunab_sample_20260409.R
#   Columns:  bank_id, county, YEAR, cohort, unit_id, deps_consistent,
#             n_branches_consistent
#   cohort   = first closure year per (bank_id, county); 10000 = never-treated.
#
# Output: data/constructed/sunab_panel_v2_YYYYMMDD.rds with added:
#   cohort_era in {"Pre-2012", "2012-2019", "2020-2024", NA (never-treated)}

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

SUNAB_RAW <- resolve_latest("data", "^sunab_panel_consistent_.*\\.rds$")

pan <- setDT(load_exact(SUNAB_RAW))

# Key design choice: cohort_era is derived from COHORT, never from YEAR.
# Never-treated (cohort == 10000) gets NA and is kept for all era panels.
pan[, cohort_era := fcase(
  cohort == 10000L,                     NA_character_,
  cohort <  2012L,                      "Pre-2012",
  cohort %between% c(2012L, 2019L),     "2012-2019",
  cohort %between% c(2020L, 2024L),     "2020-2024",
  default = NA_character_)]

cat("Cohort-era distribution (treated only):\n")
print(pan[!is.na(cohort_era), uniqueN(.SD), by = cohort_era,
          .SDcols = c("bank_id", "county")])
cat("\nNever-treated rows:", sum(pan$cohort == 10000L), "\n")

out_path <- file.path("data/constructed", paste0("sunab_panel_v2_", DATE_TAG, ".rds"))
saveRDS(pan, out_path)
cat("\nSaved:", out_path, " | nrow =", nrow(pan), "\n")
cat("sha256:", digest::digest(out_path, algo = "sha256", file = TRUE), "\n")
