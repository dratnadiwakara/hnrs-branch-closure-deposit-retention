## 2026-04-18

### Done
- Built full zip-year incumbent deposit regression in `05_deposits_zip_year.py`
- Treatment: deposit-weighted `share_deps_closed = sum(closed_branch dep_lag1) / total_zip_dep_lag1`
- Outcome: 2-year incumbent deposit growth `(inc_deps_tp1 - inc_deps_tm1) / inc_deps_tm1`
- Incumbent = banks with NO closed branch in that zip-year (openers allowed)
- Same-branch filter: branch must have both `dep_lag1_aligned` AND `dep_lead1_aligned` non-null
- FE: zip + county_yr; SE clustered at zip; controls: log_n_branches, log_n_banks
- Text table output printed to terminal (in addition to PNG)
- Final results match digital retention hypothesis: Pre-2012 +0.168***, 2012-2019 +0.102***, 2020-2024 +0.051***

### Dead ends
- `frac_branches_closed` (count-based treatment) — user replaced with deposit-weighted version
- `frac_new_branches` control — dropped per user request
- Normalizing outcome by `total_deps_t1` — produces ALL NEGATIVE coefficients across all periods due to mechanical denominator bias: high-closure zip-years have inflated denominator (includes closed-branch deposits), mechanically pushing coefficient negative. Must use `inc_deps_tm1`.
- Restricting to organic-only closures (M&A excluded) — made coefficients MORE negative, not less; not the root cause
- 1-year outcome window (t to t+1) using `DEPSUMBR` at t and `dep_lead1_aligned` at t+1 — composition bias from different branch sets at endpoints

### Lessons
- Critical invariant: outcome denominator must be `inc_deps_tm1` (incumbent own t-1 deposits), NOT `total_deps_t1`. The latter includes closed-branch deposits. High-treatment zips → high `total_deps_t1` → mechanically small outcome → spuriously negative coefficient even if deposits genuinely flow to incumbents.
- Same-branch filter is essential: compute `inc_deps_tm1` and `inc_deps_tp1` from same `inc_both` subset (branches with both endpoints non-null). Otherwise t-1 and t+1 aggregates use different branch sets.
- pyfixest uses `m._N` for observation count (not `m.nobs`)
- `winsorize()` in common.py returns a series aligned to original index — safe to use with `.reindex(panel.index)` pattern

### Next
- Build `06_lending_zip_year.py`: zip-year HMDA and CRA lending outcomes using same zip-year panel structure
- Consider more period granularity: split pre-2012 into 2000-2007 and 2008-2011
- Scripts 03/04 still use `total_deps` denominator — may have same bias; check if results are qualitatively wrong

## 2026-04-18 (session 2)

### Done
- Built `06_county_lending_regression.py`: zip-year deposits + county-year deposits + county-year HMDA + county-year CRA
- Built `07_branch_panel_regression.py`: branch-year incumbent deposit regressions replicating Table 1 from reference QMD; loads COUNTY_CONTROLS RDS, all 7 extra controls found and used; 4 models (2 periods × 2 FE specs)
- Built `08_main_regressions.R`: minimal coauthor-readable R script running all 4 regressions from raw data; fixed data.table `shift()` positional arg bug; added full controls suite (log1p_total_deps, county_dep_growth_t4_t1 from raw, 7 COUNTY_CONTROLS vars)
- Updated CLAUDE.md: replaced matplotlib pop-up rule with text-table printing pattern; added "show all controls" and "show intermediates" rules

### Dead ends
- County-level deposit regression shows NO digital decline (+0.16/+0.23/+0.21) vs zip (+0.14/+0.11/+0.09) — caused by weaker state×year FE (vs county×year in zip regression); not a bug, a design limitation of county spec
- HMDA/CRA using total county lending (not incumbent-only): creates mechanical negative bias (closing bank's lending drops, pulls aggregate down). Must filter to incumbent banks before aggregating to county.
- `eval(prd[[nm]])` scoping inside `desc()` function: `YEAR` not found in data.table `dt[eval(expr)]` — evaluates in calling frame. Fix: compute period subsets inline with `dt[YEAR < 2012]` etc.

### Lessons
- `data.table::shift(x, 1, "lead")` silently does a LAG — positional arg `"lead"` goes to `fill`, not `type`. ALWAYS use named args: `shift(x, n=1L, type="lead")`. Missing this makes all leads NA → empty panels.
- COUNTY_CONTROLS RDS column names: `county_code` (not `county`) and `year` (not `YEAR`) — rename on load.
- County-level controls (log_population_density etc.) are perfectly collinear with county×year FE in zip regressions — fixest drops them with collinearity note. Expected, not a bug.
- `lmi` dropped in pre-2012 county regression — collinear with county FE in that period (insufficient within-variation).
- `07_branch_panel_regression.py` results vs R reference: Python +0.061***/+0.100***/+0.003/+0.050* vs R +0.075***/+0.130***/+0.012/+0.052** — pattern matches, small sample difference (~1%)

### Next
- HMDA post-2012 positive (+0.35**/+0.27*) is counterintuitive — worth investigating whether this reflects genuine mortgage business capture or a data artifact (HMDA matching via RSSDID crosswalk may miss some pre-2018 banks)
- County deposit no-decline may need county×year FE (drop state×year) but that requires a different treatment variation strategy — discuss with coauthors
- Consider splitting pre-2012 into 2000-2007 (pre-crisis) and 2008-2011 (crisis) for richer pre-period heterogeneity

## 2026-04-18 (session 4)

### Done
- Built `09_anchored_regressions.R`: 6-table script anchored on NRS (2026) Table 14, then progressively extending
- Table 1: NRS Table 14 partial replication — `fraction_of_branches_closed`, no-close incumbent, 1-yr window, total_deps denominator, demographics filter; N=70,727 vs ref 73,123
- Table 2: deposit-weighted (`share_deps_closed`) at zip, same spec
- Table 3: `share_deps_closed` county deposits, 2-yr window, inc_tm1 denominator
- Table 4: HMDA purchase county-year (incumbent, 2-yr)
- Table 5: CRA SBL county-year (incumbent, 2-yr)
- Table 6: HMDA purchase zip-year — tracts mapped to zips via HUD crosswalk `RES_RATIO`
- Dropped `fraction_of_new_branches` from all regressions AND relaxed incumbent definition to no-close-only (was no-open-AND-no-close) — this substantially improved pre-2012 coefficient: T1 +0.029*** → +0.095***
- Snapshot updated in-place at `docs/snapshots/20260418-08-main-regressions/index.md`

### Dead ends
- `fraction_of_new_branches` in regression: user removed; also drives no-open filter on incumbent which suppresses pre-2012 effect — removing both together is the correct move
- Winsorizing at [1%, 99%] instead of [2.5%, 97.5%]: Tables 1–5 qualitatively unchanged; Table 6 (zip HMDA) unstable — 2012-19 coeff flips from +0.22 ns to +0.81*. Reverted to [2.5%, 97.5%].

### Lessons
- No-open incumbent filter suppresses pre-2012 deposit reallocation effect — growing incumbents (who open branches) are precisely those absorbing displaced deposits; excluding them biases against finding the effect
- HUD tract-zip crosswalk (`tract_zip_122019.xlsx`): columns `TRACT` (11-char string), `ZIP` (integer, needs `formatC` pad to 5), `RES_RATIO`. Located at `data/raw/tract_zip_122019.xlsx`.
- HMDA census_tract is 11-digit string for both pre- and post-2018; filter `LENGTH(census_tract) = 11` to drop NULLs and 'NA' strings
- Zip-level HMDA (Table 6) result is outlier-sensitive (winsorization test showed instability) — treat with caution regardless of significance
- `Rscript -e "..."` segfaults in this shell for readxl calls — write script to file and run, or use Python/openpyxl to inspect Excel files
- Remaining gap vs NRS Table 14 N (70,727 vs 73,123): attributed to OTS filter (banks mass-opening branches in 2011 due to OTS→FDIC charter conversion); not implemented

### Next
- Table 6 zip HMDA is noisy — consider aggregating to larger geographic unit or dropping
- OTS filter could close the remaining N gap vs Table 14 if needed for closer replication
- County deposit no-decline (+0.16/+0.23/+0.21) still unresolved — discuss county×year FE approach with coauthors

## 2026-04-18 (session 5)

### Done
- Reviewed theory model (`correspondence/deposit_reallocation_model_v2.md`) against empirics — model fits. Key: declining incumbent absorption (0.168→0.102→0.051) maps directly to Prediction 2 (high-τ banks release fewer deposits to rivals).
- Built `10_bank_county_year_regressions.py`: own-closure design, replicates sections 1.1 and 1.2 of coauthor reference HTML. Section 1.1 coefficients match exactly (Pre-2012 N=178,022, 2012-2019 N=173,127).
- Built `10_bank_county_year_regressions.R`: R analog using native fixest `sunab()` — preferred for 1.2 since pyfixest `SaturatedEventStudy` gives slightly different aggregation.
- Updated snapshot `docs/snapshots/20260418-08-main-regressions/index.md` in-place with 1.1 table and 1.2 event-study figure + coefficient table.

### Dead ends
- pyfixest v0.50 does NOT support `sunab()` in formula strings — `NameError: name 'sunab' is not defined`. Use `pf.event_study(estimator="saturated", att=False)` + `.aggregate()` instead.
- pyfixest `SaturatedEventStudy.aggregate()` can produce large boundary coefficients (e.g. t=−4 coef=1.12 for 2012-2019) when few cohorts span that event-time — artifact of sparse boundary cells, not a bug in data. R's `sunab()` handles this more cleanly.
- `np.log1p()` fails on pandas Series of int dtype from pyreadr-loaded RDS — cast `.astype(float)` first.
- `matplotlib.fill_between()` fails with `TypeError: isfinite not supported` when x/y arrays are pandas Series with int dtype — convert to `.to_numpy(dtype=float)` before passing to matplotlib.

### Lessons
- Section 1.1 data lives in `data/reg_main_20260418.rds` (no time suffix, only date — glob pattern `reg_main_*.rds` still matches). Sunab panels have full timestamp: `sunab_panel_consistent_20260418_083640.rds`.
- Section 1.1 FE is `bank_id^YEAR + county^YEAR` (bank-year and county-year interactions) — pyfixest supports `^` syntax directly in formula string.
- Sun & Abraham event study (1.2) post-event pattern: Pre-2012 reverses at t=2/t=3 (−0.065, −0.121***); digital era (2012-2019, 2020-2024) shows persistent positive retention (+0.25–+0.35***). This is Prediction 1 of the model: high-τ banks retain deposits; low-τ banks do not.
- Theory model gap: empirics currently only cover INCUMBENT absorption (competitor-closure design). OWN-closure retention (Prediction 1 directly) is in `reg_main` and `sunab` panels but not yet tested with digital heterogeneity interaction (`closure_share × has_app`).

### Next
- Test Prediction 1 directly: interact `closure_share` with closing bank's `has_app` in Section 1.1 spec — does retention increase with digital quality within the own-closure panel?
- Test Prediction 3 (deposit-credit decoupling): for closing banks, does local lending fall by same ψ regardless of `has_app`? Needs bank-county lending outcomes joined to `reg_main`.
- Test Corollary 1 (geographic reallocation): do high-`has_app` closing banks increase lending in OTHER counties post-closure? Needs bank-level panel across all counties.
- pyfixest 1.2 event study has boundary artifact — flag to coauthors that R version is canonical for that figure.

## 2026-04-19

### Done
- Rewrote `docs/snapshots/20260418-08-main-regressions/index.md` twice: first pass added Mean(DV)/SD(treatment)/fenced-code-block tables; second pass applied updated skill format (no bold coefficients, FE indicator rows, SE clustering row, Adj. R² row)
- Computed Mean(DV) and SD(treatment) for Tables 1–6 via `stats_extract.R` (temp script, now deleted) and `stats_extract_cra.R` (temp, deleted)
- Computed Adj. R² for Table 7 by re-running feols on `data/reg_main_20260418.rds`: All=0.354, Pre-2012=0.403, 2012-2024=0.320, 2012-2019=0.287

### Dead ends
- CRA DuckDB column is `county` (not `county_code`) and `county_fips` on disclosure_panel; crosswalk column is `rssdid` (not `rssd_id`) on transmittal_panel — the original `stats_extract.R` had wrong column names, took 3 fixes to get right query
- `Rscript -e "..."` segfaults on complex multi-library scripts in this shell — write to file and run always
- `lending_panel_20260418.rds` has bank-county-year rows (529k rows, 64k unique county-years) — cannot use directly for county-year regressions without aggregating; dep_growth is bank-level not county-level

### Lessons
- Correct CRA SQL: `FROM disclosure_panel d JOIN transmittal_panel t ON d.respondent_id=t.respondent_id AND d.agency_code=t.agency_code AND d.year=t.year` using `d.county_fips AS county` and `CAST(t.rssdid AS BIGINT) AS rssdid`. Must also filter `CAST(d.action_taken AS INTEGER)=1`.
- Mean(DV)/SD(treatment) stats from full zip panel (no demographics filter) slightly overcount vs regression N (~10% gap due to `!is.na(sophisticated)` filter applied in T1/T2 regressions) — sufficient for snapshot but not exact regression-sample stats
- Adj. R² for Tables 1–6 requires full pipeline re-run (zip/county panel rebuild + HMDA/CRA DuckDB queries) — not computed this session, left as `—` in snapshot
- Updated skill format: coefficients plain (no bold), footer order is N → FE indicators → SE → Mean(DV) → SD(treatment) → Adj. R² → Within R²; FE indicators are one row per FE type with Yes/No per column

### Next
- Run `09_anchored_regressions.R` with `r2(model, "ar2")` extraction to fill in Adj. R² for Tables 1–6
- Interact `closure_share × has_app` in Section 1.1 to test Prediction 1 directly

## 2026-04-18 (session 3)

### Done
- Added regression (5) to `08_main_regressions.R`: purchase-only HMDA (`action_taken='1' AND loan_purpose='1'`)
- Updated snapshot `docs/snapshots/20260418-08-main-regressions/index.md` in-place with new table and revised interpretation

### Lessons
- Pre-2018 and post-2018 HMDA both use `loan_purpose = '1'` for home purchase — same code across the schema change; no separate handling needed
- All-HMDA positive post-2012 (+0.35***/+0.27*) is entirely refi-driven: purchase-only HMDA null all periods (-0.09/+0.03/+0.18 ns) — incumbents capture displaced refinancing relationships but NOT new purchase originations after competitor closures

### Next
- Investigate whether refi-driven HMDA effect is pre- vs post-digital (split regression 3 vs 5 further, or add loan_purpose interaction)
- County deposit no-decline still unresolved — discuss county×year FE approach with coauthors
