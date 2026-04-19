## Do Deposits Follow Branches? Technology, Deposit Reallocation, and Local Credit

## Summary

We develop a model of deposit markets in which a branch provides two distinct types of value: a convenience value to depositors ( ϕ ) and a relationship value on the lending side ( ψ ). Digital technology substitutes more readily for ϕ than for ψ : a good app replicates the convenience of in-person banking, but imperfectly replaces the local monitoring, soft information, and borrower relationships that a branch generates on the lending side. This asymmetry means that branch closure affects the deposit and credit sides of the balance sheet differently; we characterize each consequence below, taking the closure decision as given.

- Deposit reallocation. When a high-technology bank closes a branch, the convenience loss to depositors is small (the app already does most of what the branch did), so the bank retains most of its deposits. Because few deposits are released, rivals absorb correspondingly little; the retained deposits fund lending elsewhere rather than flowing to rivals in the same market.
- Credit reallocation. Despite retaining deposits, the closing bank loses local lending capacity: the relationship value ψ that sustains local loan demand is only imperfectly replaced by technology. Competitors that absorb displaced deposits do extend local loans in turn, partially offsetting the credit loss. Whether aggregate local credit falls is an empirical question; the model establishes that high-technology closures retain deposits and release little to competitors, limiting the local lending response, while low-technology closures release more for competitors to intermediate locally.

## 1 Environment

The economy consists of markets j ∈ J and banks i ∈ I . Each market j contains a mass Dj of depositors. Each bank has a given technology level τ i ≥ 0 and a given branch network

bij ∈ { 0, 1 } across markets 1 , and offers a deposit rate r d ij and a lending rate r ℓ ij at the bankmarket level. Deposit rates are set locally, reflecting that competition intensity varies across markets with different branch structures and concentration.

## 2 Depositor Demand

We model depositor choice using the discrete-choice demand framework of Berry et al. (1995), applied to retail deposit markets by Egan et al. (2017) and Dick (2008). The key idea is that each depositor picks the bank that gives her the highest utility, where utility depends on observable bank attributes (rates, technology, branch access) and on an idiosyncratic preference shock that varies across depositors. Because we observe bank attributes but not individual preferences, the model delivers predictions about market shares rather than individual choices.

Each depositor in market j evaluates bank i according to:

<!-- formula-not-decoded -->

where r d ij is the deposit rate. The parameter α &gt; 0 captures the value depositors place on digital quality: a better app raises utility by ατ i . The parameter ϕ &gt; 0 captures the convenience value they place on having a branch: depositors lose ϕ in utility when the bank has no local branch ( bij = 0) and lose nothing when it does ( bij = 1). The term ξ ij is unobserved bank-market quality, and ε ij is an idiosyncratic logit taste shock (i.i.d. across depositors and banks).

A depositor chooses bank i whenever Uij exceeds the utility of every alternative. Averaging over all depositors, the market share of bank i in market j depends only on mean utility δ ij ≡ r d ij + ατ i -ϕ ( 1 -bij ) + ξ ij and takes the standard multinomial logit form: 2

<!-- formula-not-decoded -->

1 In the empirical work, τ i is measured using three indicators: whether the bank offers a mobile app, an index of app quality (based on app store ratings and functionality), and mobile banking availability at the county level. Together these capture both the extensive margin (does the bank have a digital channel?) and the intensive margin (how well does it substitute for in-person banking?). The county-level mobile availability measure allows τ i to vary across markets, reflecting that the effective substitutability of digital banking for branch access depends on local smartphone penetration and broadband infrastructure.

2 The denominator includes an outside option k = 0 with mean utility normalized to zero, representing depositors who bank outside the local market. This ensures shares do not mechanically sum to one and allows for an extensive margin of deposit participation.

## 3 Branch Closure and Deposit Reallocation

We analyze branch closure as a comparative static: bij moves from 1 to 0. Superscripts 1 and 0 denote values before and after closure. 3

## 3.1 Utility Loss and Post-Closure Shares

Closing the branch reduces mean depositor utility by ∆ ij .

<!-- formula-not-decoded -->

This is the net convenience loss: the branch provided convenience value ϕ to depositors, but the bank's digital platform already replaces ατ i of that convenience. A bank with a high-quality app (large τ i ) has a small ∆ ij and closing its branch barely affects depositors, while a low-technology bank has a large ∆ ij and loses many of them. When ατ i ≥ ϕ , the digital channel fully substitutes for the branch and ∆ ij ≤ 0, and closure has no deposit cost at all.

Because the demand model implies that only the utility depositors derive from bank i changes when it closes its branch (competitors' attractiveness is unaffected), the post-closure market share is

## 3.2 Retention Rate

Define the retention rate R ij as the fraction of pre-closure deposits that remain with bank i after closing its branch in market j .

<!-- formula-not-decoded -->

Two forces raise retention: a small ∆ ij (good app, so little utility is lost) and a large preclosure share s 1 ij (a large incumbent faces proportionally less competition for its depositors).

3 The model analyzes a single bank's closure taking competitors' decisions as fixed. When multiple banks close simultaneously in the same market, the predictions extend directly: the total deposit release is the sum of individual releases across all closing banks, and competitors absorb from this aggregate pool in proportion to their remaining market shares. In the empirical tests, we exploit this aggregation by using total deposits at all closed branches in a market as the right-hand-side variable, with deposits at individual competitor branches as the outcome. The single-closure comparative static therefore describes the market-level shock without loss of generality.

<!-- formula-not-decoded -->

Both factors favor the large, high-technology banks, consistent with the empirical results we have thus far.

Prediction 1 ( Technology and retention ). ∂ R ij / ∂τ i &gt; 0 : higher digital technology raises deposit retention after closure. The cross-partial ∂ 2 R ij / ( ∂τ i ∂ s 1 ij ) &gt; 0 shows that technology amplifies retention for large-share incumbents.

## 3.3 Competitor Absorption

Because the i.i.d. shock assumption implies IIA, competitors' relative shares are unchanged after bank i 's closure, so released deposits are distributed across rivals in proportion to their pre-closure shares. We treat this as a conservative benchmark. Note that the total volume released to competitors, Dj ( s 1 ij -s 0 ij ) , depends only on bank i 's own retention and is therefore decreasing in τ i under any substitution pattern.

Define the absorption share A kj as competitor k 's fraction of the total deposits released by the closure.

<!-- formula-not-decoded -->

The deposit gain for competitor k is then ∆ Dkj = Dj · A kj · ( s 1 ij -s 0 ij ) : the total pool released scaled by competitor k 's absorption share.

Prediction 2 ( Competitor absorption ). The absorption share A kj is increasing in competitor k's preclosure market share s 1 kj . Since s 1 kj is itself increasing in τ k and bkj, larger and more technologically advanced competitors absorb a greater share of the released deposits. The total pool ( s 1 ij -s 0 ij ) is decreasing in τ i, so even the largest competitor gains little when a high-technology bank closes.

Note. The proportional distribution under IIA is conservative: it spreads absorbed deposits across all rivals in proportion to market share, regardless of similarity to the closing bank. An extension that allows depositors to substitute more strongly within groups of similar banks would concentrate absorption further among large and app-capable rivals, amplifying rather than attenuating the effects in Prediction 2. In the baseline model, market share is the only channel through which competitor characteristics matter: τ k and bkj affect A kj only through s 1 kj . The two characteristics most relevant to our empirical tests are:

Size. Depositors who leave a large bank are more likely to move to another large bank: they are accustomed to a certain level of service, branch density, and product breadth.

App capability. Depositors who valued the digital platform of the closing bank are likely to prefer other app-capable banks.

In both cases, the extension would predict that the relevant characteristic amplifies absorption beyond pre-closure market share: large competitors absorb disproportionately more

than their share alone would imply, and app-capable competitors absorb disproportionately more after a technology-intensive closure beyond pre-closure market share s 1 kj , controlling for total deposits released Dj ( s 1 ij -s 0 ij ) .

## 4 Branch Closure and Credit Reallocation

## 4.1 Relationship Lending

A branch lets lenders collect soft information about borrowers and local conditions that apps imperfectly capture, so borrowers prefer a lender with local presence. We model this through the relationship value ψ &gt; 0.

Loan demand from bank i in market j is

<!-- formula-not-decoded -->

where ℓ j is baseline loan demand in market j , η &gt; 0 is the price sensitivity of borrowers, and ψ &gt; 0 is the relationship value of a branch in local lending. 4

Branch closure ( bij : 1 → 0) reduces local loan demand by ψ . Since τ i does not appear in (7), this reduction is independent of technology regardless of how the loan rate adjusts: any loan rate response to closure is common across banks of all technology levels and therefore drops out of cross-sectional comparisons between high- and low-technology closures.

Note. The specification ψ bij embeds the assumption that the branch is the sole source of relationship capacity: when bij = 0, relationship value disappears entirely. This reflects the finding in Narayanan et al. (2025) that closure decisions are driven by deposit franchise considerations rather than lending capacity.

## 4.2 Deposit-Credit Decoupling

The asymmetry between ϕ and ψ drives a wedge between what happens to deposits and what happens to local credit after a branch closes. On the liability side, high-technology banks retain deposits because ∆ ij = ϕ -ατ i is small: the app substitutes for the convenience a branch provides to depositors. On the asset side, local loan demand falls by ψ regardless

4 In the empirical work, we proxy the lending loss ψ using small business loan originations from CRA data and mortgage originations from HMDA, both measured at the bank-county level. CRA small business lending is the loan category most directly tied to branch-based soft information and repeated borrower relationships, making it the closest observable counterpart to ψ . HMDAlending, particularly in low-to-moderate income (LMI) areas where information asymmetries are larger and alternative credit sources are scarcer, provides a complementary measure. The model treats ψ as constant across banks and markets, but the empirical tests allow for heterogeneity.

of τ i : apps replicate local soft information less readily than they replicate the convenience of branch access. 5

Prediction 3 ( Deposit-credit decoupling ). After branch closure, retained deposits D 0 ij = Djs 0 ij are increasing in τ i, while the reduction in local lending ∆ Lij = -ψ &lt; 0 is independent of τ i .

<!-- formula-not-decoded -->

The numerator is independent of technology: the relationship value ψ that attracts local borrowers is unaffected by the bank's app quality, so the lending loss from closing a branch is the same regardless of τ i . The denominator rises with technology. High-technology banks retain deposits but withdraw local credit; the local lending-to-deposit ratio falls most sharply for the banks that retain the most deposits.

The decoupling creates a growing gap at the bank level: retained deposits D 0 ij rise with technology while post-closure local loans L 0 ij fall by ψ regardless of τ i . Define the net local funding surplus as ˜ Lij ≡ D 0 ij -L 0 ij : the excess of deposits over local lending that the bank must deploy elsewhere.

Corollary 1 ( Geographic reallocation ) . ∂ ( ∆ ˜ Lij ) / ∂τ i &gt; 0 : among banks that close branches, those with higher technology experience a larger increase in lending outside market j. Retained deposits do not sit idle; they fund lending elsewhere.

Note. We can test this directly using bank-level branch network data: for a bank that closes a branch in market j , we can examine whether CRA and HMDA lending increases in other markets where the bank retains branches, and whether this reallocation is larger for high-technology banks.

## 4.3 Competitor Lending

̸

While the closing bank loses relationship capacity in market j , its competitors do not. Each competitor k = i that remains active has bkj = 1: relationship capacity is fully intact. At the same time, competitor k receives a deposit inflow ∆ Dkj from the reallocation in Section 3.

We assume full intermediation: competitors extend local loans equal to their deposit gain. 6 Banks with intact branch networks and relationship capacity face no barrier to

5 Consistent with this, Nguyen (2019) finds that branch closures cause large and persistent declines in local small business lending.

6 Under partial intermediation, let λ ∈ [ 0, 1 ] denote the fraction of absorbed deposits deployed as local loans. The lending gain for competitor k becomes ∆ L ∗ kj = λ ∆ Dkj , and aggregate competitor lending gain becomes λ Dj ( s 1 ij -s 0 ij ) . Prediction 5 then reads ∆ L agg j = -ψ + λ Dj ( s 1 ij -s 0 ij ) , so full intermediation ( λ = 1) maximizes

deploying absorbed deposits into local credit. The lending gain for competitor k is therefore

<!-- formula-not-decoded -->

̸

where A kj = s 1 kj / ( 1 -s 1 ij ) is the absorption share from (6). Lending gains distribute across competitors in the same proportions as deposit gains. Since ∑ k = i A kj = 1, summing over all competitors:

̸

<!-- formula-not-decoded -->

Total competitor lending gain equals exactly the total displaced deposit pool.

Prediction 4 ( Competitor lending ). Under full intermediation, each competitor k's local lending gain is proportional to its absorption share A kj. Aggregate competitor lending gain equals the total displaced deposit pool Dj ( s 1 ij -s 0 ij ) , which is decreasing in τ i by Prediction 1. High-technology closures release fewer deposits to competitors, limiting the local lending response.

## 4.4 Aggregate Local Credit

Predictions 3 and 4 characterize what happens at the bank level. This subsection asks what happens to aggregate local credit in market j .

Prediction 5 ( Aggregate local credit ). Net aggregate local lending in market j changes by

<!-- formula-not-decoded -->

Local credit falls if and only if ψ &gt; Dj ( s 1 ij -s 0 ij ) : the relationship loss at the closing bank exceeds the deposit pool competitors can intermediate. Since Dj ( s 1 ij -s 0 ij ) is decreasing in τ i (Prediction 1), this condition is more likely to hold when the closing bank has high technology. The same technology that prevents deposit outflow also limits the deposit pool available to competitors, making the credit withdrawal harder to replace locally. Whether aggregate local credit falls is an empirical question.

To summarize, Prediction 1 establishes that high-technology banks retain deposits. Prediction 2 establishes that little flows to rivals. Prediction 3 establishes that deposits and credit decouple at the bank level: the lending loss is independent of technology while deposit retention rises with it, so the funding surplus grows with τ i and retained deposits are redeployed to non-local markets (Corollary 1). Prediction 4 establishes that competitors translate absorbed deposits into local loans, but the pool they receive is small when technology is

the competitor offset. Our results therefore represent an upper bound on the extent to which local competitors can replace the withdrawn credit; any λ &lt; 1 makes a net local credit contraction more likely and strengthens the empirical motivation for Prediction 5.

high. Prediction 5 shows that aggregate local credit is ambiguous in sign, with technology as the key moderator: high-technology closures are more likely to produce a net local credit contraction.

Remark 1 (Deposit HHI and credit market mismeasurement) . Standard measures of local deposit market concentration register the closing bank's share loss s 1 ij -s 0 ij = s 1 ij ( 1 -R ij ) as a signal of competitive change. Because R ij is increasing in τ i (Prediction 1), this share loss is smaller for high-technology closures and larger for low-technology closures. The credit loss ψ is independent of τ i . Deposit HHI therefore moves in the opposite direction to credit market harm: high-technology closures produce the smallest deposit concentration signal but the largest wedge between retained deposits and withdrawn credit (Prediction 3). Regulators using deposit-based HHI to assess competitive harm from branch closures will systematically understate the credit-market impact of high-technology closures and overstate that of low-technology ones. A more informative measure would weight market concentration by local credit activity rather than deposits-for example, using small business loan shares from CRA data or mortgage shares from HMDA in place of deposit shares. Such a credit-based HHI would move in the same direction as the actual harm to local borrowers, correcting the bias that deposit HHI introduces precisely when the competitive concern is greatest.

## References

- Berry, S. T., Levinsohn, J., and Pakes, A. (1995). Automobile prices in market equilibrium. Econometrica , 63(4):841-890.
- Dick, A. A. (2008). Demand estimation and consumer welfare in the banking industry. Journal of Banking and Finance , 32(8):1661-1676.
- Egan, M., Hortacsu, A., and Matvos, G. (2017). Deposit competition and financial fragility: Evidence from the US banking sector. American Economic Review , 107(1):169-216.
- Narayanan, R. P., Ratnadiwakara, D., and Strahan, P. E. (2025). The decline of bank branching. Working Paper 33773, National Bureau of Economic Research.
- Nguyen, H.-L. Q. (2019). Are credit markets still local? Evidence from bank branch closings. American Economic Journal: Applied Economics , 11(1):1-32.