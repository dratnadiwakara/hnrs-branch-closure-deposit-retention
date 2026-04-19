# v20260410 — Notes & Memory

## What this folder is

This is the main analysis version as of April 2026. Three sample-construction scripts feed three result-generation Quarto documents. All scripts follow the date-suffix convention (`_20260409`).

---

## Data paths (external, not in repo)

| Dataset | Path |
|---------|------|
| Branch closure panel | `C:/OneDrive/data/closure_opening_data_simple.rds` |
| Bank app panel | `C:/OneDrive/data/CH_full_app_reviews_panel.csv` |
| FDIC Summary of Deposits | `C:/OneDrive/data/fdic_sod_2000_2025_simple.rds` |
| Branch visit counts (Placer.ai) | `C:/OneDrive/data/nrs_branch_closure/bank_branch_visits_count_2019_2022.rds` |
| County-ZIP crosswalk | `C:/OneDrive/data/county_zip_122019.xlsx` |
| ZIP demographics | `C:/OneDrive/data/nrs_branch_closure/zip_demographics_panel.rds` |
| County controls | `C:/OneDrive/data/nrs_branch_closure/county_controls_panel.rds` |
| HMDA DuckDB | `C:/empirical-data-construction/hmda/hmda.duckdb` |
| CRA DuckDB | `C:/empirical-data-construction/cra/cra.duckdb` |

---

## Identification

- **Treatment** (branch-year panel): `share_deps_closed` — county-year share of deposits in branches being closed by **other** (competitor) banks. This is the incumbent analysis.
- **Treatment** (bank-county-year panel): `closure_share` — bank's OWN closing deposits / total bank-county deposits. This measures the closing bank's behavior.
- **Exclusions**: M&A-related closures (different owner in prior 3 years); extreme closure intensity (top 5%).
- **Key fixed effects (branch panel)**: `UNINUMBR + state_yr + bank_yr`
- **Key fixed effects (bank-county panel)**: `bank_id^YEAR + county^YEAR`
- **Top 4 banks (CERT)**: 628, 3510, 3511, 7213
- **Large bank threshold**: assets > $100B

---

## Regression quick-reference

| Script | Unit | DV | Treatment | FE |
|--------|------|----|-----------|-----|
| `branch_year_regression_20260409.qmd` | branch-year (incumbents) | `gr_branch` | `share_deps_closed` | `UNINUMBR + state_yr + bank_yr` |
| `bank_county_year_regression_20260409.qmd` | bank-county-year | `growth_on_total_t1` | `closure_share` | `bank_id^YEAR + county^YEAR` |
| `bank_county_year_sunab_20260409.qmd` | bank-county-year | `log1p(deps)` | Sun & Abraham cohort×year | `unit_id + YEAR` |

---

## Pending work

- **Parallel lending regressions** — see `plan_lending_regression_20260414.md` for full spec.
  - Two new scripts to write:
    1. `sample-construction/build_lending_panel_20260414.R` — queries HMDA + CRA DuckDB, builds bank-county-year lending panel merged with existing branch panel treatment/controls
    2. `result-generation/lending_regression_20260414.qmd` — runs 9 regressions (3 periods × deposits/HMDA/CRA), exports combined table
  - Prompted by Phil Strahan email (April 10, 2026): incumbents should increase local lending pre-2012 but not in recent years.

---

## HMDA DuckDB notes

- Tables: `lar_panel` (hive-partitioned, query `WHERE year = ...` first), `avery_crosswalk` (RSSD linkage), `panel_metadata`
- Originations: `action_taken = '1'`; amount in dollars (`loan_amount`)
- Pre-2018 lender ID: `respondent_id + agency_code` → join `avery_crosswalk` for RSSD
- Post-2018 lender ID: `lei` → join `avery_crosswalk` for RSSD
- County FIPS: `LEFT(census_tract, 5)`

## CRA DuckDB notes

- Tables: `disclosure_panel` (lender × county × year), `aggregate_panel` (market totals), `transmittal_panel` (lender identity + RSSD)
- For incumbent bank lending: use `disclosure_panel`, `table_id = 'D1-1'` (SBL originations), `report_level = '040'` (county total — avoids double-counting sub-county rows)
- Amount columns in **thousands**: multiply by 1000. Use `amt_loans_lt_100k + amt_loans_100k_250k + amt_loans_250k_1m`
- Lender RSSD: join `transmittal_panel` on `(respondent_id, agency_code, year)`
- Only large banks (above CRA filing threshold) appear — smaller banks will be absent

## Linking HMDA/CRA to FDIC CERT

- `closure_opening_data_simple.rds` has both `CERT` and `RSSDID` — use this as the crosswalk
- In `reg_main` panel: `bank_id = CERT`
- In branch panel: `CERT` is available; `bank_yr = paste0(RSSDID, YEAR)`
