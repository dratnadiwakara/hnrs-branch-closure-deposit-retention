# 02_decompositions.R — snapshot §§3-7 (post-2012 decomposition & interactions).
# Periods: 2012-19, 2020-22, 2023-24.

rm(list = ls())
source("code/approach-streamlined-20260423/00_common.R")

# Source: data/zip_tech_sample_YYYYMMDD.rds
# Built by:   code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R
# Key vars:   share_deps_closed_{top4,large,small,app,noapp}, perc_hh_wMobileSub,
#             sophisticated. Mobile LOCF-extended through 2024/2025 per in-line
#             fix at lines 192-205 of the build script (2026-04-23).
dt <- setDT(load_latest("data", "^zip_tech_sample_\\d{8}\\.rds$"))

periods <- c("2012-19", "2020-22", "2023-24")
dsets   <- setNames(lapply(periods, period_filter, dt = dt), periods)

run <- function(fml, d) tryCatch(feols(fml, data = d, vcov = ~zip),
  error = function(e) { cat("  !", conditionMessage(e), "\n"); NULL })

CTRL <- "log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1 | zip + county_yr"

# §3 Size decomposition
m <- lapply(dsets, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed_top4 + share_deps_closed_large + share_deps_closed_small + ", CTRL)), d))
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets, "outcome", "share_deps_closed"),
                order = c("share_deps_closed_top4", "share_deps_closed_large", "share_deps_closed_small")),
         md_out("T3_size_decomposition"))

# §4 App decomposition
m <- lapply(dsets, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed_app + share_deps_closed_noapp + share_deps_closed_top4 + ", CTRL)), d))
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets, "outcome", "share_deps_closed"),
                order = c("share_deps_closed_app", "share_deps_closed_noapp", "share_deps_closed_top4")),
         md_out("T4_app_decomposition"))

# §5 Mobile interaction
m <- lapply(dsets, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed + share_deps_closed:perc_hh_wMobileSub + perc_hh_wMobileSub + ", CTRL)), d))
m <- Filter(Negate(is.null), m)
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets[names(m)], "outcome", "share_deps_closed"),
                order = c("share_deps_closed$", "share_deps_closed:perc", "perc_hh_wMobileSub")),
         md_out("T5_mobile_interaction"))

# §6 Combined decomposition
m <- lapply(dsets, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed_app + share_deps_closed_noapp + share_deps_closed_top4 ",
  "+ share_deps_closed:perc_hh_wMobileSub + perc_hh_wMobileSub + ", CTRL)), d))
m <- Filter(Negate(is.null), m)
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets[names(m)], "outcome", "share_deps_closed"),
                order = c("share_deps_closed_app", "share_deps_closed_noapp",
                          "share_deps_closed_top4", "share_deps_closed:perc",
                          "perc_hh_wMobileSub")),
         md_out("T6_combined_decomposition"))

# §7 Sophistication interaction (extended period: 2000-07, 2008-11, 2012-19, 2020-22, 2023-24)
periods7 <- c("2000-07", "2008-11", "2012-19", "2020-22", "2023-24")
dsets7   <- setNames(lapply(periods7, period_filter, dt = dt), periods7)
m <- Filter(Negate(is.null), lapply(dsets7, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed + share_deps_closed:sophisticated + sophisticated + ", CTRL)), d)))
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets7[names(m)], "outcome", "share_deps_closed"),
                order = c("share_deps_closed$", "share_deps_closed:soph", "sophisticated$")),
         md_out("T7_sophistication_interaction"))

cat("Wrote §§3-7 to tables/\n")
