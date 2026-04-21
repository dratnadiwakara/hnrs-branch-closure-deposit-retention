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
- ~~Snapshot results with `/skills/snapshot-results "technology-sorting"`~~ DONE
- Investigate reversed mobile interaction sign in 2020-24
- Consider LaTeX table export (set `save_tables <- TRUE` in the QMD) for paper integration
- `perc_hh_wMobileSub` data path is `data/raw/perc_hh_wMobileSub.csv` (in-repo); source and coverage years should be documented

---

## 2026-04-20

### Done
- Added `log_total_deps` + `dep_growth_t3t1` controls to all zip-year regressions in `02_zip_tech_regressions_20260419.qmd` and rebuilt sample in `01_build_zip_tech_sample_20260419.R`; N drops by ~6k for 2000-07 (2000-01 NAs from 2yr lag)
- Table 6 replaced from sample-split to `share_deps_closed × sophisticated` interaction (within-year zip classification, LOCF-filled)
- `03_own_closure_het_20260420.R`: own-closure heterogeneity at bank-county-year level — Tables A–E (baseline, ×sophisticated, ×sophisticated period split, ×mobile, combined); FE `bank_id^YEAR + county^YEAR`; loads `data/reg_main_*.rds`
- `04_build_bank_zip_year_sample_20260420.R`: new sample construction aggregating branch panel to bank×zip×year; saves `data/reg_main_zip_YYYYMMDD.rds`
- `05_own_closure_het_zip_20260420.R`: same Tables A–E at bank-zip-year level; FE `bank_id^YEAR + zip^YEAR`
- Snapshot `docs/snapshots/20260420-own-closure-het/` created — zip-year Tables 1–6 + county own-closure Tables 7–10

### Dead ends
- `sophisticated × closure_share` interaction **unidentifiable at zip level** with `zip^YEAR` FE — `sophisticated` is a zip characteristic, zero within-zip-year bank variation, 0/238,188 zip-years have both soph and unsoph banks → coefficient is noise
- `ntile()` not available without loading dplyr — replaced with `ntile2 <- function(x) as.integer(x >= median(x, na.rm=TRUE)) + 1L` in `04_build_bank_zip_year_sample_20260420.R`
- R 4.5.3 still has packages only in 4.4 library — workaround: `.libPaths(c('C:/Users/dimut/AppData/Local/R/win-library/4.4', .libPaths()))` prepended before running scripts from Claude
- `large_but_not_top4_bank` variable name in early draft of `03` — actual variable in `reg_main_*.rds` is `large_bank`; fixed with replace_all

### Lessons
- **Own-closure zip vs county:** zip-level `closure_share` coeff is 0.57–0.66*** (large, stable, no attenuation post-2012); county-level baseline is similar but het story differs — `sophisticated` only identified at county level, `mobile` interaction only at zip level
- **`sophisticated` het identified only where it varies cross-sectionally within FE group:** county×year FE absorbs county-level variation leaving within-county bank variation → works; zip×year FE absorbs zip-level variation with no remaining cross-bank variation → unidentified
- **`perc_hh_wMobileSub` het:** null at county level (county×year FE absorbs main effect AND most variation driving the interaction), significant at zip level (−0.14** in 2012-19, −0.21** in 2014-19 combined)
- **Own-closure county key results:** `closure_share × sophisticated` = −0.207*** pre-2012, −0.191** 2012-13, −0.067* 2014-19 (attenuating); `large_bank` premium = +0.21–0.25*** post-2012; mobile null
- **Running long scripts via Claude:** use `< script.R` redirect, NOT `-e` inline; `-e` segfaults on complex code
- **R 4.5.3 packages missing:** data.table, fixest, stringr all in 4.4 lib; CLAUDE.md `R_EXE` points to 4.5.3 but needs lib path workaround every run

### Next
- Investigate reversed mobile interaction in 2020-24 (zip Table 4 col 3: +0.81*** — likely few mobile-data counties with closures)
- Decide whether zip or county own-closure design is canonical for paper; county has better het story (sophisticated); zip has cleaner retention coefficient
- Consider event-study (Sun-Abraham) version of own-closure design for pre-trend validation
- `05_own_closure_het_zip_20260420.R` Table B–C (sophisticated) shows noise — may want to drop those tables or add caveat in paper
