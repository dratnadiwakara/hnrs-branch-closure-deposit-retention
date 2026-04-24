# 04_nguyen_figure2.R
# Replicate Figure 2 of Nguyen (2019): event study of branch-closure probability
# in ZIPs exposed to a large merger, relative to unexposed ZIPs, around the
# merger year. Mirrors the specification in
#   r-utilities/Projects/deposits_closures_openings/Nguyen_instrument_v1.1.qmd
# (branch panel, closure dummy LHS, ZIPBR + YEAR FE, county-clustered SE).

rm(list = ls())
source("code/approach-merger-iv-20260424/00_common.R")

# Source: code/approach-merger-iv-20260424/data/branch_panel_20260424.rds
# Built by:   code/approach-merger-iv-20260424/02_build_branch_panel.R
# Contents:   branch-year panel (UNINUMBR, YEAR, CERT, RSSDID, ZIPBR, STCNTYBR,
#             DEPSUMBR, BRSERTYP, BRNUM, closed).
branch_panel <- readRDS(dat_out("branch_panel_20260424"))
setDT(branch_panel)

# Source: code/approach-merger-iv-20260424/data/nguyen_instrument_zips_20260424.rds
# Built by:   code/approach-merger-iv-20260424/03_build_merger_instrument.R
# Contents:   (ZIPBR, Event_Year, Merger_TransNum, Buyer_RSSD, Target_RSSD).
instrument_dt <- readRDS(dat_out("nguyen_instrument_zips_20260424"))
setDT(instrument_dt)

# First treatment year per ZIP.
zip_event_years <- instrument_dt[, .(Event_Year = min(Event_Year)), by = ZIPBR]

branch_panel[, ZIPBR := str_pad(as.character(ZIPBR), 5, "left", "0")]
zip_event_years[, ZIPBR := str_pad(as.character(ZIPBR), 5, "left", "0")]

treated_panel <- merge(branch_panel, zip_event_years, by = "ZIPBR", all.x = TRUE)
treated_panel[, rel_year := YEAR - Event_Year]
treated_panel[is.na(rel_year), rel_year := -1000L]

est_event <- feols(
  closed ~ i(rel_year, ref = -1, keep = -5:5) | ZIPBR + YEAR,
  cluster = ~STCNTYBR,
  data = treated_panel
)

print(est_event)

# Save coefficient table
coefs <- data.table(term = names(coef(est_event)),
                    est  = coef(est_event),
                    se   = se(est_event))
coefs[, rel := as.integer(sub(".*::(-?\\d+)$", "\\1", term))]
coefs <- coefs[!is.na(rel)][order(rel)]
coefs[, `:=`(ci_lo = est - 1.96 * se, ci_hi = est + 1.96 * se)]
writeLines(knitr::kable(coefs[, .(rel_year = rel, est = round(est, 5),
                                  se = round(se, 5),
                                  ci_lo = round(ci_lo, 5),
                                  ci_hi = round(ci_hi, 5))],
                        format = "pipe"),
           md_out("T_nguyen_figure2_coefs"))

# Plot
png(fig_out("F_nguyen_figure2"), width = 900, height = 600, bg = "transparent", res = 120)
iplot(est_event,
      main = "Impact of Merger Exposure on Branch Closings",
      xlab = "Years since merger",
      ylab = "Probability of Branch Closing",
      ci_level = 0.95, ci.width = 0, pt.join = TRUE, grid = TRUE,
      col = "#012169", pt.pch = 20, pt.cex = 1.5,
      xlim = c(-6, 6))
abline(v = 0, col = "gray50", lty = 2)
dev.off()

cat("Figure written to:", fig_out("F_nguyen_figure2"), "\n")
cat("Coef table:", md_out("T_nguyen_figure2_coefs"), "\n")
