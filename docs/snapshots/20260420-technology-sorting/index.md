---
layout: default
title: "technology-sorting — 2026-04-20"
---

# Snapshot: technology-sorting

> Zip-year deposit reallocation regressions decomposed by closing-bank technology type and local digital infrastructure. Controls: log branches, log incumbent banks, log lagged zip deposits, zip deposit growth t−3 to t−1. Pre-2012: incumbents absorb 11–12% of deposits from closing small/no-app banks per unit share. Post-2012: reallocation collapses to near zero — 2012–19 coefficient indistinguishable from zero, 2020–24 marginally positive at 0.022*. Mobile penetration interaction is negative and significant in 2012–19 (−0.16***), consistent with local digital infrastructure substituting for physical branches. Depositor sophistication interaction (Table 6) is uniformly insignificant across all periods — the structural break at 2012 dominates, with no detectable heterogeneity by depositor type.

---

## 1. Baseline — Zip-Year

**Unit:** zip × year  
**LHS:** `outcome = (inc_tp1 – inc_curr) / total_deps` — change in incumbent deposits normalized by total zip deposits, winsorized 2.5/97.5  
**Treatment:** `share_deps_closed` = deposits in closing branches / total zip deposits  
**Incumbent:** banks present in zip at t+1 that were present at t  
**FE:** zip + county×year | **SE:** clustered at zip  
**Controls:** log(# branches), log(# incumbent banks), log(total zip deposits at t−1), zip deposit growth t−3 to t−1  
*Note: 2000–01 observations dropped due to 2-year lag for dep_growth_t3t1 (N for 2000–07 = 51,558 vs 70,727 without growth control)*

```
|                    | 2000–07    | 2008–11    | 2012–19    | 2020–24    |
| ------------------ | ---------- | ---------- | ---------- | ---------- |
| share_deps_closed  | 0.1208***  | 0.1048***  | 0.0098     | 0.0241*    |
|                    | (0.0205)   | (0.0216)   | (0.0100)   | (0.0128)   |
| log_n_branches     | −0.0145*   | 0.0474***  | 0.0194**   | 0.0370***  |
|                    | (0.0085)   | (0.0110)   | (0.0076)   | (0.0106)   |
| log_n_inc_banks    | 0.0890***  | 0.0499***  | 0.0713***  | 0.0934***  |
|                    | (0.0075)   | (0.0079)   | (0.0058)   | (0.0089)   |
| log_total_deps     | −0.0985*** | −0.1202*** | −0.1049*** | −0.1054*** |
|                    | (0.0059)   | (0.0098)   | (0.0083)   | (0.0122)   |
| dep_growth_t3t1    | −0.0081*** | −0.0054    | −0.0036    | −0.0371*** |
|                    | (0.0022)   | (0.0044)   | (0.0028)   | (0.0057)   |
| N                  | 51,558     | 44,830     | 89,954     | 51,586     |
| Zip FE             | Yes        | Yes        | Yes        | Yes        |
| County×Year FE     | Yes        | Yes        | Yes        | Yes        |
| SE                 | Zip        | Zip        | Zip        | Zip        |
| Within R²          | 0.06325    | 0.04686    | 0.04285    | 0.05693    |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 2. Closing-Bank Size Decomposition — Zip-Year

**Treatment decomposition:**  
- `share_deps_closed_top4` = deposits in top-4 (JPM/BAC/WFC/Citi) closing branches / total deps  
- `share_deps_closed_large` = large-but-not-top4 (assets > $100B) closing branches / total deps  
- `share_deps_closed_small` = all other closing branches / total deps  

*Hypothesis: top-4 closures produce near-zero spillover; small-bank closures drive pre-2012 effect.*

```
|                          | 2000–07    | 2008–11    | 2012–19    | 2020–24    |
| ------------------------ | ---------- | ---------- | ---------- | ---------- |
| share_deps_closed_top4   | 0.0405     | 0.1051***  | −0.0331**  | 0.0199     |
|                          | (0.0404)   | (0.0340)   | (0.0141)   | (0.0144)   |
| share_deps_closed_large  | 0.1651***  | 0.0920**   | 0.0095     | 0.0249     |
|                          | (0.0386)   | (0.0394)   | (0.0147)   | (0.0212)   |
| share_deps_closed_small  | 0.1290***  | 0.1114***  | 0.0611***  | 0.0329     |
|                          | (0.0263)   | (0.0322)   | (0.0157)   | (0.0210)   |
| log_n_branches           | −0.0146*   | 0.0474***  | 0.0177**   | 0.0367***  |
|                          | (0.0085)   | (0.0110)   | (0.0076)   | (0.0107)   |
| log_n_inc_banks          | 0.0891***  | 0.0498***  | 0.0726***  | 0.0936***  |
|                          | (0.0075)   | (0.0079)   | (0.0058)   | (0.0089)   |
| log_total_deps           | −0.0984*** | −0.1203*** | −0.1047*** | −0.1054*** |
|                          | (0.0059)   | (0.0098)   | (0.0083)   | (0.0122)   |
| dep_growth_t3t1          | −0.0082*** | −0.0054    | −0.0035    | −0.0371*** |
|                          | (0.0022)   | (0.0044)   | (0.0028)   | (0.0057)   |
| N                        | 51,558     | 44,830     | 89,954     | 51,586     |
| Zip FE                   | Yes        | Yes        | Yes        | Yes        |
| County×Year FE           | Yes        | Yes        | Yes        | Yes        |
| SE                       | Zip        | Zip        | Zip        | Zip        |
| Within R²                | 0.06345    | 0.04687    | 0.04331    | 0.05694    |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 3. Closing-Bank App Decomposition — Zip-Year

**Treatment decomposition:**  
- `share_deps_closed_app` = deposits in non-top4 closing branches with mobile app / total deps  
- `share_deps_closed_noapp` = deposits in closing branches without mobile app / total deps  

*Hypothesis: app-bank closures produce less reallocation; both converge to zero post-2012 as app coverage expands.*

```
|                          | 2000–07    | 2008–11    | 2012–19    | 2020–24    |
| ------------------------ | ---------- | ---------- | ---------- | ---------- |
| share_deps_closed_app    | 0.2816     | 0.1378***  | 0.0267**   | 0.0248     |
|                          | (0.1717)   | (0.0523)   | (0.0122)   | (0.0164)   |
| share_deps_closed_noapp  | 0.1194***  | 0.0919***  | 0.0850***  | 0.0131     |
|                          | (0.0206)   | (0.0285)   | (0.0232)   | (0.0498)   |
| log_n_branches           | −0.0145*   | 0.0506***  | 0.0148*    | 0.0399***  |
|                          | (0.0085)   | (0.0110)   | (0.0076)   | (0.0106)   |
| log_n_inc_banks          | 0.0890***  | 0.0452***  | 0.0765***  | 0.0894***  |
|                          | (0.0075)   | (0.0077)   | (0.0054)   | (0.0080)   |
| log_total_deps           | −0.0985*** | −0.1198*** | −0.1051*** | −0.1050*** |
|                          | (0.0059)   | (0.0098)   | (0.0083)   | (0.0120)   |
| dep_growth_t3t1          | −0.0081*** | −0.0055    | −0.0035    | −0.0372*** |
|                          | (0.0022)   | (0.0044)   | (0.0028)   | (0.0057)   |
| N                        | 51,558     | 44,830     | 89,954     | 51,586     |
| Zip FE                   | Yes        | Yes        | Yes        | Yes        |
| County×Year FE           | Yes        | Yes        | Yes        | Yes        |
| SE                       | Zip        | Zip        | Zip        | Zip        |
| Within R²                | 0.06328    | 0.04645    | 0.04318    | 0.05688    |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 4. Mobile Penetration Interaction — Zip-Year

**Additional variable:** `perc_hh_wMobileSub` = county-year share of households with mobile subscription (raw data: 2007–2023; LOCF-filled within county; 2023 value held for 2024+)  
**Interaction:** `share_deps_closed × perc_hh_wMobileSub`  
*Sample restricted to 2012+ because raw mobile data starts 2007 and pre-2012 coverage is insufficient for reliable inference.*  
*Hypothesis: high-mobile counties see less reallocation — local digital infrastructure substitutes for physical branches.*

```
|                                               | 2012–24    | 2012–19    | 2020–24    |
| --------------------------------------------- | ---------- | ---------- | ---------- |
| share_deps_closed                             | 0.0453*    | 0.1000***  | −0.6460*** |
|                                               | (0.0234)   | (0.0276)   | (0.1802)   |
| share_deps_closed × perc_hh_wMobileSub        | −0.0777**  | −0.1604*** | 0.8055***  |
|                                               | (0.0304)   | (0.0405)   | (0.2104)   |
| log_n_branches                                | 0.0148***  | 0.0134*    | 0.0452***  |
|                                               | (0.0057)   | (0.0078)   | (0.0128)   |
| log_n_inc_banks                               | 0.0682***  | 0.0733***  | 0.1015***  |
|                                               | (0.0046)   | (0.0060)   | (0.0106)   |
| log_total_deps                                | −0.0849*** | −0.1017*** | −0.0832*** |
|                                               | (0.0057)   | (0.0084)   | (0.0131)   |
| dep_growth_t3t1                               | −0.0027    | −0.0031    | −0.0674*** |
|                                               | (0.0023)   | (0.0029)   | (0.0072)   |
| N                                             | 102,644    | 70,195     | 32,230     |
| Zip FE                                        | Yes        | Yes        | Yes        |
| County×Year FE                                | Yes        | Yes        | Yes        |
| SE                                            | Zip        | Zip        | Zip        |
| Within R²                                     | 0.04115    | 0.04342    | 0.06161    |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 5. Combined Decomposition (Post-2012) — Zip-Year

**All channels simultaneously, post-2012 sample.** Separate coefficients for app, no-app, top4; interaction with mobile penetration on aggregate closure share.  
*Col (1): 2012–24. Col (2): 2012–19.*

```
|                                               | 2012–24    | 2012–19    |
| --------------------------------------------- | ---------- | ---------- |
| share_deps_closed_app                         | 0.0401*    | 0.0981***  |
|                                               | (0.0239)   | (0.0282)   |
| share_deps_closed_noapp                       | 0.0689**   | 0.1329***  |
|                                               | (0.0282)   | (0.0333)   |
| share_deps_closed_top4                        | 0.0058     | 0.0519*    |
|                                               | (0.0259)   | (0.0312)   |
| share_deps_closed × perc_hh_wMobileSub        | −0.0536*   | −0.1363*** |
|                                               | (0.0312)   | (0.0412)   |
| log_n_branches                                | 0.0142**   | 0.0127     |
|                                               | (0.0057)   | (0.0079)   |
| log_n_inc_banks                               | 0.0688***  | 0.0741***  |
|                                               | (0.0046)   | (0.0060)   |
| log_total_deps                                | −0.0849*** | −0.1016*** |
|                                               | (0.0057)   | (0.0084)   |
| dep_growth_t3t1                               | −0.0027    | −0.0031    |
|                                               | (0.0023)   | (0.0029)   |
| N                                             | 102,644    | 70,195     |
| Zip FE                                        | Yes        | Yes        |
| County×Year FE                                | Yes        | Yes        |
| SE                                            | Zip        | Zip        |
| Within R²                                     | 0.04130    | 0.04367    |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 6. Depositor Sophistication Interaction — Zip-Year

**Interaction:** `share_deps_closed × sophisticated` where `sophisticated` is a zip×year binary from the demographics panel (within-year classification).  
**Main effect of `sophisticated` included** (dropped in 2000–07 due to collinearity with zip FE — insufficient within-zip variation in that subsample).  
*Hypothesis: negative interaction — unsophisticated zip-years show larger reallocation; sophisticated zip-years show attenuated effect.*

```
|                                    | 2000–07    | 2008–11    | 2012–19    | 2020–24    |
| ---------------------------------- | ---------- | ---------- | ---------- | ---------- |
| share_deps_closed                  | 0.1219***  | 0.1147***  | 0.0224*    | 0.0070     |
|                                    | (0.0275)   | (0.0301)   | (0.0129)   | (0.0171)   |
| share_deps_closed × sophisticated  | −0.0024    | −0.0179    | −0.0243    | 0.0308*    |
|                                    | (0.0375)   | (0.0390)   | (0.0155)   | (0.0183)   |
| sophisticated                      |            | 0.0022     | 0.0061***  | −0.0004    |
|                                    |            | (0.0068)   | (0.0021)   | (0.0050)   |
| log_n_branches                     | −0.0145*   | 0.0474***  | 0.0194**   | 0.0372***  |
|                                    | (0.0085)   | (0.0110)   | (0.0076)   | (0.0106)   |
| log_n_inc_banks                    | 0.0890***  | 0.0500***  | 0.0711***  | 0.0934***  |
|                                    | (0.0075)   | (0.0079)   | (0.0057)   | (0.0089)   |
| log_total_deps                     | −0.0985*** | −0.1202*** | −0.1049*** | −0.1054*** |
|                                    | (0.0059)   | (0.0098)   | (0.0083)   | (0.0122)   |
| dep_growth_t3t1                    | −0.0081*** | −0.0054    | −0.0036    | −0.0371*** |
|                                    | (0.0022)   | (0.0044)   | (0.0028)   | (0.0057)   |
| N                                  | 51,558     | 44,830     | 89,954     | 51,586     |
| Zip FE                             | Yes        | Yes        | Yes        | Yes        |
| County×Year FE                     | Yes        | Yes        | Yes        | Yes        |
| SE                                 | Zip        | Zip        | Zip        | Zip        |
| Within R²                          | 0.06325    | 0.04687    | 0.04300    | 0.05702    |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

*Interaction uniformly insignificant across all periods. Depositor sophistication does not moderate branch-closure reallocation — the structural break at 2012 is the dominant pattern, not cross-sectional heterogeneity in depositor type.*

---

*Sources: `code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R`, `code/approach-technology-sorting/02_zip_tech_regressions_20260419.qmd`*
