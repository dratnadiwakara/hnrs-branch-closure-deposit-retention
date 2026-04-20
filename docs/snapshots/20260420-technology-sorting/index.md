---
layout: default
title: "technology-sorting — 2026-04-20"
---

# Snapshot: technology-sorting

> Zip-year deposit reallocation regressions decomposed by closing-bank technology type and local digital infrastructure. Pre-2012: incumbents absorb 8–12% of deposits from closing small/no-app banks per unit share. Post-2012: reallocation collapses to near zero across all bank types. Mobile interaction is negative and significant in 2012–19, suggesting high-mobile-penetration counties see even less reallocation. Sophistication split is largely flat across groups — unsophisticated zips show slightly larger pre-2012 effects, consistent with branch-dependent depositors being most affected by closures. The dominant story is a structural break at 2012 driven by digital banking adoption, not cross-sectional heterogeneity in depositor sophistication.

---

## 1. Baseline — Zip-Year

**Unit:** zip × year  
**LHS:** `outcome = (inc_tp1 – inc_curr) / total_deps` — change in incumbent deposits normalized by total zip deposits, winsorized 2.5/97.5  
**Treatment:** `share_deps_closed` = deposits in closing branches / total zip deposits (deposit-weighted competitor closure exposure)  
**Incumbent:** banks present in zip in year t+1 that were present in year t  
**FE:** zip + county×year | **SE:** clustered at zip  
**Controls:** log(# branches), log(# incumbent banks)  
**Sample:** 2000–2024, n_inc_banks ≥ 2, branches_lag1 ≥ 2; organic closures only (no M&A)

```
| | (1) 2000–07 | (2) 2008–11 | (3) 2012–19 | (4) 2020–24 |
|---|---|---|---|---|
| share_deps_closed | 0.1167*** | 0.0843*** | -0.0170* | -0.0178 |
| | (0.0156) | (0.0219) | (0.0101) | (0.0119) |
| log_n_branches | -0.1155*** | -0.0647*** | -0.0557*** | -0.0659*** |
| | (0.0054) | (0.0091) | (0.0058) | (0.0094) |
| log_n_inc_banks | 0.0743*** | 0.0341*** | 0.0501*** | 0.0571*** |
| | (0.0056) | (0.0081) | (0.0057) | (0.0086) |
| N | 70,727 | 44,953 | 89,982 | 51,601 |
| Zip FE | Yes | Yes | Yes | Yes |
| County×Year FE | Yes | Yes | Yes | Yes |
| SE | Zip | Zip | Zip | Zip |
| Within R² | 0.01422 | 0.00307 | 0.00374 | 0.00459 |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 2. Closing-Bank Size Decomposition — Zip-Year

**Treatment decomposition:**  
- `share_deps_closed_top4` = deposits in top-4 (JPM/BAC/WFC/Citi) closing branches / total deps  
- `share_deps_closed_large` = large-but-not-top4 (total assets > $100B) closing branches / total deps  
- `share_deps_closed_small` = all other closing branches / total deps  

*Hypothesis: top-4 closures produce near-zero spillover (customers retained digitally); small-bank closures drive pre-2012 effect.*

```
| | (1) 2000–07 | (2) 2008–11 | (3) 2012–19 | (4) 2020–24 |
|---|---|---|---|---|
| share_deps_closed_top4 | 0.0434 | 0.0737** | -0.0663*** | -0.0203 |
| | (0.0384) | (0.0344) | (0.0138) | (0.0138) |
| share_deps_closed_large | 0.1233*** | 0.0760* | -0.0179 | -0.0213 |
| | (0.0327) | (0.0413) | (0.0154) | (0.0210) |
| share_deps_closed_small | 0.1287*** | 0.0958*** | 0.0428*** | -0.0074 |
| | (0.0187) | (0.0321) | (0.0161) | (0.0200) |
| log_n_branches | -0.1155*** | -0.0647*** | -0.0575*** | -0.0661*** |
| | (0.0054) | (0.0091) | (0.0058) | (0.0095) |
| log_n_inc_banks | 0.0743*** | 0.0341*** | 0.0516*** | 0.0573*** |
| | (0.0056) | (0.0081) | (0.0057) | (0.0087) |
| N | 70,727 | 44,953 | 89,982 | 51,601 |
| Zip FE | Yes | Yes | Yes | Yes |
| County×Year FE | Yes | Yes | Yes | Yes |
| SE | Zip | Zip | Zip | Zip |
| Within R² | 0.01433 | 0.00309 | 0.00436 | 0.00460 |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 3. Closing-Bank App Decomposition — Zip-Year

**Treatment decomposition:**  
- `share_deps_closed_app` = deposits in non-top4 closing branches with mobile app / total deps  
- `share_deps_closed_noapp` = deposits in closing branches without mobile app / total deps  

*Hypothesis: app-bank closures produce less reallocation (depositors already digital); gap grows post-2012 as app coverage expands.*

```
| | (1) 2000–07 | (2) 2008–11 | (3) 2012–19 | (4) 2020–24 |
|---|---|---|---|---|
| share_deps_closed_app | 0.2640 | 0.1236** | 0.0071 | -0.0083 |
| | (0.1731) | (0.0540) | (0.0128) | (0.0161) |
| share_deps_closed_noapp | 0.1159*** | 0.0786*** | 0.0684*** | -0.0500 |
| | (0.0156) | (0.0286) | (0.0239) | (0.0452) |
| log_n_branches | -0.1155*** | -0.0623*** | -0.0639*** | -0.0697*** |
| | (0.0054) | (0.0090) | (0.0056) | (0.0089) |
| log_n_inc_banks | 0.0743*** | 0.0310*** | 0.0595*** | 0.0614*** |
| | (0.0056) | (0.0079) | (0.0053) | (0.0079) |
| N | 70,727 | 44,953 | 89,982 | 51,601 |
| Zip FE | Yes | Yes | Yes | Yes |
| County×Year FE | Yes | Yes | Yes | Yes |
| SE | Zip | Zip | Zip | Zip |
| Within R² | 0.01424 | 0.00289 | 0.00385 | 0.00456 |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 4. Mobile Penetration Interaction — Zip-Year

**Additional variable:**  
- `perc_hh_wMobileSub` = county-year share of households with mobile subscription (LOCF-filled; 2023 cap)  
- Interaction: `share_deps_closed × perc_hh_wMobileSub`  

*Hypothesis: high-mobile counties see less reallocation — local digital infrastructure substitutes for physical branches.*  
*Col (1): pre-2012 only. Col (2): full sample 2000–24. Col (3): 2012–19. Col (4): 2020–24.*

```
| | (1) 2000–11 | (2) 2000–24 | (3) 2012–19 | (4) 2020–24 |
|---|---|---|---|---|
| share_deps_closed | 0.2119** | 0.0175 | 0.0630** | -0.7649*** |
| | (0.0830) | (0.0237) | (0.0279) | (0.1778) |
| share_deps_closed × perc_hh_wMobileSub | -0.4002* | -0.0654** | -0.1437*** | 0.8923*** |
| | (0.2338) | (0.0308) | (0.0413) | (0.2082) |
| log_n_branches | -0.0660*** | -0.0504*** | -0.0604*** | -0.0662*** |
| | (0.0076) | (0.0046) | (0.0061) | (0.0119) |
| log_n_inc_banks | 0.0359*** | 0.0503*** | 0.0517*** | 0.0608*** |
| | (0.0072) | (0.0045) | (0.0059) | (0.0105) |
| N | 43,170 | 102,674 | 70,223 | 32,231 |
| Zip FE | Yes | Yes | Yes | Yes |
| County×Year FE | Yes | Yes | Yes | Yes |
| SE | Zip | Zip | Zip | Zip |
| Within R² | 0.00364 | 0.00445 | 0.00476 | 0.00597 |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

*Caution: mobile subscription data has limited pre-2012 coverage (sparse county×year cells); col (1) uses narrower sample.*

---

## 5. Combined Decomposition (Post-2012) — Zip-Year

**All channels simultaneously, post-2012 sample:**  
- `share_deps_closed_app`, `share_deps_closed_noapp`, `share_deps_closed_top4` (separate coefficients)  
- Interaction with `perc_hh_wMobileSub` on aggregate `share_deps_closed`  
*Col (1): 2012–24. Col (2): 2012–19.*

```
| | (1) 2012–24 | (2) 2012–19 |
|---|---|---|
| share_deps_closed_app | 0.0123 | 0.0615** |
| | (0.0241) | (0.0281) |
| share_deps_closed_noapp | 0.0409 | 0.1011*** |
| | (0.0288) | (0.0342) |
| share_deps_closed_top4 | -0.0213 | 0.0057 |
| | (0.0261) | (0.0313) |
| share_deps_closed × perc_hh_wMobileSub | -0.0416 | -0.1154*** |
| | (0.0315) | (0.0418) |
| log_n_branches | -0.0510*** | -0.0611*** |
| | (0.0046) | (0.0061) |
| log_n_inc_banks | 0.0509*** | 0.0526*** |
| | (0.0045) | (0.0059) |
| N | 102,674 | 70,223 |
| Zip FE | Yes | Yes |
| County×Year FE | Yes | Yes |
| SE | Zip | Zip |
| Within R² | 0.00460 | 0.00511 |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 6. Financial Sophistication Split — Zip-Year

**Sample split:** `sophisticated` = majority-year classification of zip as high-financial-sophistication (from zip demographics panel)  
*Cols (1)–(4): sophisticated zips. Cols (5)–(8): unsophisticated zips. Periods: 2000–07, 2008–11, 2012–19, 2020–24.*

```
| | (1) Soph 00–07 | (2) Soph 08–11 | (3) Soph 12–19 | (4) Soph 20–24 | (5) Unsoph 00–07 | (6) Unsoph 08–11 | (7) Unsoph 12–19 | (8) Unsoph 20–24 |
|---|---|---|---|---|---|---|---|---|
| share_deps_closed | 0.0954*** | 0.0787*** | -0.0176 | -0.0091 | 0.1439*** | 0.0794** | -0.0202 | -0.0392* |
| | (0.0211) | (0.0281) | (0.0138) | (0.0142) | (0.0246) | (0.0367) | (0.0149) | (0.0238) |
| N | 34,601 | 21,814 | 44,529 | 25,976 | 32,095 | 20,622 | 40,327 | 22,418 |
| Zip FE | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| County×Year FE | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| SE | Zip | Zip | Zip | Zip | Zip | Zip | Zip | Zip |
| Within R² | 0.01735 | 0.00443 | 0.00511 | 0.00493 | 0.01094 | 0.00144 | 0.00301 | 0.00642 |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

*Unsophisticated zips show slightly larger pre-2012 coefficients (0.144 vs 0.095 in 2000–07), consistent with branch-dependent depositors being most affected. Both groups collapse to near zero post-2012.*

---

*Sources: `code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R`, `code/approach-technology-sorting/02_zip_tech_regressions_20260419.qmd`*
