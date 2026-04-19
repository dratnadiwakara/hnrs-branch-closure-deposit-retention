# Plan: Parallel Lending Regressions (HMDA Mortgages & CRA SBL)

## Context

Phil Strahan's email (correspondence/emails.md, lines 8–10) suggests deepening the deposit analysis by running parallel regressions with lending outcomes. The argument: if banks truly retain deposits when they close branches (recent period), they should also not cut lending — and incumbent banks should not see credit spillovers in recent years either. In the early period (pre-2012), however, incumbents should pick up both deposits AND local lending after competitor closures.

The deposit analysis already runs the baseline specification at line 88 of `code/v20260410/result-generation/branch_year_regression_20260409.qmd`:

```r
gr_branch ~ share_deps_closed + ..controls | UNINUMBR + state_yr + bank_yr
```

where `share_deps_closed` is the county-year share of deposits in branches being closed by **other** (competitor) banks, and the sample is incumbent-only branch-years.

We want three parallel regressions — deposits, HMDA mortgage originations, CRA small business loans — using the same treatment (`share_deps_closed`) and period splits (Pre 2012 / 2012–2024 / 2012–2019).

Because HMDA and CRA data exist at the **bank-county-year** level (not branch-year), the lending regressions will aggregate to that level and use `bank_county_id + state_yr + bank_yr` as fixed effects — the direct bank-county analog of `UNINUMBR + state_yr + bank_yr`.

---

## Approach

### New script 1 — Sample construction
**File**: `code/v20260410/sample-construction/build_lending_panel_20260414.R`

**Steps:**

1. **Load branch panel** (`branch_panel_regression_sample_*.rds`) — this has `share_deps_closed`, county controls, `incumbent_bank`, `CERT`, `RSSDID`, `county`, `YEAR`. Filter to `incumbent_bank == 1`. Extract the county-year closure share table.

2. **Build CERT → RSSDID crosswalk** from `C:/OneDrive/data/closure_opening_data_simple.rds` (has both `CERT` and `RSSDID`). Use to link FDIC cert numbers to RSSD IDs needed for HMDA/CRA joins.

3. **Query HMDA DuckDB** (`C:/empirical-data-construction/hmda/hmda.duckdb`, table `lar_panel`):
   - Filter: `action_taken = '1'` (originations only)
   - Pre-2018: join to `avery_crosswalk` on `(respondent_id, agency_code)` to get `rssd_id`
   - Post-2018: join to `avery_crosswalk` on `lei` to get `rssd_id`
   - Aggregate: `SUM(loan_amount)` grouped by `(rssd_id, county_fips, year)` — county FIPS = `LEFT(census_tract, 5)`
   - Join `rssd_id → CERT` via crosswalk from step 2

4. **Query CRA DuckDB** (`C:/empirical-data-construction/cra/cra.duckdb`, table `disclosure_panel`):
   - Filter: `table_id = 'D1-1'` (small business originations), `report_level = '040'` (county total, no double-counting), `action_taken = 1`
   - Join to `transmittal_panel` on `(respondent_id, agency_code, year)` to get `rssd_id`
   - Aggregate: `SUM((amt_loans_lt_100k + amt_loans_100k_250k + amt_loans_250k_1m) * 1000)` grouped by `(rssd_id, county_fips, year)`
   - Join `rssd_id → CERT` via crosswalk from step 2

5. **Construct bank-county-year panel** for incumbents:
   - Start from distinct `(CERT, county, YEAR)` combinations in the branch panel (incumbent-only)
   - Left-join HMDA and CRA totals on `(CERT, county, YEAR)`
   - Within each `(CERT, county)` group, lag (t-1) and lead (t+1) each lending total
   - Compute growth outcomes:
     - `hmda_growth = (hmda_tp1 - hmda_tm1) / hmda_tm1`
     - `cra_growth  = (cra_tp1  - cra_tm1)  / cra_tm1`
   - Winsorize both at [2.5%, 97.5%] (same as `gr_branch`)
   - Construct `bank_county_id = paste0(CERT, "_", county)`
   - Construct `state_yr = paste0(substr(county, 1, 2), YEAR)` and `bank_yr = paste0(CERT, YEAR)`
   - Merge in county controls from branch panel (`banks_county_lag1`, `county_dep_growth_t4_t1`, `log_population_density`, `lag_county_deposit_hhi`, `lag_establishment_gr`, `lag_payroll_gr`, `lag_hmda_mtg_amt_gr`, `lag_cra_loan_amount_amt_lt_1m_gr`, `lmi`)

6. **Save** as `data/constructed/lending_panel_YYYYMMDD_HHMMSS.rds`

---

### New script 2 — Regressions
**File**: `code/v20260410/result-generation/lending_regression_20260414.qmd`

**Setup** mirrors `branch_year_regression_20260409.qmd`:

```r
setFixest_fml(
  ..fixef    = ~ bank_county_id + state_yr + bank_yr,
  ..controls = ~ log1p(banks_county_lag1) +
                 county_dep_growth_t4_t1 +
                 log_population_density +
                 lag_county_deposit_hhi +
                 lag_establishment_gr +
                 lag_payroll_gr +
                 lag_hmda_mtg_amt_gr +
                 lag_cra_loan_amount_amt_lt_1m_gr +
                 lmi
)
```

Note: `log1p(dep_lag1_aligned)` from the branch-year controls is dropped (it's branch-level and unavailable in the lending panel).

**Regressions** — nine models (3 periods × 3 outcomes), clustered at bank-county level (`vcov = ~bank_county_id`):

```r
# Period filters: YEAR < 2012 / YEAR >= 2012 / YEAR %in% 2012:2019
# Outcomes: gr_branch (from branch panel), hmda_growth, cra_growth

feols(outcome ~ share_deps_closed + ..controls | ..fixef,
      data = dt[period_filter],
      vcov = ~bank_county_id)
```

**Output table**: A single `etable()` call with 9 columns grouped by outcome (deposits | HMDA | CRA) × period. Export as `latex/tables/lending_parallel_YYYYMMDD_HHMMSS.tex`.

---

## Critical Files

| Role | Path |
|------|------|
| Existing branch panel (source of treatment + controls) | `data/constructed/branch_panel_regression_sample_*.rds` |
| Crosswalk for CERT↔RSSDID | `C:/OneDrive/data/closure_opening_data_simple.rds` |
| HMDA DuckDB | `C:/empirical-data-construction/hmda/hmda.duckdb` |
| CRA DuckDB | `C:/empirical-data-construction/cra/cra.duckdb` |
| New sample construction script | `code/v20260410/sample-construction/build_lending_panel_20260414.R` |
| New regression Quarto doc | `code/v20260410/result-generation/lending_regression_20260414.qmd` |
| Reference: branch-year regression | `code/v20260410/result-generation/branch_year_regression_20260409.qmd` |
| Reference: branch panel construction | `code/v20260410/sample-construction/build_branch_panel_regression_sample_20260409.R` |

---

## Key Design Decisions

- **Unit of observation**: bank-county-year (not branch-year) — HMDA and CRA do not have branch-level detail.
- **Fixed effects**: `bank_county_id + state_yr + bank_yr` — direct analog of branch FE + state-year + bank-year at the aggregated level.
- **Treatment**: `share_deps_closed` (county-year share of deposits in closing branches by competitors) — matches the branch-year incumbent analysis, NOT `closure_share` (which is the bank's own closures).
- **Sample**: incumbent banks only (those that do not close a branch in the county-year), same restriction as branch panel.
- **Lending growth normalization**: simple rate `(tp1 - tm1) / tm1`. Winsorized at [2.5%, 97.5%].
- **Missing lending**: banks below CRA/HMDA filing thresholds will have `NA` outcomes and drop naturally from `feols`. CRA regression will skew toward larger banks; note this in the table header.

---

## Verification

1. Run `build_lending_panel_20260414.R`; confirm `lending_panel_*.rds` created in `data/constructed/`.
2. Check `nrow(dt)` and `uniqueN(dt[, .(CERT, county)])` per outcome — CRA should be smallest.
3. Coefficient on `share_deps_closed` should be positive Pre-2012 and near zero 2012–2024 for HMDA/CRA, mirroring the deposit result.
4. Export table and compile with `/skills/latex-compile`.
