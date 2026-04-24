# approach-streamlined-v2-20260423 — Audit-ready pipeline

Parallel rebuild of `code/approach-streamlined-20260423/` addressing the AI pipeline audit (2026-04-23). v1 left untouched as historical baseline.

## Fixes applied (by audit point)

| # | Audit claim | v1 location | v2 location |
|---|-------------|-------------|-------------|
| 1 | CRA "unfiltered" silently carried `inc_set` | `sample-construction/B3_cra_county_panel_20260423.R:65,88` | `sample-construction/S4_build_cra_panels.R` — three explicit universes `cra_growth_{all, branch, incumbent}`, each with independent lag/lead growth |
| 2 | ZIP→county via `.SD[1]` first-match | `approach-technology-sorting/04_build_bank_zip_year_sample_20260420.R:63` | `sample-construction/S1_build_zip_county_xwalk.R` — HUD max-TOT_RATIO per ZIP (ties broken by lex-smallest county FIPS) |
| 3 | HMDA "all" was already incumbent-filtered | `sample-construction/B1_hmda_zip_panels_20260423.R:107,116` | `sample-construction/S5_build_hmda_panels.R` — four outcomes × three universes (12 growth columns) |
| 4 | S&A split on observation YEAR, not cohort | `06_sunab_eventstudy.R:22-26` | `sample-construction/S6_build_sunab_panel.R` attaches `cohort_era` ∈ {Pre-2012, 2012-2019, 2020-2024} keyed off COHORT; `06_sunab_eventstudy.R` filters on `cohort_era` |
| 5 | Output-filename drift | v1 `04_cra_county.R:88` wrote `T3_cra_county.md` but tables/ held stale legacy names | `diagnostics/output_manifest_check.R` fails if tables/ contains files not registered via `register_outputs()`; all v2 filenames deterministic (`T01..T14`) |
| 6 | Own-closure filters applied at build time | `approach-technology-sorting/04_build_bank_zip_year_sample_20260420.R:185-190, 247-249` | `sample-construction/S3_build_bank_zip_sample.R` stores filters as FLAG columns (`extreme_intensity_pctl`, `clean_no_change_if_no_closure`, `any_closure_prev_owner_other_3y`); `05_own_closure.R` reports a 5-spec sensitivity matrix |
| 7 | App/noapp NOT orthogonal to top4/large/small | `approach-technology-sorting/01_build_zip_tech_sample_20260419.R:115-119` | `sample-construction/S2_build_zip_tech_sample.R` — ORTHOGONAL 5-bucket partition `{top4, large_app, large_noapp, small_app, small_noapp}` that sums to `share_deps_closed` (identity asserted `stopifnot(max_err < 1e-8)`). Legacy aggregates retained for reference |
| 8 | CRA `county_dep_growth_t4_t1` used current-year numerator | `04_cra_county.R:50-59` | `04_cra_county.R` — renamed `county_dep_growth_lag4_l1` built from t-1 and t-4 deposits; RHS-variable timing table in script header |
| 9 | `load_latest()` used mtime, silent on no-match | `00_common.R:66-69` | `00_common.R::load_exact` requires explicit path; optional `expect_rows` + `expect_sha` assertions. `manifest.yml` pins artifact paths/hashes. Old `load_latest_explore` kept for interactive work only |
| 10 | Ad-hoc LOCF for mobile/app in two places | `approach-technology-sorting/01_build_zip_tech_sample_20260419.R:192-205`, `04_build_bank_zip_year_sample_20260420.R:220-224` | `00_common.R::extend_county_year_locf` — one helper used by S2 and S3 |

## Pipeline

```
S1_build_zip_county_xwalk.R           (~1 sec)   → zip_county_xwalk_v2.rds
S2_build_zip_tech_sample.R            (~60 sec)  → zip_tech_sample_v2_YYYYMMDD.rds
S3_build_bank_zip_sample.R            (~90 sec)  → bank_zip_sample_v2_YYYYMMDD.rds
S4_build_cra_panels.R                 (~90 sec)  → cra_panels_v2_YYYYMMDD.rds
S5_build_hmda_panels.R                (~15 min)  → hmda_panels_v2_YYYYMMDD.rds   (duckdb-heavy)
S6_build_sunab_panel.R                (~2 sec)   → sunab_panel_v2_YYYYMMDD.rds   (just adds cohort_era)

01_zip_reallocation.R        → T01_zip_count.md, T02_zip_depwt.md
02_decompositions.R          → T03_size_app_orthogonal.md, T04..T07
03_hmda_zip.R                → T08_hmda_{purch,refi,sl,jumbo}_{all,branch,incumbent}.md  (12)
04_cra_county.R              → T12_cra_{all,branch,incumbent}.md
05_own_closure.R             → T13_own_closure_filter_matrix.md, _paper_periods.md
06_sunab_eventstudy.R        → T14_sunab_{estimates,cohort_counts}.md, F14_sunab_by_cohort_era.png

diagnostics/output_manifest_check.R  → fails on orphan or missing outputs
diagnostics/flow_*_v2_*.md           → per-builder sample-flow attrition
manifest.yml                         → pinned upstream paths (expect_rows/sha256 filled after first build)
```

## Known limitations / not addressed

- **Multi-county ZIP robustness** (audit fix 2, alternate): dropped per user instruction. `max_tot_ratio` is applied as the deterministic rule; no weighted or `single_county_flag == 1` robustness restriction.
- **n_remaining_branches as control**: retained in own-closure spec without a pre/post-treatment audit column. Known limitation flagged in audit.
- **Audit timing table inside `04_cra_county.R`**: provided as a comment header, not a separate diagnostic file.

## Upstream raw sources (documented in `manifest.yml`)

- HUD: `~/OneDrive/data/ZIP_COUNTY_122019.xlsx` (ZIP-county) and `data/raw/tract_zip_122019.xlsx` (tract-ZIP)
- SOD: `~/OneDrive/data/closure_opening_data_simple.rds`
- County controls: `~/OneDrive/data/nrs_branch_closure/county_controls_panel.rds`
- App panel: `~/OneDrive/data/CH_full_app_reviews_panel.csv` (raw ends 2021; LOCF to 2025)
- Mobile: `data/raw/perc_hh_wMobileSub.csv` (raw ends 2023; LOCF to 2025)
- HMDA: `C:/empirical-data-construction/hmda/hmda.duckdb`
- CRA: `C:/empirical-data-construction/cra/cra.duckdb`
- CLL: `data/constructed/cll_county_year_20260423.rds` (from v1 pipeline, 2012-2025)

## Reproducibility

Every 01..06 analysis script begins with `rm(list = ls())` and pins its input via `resolve_latest()` + `load_exact()` on a v2-tagged artifact. `output_manifest_check.R` enforces filename discipline after each run. `manifest.yml` pins artifact provenance; `expect_rows`/`sha256` to be populated after the first successful end-to-end run.
