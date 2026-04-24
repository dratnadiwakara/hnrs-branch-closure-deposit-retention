# 06_sunab_eventstudy.R — v2 section 14.
# Sun & Abraham event study split BY COHORT_ERA, not observation YEAR.
# Fixes v1 bug (06_sunab_eventstudy.R:22-26) where `pan[YEAR < 2012]` mixed
# pre-period observations from later cohorts into the "Pre-2012" panel.
#
# Each era panel keeps: (a) cohort rows tagged with that cohort_era, PLUS
# (b) never-treated controls (cohort == 10000). ref.p = -1.

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

# Source: data/constructed/sunab_panel_v2_YYYYMMDD.rds
# Built by:   sample-construction/S6_build_sunab_panel.R
# Contents:   bank-county-year panel with cohort + cohort_era columns.
SUN <- resolve_latest("data/constructed", "^sunab_panel_v2_\\d{8}\\.rds$")
pan <- setDT(load_exact(SUN))

run_es <- function(d) feols(
  log1p(deps_consistent) ~ sunab(cohort, YEAR, ref.p = -1) | unit_id + YEAR,
  data = d, vcov = ~bank_id)

eras <- c("Pre-2012", "2012-2019", "2020-2024")
models <- setNames(lapply(eras, function(era) {
  sub <- pan[cohort_era == era | cohort == 10000L]
  run_es(sub)
}), eras)

# Cohort-count table per era (for transparency)
cohort_counts <- pan[!is.na(cohort_era),
  .(n_cohorts = uniqueN(cohort),
    n_unit_years = .N,
    n_unit_ids = uniqueN(unit_id)),
  by = cohort_era][order(factor(cohort_era, levels = eras))]
writeLines(c("# S&A cohort-count by era",
             as.character(knitr::kable(cohort_counts, format = "pipe"))),
           md_out("T14_sunab_cohort_counts"))

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
es[, period := factor(period, levels = eras)]

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
       color = NULL, shape = NULL,
       subtitle = "Era split by COHORT (first-closure year), not observation YEAR") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom",
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA))

ggsave(fig_out("F14_sunab_by_cohort_era"), p, width = 9, height = 6, bg = "transparent")

wide <- dcast(es, event_time ~ period, value.var = "estimate")
wide_r <- wide[, lapply(.SD, function(x) if (is.numeric(x)) rnd(x) else as.character(x))]
writeLines(as.character(knitr::kable(wide_r, format = "pipe")),
           md_out("T14_sunab_estimates"))

register_outputs(c("T14_sunab_cohort_counts.md", "T14_sunab_estimates.md",
                   "F14_sunab_by_cohort_era.png"))

cat("=== §14 Sun-Abraham (cohort-era) ===\n")
print(cohort_counts); cat("\n"); print(wide)
