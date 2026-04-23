# approach-streamlined-20260423 — Decision Log

Tracks diagnostic results and adoption decisions for each coauthor suggestion. Plan: `~/.claude/plans/docs-snapshots-20260418-08-main-regress-purrfect-seahorse.md`.

Coauthor comments — source: `correspondence/emails.md` (top two, Phil + Rajesh, 2026-04-22).

## Adoption summary (populated after diagnostics run)

| # | Suggestion | Diagnostic | Decision | Rationale |
|---|---|---|---|---|
| 1 | Drop county-level deposit aggregation | — | **ADOPT** (zip primary; county demoted to Appendix A1) | Phil #1 + Rajesh T3. Zip captures proximity; county adds noise with weaker FE. |
| 2 | CRA restricted to banks with ≥1 branch in county | D4 | **ALREADY APPLIED** (no spec change) | Snapshot §6 CRA already inner-joined `cra` with `inc_set`. `inc_set` is defined from the SOD closure panel (`raw_c[inc == TRUE]`), so a bank appears only if it had a branch in that county-year. Phil's filter is already implicit. T3 shows identical coefficients in "in-county" vs "all" columns, which confirms this. Documented in T3 notes. |
| 3 | HMDA second-lien only | D2 | **ADOPT as Panel B** | D2 showed 49k–163k zip-years with ≥1 second-lien origination per period — enough for identification. Coefficients large but standard errors also large (small zip-year base → % growth unstable); all n.s. across periods, reinforcing the null found in the pooled HMDA spec. |
| 4 | HMDA jumbo only | D3 | **ADOPT as Panel C (2012+)** | CLL panel built from local FHFA xls files; 45,273 county-year limits across 2012–2025. Jumbo growth coefficients null across periods (−0.06 in 2012–19, +0.25 in 2020–22, n.s.) — consistent with no lending spillover. |
| 5 | Split 2020–24 into 2020–22 vs 2023–24 | D1 | **ADOPT** (main tables use 5-column period layout) | D1 confirms the COVID-contamination hypothesis: §2 share_deps_closed is 0.058*** in 2020–22 but −0.018 (n.s.) in 2023–24, which matches the 2012–19 digital-era null. The pooled 2020–24 positive is driven entirely by 2020–22. |
| 6 | Combined heterogeneity for own-closure | — | **ADOPT directly in T4 Panel B** | Phil Apr 9 agreement. Main takeaway: `closure_share` alone is 0.57–0.69*** across every period (retention is digital-era-agnostic once we look at own closures). Interactions with top4, large-non-top4, and `perc_hh_wMobileSub` are mostly small and insignificant in the digital era. |
| 7 | M&A IV | — | **SKIP** | Per user instruction. |

## Known data limits

- **HMDA 2023–24 column (T2):** HMDA 2-year growth at year *t* needs lead data at *t+1*. 2025 LAR has not been released, so year 2024 growth is NA for every zip. The 2023–24 slice collapses to year 2023 only, which implies zip × county×year FE are collinear (one year per county). Therefore T2 omits the 2023–24 column. Revisit once 2025 HMDA ships.
- **Mobile interaction in 2023–24 (D1 §12, T5):** `perc_hh_wMobileSub` is LOCF-held at its 2023 value for 2024+, so within-county-year variation is zero in 2023–24 and the interaction drops to singletons. Reported as "infeasible" rather than zero.
- **CRA 2023–24 column (T3):** Same issue as HMDA — CRA 2-year growth at year 2024 needs 2025 data which isn't available. T3 ends at 2020–22 for now.

---

## Diagnostic logs (appended by scripts)

## D2 — Second-lien coverage — 2026-04-23 09:45

**D2: Second-lien HMDA coverage**

Tract-year cells with >=1 second-lien purchase origination, mapped to zip-year via HUD RES_RATIO crosswalk.

| period | n_zip_years | mean_origs_per_zip_yr | median_origs |
|---|---|---|---|
| 2004-07 | 106143 | 24.97 | 3.74 |
| 2008-11 |  64946 |  2.35 | 0.78 |
| 2012-19 | 163470 |  3.74 | 0.92 |
| 2020-22 |  72997 |  4.87 | 1.07 |
| 2023-24 |  49346 |  3.65 | 1.01 |

**Decision:** ADOPT — build B1 second-lien HMDA panel, add Panel B to T2.

## D4 — CRA in-county coverage — 2026-04-23 09:45

**D4: CRA in-county-branch filter coverage**

For each CRA respondent × county × year row (mapped rssd → CERT), flag whether the bank has >=1 branch in that county-year from SOD closure panel.

| period | n_obs | n_in_county | n_out_county | pct_in_county | amt_in_county | amt_out_county | pct_amt_in |
|---|---|---|---|---|---|---|---|
| 2012-19 | 761820 | 108485 | 653335 | 14.2 | 1.278445e+12 | 504411508000 | 71.7 |
| 2020-22 | 382005 |  43271 | 338734 | 11.3 | 7.546475e+11 | 312111322000 | 70.7 |
| 2023-24 | 213916 |  29247 | 184669 | 13.7 | 2.910930e+11 | 209115244000 | 58.2 |
| pre-2012 | 882029 | 142022 | 740007 | 16.1 | 2.082815e+12 | 615618623000 | 77.2 |

**Decision:** SHOW BOTH — filter loses too many obs; report filtered + unfiltered side by side.

## D1 — Pandemic split — 2026-04-23 09:46

**D1: Pandemic split diagnostic**

Rerun §2 and §12 splitting 2020–24 into 2020–22 vs 2023–24.

| Spec | Period | Coef | SE | Sig | N |
|---|---|---|---|---|---|
| §2 main | 2012-19 | 0.010 | 0.010 |  | 89954 |
| §2 main | 2020-22 | 0.058 | 0.019 | *** | 31052 |
| §2 main | 2023-24 | -0.018 | 0.027 |  | 20304 |
| §12 int | 2012-19 | -0.160 | 0.040 | *** | 70195 |
| §12 int | 2020-22 | 0.512 | 0.260 | ** | 24272 |
| §12 int | 2023-24 | NA | NA | infeasible | NA |

**Decision:** Always adopt the 3-way split (2012-19 / 2020-22 / 2023-24) in main tables.
Interpretation depends on whether 2023-24 pattern matches 2012-19 or stays COVID-like.

## D3 — CLL validation — 2026-04-23 09:46

**D3: FHFA conforming-loan-limit (CLL) county-year panel**

Parsed 14 xls/xlsx files from `C:/Users/dimut/OneDrive/github/shadow-bank-impact/data/raw/CLL`.
Combined county-year observations: **45273**.
Unique counties: 3238. Years: 2012–2025.

Median CLL (one-unit) by year:

| year | median 1-unit limit | n counties |
|---|---|---|
| 2012 | 417000 | 3234 |
| 2013 | 417000 | 3234 |
| 2014 | 417000 | 3234 |
| 2015 | 417000 | 3234 |
| 2016 | 417000 | 3234 |
| 2017 | 424100 | 3234 |
| 2018 | 453100 | 3234 |
| 2019 | 484350 | 3234 |
| 2020 | 510400 | 3233 |
| 2021 | 548250 | 3233 |
| 2022 | 647200 | 3233 |
| 2023 | 726200 | 3234 |
| 2024 | 766550 | 3234 |
| 2025 | 806500 | 3234 |

**Decision:** ADOPT — use CLL panel to flag jumbo HMDA loans (loan_amount > county-year 1-unit limit). Jumbo panel runs 2012+ only.

Saved panel: `data/constructed/cll_county_year_20260423.rds`.

## B3 — CRA county-year panels — 2026-04-23 09:49

Built both unfiltered and in-county-branch-filtered CRA growth at county-year.
Saved: `data/constructed/cra_county_panels_20260423.rds`.
N(unfiltered): 57251 | N(in-county): 57251

## B1 — HMDA zip-year panels — 2026-04-23 09:54

Built combined panel with three HMDA outcomes at zip-year: all purchase, second-lien, jumbo.
Saved: `data/constructed/hmda_zip_panels_20260423.rds`.
N(all): 231504 | N(second-lien): 38314 | N(jumbo, 2012+): 121217

---

## 2026-04-23

### Done
- Snapshot `docs/snapshots/20260423-approach-streamlined-20260423/` published with 13 sections + Sun & Abraham plot.
- Added `07_decompositions_20260423.R` (later consolidated into minimal script set).
- Fixed mobile LOCF gap: `code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R:192-205` now synthesizes 2024/2025 rows copying 2023 per county — `perc_hh_wMobileSub` no longer drops in 2023-24. Rebuilt sample as `data/zip_tech_sample_20260423.rds`.
- Extended HMDA (§§8-10) and CRA (§11) last column to pooled 2020-23 (2024 still NA — needs 2025 LAR/CRA release). Added `"2020-23"` key to `period_filter` in common.R.
- Confirmed §11 = old §12: `inc_set` (SOD-derived) already guarantees ≥1 branch, so Phil's filter was implicit. Old in-county vs all-respondent panels returned identical coefficients → consolidated to single §11.
- Consolidated approach folder: moved all prior scripts + `build/` + `diagnostics/` into `_delete/`; replaced with 6 minimal scripts (`00_common.R`, `01_zip_reallocation.R`, `02_decompositions.R`, `03_hmda_zip.R`, `04_cra_county.R`, `05_own_closure.R`, `06_sunab_eventstudy.R`).

### Dead ends
- §§5-6 (mobile interaction) 2023-24 column originally infeasible — fixest reported all singletons. Root cause was merge-stage NA for year 2024, not within-county collinearity. Do not debug as FE issue; fix at `perc_mob` construction.

### Lessons
- `perc_mob` raw data ends at 2023. `nafill(type="locf")` in B-script only fills within existing rows — it does NOT create new rows for 2024/2025. Must `CJ(county, extend_years)` + merge before the main join.
- CRA county panel year 2023 IS present (2024 CRA data exists in duckdb); only year 2024 growth is missing because 2025 CRA not yet released. HMDA same pattern.
- `inc_set` from `raw_c[inc == TRUE]` implicitly requires SOD branch presence — no need for separate `has_branch` filter. This is why the "all respondents" CRA panel was redundant.
- Raw `.md` table files in `tables/` (e.g. `T3_size_decomposition.md`) live under the approach folder, not in the snapshot folder — snapshot `index.md` inlines pretty-formatted tables instead of `\input`-ing them.

### Next
- Build scripts live in `_delete/build/`. If raw data changes, restore those before rerunning `01-06` — or fold them into the main folder.
- §7 sophistication still uses 5-column period layout (legacy). Consider trimming to post-2012 if consistency with §§3-6 matters.

## B1 — HMDA zip-year panels — 2026-04-23 15:00

Built combined panel with four HMDA outcomes at zip-year: all purchase, second-lien, jumbo, refinance.
Saved: `data/constructed/hmda_zip_panels_20260423.rds`.
N(all): 231504 | N(second-lien): 38314 | N(jumbo, 2012+): 121217 | N(refi): 234823
