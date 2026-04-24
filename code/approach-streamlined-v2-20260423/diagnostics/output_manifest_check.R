# output_manifest_check.R
# Enforces filename discipline. Fails if tables/ or figures/ contain files
# NOT registered by analysis scripts 01..06 via register_outputs().
#
# Addresses audit comment 5 (v1 script 04_cra_county.R wrote T3_cra_county.md
# but tables/ held T3_panelA_incounty_primary.md etc. — stale-output drift).

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

registered <- if (file.exists(OUTPUT_REGISTRY_PATH))
  readLines(OUTPUT_REGISTRY_PATH) else character()
# Figures are registered via fig_out(nm) -> "<nm>.png"; assume all F*.png
# outputs are registered if any.
tables  <- list.files(tables_path,  pattern = "\\.md$")
figures <- list.files(figures_path, pattern = "\\.(png|pdf)$")

orphans_tbl <- setdiff(tables, registered)
orphans_fig <- setdiff(figures, registered)

cat("[check] registered:", length(registered),
    " | tables/:", length(tables),
    " | figures/:", length(figures), "\n")

if (length(orphans_tbl) || length(orphans_fig)) {
  cat("\nOrphan files (present but not registered):\n")
  for (f in orphans_tbl) cat("  tables/",  f, "\n")
  for (f in orphans_fig) cat("  figures/", f, "\n")
  stop("output_manifest_check: orphan outputs detected")
}
missing_tbl <- setdiff(registered[grepl("\\.md$", registered)], tables)
missing_fig <- setdiff(registered[grepl("\\.(png|pdf)$", registered)], figures)
if (length(missing_tbl) || length(missing_fig)) {
  cat("\nRegistered but missing on disk:\n")
  for (f in missing_tbl) cat("  tables/",  f, "\n")
  for (f in missing_fig) cat("  figures/", f, "\n")
  stop("output_manifest_check: registered outputs missing")
}
cat("[check] PASS — all outputs registered and present.\n")
