# 02_decompositions.R — v2 sections 3-7.
# Post-2012 decompositions on the ORTHOGONAL size x app partition:
#   {top4, large_app, large_noapp, small_app, small_noapp}
# These five sum to share_deps_closed (identity asserted in S2).
#
# Sections:
#   T03 size x app  (five mutually exclusive buckets side-by-side)
#   T04 app / noapp (legacy aggregate — kept because coauthors reference it;
#                    noapp is NOT orthogonal to top4, see S2 construction)
#   T05 mobile x share_deps_closed  interaction
#   T06 combined   (top4 + large_app + large_noapp + small_app + small_noapp
#                    + share_deps_closed x perc_hh_wMobileSub)
#   T07 sophistication x share_deps_closed

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

# Source: data/constructed/zip_tech_sample_v2_YYYYMMDD.rds
# Built by:   sample-construction/S2_build_zip_tech_sample.R
# Contents:   includes share_deps_closed_{top4, large_app, large_noapp,
#             small_app, small_noapp}, share_deps_closed_{app, noapp},
#             perc_hh_wMobileSub, sophisticated.
ZTP <- resolve_latest("data/constructed", "^zip_tech_sample_v2_\\d{8}\\.rds$")
dt  <- setDT(load_exact(ZTP))

periods <- c("2012-19", "2020-22", "2023-24")
dsets   <- setNames(lapply(periods, period_filter, dt = dt), periods)

CTRL <- "log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1 | zip + county_yr"
run  <- function(fml, d) tryCatch(feols(fml, data = d, vcov = ~zip),
  error = function(e) { cat("  !", conditionMessage(e), "\n"); NULL })

# T03: five orthogonal buckets
m <- lapply(dsets, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed_top4 + share_deps_closed_large_app ",
  "+ share_deps_closed_large_noapp + share_deps_closed_small_app ",
  "+ share_deps_closed_small_noapp + ", CTRL)), d))
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets, "outcome", "share_deps_closed"),
                order = c("share_deps_closed_top4", "share_deps_closed_large_app",
                          "share_deps_closed_large_noapp", "share_deps_closed_small_app",
                          "share_deps_closed_small_noapp")),
         md_out("T03_size_app_orthogonal"))

# T04: legacy app/noapp aggregates
m <- lapply(dsets, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed_app + share_deps_closed_noapp + ", CTRL)), d))
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets, "outcome", "share_deps_closed"),
                order = c("share_deps_closed_app", "share_deps_closed_noapp")),
         md_out("T04_app_noapp_legacy"))

# T05: mobile interaction
m <- Filter(Negate(is.null), lapply(dsets, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed + share_deps_closed:perc_hh_wMobileSub + ",
  "perc_hh_wMobileSub + ", CTRL)), d)))
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets[names(m)], "outcome", "share_deps_closed"),
                order = c("share_deps_closed$", "share_deps_closed:perc", "perc_hh_wMobileSub")),
         md_out("T05_mobile_interaction"))

# T06: combined (orthogonal partition + mobile interaction)
m <- Filter(Negate(is.null), lapply(dsets, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed_top4 + share_deps_closed_large_app ",
  "+ share_deps_closed_large_noapp + share_deps_closed_small_app ",
  "+ share_deps_closed_small_noapp + share_deps_closed:perc_hh_wMobileSub ",
  "+ perc_hh_wMobileSub + ", CTRL)), d)))
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets[names(m)], "outcome", "share_deps_closed"),
                order = c("share_deps_closed_top4", "share_deps_closed_large_app",
                          "share_deps_closed_large_noapp", "share_deps_closed_small_app",
                          "share_deps_closed_small_noapp", "share_deps_closed:perc",
                          "perc_hh_wMobileSub")),
         md_out("T06_combined_orthogonal"))

# T07: sophistication interaction (five-period since sophistication exists pre-2012)
periods7 <- c("2000-07", "2008-11", "2012-19", "2020-22", "2023-24")
dsets7   <- setNames(lapply(periods7, period_filter, dt = dt), periods7)
m <- Filter(Negate(is.null), lapply(dsets7, function(d) run(as.formula(paste0(
  "outcome ~ share_deps_closed + share_deps_closed:sophisticated ",
  "+ sophisticated + ", CTRL)), d)))
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets7[names(m)], "outcome", "share_deps_closed"),
                order = c("share_deps_closed$", "share_deps_closed:soph", "sophisticated$")),
         md_out("T07_sophistication_interaction"))

register_outputs(c("T03_size_app_orthogonal.md", "T04_app_noapp_legacy.md",
                   "T05_mobile_interaction.md", "T06_combined_orthogonal.md",
                   "T07_sophistication_interaction.md"))
cat("Wrote T03..T07 to tables/\n")
