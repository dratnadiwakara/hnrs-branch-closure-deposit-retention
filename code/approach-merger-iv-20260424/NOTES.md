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
