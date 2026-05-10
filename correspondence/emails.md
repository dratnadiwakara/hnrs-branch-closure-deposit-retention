

Philip Strahan
Tue, May 5, 1:33 PM (5 days ago)
to me, Rajesh, Charlotte

Not really sure.  We could construct the predicted zip-year level closure variables directly, with "the fraction of banks in zip with apps x mobile usage locally" as the key driver ("instrument"), plus the other controls in our current framework.  This would obviate the need to aggregate, and also we would not need to worry about bank-year effects.

Linear model is easier... I would always suggest at least starting with that.

Does that make sense?

Philip E. Strahan
Collins Professor of Finance
Seidner Department of Finance
Boston College, Carroll School of Management

---
Dimuthu Ratnadiwakara <dimuthu.ratnadiwakara@gmail.com>
Tue, May 5, 11:33 AM (5 days ago)
to Philip, Rajesh, Charlotte

Few follow up questions:
Should the 'first stage' be a logistic regression? but, if we want bank-year FE,  logistic  becomes hard to fit?
Do we keep bank-year fixed effects? 
When aggregating fitted bank-zip closure probabilities up to the zip-year, should we use deposit-weighted or branch-count weighted?

---
Philip Strahan
8:53 AM (1 hour ago)
to Rajesh, me, Charlotte

Here is an elaboration of Rajesh's idea:

Use (app adoption x local mobile phone) (+controls) to get the predicted probability of branch closure at the bank-locality level.  Aggregate this up across banks in a given locality to get the total predicted level of branch closures.  The difference between this market-level prediction and the actual closure rate would capture closures unrelated to technology.  We now have two variables representing branch closure.  The one driven by tech (the predicted value) should have low (or no) deposit spillover to other branches; the other component should have high spillovers.  It is basically a way to test our theory from cross-section; right now, all we can do is look at how spillovers vary over time.


Philip E. Strahan
---

Rajesh P Narayanan
Attachments
Mon, May 4, 12:33 PM (21 hours ago)
to me, Philip, Charlotte

Sorry! I missed seeing the last round of results.

Few observations/thoughts:

Time period: There seems to be something different about the 2020-2022 Covid period where the results change from 2012-2019. I think we should drop it, given that a lot of the deposit flows in that period were driven by stimulus.
Top 4: We have WFC in our top 4. Wells was subject to the penalty/asset cap restriction in 2018 which caused it to shrink its balance sheet (reduce deposits and close branches (see attached paper by Ruan-Vij, forthcoming RFS).  We should probably drop these post 2017 closures, because, as the paper shows, the depositors moved to nearby branches for other reasons. 
Branch openings: What if there are openings in t-1 (which affects our RHS closed bank share variable or in the year after (which affects our LHS incumbent share variable)? Probably not an issue in t-1, as we normalize by total deposits at t-1, but maybe in year t because we normalize the LHS also by deposits at t-1. May be a problem with large banks as they were the ones opening branches. 
Identification:  

Nguyen merger instrument: The first stage results show that the instrument is strong (based on F-stats) only in 2008-11 and 2023-2024, but weak during the 2012-2019 period when digital transformation is taking place. The Nguyen merger instrument is fundamentally bank-level variation mapped to ZIP codes.  There may not be enough bank level variation in that period to drive variation (we have 114 mergers overall).  So, why not introduce the variation in mobile adoption we have as an interaction in the instrument — Expose_event x Mobile adoption (at say t-2).
Alternatively, we could also do App launch (=1 if bank had launched app prior to t) X Mobile adoption at t-2.  Here we are predicting closures by digitally-capable banks (which introduced an app) in markets with high mobile adoption — the bank knows its depositors can migrate digitally.  But high mobile adoption markets may also be wealthier, younger, or more urban, which may independently affect deposit growth (violating the exclusion restriction). Hence a 2 or 3 year lagged mobile adoption rate
Or leave out bank level variation, and go with market level variation Bartik style:  Zip z’s mobile adoption rate in base year t0 (share) X National change in mobile adoption in year t excluding zip z’s contribution (shift).  That is, predict mobile adoption by a ZIP's pre-determined exposure to national technology trends and ask if it predicts the share of deposits at closed branches in that ZIP.   Higher predicted mobile adoption in a ZIP should attract more branch closures by digitally-capable banks because these banks know their depositors can migrate digitally, making it rational to close branches in high-mobile ZIPs rather than low-mobile ZIPs. Essentially, we are predicting more physical branch closures in high-mobile-adoption ZIPs, for technology infrastructure reasons rather than local deposit market weakness.

---

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