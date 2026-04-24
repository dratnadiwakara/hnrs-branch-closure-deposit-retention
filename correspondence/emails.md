

Philip Strahan
Wed, Apr 22, 8:17 AM (1 day ago)
to me, Rajesh, chaendler

Here are a few questions/issues:

1. I am not sure why the county-level aggregation for deposit growth of incumbents is so different from zip-level aggregation.  Should we drop this?
2. For CRA growth of incumbents: try including only CRA loans made by banks with at least 1 branch in the county.  The issue here is that there are a lot of CRA originations by banks in counties where they have no branches, and this is more like a credit card business than a branch-based SBL.
3.  For mortgages, perhaps we should look at second-lien mortgages only, which are more information sensitive than vanilla first mortgages, harder to securitize, and more likely to be affected by branch presence.
4.  I don't understand what is going on in Table 12, where the effects of mobile penetration flip sign in the last period.  Any ideas?   All I can think of is that it has something to do with the Pandemic.  Perhaps try 2023-2024 only to see if this looks different.)
5.  Are we trying an M&A based "IV" for these models?

Phil



Philip E. Strahan
Collins Professor of Finance
Seidner Department of Finance
Boston College, Carroll School of Management


---

Rajesh P Narayanan
Wed, Apr 22, 9:51 PM (11 hours ago)
to Philip, me, chaendler@mail.smu.edu

A few more to add to Phil’s:

Table 2 and 9: the last regression using 2020-2024 shows a significant coefficient on shares_deps_closed. the 2012-2019 period does not. I think this is related to Phil’s comment 4 below that it may be contaminated by Covid. Maybe leave out 2020-2022 and try 2023-2024?
Table 3: Do not have a good explanation for why the county level result are different from zip level ones. Yes, the county is a much larger geographic area (more zips), but other zips in the county gain?! - do not quite understand. I think it is better to stay with zip aggregation. Zip captures proximity to residence since it is a postal code, and people tend to bank close to their homes.  
Table 4: On the HMDA regressions, maybe try jumbo loans (not sold, relationship)?

---
Philip Strahan
Attachments
Fri, Apr 10, 6:43 AM (1 day ago)
to Dimuthu, Charlotte, Rajesh

Team,

Maybe a way to deepen our analysis is to look also at credit outcomes in parallel with deposit changes.  

The literature has claimed that after branches are closed (due to M&A), the bank closing the branch cuts lending... We are focusing on the implication of all closures (endogenously chosen) on deposits, arguing that in recent years banks retain most (or all) of their deposits when they close branches.  This implies that the bank closing the branch should not cut lending, and that there should be no credit spillover to incumbent banks.  In the early period, however, we should see incumbents increase local lending after closure.  As such, we could report parallel regressions to the ones we do for deposits using SBL and mortgage originations.

(We might have to do the M&A identification strategy for this analysis, as well as the deposit stuff.  There is a recent paper, attached, which does this in recent setting - it basically updates the Nguyen (2019) paper.  The recent paper focuses on real effects but does not look at how branch closings affects (or does not affect) the lending of incumbent banks, which is our strategy.)

Phil

Philip E. Strahan
Collins Professor of Finance
Seidner Department of Finance
Boston College, Carroll School of Management

---

DR Email on Apr 9, 2026

3. Branch-year regressions: combined heterogeneity specification

Consolidate heterogeneity tables (secs 3, 4, and 5 in the branch-level results) into a single specification. I am not sure which one of the following two we settled on

- Single closure measure: `gr_branch ~ share_deps_closed × top4 + share_deps_closed × large_but_not_top4_bank + share_deps_closed × perc_hh_wMobileSub + controls + FE`

- Closure measure decomposed by closing-bank size: Each of `share_deps_closed_top4`, `share_deps_closed_large_but_not_top4`, and `share_deps_closed_small` interacted with `top4`, `large_but_not_top4_bank`, and `perc_hh_wMobileSub` 
4. Bank-county-year regressions: combined heterogeneity specification

Merge the current sec 3.1 and 3.2 into a single specification:

`growth_on_total_t1 ~ closure_share × top4 + closure_share × large_but_not_top4_bank + closure_share × perc_hh_wMobileSub + controls + FE`



---

PS Response on Apr 9, 2026

Branch-year regressions: combined heterogeneity specification

Consolidate heterogeneity tables (secs 3, 4, and 5 in the branch-level results) into a single specification. I am not sure which one of the following two we settled on

- Single closure measure: `gr_branch ~ share_deps_closed × top4 + share_deps_closed × large_but_not_top4_bank + share_deps_closed × perc_hh_wMobileSub + controls + FE`

- Closure measure decomposed by closing-bank size: Each of `share_deps_closed_top4`, `share_deps_closed_large_but_not_top4`, and `share_deps_closed_small` interacted with `top4`, `large_but_not_top4_bank`, and `perc_hh_wMobileSub` 

I had in mind: gr_branch ~= share_closed_app, share_close_no_app, share_closed_top4, share_closed x Top4_bank, share_closed x Large_but_not_Top4, Share_closed x Perc_HH_MobileSub

4. Bank-county-year regressions: combined heterogeneity specification

Merge the current sec 3.1 and 3.2 into a single specification:

`growth_on_total_t1 ~ closure_share × top4 + closure_share × large_but_not_top4_bank + closure_share × perc_hh_wMobileSub + controls + FE`

I had in mind: growth_on_total_t1 = closure_share, closure_share × top4, closure_share × large_but_not_top4_bank, closure_share × perc_hh_wMobileSub + controls + FE