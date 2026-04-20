---
layout: default
title: "own-closure-het — 2026-04-20"
---

# Snapshot: own-closure-het

> Two complementary designs — zip-year incumbent reallocation and bank-county-year own-closure retention — both show the digital transition sharply at 2012. In the zip-year design, incumbents absorb 11–12% of closed-branch deposits per unit share pre-2012; this collapses to zero post-2012 (2012–19 insignificant), with mobile penetration attenuating reallocation (−0.16*** in 2012–19). In the bank-county-year own-closure design, closing banks retain ~54–68% of deposits at remaining branches (large, stable coefficient). Sophisticated-county depositors show systematically lower retention: −0.207*** pre-2012, −0.191** in 2012–13, −0.067* in 2014–19 — attenuating as sophisticated depositors move to digital channels. Large non-top4 banks retain significantly more (+0.21–0.25***). Mobile penetration interaction is null in the county own-closure design. Combined, both designs are consistent with the mechanism: digital-capable depositors leave branches more easily, reducing both competitor spillovers and own-bank physical retention.

---

## Part A — Zip-Year Incumbent Reallocation

---

## 1. Baseline — Zip-Year

**Unit:** zip × year
**LHS:** `outcome = (inc_tp1 – inc_curr) / total_deps` — change in incumbent deposits normalized by total zip deposits, winsorized 2.5/97.5
**Treatment:** `share_deps_closed` = deposits in closing branches / total zip deposits
**Incumbent:** banks with no closures in that zip-year
**FE:** zip + county×year | **SE:** clustered at zip
**Controls:** log(# branches), log(# incumbent banks), log(total zip deposits at t−1), zip deposit growth t−3 to t−1
*Note: 2000–01 observations dropped due to 2-year lag for dep_growth_t3t1*

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
| Mean(outcome)      | 0.049      | 0.037      | 0.062      | 0.054      |
| SD(share_deps_cl.) | 0.034      | 0.033      | 0.047      | 0.060      |
| Adj. R²            | 0.540      | 0.487      | 0.482      | 0.567      |
| Within R²          | 0.063      | 0.047      | 0.043      | 0.057      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10*

---

## 2. Closing-Bank Size Decomposition — Zip-Year

**Unit:** zip × year
**LHS:** `outcome` (same as Table 1)
**Treatment:** `share_deps_closed_top4` / `_large` / `_small` — closed deposits decomposed by bank size tier, each normalized by total zip deposits
**FE:** zip + county×year | **SE:** clustered at zip
**Controls:** same as Table 1

```
|                          | 2000–07    | 2008–11    | 2012–19    | 2020–24    |
| ------------------------ | ---------- | ---------- | ---------- | ---------- |
| share_deps_closed_top4   | 0.0405     | 0.1051***  | −0.0331**  | 0.0199     |
|                          | (0.0404)   | (0.0340)   | (0.0141)   | (0.0144)   |
| share_deps_closed_large  | 0.1651***  | 0.0920**   | 0.0095     | 0.0249     |
|                          | (0.0386)   | (0.0394)   | (0.0147)   | (0.0212)   |
| share_deps_closed_small  | 0.1290***  | 0.1114***  | 0.0611***  | 0.0329     |
|                          | (0.0263)   | (0.0322)   | (0.0157)   | (0.0210)   |
| N                        | 51,558     | 44,830     | 89,954     | 51,586     |
| Zip FE                   | Yes        | Yes        | Yes        | Yes        |
| County×Year FE           | Yes        | Yes        | Yes        | Yes        |
| SE                       | Zip        | Zip        | Zip        | Zip        |
| Mean(outcome)            | 0.049      | 0.037      | 0.062      | 0.054      |
| SD(share_deps_cl._small) | 0.028      | 0.023      | 0.027      | 0.030      |
| Adj. R²                  | 0.540      | 0.487      | 0.482      | 0.567      |
| Within R²                | 0.063      | 0.047      | 0.043      | 0.057      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10*

---

## 3. Closing-Bank App Decomposition — Zip-Year

**Unit:** zip × year
**LHS:** `outcome` (same as Table 1)
**Treatment:** `share_deps_closed_app` = closed deposits from non-top4 banks with mobile app; `share_deps_closed_noapp` = from banks without app
**FE:** zip + county×year | **SE:** clustered at zip
**Controls:** same as Table 1

```
|                          | 2000–07    | 2008–11    | 2012–19    | 2020–24    |
| ------------------------ | ---------- | ---------- | ---------- | ---------- |
| share_deps_closed_app    | 0.2816     | 0.1378***  | 0.0267**   | 0.0248     |
|                          | (0.1717)   | (0.0523)   | (0.0122)   | (0.0164)   |
| share_deps_closed_noapp  | 0.1194***  | 0.0919***  | 0.0850***  | 0.0131     |
|                          | (0.0206)   | (0.0285)   | (0.0232)   | (0.0498)   |
| N                        | 51,558     | 44,830     | 89,954     | 51,586     |
| Zip FE                   | Yes        | Yes        | Yes        | Yes        |
| County×Year FE           | Yes        | Yes        | Yes        | Yes        |
| SE                       | Zip        | Zip        | Zip        | Zip        |
| Mean(outcome)            | 0.049      | 0.037      | 0.062      | 0.054      |
| SD(share_deps_cl._noapp) | 0.034      | 0.026      | 0.017      | 0.012      |
| Adj. R²                  | 0.540      | 0.487      | 0.482      | 0.567      |
| Within R²                | 0.063      | 0.046      | 0.043      | 0.057      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10*

---

## 4. Mobile Penetration Interaction — Zip-Year

**Unit:** zip × year, 2012+ only (mobile data available from 2012)
**LHS:** `outcome` (same as Table 1)
**Treatment:** `share_deps_closed` × `perc_hh_wMobileSub` — interaction with county-level mobile subscription share (main effect absorbed by county×year FE)
**FE:** zip + county×year | **SE:** clustered at zip
**Controls:** same as Table 1

```
|                                      | 2012–2024  | 2012–2019  | 2020–2024  |
| ------------------------------------ | ---------- | ---------- | ---------- |
| share_deps_closed                    | 0.0453*    | 0.1000***  | −0.6460*** |
|                                      | (0.0234)   | (0.0276)   | (0.1802)   |
| share_deps_closed × mobile           | −0.0777**  | −0.1604*** | 0.8055***  |
|                                      | (0.0304)   | (0.0405)   | (0.2104)   |
| N                                    | 102,644    | 70,195     | 32,230     |
| Zip FE                               | Yes        | Yes        | Yes        |
| County×Year FE                       | Yes        | Yes        | Yes        |
| SE                                   | Zip        | Zip        | Zip        |
| Mean(outcome)                        | 0.068      | 0.071      | 0.060      |
| SD(share_deps_closed)                | 0.057      | 0.051      | 0.068      |
| Adj. R²                              | 0.451      | 0.446      | 0.592      |
| Within R²                            | 0.041      | 0.043      | 0.062      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10. 2020–24 coefficients: the large reversal reflects few mobile-data counties with closures in that period — interpret with caution.*

---

## 5. Combined App + Mobile — Zip-Year

**Unit:** zip × year, 2012+ only
**LHS:** `outcome` (same as Table 1)
**Treatment:** app/noapp/top4 shares + mobile interaction, estimated jointly
**FE:** zip + county×year | **SE:** clustered at zip
**Controls:** same as Table 1

```
|                                      | 2012–2024  | 2012–2019  |
| ------------------------------------ | ---------- | ---------- |
| share_deps_closed_app                | 0.0401*    | 0.0981***  |
|                                      | (0.0239)   | (0.0282)   |
| share_deps_closed_noapp              | 0.0689**   | 0.1329***  |
|                                      | (0.0282)   | (0.0333)   |
| share_deps_closed_top4               | 0.0058     | 0.0519*    |
|                                      | (0.0259)   | (0.0312)   |
| share_deps_closed × mobile           | −0.0536*   | −0.1363*** |
|                                      | (0.0312)   | (0.0412)   |
| N                                    | 102,644    | 70,195     |
| Zip FE                               | Yes        | Yes        |
| County×Year FE                       | Yes        | Yes        |
| SE                                   | Zip        | Zip        |
| Mean(outcome)                        | 0.068      | 0.071      |
| SD(share_deps_closed)                | 0.057      | 0.051      |
| Adj. R²                              | 0.451      | 0.446      |
| Within R²                            | 0.041      | 0.044      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10*

---

## 6. Depositor Sophistication Interaction — Zip-Year

**Unit:** zip × year
**LHS:** `outcome` (same as Table 1)
**Treatment:** `share_deps_closed` × `sophisticated` — interaction with within-year binary zip classification (above-median college AND above-median dividend/capital gains). Main effect of `sophisticated` partially absorbed by zip FE.
**FE:** zip + county×year | **SE:** clustered at zip
**Controls:** same as Table 1
*Note: 2012–13 period has low within-period zip variation in `sophisticated` — coefficient imprecise*

```
|                              | 2000–07    | 2008–11    | 2012–13    | 2014–19    | 2020–24    |
| ---------------------------- | ---------- | ---------- | ---------- | ---------- | ---------- |
| share_deps_closed            | 0.1219***  | 0.1147***  | 0.0899**   | 0.0208     | 0.0070     |
|                              | (0.0275)   | (0.0301)   | (0.0403)   | (0.0150)   | (0.0171)   |
| share_deps_closed × soph.    | −0.0024    | −0.0179    | 0.0093     | −0.0338**  | 0.0308*    |
|                              | (0.0375)   | (0.0390)   | (0.0480)   | (0.0172)   | (0.0183)   |
| N                            | 51,558     | 44,830     | 22,868     | 66,796     | 51,586     |
| Zip FE                       | Yes        | Yes        | Yes        | Yes        | Yes        |
| County×Year FE               | Yes        | Yes        | Yes        | Yes        | Yes        |
| SE                           | Zip        | Zip        | Zip        | Zip        | Zip        |
| Mean(outcome)                | 0.049      | 0.037      | 0.037      | 0.071      | 0.054      |
| SD(share_deps_closed)        | 0.034      | 0.033      | 0.040      | 0.049      | 0.060      |
| Adj. R²                      | 0.540      | 0.487      | 0.645      | 0.511      | 0.568      |
| Within R²                    | 0.063      | 0.047      | 0.005      | 0.045      | 0.057      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10. `sophisticated` main effect included in cols 2–5 but near-zero (absorbed by zip FE in col 1).*

---

## Part B — Bank-County-Year Own-Closure Retention

---

## 7. Baseline Own-Closure — Bank-County-Year

**Unit:** bank × county × year
**LHS:** `growth_on_total_t1 = (deps_remain_tp1 – deps_remain_t1) / total_deps_bank_county_t1` — growth in deposits at surviving branches, normalized by total bank-county deposits at t−1, winsorized 2.5/97.5
**Treatment:** `closure_share` = closed-branch deposits / total bank-county deposits at t−1
**FE:** bank×year + county×year | **SE:** clustered at bank
**Controls:** log(total bank-county deposits at t−1), log(# remaining branches), bank-county market share at t−1
*Sample: organic closures only (M&A-excluded), non-extreme intensity, clean no-change control group*

```
|                               | Pre-2012   | 2012–2024  | 2012–2019  |
| ----------------------------- | ---------- | ---------- | ---------- |
| closure_share                 | 0.5378***  | 0.6823***  | 0.6685***  |
|                               | (0.0312)   | (0.0220)   | (0.0249)   |
| log(total_deps_bank_cty_t1)   | −0.1985*** | −0.1467*** | −0.1422*** |
|                               | (0.0048)   | (0.0042)   | (0.0045)   |
| log(n_remaining_branches)     | 0.2272***  | 0.1621***  | 0.1546***  |
|                               | (0.0070)   | (0.0065)   | (0.0076)   |
| mkt_share_county_t1           | 0.3306***  | 0.3354***  | 0.3436***  |
|                               | (0.0217)   | (0.0159)   | (0.0177)   |
| N                             | 178,022    | 280,777    | 173,127    |
| Bank×Year FE                  | Yes        | Yes        | Yes        |
| County×Year FE                | Yes        | Yes        | Yes        |
| SE                            | Bank       | Bank       | Bank       |
| Mean(growth_on_total_t1)      | 0.159      | 0.155      | 0.139      |
| SD(closure_share)             | 0.027      | 0.038      | 0.037      |
| Adj. R²                       | 0.403      | 0.320      | 0.286      |
| Within R²                     | 0.237      | 0.147      | 0.145      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10*

---

## 8. Depositor Sophistication Interaction — Bank-County-Year

**Unit:** bank × county × year
**LHS:** `growth_on_total_t1` (same as Table 7)
**Treatment:** `closure_share` × `sophisticated` — county classified above-median college + investment income in that year. Main effect absorbed by county×year FE.
**FE:** bank×year + county×year | **SE:** clustered at bank
**Controls:** same as Table 7

```
|                               | Pre-2012   | 2012–2024  | 2012–2019  | 2020–2024  |
| ----------------------------- | ---------- | ---------- | ---------- | ---------- |
| closure_share                 | 0.6521***  | 0.7118***  | 0.7266***  | 0.6934***  |
|                               | (0.0411)   | (0.0244)   | (0.0294)   | (0.0358)   |
| closure_share × sophisticated | −0.2066*** | −0.0498*   | −0.0953**  | 0.0135     |
|                               | (0.0581)   | (0.0298)   | (0.0383)   | (0.0410)   |
| N                             | 175,412    | 278,505    | 171,724    | 106,781    |
| Bank×Year FE                  | Yes        | Yes        | Yes        | Yes        |
| County×Year FE                | Yes        | Yes        | Yes        | Yes        |
| SE                            | Bank       | Bank       | Bank       | Bank       |
| Mean(growth_on_total_t1)      | 0.158      | 0.155      | 0.139      | 0.182      |
| SD(closure_share)             | 0.027      | 0.038      | 0.037      | 0.040      |
| Adj. R²                       | 0.403      | 0.321      | 0.287      | 0.359      |
| Within R²                     | 0.237      | 0.147      | 0.145      | 0.150      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10. Sophisticated main effect absorbed by county×year FE.*

---

## 9. Depositor Sophistication, Period Split — Bank-County-Year

**Unit:** bank × county × year
**LHS:** `growth_on_total_t1` (same as Table 7)
**Treatment:** same as Table 8, split at 2012/2013
**FE:** bank×year + county×year | **SE:** clustered at bank
**Controls:** same as Table 7

```
|                               | Pre-2012   | 2012–2013  | 2014–2019  | 2020–2024  |
| ----------------------------- | ---------- | ---------- | ---------- | ---------- |
| closure_share                 | 0.6521***  | 0.7944***  | 0.7104***  | 0.6934***  |
|                               | (0.0411)   | (0.1134)   | (0.0355)   | (0.0358)   |
| closure_share × sophisticated | −0.2066*** | −0.1912**  | −0.0671*   | 0.0135     |
|                               | (0.0581)   | (0.0945)   | (0.0371)   | (0.0410)   |
| N                             | 175,412    | 43,019     | 128,705    | 106,781    |
| Bank×Year FE                  | Yes        | Yes        | Yes        | Yes        |
| County×Year FE                | Yes        | Yes        | Yes        | Yes        |
| SE                            | Bank       | Bank       | Bank       | Bank       |
| Mean(growth_on_total_t1)      | 0.158      | 0.098      | 0.153      | 0.182      |
| SD(closure_share)             | 0.027      | 0.035      | 0.037      | 0.040      |
| Adj. R²                       | 0.403      | 0.269      | 0.286      | 0.359      |
| Within R²                     | 0.237      | 0.123      | 0.153      | 0.150      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10. Strong negative interaction pre-2012 and 2012–13, attenuating by 2014–19, zero by 2020–24.*

---

## 10. Combined Heterogeneity — Bank-County-Year

**Unit:** bank × county × year, 2012+ only
**LHS:** `growth_on_total_t1` (same as Table 7)
**Treatment:** `closure_share` with interactions for top4/large bank type, mobile penetration, and depositor sophistication simultaneously
**FE:** bank×year + county×year | **SE:** clustered at bank
**Controls:** same as Table 7

```
|                               | 2012–2024  | 2012–2019  | 2014–2019  |
| ----------------------------- | ---------- | ---------- | ---------- |
| closure_share                 | 0.5278***  | 0.5473***  | 0.4496***  |
|                               | (0.0501)   | (0.0416)   | (0.0556)   |
| closure_share × top4          | −0.0786    | −0.0401    | −0.0438    |
|                               | (0.0524)   | (0.0424)   | (0.0464)   |
| closure_share × large         | 0.2127***  | 0.2454***  | 0.2283***  |
|                               | (0.0449)   | (0.0560)   | (0.0640)   |
| closure_share × mobile        | 0.0900     | 0.0400     | 0.1642     |
|                               | (0.0780)   | (0.0751)   | (0.1043)   |
| closure_share × sophisticated | −0.0463    | −0.0884*   | −0.0684    |
|                               | (0.0303)   | (0.0463)   | (0.0579)   |
| N                             | 134,597    | 89,674     | 67,396     |
| Bank×Year FE                  | Yes        | Yes        | Yes        |
| County×Year FE                | Yes        | Yes        | Yes        |
| SE                            | Bank       | Bank       | Bank       |
| Mean(growth_on_total_t1)      | 0.190      | 0.175      | 0.195      |
| SD(closure_share)             | 0.045      | 0.043      | 0.043      |
| Adj. R²                       | 0.359      | 0.325      | 0.317      |
| Within R²                     | 0.157      | 0.156      | 0.162      |
```
*Note: *** p<0.01, ** p<0.05, * p<0.10. Mobile interaction null at county level (absorbed by county×year FE). Large bank premium robust across all post-2012 periods.*

---

*Sources: 02_zip_tech_regressions_20260419.qmd, 03_own_closure_het_20260420.R*
