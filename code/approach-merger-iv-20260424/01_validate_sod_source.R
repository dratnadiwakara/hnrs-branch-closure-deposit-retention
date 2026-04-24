# 01_validate_sod_source.R
# One-shot sanity check: confirm sod.duckdb aligns with legacy fdic_sod_2000_2025.rds
# before the rest of this approach depends on the duckdb view.

rm(list = ls())
source("code/approach-merger-iv-20260424/00_common.R")

con <- open_sod()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

duck <- setDT(dbGetQuery(con, "
  SELECT YEAR,
         COUNT(*)             AS n_rows,
         COUNT(DISTINCT UNINUMBR) AS n_branches,
         SUM(DEPSUMBR)        AS total_dep_k
  FROM sod
  WHERE YEAR BETWEEN 2000 AND 2025
  GROUP BY YEAR
  ORDER BY YEAR
"))

# Legacy source: C:/Users/dimut/OneDrive/data/fdic_sod_2000_2025.rds
# Built by: external (FDIC downloads, see r-utilities)
# Contents: branch-year SOD panel 2000-2025; columns include
#           UNINUMBR, YEAR, CERT, RSSDID, ZIPBR, STCNTYBR, DEPSUMBR, ASSET, BRSERTYP.
legacy <- setDT(readRDS("C:/Users/dimut/OneDrive/data/fdic_sod_2000_2025.rds"))
legacy_sum <- legacy[, .(
  n_rows       = .N,
  n_branches   = uniqueN(UNINUMBR),
  total_dep_k  = sum(DEPSUMBR, na.rm = TRUE)
), by = YEAR][order(YEAR)]

cmp <- merge(duck, legacy_sum, by = "YEAR", suffixes = c("_duck", "_leg"))
cmp[, d_rows_pct := round(100 * (n_rows_duck - n_rows_leg) / n_rows_leg, 3)]
cmp[, d_dep_pct  := round(100 * (total_dep_k_duck - total_dep_k_leg) / total_dep_k_leg, 3)]

need_cols <- c("UNINUMBR","YEAR","CERT","RSSDID","ZIPBR","STCNTYBR",
               "DEPSUMBR","ASSET","BRSERTYP","BRNUM")
duck_cols <- dbGetQuery(con, "DESCRIBE sod")$column_name
missing   <- setdiff(need_cols, duck_cols)

pass_rows <- all(abs(cmp$d_rows_pct) <= 0.1, na.rm = TRUE)
pass_cols <- length(missing) == 0
pass      <- pass_rows && pass_cols

md <- c(
  paste0("# SOD duckdb vs legacy rds — validation (", format(Sys.time(), "%Y-%m-%d"), ")"),
  "",
  paste0("**Overall:** ", ifelse(pass, "PASS", "FAIL")),
  paste0("- row-count check (±0.1% per year): ", ifelse(pass_rows, "PASS", "FAIL")),
  paste0("- required columns present: ", ifelse(pass_cols,
          "PASS", paste0("FAIL — missing: ", paste(missing, collapse = ", ")))),
  "",
  "## Per-year comparison",
  "",
  knitr::kable(cmp, format = "pipe")
)
writeLines(md, log_out("sod_validation_20260424"))

cat("=== SOD validation ===\n")
print(cmp)
cat("\nMissing columns:", paste(missing, collapse = ", "), "\n")
cat("\nPASS:", pass, "\n")

if (!pass) stop("SOD duckdb validation failed — see ", log_out("sod_validation_20260424"))
