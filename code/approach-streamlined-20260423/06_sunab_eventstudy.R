# 06_sunab_eventstudy.R — snapshot §13 (Sun & Abraham event study).
# LHS: log1p(deps_consistent) at branches that do not close in cohort year.
# Three era panels: Pre-2012, 2012-2019, 2020-2024. Ref period = -1.

rm(list = ls())
source("code/approach-streamlined-20260423/00_common.R")

# Source: data/sunab_panel_consistent_*.rds
# Built by:   code/v20260418/sample-construction/bank_county_year_sunab_sample_20260409.R
#             (writes via `saveRDS(sunab_panel_consistent, ...)` at line 192)
# Contents:   bank-county-year panel with consistent branch set per cohort —
#             branches that do NOT close in the cohort year. Cols: unit_id,
#             bank_id, YEAR, cohort (= first closure year or NA for controls),
#             deps_consistent (sum of deposits at consistent branches).
#             50% sample of never-treated controls included with cohort=10000.
pan <- setDT(load_latest("data", "^sunab_panel_consistent_.*\\.rds$"))

run_es <- function(d) feols(
  log1p(deps_consistent) ~ sunab(cohort, YEAR, ref.p = -1) | unit_id + YEAR,
  data = d, vcov = ~bank_id)

models <- list(
  "Pre-2012"  = run_es(pan[YEAR <  2012]),
  "2012-2019" = run_es(pan[YEAR %between% c(2012, 2019)]),
  "2020-2024" = run_es(pan[YEAR >= 2020])
)

# Extract event-time coefficients
tidy <- function(model, label) {
  ct <- as.data.table(coeftable(model), keep.rownames = "term")
  ct <- ct[grepl("sunab\\(|::", term)]
  ct[, event_time := as.integer(gsub(".*?(-?\\d+)\\D*$", "\\1", term))]
  ct[, `:=`(estimate = Estimate, se = `Std. Error`, period = label)]
  ct[, .(period, event_time, estimate, se)]
}
es <- rbindlist(Map(tidy, models, names(models)))
ref <- unique(es[, .(period)])[, `:=`(event_time = -1L, estimate = 0, se = 0)]
es  <- rbindlist(list(es, ref), fill = TRUE)[order(period, event_time)]
es[, period := factor(period, levels = names(models))]

# Figure
p <- ggplot(es, aes(x = event_time, y = estimate, group = period, color = period)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = 0.8) +
  geom_point(aes(shape = period), size = 2.2) +
  geom_errorbar(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se),
                width = 0.2, linewidth = 0.4) +
  scale_color_manual(values = c("Pre-2012" = "#1b9e77",
                                "2012-2019" = "#d95f02",
                                "2020-2024" = "#7570b3")) +
  labs(x = "Years relative to first closure", y = "Event-time effect",
       color = NULL, shape = NULL) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom",
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA))

ggsave(fig_out("T6_sunab_eventstudy"), p, width = 9, height = 6, bg = "transparent")

# Estimates table
wide <- dcast(es, event_time ~ period, value.var = "estimate")
wide_r <- wide[, lapply(.SD, function(x) if (is.numeric(x)) rnd(x) else as.character(x))]
writeLines(as.character(knitr::kable(wide_r, format = "pipe")), md_out("T6_sunab_estimates"))

cat("=== §13 Sun & Abraham ===\n"); print(wide)
cat("Wrote figure:", fig_out("T6_sunab_eventstudy"), "\n")
cat("Wrote table:",  md_out("T6_sunab_estimates"), "\n")
