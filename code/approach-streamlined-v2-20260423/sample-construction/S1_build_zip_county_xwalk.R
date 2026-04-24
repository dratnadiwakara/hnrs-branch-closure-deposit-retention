# S1_build_zip_county_xwalk.R
# Canonical ZIP -> county mapping used by every v2 sample builder.
# Rule: for each ZIP, pick the county with maximum TOT_RATIO.
# Ties: lexicographically smallest county FIPS (deterministic).
#
# Replaces the first-match .SD[1] mapping in:
#   code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R:163
#   code/approach-technology-sorting/04_build_bank_zip_year_sample_20260420.R:63
#
# Output: data/constructed/zip_county_xwalk_v2.rds
# Columns: zip (5-digit), primary_county (5-digit FIPS), max_tot_ratio, n_counties

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

HUD_XW <- "C:/Users/dimut/OneDrive/data/ZIP_COUNTY_122019.xlsx"

xw <- load_exact(HUD_XW)
setDT(xw)
xw[, `:=`(
  zip    = str_pad(as.character(ZIP),    5, "left", "0"),
  county = str_pad(as.character(COUNTY), 5, "left", "0"),
  TOT_RATIO = as.numeric(TOT_RATIO)
)]

# Max TOT_RATIO per zip. Tie-break by lex-smallest county FIPS.
setorder(xw, zip, -TOT_RATIO, county)
primary <- xw[, .SD[1L], by = zip,
              .SDcols = c("county", "TOT_RATIO")]
setnames(primary, c("county", "TOT_RATIO"), c("primary_county", "max_tot_ratio"))

n_cty <- xw[TOT_RATIO > 0, .(n_counties = uniqueN(county)), by = zip]
out   <- merge(primary, n_cty, by = "zip", all.x = TRUE)
out[is.na(n_counties), n_counties := 1L]

# Diagnostics.
cat("ZIPs mapped:", nrow(out), "\n")
cat("ZIPs with >1 county (TOT_RATIO > 0):",
    sum(out$n_counties > 1), " (",
    round(100 * mean(out$n_counties > 1), 2), "% )\n", sep = "")
cat("Median max_tot_ratio for multi-county ZIPs:",
    round(median(out[n_counties > 1, max_tot_ratio]), 4), "\n")

out_path <- "data/constructed/zip_county_xwalk_v2.rds"
saveRDS(out, out_path)
cat("Saved:", out_path, " | nrow =", nrow(out), "\n")
cat("sha256:", digest::digest(out_path, algo = "sha256", file = TRUE), "\n")
