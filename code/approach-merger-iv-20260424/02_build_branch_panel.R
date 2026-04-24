# 02_build_branch_panel.R
# Build branch-year panel from sod.duckdb with a `closed` flag.
# Replaces the legacy closure_opening_data_simple.rds.
# closed[t] = 1 if UNINUMBR present in year t but absent in t+1.

rm(list = ls())
source("code/approach-merger-iv-20260424/00_common.R")

con <- open_sod()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

# Source: C:/empirical-data-construction/sod/sod.duckdb (view `sod`)
# Contents: branch-year rows 1994-2025. Keep physical branches (BRSERTYP 11/12/21).
dt <- setDT(dbGetQuery(con, "
  SELECT UNINUMBR, YEAR, CERT, RSSDID, ZIPBR,
         LPAD(STCNTYBR, 5, '0') AS STCNTYBR,
         DEPSUMBR, BRSERTYP, BRNUM
  FROM sod
  WHERE YEAR BETWEEN 1999 AND 2025
    AND BRSERTYP IN (11, 12, 21)
"))

dt[, ZIPBR := str_pad(ZIPBR, 5, "left", "0")]
setorder(dt, UNINUMBR, YEAR)

# closed[t] = 1 if branch UNINUMBR observed in year t but not t+1.
yrs_by_uni <- dt[, .(yrs = list(sort(unique(YEAR)))), by = UNINUMBR]
max_yr     <- dt[, max(YEAR)]
closed_rows <- yrs_by_uni[, .(YEAR   = unlist(yrs),
                              closed = as.integer(!(unlist(yrs) + 1) %in% unlist(yrs))),
                          by = UNINUMBR]
closed_rows[YEAR == max_yr, closed := NA_integer_]

dt <- merge(dt, closed_rows, by = c("UNINUMBR", "YEAR"), all.x = TRUE)

saveRDS(dt, dat_out("branch_panel_20260424"))

close_by_yr <- dt[!is.na(closed), .(n_branches = .N, n_closed = sum(closed)), by = YEAR][order(YEAR)]
close_by_yr[, pct := round(100 * n_closed / n_branches, 3)]

md <- c(
  paste0("# Branch panel build (", format(Sys.time(), "%Y-%m-%d"), ")"),
  "",
  paste0("Rows written: ", nrow(dt),
         " | branches: ", uniqueN(dt$UNINUMBR),
         " | years: ", paste(range(dt$YEAR), collapse = "-")),
  paste0("File: `", dat_out("branch_panel_20260424"), "`"),
  "",
  "## Closures per year",
  "",
  knitr::kable(close_by_yr, format = "pipe")
)
writeLines(md, log_out("branch_panel_build_20260424"))

cat("=== branch panel ===\nrows:", nrow(dt), " branches:", uniqueN(dt$UNINUMBR), "\n\n")
print(close_by_yr)
