# ============================================================
# 10_bank_county_year_regressions.R
#
# Replicates sections 1.1 and 1.2 from:
#   https://dratnadiwakara.github.io/HNRS-Deposit-Reallocation/results/
#   bank_county_year_sunab_and_panel_results_summary_20260306.html
#
# Section 1.1 — Panel regressions
#   Source: code/v20260418/result-generation/bank_county_year_regression_20260409.qmd
#   Unit:   bank-county-year
#   DV:     growth_on_total_t1  (1-yr deposit growth at remaining branches)
#   Treat:  closure_share       (own closing deposits / total bank-county deposits)
#   FE:     bank_id^YEAR + county^YEAR
#   SE:     clustered at bank_id
#   Periods: All | Pre-2012 | 2012-2024 | 2012-2019
#
# Section 1.2 — Sun & Abraham event study (consistent branch set)
#   Source: code/v20260418/result-generation/bank_county_year_sunab_20260409.qmd
#   Unit:   bank-county-year
#   DV:     log1p(deps_consistent)
#   Method: Sun & Abraham (2021), ref = -1
#   FE:     unit_id + YEAR
#   SE:     clustered at bank_id
#   Periods: Pre-2012 | 2012-2019 | 2020-2024 (superimposed)
# ============================================================

rm(list = ls())

library(data.table)
library(fixest)
library(ggplot2)

# ── Config ────────────────────────────────────────────────────────────────────

DATA_PATH   <- "data"
save_tables  <- FALSE
save_figures <- TRUE
out_dir      <- "code/approach-python-baseline/output/bank_county_year"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dat_suffix   <- format(Sys.time(), "%Y%m%d_%H%M%S")

primary_blue   <- "#012169"
primary_gold   <- "#f2a900"
accent_gray    <- "#525252"
period_colors  <- c("Pre 2012"  = "#1b9e77",
                    "2012-2019" = "#d95f02",
                    "2020-2024" = "#7570b3")

theme_custom <- function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", color = primary_blue),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      plot.background  = element_rect(fill = "transparent", color = NA),
      panel.background = element_rect(fill = "transparent", color = NA)
    )
}

# ── Helper: load most recent matching .rds ────────────────────────────────────

load_latest <- function(folder, pattern) {
  files <- list.files(folder, pattern = pattern, full.names = TRUE)
  if (!length(files)) stop("No file matching '", pattern, "' in ", folder)
  f <- files[which.max(file.mtime(files))]
  message("Loading: ", basename(f))
  readRDS(f)
}

# ── Helper: Sun & Abraham tidy ────────────────────────────────────────────────

sunab_tidy <- function(model, label) {
  ct <- as.data.table(coeftable(model), keep.rownames = "term")
  ct <- ct[grepl("sunab\\(|::", term)]
  if (nrow(ct) == 0L)
    stop("No sunab terms detected. Verify sunab() in formula.")
  ct[, event_time := as.integer(gsub(".*?(-?\\d+)\\D*$", "\\1", term))]
  ct[, `:=`(estimate = Estimate, se = `Std. Error`, period = label)]
  ct[, .(period, event_time, estimate, se)]
}

add_ref_point <- function(es_dt, ref = -1L) {
  refs <- unique(es_dt[, .(period)])
  refs[, `:=`(event_time = ref, estimate = 0, se = 0)]
  out <- rbindlist(list(es_dt, refs), fill = TRUE)
  setorder(out, period, event_time)
  out
}

# =============================================================================
# SECTION 1.1 — Panel regressions: closure_share → growth_on_total_t1
# =============================================================================

message("\n", strrep("=", 60))
message("SECTION 1.1 — Bank-County-Year Panel Regressions")
message(strrep("=", 60))

reg_main <- load_latest(DATA_PATH, "^reg_main_.*\\.rds$")
setDT(reg_main)
message("  shape: ", nrow(reg_main), " x ", ncol(reg_main))
message("  YEAR range: ", min(reg_main$YEAR), " – ", max(reg_main$YEAR))

# Derive large_but_not_top4_bank (mirrors QMD data prep)
reg_main[, large_but_not_top4_bank := as.integer(large_bank == 1L & top4_bank == 0L)]

setFixest_fml(
  ..fixef    = ~ bank_id^YEAR + county^YEAR,
  ..controls = ~ log1p(total_deps_bank_county_t1) +
                 log1p(n_remaining_branches) +
                 mkt_share_county_t1
)
setFixest_etable(
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.1),
  se.below    = TRUE
)

r11 <- list(
  "All"       = feols(growth_on_total_t1 ~ closure_share + ..controls | ..fixef,
                      data = reg_main,                         vcov = ~bank_id),
  "Pre 2012"  = feols(growth_on_total_t1 ~ closure_share + ..controls | ..fixef,
                      data = reg_main[YEAR < 2012],            vcov = ~bank_id),
  "2012-2024" = feols(growth_on_total_t1 ~ closure_share + ..controls | ..fixef,
                      data = reg_main[YEAR >= 2012],           vcov = ~bank_id),
  "2012-2019" = feols(growth_on_total_t1 ~ closure_share + ..controls | ..fixef,
                      data = reg_main[YEAR %in% 2012:2019],    vcov = ~bank_id)
)

etable(r11, title = "Table 1.1 — Closure intensity and deposit growth at remaining branches")

if (save_tables) {
  writeLines(
    etable(r11, tex = TRUE),
    con = file.path(out_dir, paste0("table11_bank_cty_baseline_", dat_suffix, ".tex"))
  )
}

# =============================================================================
# SECTION 1.2 — Sun & Abraham event study (consistent branch set)
# =============================================================================

message("\n", strrep("=", 60))
message("SECTION 1.2 — Sun & Abraham Event Study (Consistent Branch Set)")
message(strrep("=", 60))

sunab_panel_consistent <- load_latest(DATA_PATH, "^sunab_panel_consistent_.*\\.rds$")
setDT(sunab_panel_consistent)
message("  shape: ", nrow(sunab_panel_consistent), " x ", ncol(sunab_panel_consistent))

# Run Sun & Abraham by period (mirrors QMD)
m_pre   <- feols(log1p(deps_consistent) ~ sunab(cohort, YEAR, ref.p = -1) | unit_id + YEAR,
                 data = sunab_panel_consistent[YEAR < 2012],            vcov = ~bank_id)
m_12_19 <- feols(log1p(deps_consistent) ~ sunab(cohort, YEAR, ref.p = -1) | unit_id + YEAR,
                 data = sunab_panel_consistent[YEAR >= 2012 & YEAR <= 2019], vcov = ~bank_id)
m_20_24 <- feols(log1p(deps_consistent) ~ sunab(cohort, YEAR, ref.p = -1) | unit_id + YEAR,
                 data = sunab_panel_consistent[YEAR >= 2020],            vcov = ~bank_id)

# Extract and combine event-time coefficients
es_cons <- rbindlist(list(
  sunab_tidy(m_pre,   "Pre 2012"),
  sunab_tidy(m_12_19, "2012-2019"),
  sunab_tidy(m_20_24, "2020-2024")
), fill = TRUE)
es_cons <- add_ref_point(es_cons, ref = -1L)

message("\nEvent-time coefficients (consistent branch set):")
print(es_cons)

# ── Plot ──────────────────────────────────────────────────────────────────────

es_cons[, period := factor(period, levels = c("Pre 2012", "2012-2019", "2020-2024"))]

g_cons <- ggplot(es_cons, aes(x = event_time, y = estimate,
                               group = period, color = period)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_line(linewidth = 0.8) +
  geom_point(aes(shape = period), size = 2.2) +
  geom_errorbar(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se),
                width = 0.2, linewidth = 0.4) +
  scale_color_manual(values = c("Pre 2012"  = "#1b9e77",
                                "2012-2019" = "#d95f02",
                                "2020-2024" = "#7570b3")) +
  labs(
    title = "Sun & Abraham (Consistent Branch Set): Superimposed by Period",
    x     = "Years Relative to First Closure",
    y     = "Event-time effect",
    color = "Period", shape = "Period"
  ) +
  theme_custom()

print(g_cons)

if (save_figures) {
  out_fig <- file.path(out_dir, paste0("sunab_consistent_branch_set_", dat_suffix, ".png"))
  ggsave(out_fig, plot = g_cons, width = 9, height = 6, bg = "transparent")
  message("Figure saved: ", out_fig)
}
