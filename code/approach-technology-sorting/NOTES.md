# approach-technology-sorting — Notes

## 2026-04-19

### Done
- Built `code/approach-technology-sorting/` — new folder for technology-sorting zip-year regressions
- `01_build_zip_tech_sample_20260419.R`: builds zip-year panel from raw closure panel, adds bank-type decompositions (top4 / large / small / app / noapp) and county-level `perc_hh_wMobileSub`; saves `data/zip_tech_sample_YYYYMMDD.rds`
- `02_zip_tech_regressions_20260419.qmd`: 5 incremental tables — baseline anchor, size decomp, app decomp, mobile interaction, combined digital-era spec
- All 4 period N counts (70,727 / 44,953 / 89,982 / 51,601) match baseline exactly after fixest singleton removal

### Dead ends
- First attempt merged app panel onto `raw` (creating `raw_a`) before building zip panel — inflated N because app panel has duplicate CERT×YEAR rows; fixed by merging app data only onto the closed-branch rows (`raw_closed`) after building base zip panel from `raw`
- `R-4.5.3` fails with "no package called data.table" — all packages (data.table, fixest, stringr) are installed in `R-4.4.3` library, not 4.5; CLAUDE.md `R_EXE` is stale

### Lessons
- **Run with R 4.4.3:** `"C:/Program Files/R/R-4.4.3/bin/Rscript.exe"` — NOT the 4.5.3 path in CLAUDE.md
- **N mismatch is not a bug:** raw sample is ~78k for 2000-07 but fixest drops ~7,736 singletons to land at 70,727 — matches baseline exactly; no additional filter needed
- **`sophisticated` is now always non-NA:** zip_demo was regenerated and now has full coverage (2000-2025, no NAs); the old `!is.na(sophisticated)` filter was data-availability-based and no longer does anything meaningful; the N match happens through fixest singletons, not the sophisticated filter
- **`perc_hh_wMobileSub` main effect always dropped:** it's county-year, collinear with county×year FE; only the interaction with `share_deps_closed` is identified (valid because `share_deps_closed` varies across zips within county-year)
- **Mobile data coverage:** very sparse pre-2012 (~43k of 128k observations); Table 4 pre-2012 column has low power; focus on 2012+ for mobile interaction results

### Key results
- Table 2 (size): top4 coeff small/insignificant pre-2012 (0.04 vs small 0.13***); top4 goes negative post-2012 (-0.066***); small banks drive pre-digital spillover
- Table 3 (app): noapp closures positive through 2012-19 (0.068***); app closures near zero throughout — confirms app → retention → less released to rivals
- Table 4 (mobile): interaction negative and significant in 2012-19 (-0.14***) and 2012-24 (-0.065**); 2020-24 reverses (suspect, check data quality)

### Next
- Snapshot results with `/skills/snapshot-results "technology-sorting"`
- Investigate reversed mobile interaction sign in 2020-24
- Consider LaTeX table export (set `save_tables <- TRUE` in the QMD) for paper integration
- `perc_hh_wMobileSub` data path is `data/raw/perc_hh_wMobileSub.csv` (in-repo); source and coverage years should be documented
