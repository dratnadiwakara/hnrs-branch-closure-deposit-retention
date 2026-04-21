---
layout: default
title: "20260418-08-main-regressions — 2026-04-21"
---

# Snapshot: 20260418-08-main-regressions

> Zip-year incumbent deposit reallocation regressions decomposed by closing-bank technology type and local digital infrastructure. Controls throughout: log branches, log incumbent banks, log lagged zip deposits (`log_total_deps`), zip deposit growth t−3 to t−1 (`dep_growth_t3t1`). Baseline (Table 1): pre-2012 reallocation is strong (0.12*** in 2000–07, 0.10*** in 2008–11) and collapses post-2012 (0.010 in 2012–19, 0.024* in 2020–24). Size decomposition (Table 2): small-bank closures drive the pre-2012 effect (0.13*** / 0.11***); top-4 closures null pre-2012 but significant in the GFC window (0.11***); all types null by 2012–19 except small (0.061***). App decomposition (Table 3): no-app closures drive reallocation in both pre-digital periods; app-bank closures near-zero 2000–07 but significant 2008–11 (0.14***) and marginally 2012–19 (0.027**). Mobile penetration interaction (Table 4): negative and significant in 2012–19 (−0.160***), consistent with local digital infrastructure substituting for physical access; 2020–24 interaction reverses sign (0.806***) suggesting saturation or composition shift. Combined decomposition (Table 5): mobile interaction dominates, app/noapp split survives. Depositor sophistication interaction (Table 6): uniformly insignificant in pre-digital periods; marginally significant in 2012–19 (−0.034**) and 2020–24 (0.031*), suggesting the structural break at 2012 — not cross-sectional depositor heterogeneity — is the dominant pattern.

---

## 1. Baseline Specification — Zip-Year

**Unit:** zip × year  
**LHS:** `outcome = (inc_tp1 – inc_curr) / total_deps` — change in incumbent deposits normalized by total zip deposits at t−1, winsorized 2.5/97.5  
**Treatment:** `share_deps_closed` = deposits in closing branches / total zip deposits at t−1  
**Incumbent:** banks present in zip at t with no branch closures in that zip-year  
**FE:** zip + county×year | **SE:** clustered at zip  
**Controls:** log(# branches), log(# incumbent banks), log(total zip deposits t−1), zip deposit growth t−3 to t−1  
*Note: 2000–01 observations dropped due to 2-year lag requirement for dep_growth_t3t1*

```
|                    | (1) 2000–07  | (2) 2008–11  | (3) 2012–19  | (4) 2020–24  |
| ------------------ | ------------ | ------------ | ------------ | ------------ |
| share_deps_closed  | 0.1208***    | 0.1048***    | 0.0098       | 0.0241*      |
|                    | (0.0205)     | (0.0216)     | (0.0100)     | (0.0128)     |
| log_n_branches     | −0.0145*     | 0.0474***    | 0.0194**     | 0.0370***    |
|                    | (0.0085)     | (0.0110)     | (0.0076)     | (0.0106)     |
| log_n_inc_banks    | 0.0890***    | 0.0499***    | 0.0713***    | 0.0934***    |
|                    | (0.0075)     | (0.0079)     | (0.0058)     | (0.0089)     |
| log_total_deps     | −0.0985***   | −0.1202***   | −0.1049***   | −0.1054***   |
|                    | (0.0059)     | (0.0098)     | (0.0083)     | (0.0122)     |
| dep_growth_t3t1    | −0.0081***   | −0.0054      | −0.0036      | −0.0371***   |
|                    | (0.0022)     | (0.0044)     | (0.0028)     | (0.0057)     |
| N                  | 51,558       | 44,830       | 89,954       | 51,586       |
| Zip FE             | Yes          | Yes          | Yes          | Yes          |
| County×Year FE     | Yes          | Yes          | Yes          | Yes          |
| SE                 | Zip          | Zip          | Zip          | Zip          |
| Mean(outcome)      | 0.049        | 0.037        | 0.062        | 0.054        |
| SD(share_deps_cl.) | 0.034        | 0.033        | 0.047        | 0.060        |
| R²                 | 0.53982      | 0.48717      | 0.48155      | 0.56746      |
| Within R²          | 0.06325      | 0.04686      | 0.04285      | 0.05693      |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 2. Closing-Bank Size Decomposition — Zip-Year

**Unit:** zip × year  
**LHS:** `outcome` — same as Table 1  
**Treatment decomposition:**  
- `share_deps_closed_top4` = deposits in JPM/BAC/WFC/Citi closing branches / total deps  
- `share_deps_closed_large` = large-but-not-top4 (assets > $100B) closing branches / total deps  
- `share_deps_closed_small` = all other closing branches / total deps  
**FE:** zip + county×year | **SE:** clustered at zip  
**Controls:** same as Table 1  

```
|                          | (1) 2000–07  | (2) 2008–11  | (3) 2012–19  | (4) 2020–24  |
| ------------------------ | ------------ | ------------ | ------------ | ------------ |
| share_deps_closed_top4   | 0.0405       | 0.1051***    | −0.0331**    | 0.0199       |
|                          | (0.0404)     | (0.0340)     | (0.0141)     | (0.0144)     |
| share_deps_closed_large  | 0.1651***    | 0.0920**     | 0.0095       | 0.0249       |
|                          | (0.0386)     | (0.0394)     | (0.0147)     | (0.0212)     |
| share_deps_closed_small  | 0.1290***    | 0.1114***    | 0.0611***    | 0.0329       |
|                          | (0.0263)     | (0.0322)     | (0.0157)     | (0.0210)     |
| log_n_branches           | −0.0146*     | 0.0474***    | 0.0177**     | 0.0367***    |
|                          | (0.0085)     | (0.0110)     | (0.0076)     | (0.0107)     |
| log_n_inc_banks          | 0.0891***    | 0.0498***    | 0.0726***    | 0.0936***    |
|                          | (0.0075)     | (0.0079)     | (0.0058)     | (0.0089)     |
| log_total_deps           | −0.0984***   | −0.1203***   | −0.1047***   | −0.1054***   |
|                          | (0.0059)     | (0.0098)     | (0.0083)     | (0.0122)     |
| dep_growth_t3t1          | −0.0082***   | −0.0054      | −0.0035      | −0.0371***   |
|                          | (0.0022)     | (0.0044)     | (0.0028)     | (0.0057)     |
| N                        | 51,558       | 44,830       | 89,954       | 51,586       |
| Zip FE                   | Yes          | Yes          | Yes          | Yes          |
| County×Year FE           | Yes          | Yes          | Yes          | Yes          |
| SE                       | Zip          | Zip          | Zip          | Zip          |
| Mean(outcome)            | 0.049        | 0.037        | 0.062        | 0.054        |
| SD(share_deps_cl.)       | 0.034        | 0.033        | 0.047        | 0.060        |
| R²                       | 0.53992      | 0.48717      | 0.48180      | 0.56746      |
| Within R²                | 0.06345      | 0.04687      | 0.04331      | 0.05694      |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 3. Closing-Bank App Decomposition — Zip-Year

**Unit:** zip × year  
**LHS:** `outcome` — same as Table 1  
**Treatment decomposition:**  
- `share_deps_closed_app` = deposits in non-top4 closing branches with mobile app / total deps  
- `share_deps_closed_noapp` = deposits in non-top4 closing branches without mobile app / total deps  
**FE:** zip + county×year | **SE:** clustered at zip  
**Controls:** same as Table 1  
*Note: top-4 closures excluded from both treatment vars; column (3) uses all post-2012 sample (2012–19 pooled)*

```
|                          | (1) 2000–07  | (2) 2008–11  | (3) 2012–19  | (4) 2020–24  |
| ------------------------ | ------------ | ------------ | ------------ | ------------ |
| share_deps_closed_app    | 0.2816       | 0.1378***    | 0.0267**     | 0.0248       |
|                          | (0.1717)     | (0.0523)     | (0.0122)     | (0.0164)     |
| share_deps_closed_noapp  | 0.1194***    | 0.0919***    | 0.0850***    | 0.0131       |
|                          | (0.0206)     | (0.0285)     | (0.0232)     | (0.0498)     |
| log_n_branches           | −0.0145*     | 0.0506***    | 0.0148*      | 0.0399***    |
|                          | (0.0085)     | (0.0110)     | (0.0076)     | (0.0106)     |
| log_n_inc_banks          | 0.0890***    | 0.0452***    | 0.0765***    | 0.0894***    |
|                          | (0.0075)     | (0.0077)     | (0.0054)     | (0.0080)     |
| log_total_deps           | −0.0985***   | −0.1198***   | −0.1051***   | −0.1050***   |
|                          | (0.0059)     | (0.0098)     | (0.0083)     | (0.0120)     |
| dep_growth_t3t1          | −0.0081***   | −0.0055      | −0.0035      | −0.0372***   |
|                          | (0.0022)     | (0.0044)     | (0.0028)     | (0.0057)     |
| N                        | 51,558       | 44,830       | 89,954       | 51,586       |
| Zip FE                   | Yes          | Yes          | Yes          | Yes          |
| County×Year FE           | Yes          | Yes          | Yes          | Yes          |
| SE                       | Zip          | Zip          | Zip          | Zip          |
| Mean(outcome)            | 0.049        | 0.037        | 0.062        | 0.054        |
| SD(share_deps_cl.)       | 0.034        | 0.033        | 0.047        | 0.060        |
| R²                       | 0.53984      | 0.48695      | 0.48173      | 0.56743      |
| Within R²                | 0.06328      | 0.04645      | 0.04318      | 0.05688      |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 4. Mobile Penetration Interaction — Zip-Year (Post-2012)

**Unit:** zip × year  
**LHS:** `outcome` — same as Table 1  
**Treatment:** `share_deps_closed` (deposit-weighted)  
**Moderator:** `perc_hh_wMobileSub` = zip-level household mobile subscription rate (ACS), demeaned  
**Columns:** (1) full post-2012 sample, (2) 2012–19, (3) 2020–24  
**FE:** zip + county×year | **SE:** clustered at zip  
**Controls:** same as Table 1  
*Note: perc_hh_wMobileSub main effect absorbed by zip FE*

```
|                                      | (1) Full     | (2) 2012–19  | (3) 2020–24  |
| ------------------------------------ | ------------ | ------------ | ------------ |
| share_deps_closed                    | 0.0453*      | 0.1000***    | −0.6460***   |
|                                      | (0.0234)     | (0.0276)     | (0.1802)     |
| share_deps_closed × perc_hh_wMobSub  | −0.0777**    | −0.1604***   | 0.8055***    |
|                                      | (0.0304)     | (0.0405)     | (0.2104)     |
| log_n_branches                       | 0.0148***    | 0.0134*      | 0.0452***    |
|                                      | (0.0057)     | (0.0078)     | (0.0128)     |
| log_n_inc_banks                      | 0.0682***    | 0.0733***    | 0.1015***    |
|                                      | (0.0046)     | (0.0060)     | (0.0106)     |
| log_total_deps                       | −0.0849***   | −0.1017***   | −0.0832***   |
|                                      | (0.0057)     | (0.0084)     | (0.0131)     |
| dep_growth_t3t1                      | −0.0027      | −0.0031      | −0.0674***   |
|                                      | (0.0023)     | (0.0029)     | (0.0072)     |
| N                                    | 102,644      | 70,195       | 32,230       |
| Zip FE                               | Yes          | Yes          | Yes          |
| County×Year FE                       | Yes          | Yes          | Yes          |
| SE                                   | Zip          | Zip          | Zip          |
| Mean(outcome)                        | 0.056        | 0.060        | 0.054        |
| SD(share_deps_cl.)                   | 0.045        | 0.047        | 0.060        |
| R²                                   | 0.45112      | 0.44590      | 0.59192      |
| Within R²                            | 0.04115      | 0.04342      | 0.06161      |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 5. Combined Decomposition — Zip-Year (Post-2012)

**Unit:** zip × year  
**LHS:** `outcome` — same as Table 1  
**Treatment:** app/noapp/top4 split + mobile penetration interaction, jointly in one spec  
**Columns:** (1) full post-2012 sample, (2) 2012–19  
**FE:** zip + county×year | **SE:** clustered at zip  
**Controls:** same as Table 1  

```
|                                      | (1) Full     | (2) 2012–19  |
| ------------------------------------ | ------------ | ------------ |
| share_deps_closed_app                | 0.0401*      | 0.0981***    |
|                                      | (0.0239)     | (0.0282)     |
| share_deps_closed_noapp              | 0.0689**     | 0.1329***    |
|                                      | (0.0282)     | (0.0333)     |
| share_deps_closed_top4               | 0.0058       | 0.0519*      |
|                                      | (0.0259)     | (0.0312)     |
| share_deps_closed × perc_hh_wMobSub  | −0.0536*     | −0.1363***   |
|                                      | (0.0312)     | (0.0412)     |
| log_n_branches                       | 0.0142**     | 0.0127       |
|                                      | (0.0057)     | (0.0079)     |
| log_n_inc_banks                      | 0.0688***    | 0.0741***    |
|                                      | (0.0046)     | (0.0060)     |
| log_total_deps                       | −0.0849***   | −0.1016***   |
|                                      | (0.0057)     | (0.0084)     |
| dep_growth_t3t1                      | −0.0027      | −0.0031      |
|                                      | (0.0023)     | (0.0029)     |
| N                                    | 102,644      | 70,195       |
| Zip FE                               | Yes          | Yes          |
| County×Year FE                       | Yes          | Yes          |
| SE                                   | Zip          | Zip          |
| Mean(outcome)                        | 0.056        | 0.060        |
| SD(share_deps_cl.)                   | 0.045        | 0.047        |
| R²                                   | 0.45121      | 0.44604      |
| Within R²                            | 0.04130      | 0.04367      |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 6. Depositor Sophistication Interaction — Zip-Year

**Unit:** zip × year  
**LHS:** `outcome` — same as Table 1  
**Treatment:** `share_deps_closed` (deposit-weighted)  
**Moderator:** `sophisticated` = zip-level share of sophisticated depositors (above-median), demeaned  
**Columns:** (1) 2000–07, (2) 2008–11, (3) 2012–13 (early digital transition), (4) 2012–19 pooled, (5) 2020–24  
**FE:** zip + county×year | **SE:** clustered at zip  
**Controls:** same as Table 1  

```
|                                      | (1) 2000–07  | (2) 2008–11  | (3) 2012–13  | (4) 2012–19  | (5) 2020–24  |
| ------------------------------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
| share_deps_closed                    | 0.1219***    | 0.1147***    | 0.0899**     | 0.0208       | 0.0070       |
|                                      | (0.0275)     | (0.0301)     | (0.0403)     | (0.0150)     | (0.0171)     |
| share_deps_closed × sophisticated    | −0.0024      | −0.0179      | 0.0093       | −0.0338**    | 0.0308*      |
|                                      | (0.0375)     | (0.0390)     | (0.0480)     | (0.0172)     | (0.0183)     |
| sophisticated                        |              | 0.0022       | 0.0058       | 0.0039       | −0.0004      |
|                                      |              | (0.0068)     | (0.0061)     | (0.0027)     | (0.0050)     |
| log_n_branches                       | −0.0145*     | 0.0474***    | −0.0723***   | 0.0314***    | 0.0372***    |
|                                      | (0.0085)     | (0.0110)     | (0.0219)     | (0.0101)     | (0.0106)     |
| log_n_inc_banks                      | 0.0890***    | 0.0500***    | 0.0125       | 0.0791***    | 0.0934***    |
|                                      | (0.0075)     | (0.0079)     | (0.0180)     | (0.0073)     | (0.0089)     |
| log_total_deps                       | −0.0985***   | −0.1202***   | −0.0332*     | −0.1071***   | −0.1054***   |
|                                      | (0.0059)     | (0.0098)     | (0.0179)     | (0.0127)     | (0.0122)     |
| dep_growth_t3t1                      | −0.0081***   | −0.0054      | 0.0004       | −0.0208***   | −0.0371***   |
|                                      | (0.0022)     | (0.0044)     | (0.0083)     | (0.0052)     | (0.0057)     |
| N                                    | 51,558       | 44,830       | 22,868       | 66,796       | 51,586       |
| Zip FE                               | Yes          | Yes          | Yes          | Yes          | Yes          |
| County×Year FE                       | Yes          | Yes          | Yes          | Yes          | Yes          |
| SE                                   | Zip          | Zip          | Zip          | Zip          | Zip          |
| Mean(outcome)                        | 0.049        | 0.037        | 0.059        | 0.061        | 0.054        |
| SD(share_deps_cl.)                   | 0.034        | 0.033        | 0.045        | 0.047        | 0.060        |
| R²                                   | 0.53982      | 0.48717      | 0.64535      | 0.51108      | 0.56750      |
| Within R²                            | 0.06325      | 0.04687      | 0.00453      | 0.04533      | 0.05702      |
```
*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

*Sources: code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R, code/approach-technology-sorting/02_zip_tech_regressions_20260419.qmd*
