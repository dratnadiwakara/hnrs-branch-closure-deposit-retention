# Paper Outline for a Top Finance Journal

## Working Title
**Branch Closures, Deposit Retention, and the Credit Channel in the Digital Era**

## One-paragraph positioning
This paper studies how branch closures affect deposit reallocation and local credit supply, with a focus on the contrast between the pre-digital and digital eras. The central claim is that organic branch closures in recent years are less disruptive than the M&A-driven closures emphasized in prior work: banks retain deposits after closing branches, incumbent competitors do not receive large deposit inflows, and local lending spillovers are muted. We build this argument with existing project panels and scripts, and test mechanisms tied to digital adoption, bank size, and local digital infrastructure.

## What is already implemented in this project

| Stream | Unit | Existing script(s) | Status |
|---|---|---|---|
| Incumbent deposit response to competitor closures | Branch-year | `code/v20260410/result-generation/branch_year_regression_20260409.qmd` | Implemented |
| Closing-bank deposit response to own closures | Bank-county-year | `code/v20260410/result-generation/bank_county_year_regression_20260409.qmd` | Implemented |
| Event-study pre-trend validation | Bank-county-year | `code/v20260410/result-generation/bank_county_year_sunab_20260409.qmd` | Implemented |
| Parallel lending regressions (deposits + HMDA + CRA) | Bank-county-year | `code/v20260410/result-generation/lending_regression_20260414.qmd` | Implemented |
| Lending panel construction | Bank-county-year | `code/v20260410/sample-construction/build_lending_panel_20260414.R` | Implemented |

## Main hypotheses and tests

### A. Deposit reallocation after competitor closures

1. **H1 (Pre-2012 incumbent gains):** Higher county exposure to competitor closures (`share_deps_closed`) increases incumbent branch deposit growth (`gr_branch`) before 2012.  
   **Test:** Baseline branch-year specification in `code/v20260410/result-generation/branch_year_regression_20260409.qmd` on `YEAR < 2012`.

2. **H2 (Post-2012 attenuation):** The same coefficient becomes near zero (or substantially smaller) in 2012-2024 and 2012-2019.  
   **Test:** Same script, post-2012 columns.

3. **H3 (Aggregation consistency):** The post-2012 attenuation is also visible in bank-county-year deposit growth (`dep_growth`).  
   **Test:** Deposit block in `code/v20260410/result-generation/lending_regression_20260414.qmd`.

### B. Own closures and remaining-branch deposits

4. **H4 (Modern retention at closing banks):** Conditional on high-dimensional fixed effects, own closure intensity (`closure_share`) does not reduce deposit growth at remaining branches in modern years.  
   **Test:** `code/v20260410/result-generation/bank_county_year_regression_20260409.qmd`, post-2012 samples.

5. **H5 (Historical contrast):** The own-closure relationship differs in the pre-2012 period.  
   **Test:** Same script, pre-2012 sample.

### C. Credit channel in parallel with deposits

6. **H6 (Pre-2012 credit spillover):** Competitor closures raise incumbent mortgage and small-business lending growth before 2012.  
   **Test:** `hmda_growth` and `cra_growth` regressions in `code/v20260410/result-generation/lending_regression_20260414.qmd`, `YEAR < 2012`.

7. **H7 (Post-2012 muted credit spillover):** Post-2012, incumbent credit spillovers are near zero, consistent with muted deposit reallocation.  
   **Test:** Same script, 2012-2024 and 2012-2019 windows.

8. **H8 (Measurement/scope caveat):** CRA coverage is concentrated among larger banks; effects should be interpreted with that sample composition in mind.  
   **Test/reporting:** Existing sample-summary outputs in `lending_regression_20260414.qmd`; add threshold-matched HMDA subsamples as robustness.

### D. Mechanisms: digital adoption and bank organizational type

9. **H9 (Digital mediation):** Deposit reallocation is weaker when closing-bank digital adoption is stronger and where mobile access is higher.  
   **Test:** Combined heterogeneity table in `code/v20260410/result-generation/branch_year_regression_20260409.qmd` (app/no-app/top4 decomposition and interactions with `perc_hh_wMobileSub`).

10. **H10 (Incumbent capacity heterogeneity):** Effects differ by incumbent bank type (top-4, large-not-top4, small), consistent with distribution-channel differences.  
    **Test:** Same heterogeneity specification in branch-year regressions.

11. **H11 (Optional mechanism extension):** If available in the branch panel, foot-traffic declines can be used to show stronger attenuation where in-person banking demand falls most.  
    **Test:** Interaction extension in branch-year specification for recent years.

### E. Identification credibility and robustness

12. **H12 (Event-study credibility):** Pre-treatment event-time coefficients are close to zero under Sun and Abraham designs.  
    **Test:** `code/v20260410/result-generation/bank_county_year_sunab_20260409.qmd` using existing Sun-Abraham panels.

13. **H13 (Outcome-window robustness):** Deposit results are robust to alternative growth windows (`gr`, `gr_m3_m1`, `gr_1_3`) available in the bank-county data architecture.  
    **Test:** Extend outcome block in `bank_county_year_regression_20260409.qmd`.

## Public-data extensions (not yet fully wired into current scripts)

14. **H14 (M&A IV robustness for credit):** Use M&A-driven closure exposure as an instrument for deposit disruption, then estimate incumbent lending responses.  
    **Potential public data:** FDIC/NIC merger histories plus existing closure panel links.

15. **H15 (Bank-level balance-sheet channel):** Test whether branch-consolidating banks cut overall legal-entity lending using public call report data (e.g., C&I and total loans).  
    **Potential public data:** Call Reports / FR Y-9C panel merges.

16. **H16 (Real-economy linkage as optional extension):** Connect closure exposure to county-level real outcomes if a credible industry-county design is specified.  
    **Potential public data:** County Business Patterns, BLS QCEW, or related county-year sources.

## Proposed section structure for a journal submission

1. **Introduction:** Research question, digital-era wedge vs. M&A disruption literature, and headline findings.  
2. **Institutional Background:** Why branch closures may have changed meaning after digital adoption.  
3. **Data and Sample Construction:** Branch/deposit, HMDA, CRA, app/digital controls, and sample restrictions.  
4. **Empirical Strategy:** Competitor-closure and own-closure specifications; fixed effects; treatment definitions; exclusion rules; event-study framework.  
5. **Main Results (Deposits):** Incumbent and closing-bank deposit results by period.  
6. **Main Results (Credit):** Parallel HMDA/CRA results by period.  
7. **Mechanisms and Heterogeneity:** Digital adoption, incumbent size, and optional traffic-based channels.  
8. **Robustness and Alternative Designs:** Sun-Abraham checks, alternative outcome windows, M&A-IV extension.  
9. **Conclusion:** Implications for branch closure policy and digital access gaps.

## Script crosswalk for execution

| Purpose | Script |
|---|---|
| Build branch-year incumbent sample | `code/v20260410/sample-construction/build_branch_panel_regression_sample_20260409.R` |
| Build bank-county-year own-closure panel | `code/v20260410/sample-construction/bank_county_year_sample_20260409.R` |
| Build Sun-Abraham event-study panels | `code/v20260410/sample-construction/bank_county_year_sunab_sample_20260409.R` |
| Build HMDA/CRA lending panel | `code/v20260410/sample-construction/build_lending_panel_20260414.R` |
| Run branch-year deposit models | `code/v20260410/result-generation/branch_year_regression_20260409.qmd` |
| Run bank-county-year own-closure deposit models | `code/v20260410/result-generation/bank_county_year_regression_20260409.qmd` |
| Run Sun-Abraham event-study models | `code/v20260410/result-generation/bank_county_year_sunab_20260409.qmd` |
| Run parallel deposit/HMDA/CRA models | `code/v20260410/result-generation/lending_regression_20260414.qmd` |

## Near-term execution order (using current repository assets)

1. Re-run sample construction scripts for branch, bank-county, Sun-Abraham, and lending panels to ensure synchronized vintages.  
2. Re-run four result-generation scripts and export regression tables/figures to LaTeX directories.  
3. Populate `latex/sections/*_current.tex` with results narrative organized around H1-H13.  
4. Add public-data extensions (H14-H16) as robustness sections once baseline tables are locked.
