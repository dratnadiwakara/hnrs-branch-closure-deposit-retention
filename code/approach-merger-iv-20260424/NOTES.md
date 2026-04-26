# approach-merger-iv-20260424 — notes

## Goal

Replicate the streamlined deposit-reallocation / lending results under a
Nguyen (2019) merger-overlap instrument. First milestone: the three results in
`r-utilities/Projects/deposits_closures_openings/Nguyen_instrument_v1.1.qmd`:

1. Figure 2 event study (merger exposure → branch closure probability).
2. First-stage regression (`share_deps_closed ~ Expose_Event`).
3. IV second-stage table on 1-yr incumbent `outcome`.

## Data sources

- NIC transformations: `C:/empirical-data-construction/nic/nic.duckdb`,
  filter `TRNSFM_CD = '1'` (merger/absorption).
- SOD: `C:/empirical-data-construction/sod/sod.duckdb`.
- zip-year analysis panel: `data/zip_tech_sample_20260423.rds`.

All SOD-derived intermediates (branch panel with `closed` flag, instrument
panel) are rebuilt from duckdb sources inside `data/` of this subfolder. No
writes to the project-level `data/constructed/`.

## Deviations from prior qmd

- Outcome = 1-yr `outcome` (streamlined panel), not 3-yr `incumbent_growth_share_3yr[_own_deposits]`.
- Merger source = NIC transformations (replaces legacy `C:/data/m_and_a_data.rds`).
- RSSD-space throughout (no external CERT↔RSSD crosswalk — SOD carries both).

## 2026-04-24

### Done
- Scaffold folder + 6 scripts run end-to-end. SOD validation passed (±0.1%/yr match vs legacy rds).
- Branch panel: 2.32M rows, 132,908 branches, closure rate 2-8%/yr. `closed[t]` = UNINUMBR present t, absent t+1.
- NIC transformations SQL: `WHERE TRNSFM_CD = '1'` (21,417 rows 2001-2024 → 114 after both-side $10B filter).
- Instrument: 3,101 distinct (ZIPBR, Event_Year). Full-sample 1st-stage F=45.6; share>0 F=220.6.
- Figure 2: flat pre-trend, +0.019*** at t=0, +0.010*** t=1, +0.007*** t=2, flat t=3+. Matches Nguyen shape.
- IV 2nd stage reshaped to match streamlined T1 Panel B (period columns, `zip + county_yr` FE, same controls).
- Snapshot at `docs/snapshots/20260424-approach-merger-iv-20260424/`.

### Lessons
- NIC column `#ID_RSSD_PREDECESSOR` has literal `#` — quote in SQL: `"#ID_RSSD_PREDECESSOR"`.
- NIC db at `C:/empirical-data-construction/nic/`, NOT at `C:/Users/dimut/OneDrive/github/empirical-data-construction/nic/` (latter holds the .py scripts only).
- SOD `ASSET` is $000s; Nguyen $10B cutoff = `>= 1e7`. Both buyer AND target must clear.
- SOD carries both `CERT` and `RSSDID` on every branch row — no external CERT↔RSSD crosswalk needed.
- SOD `STCNTYBR` drops leading zero (CA = "6037"); `LPAD(STCNTYBR, 5, '0')` before join.
- `simplermarkdown::md_table(et)` returns non-character for `etable` objects — use `knitr::kable(et, format="pipe")` via existing `write_md()` helper instead.
- Period-split IV is weak: 114 mergers thin out within 4-8-yr windows. F<10 in 2000-07 and 2012-19. Full-sample IV is what has power.
- Streamlined `01_zip_reallocation.R` does NOT filter on `branches_lag1>=2 & n_inc_banks>=2` (those filters are baked into `zip_tech_sample_*.rds` upstream). Match that — don't add extra filters in IV 2nd stage.

### Next
- If 3-yr incumbent growth outcome (`gr_3yr_own`) is wanted for tighter qmd parity, build it in a new sample-construction script — not present in `zip_tech_sample_20260423.rds`.
- Extend IV to full streamlined suite (HMDA, CRA, own-closure, sophistication interactions). Currently only Panel B analog covered.
- Consider pooling periods (pre-2012 vs post-2012 vs post-2020) to restore IV power when running splits.

## 2026-04-26

### Done
- Added `07_iv_hmda_zip.R` (4 panels, periods analogous to streamlined T2) and
  `08_iv_cra_county.R` (county-aggregated Nguyen instrument: zip→county at Ref_Year).
- Snapshot §4 + §5 in `docs/snapshots/20260424-approach-merger-iv-20260424/index.md`
  populated with IV HMDA + IV CRA tables.
- HMDA jumbo unit fix (see `code/approach-streamlined-20260423/NOTES.md` for diagnosis):
  rebuilt `data/constructed/hmda_zip_panels_20260426.rds`, reran `07_iv_hmda_zip.R`.
  IV Panel C (`T_iv_hmda_panelC_jumbo.md`) now has IV-F < 2 in both columns — true
  jumbo segment too thin for IV identification within periods. Updated snapshot
  Panel C block + jumbo rows of OLS-vs-IV contrast table.

### Next
- Pool periods (pre-2012 / post-2012 / post-2020) to restore IV power across HMDA
  panels and CRA, especially for second-lien and jumbo where slice-level IV-F
  collapses.
- Extend IV to own-closure (T4 analog) and sophistication interactions (T7 analog).
