suppressPackageStartupMessages({library(DBI); library(duckdb); library(data.table)})
cll <- setDT(readRDS("data/constructed/cll_county_year_20260423.rds"))
con <- dbConnect(duckdb(), "C:/empirical-data-construction/hmda/hmda.duckdb", read_only = TRUE)
duckdb_register(con, "cll_t", cll)
df <- dbGetQuery(con, "
  SELECT l.year AS yr,
         COUNT(*) AS n_all,
         SUM(CASE WHEN CAST(l.loan_amount AS DOUBLE) > c.cll_1unit THEN 1 ELSE 0 END) AS n_jumbo
  FROM lar_panel l
  JOIN cll_t c ON LEFT(l.census_tract,5) = c.county AND l.year = c.year
  WHERE l.action_taken = '1'
    AND l.loan_purpose = '1'
    AND LENGTH(l.census_tract) = 11
    AND l.year >= 2012
  GROUP BY l.year
  ORDER BY l.year")
df$pct_jumbo <- round(100 * df$n_jumbo / df$n_all, 2)
print(df, row.names = FALSE)
dbDisconnect(con, shutdown = TRUE)
