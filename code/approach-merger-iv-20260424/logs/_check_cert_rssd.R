suppressPackageStartupMessages({library(data.table)})
raw <- setDT(readRDS("C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"))
cat("SOD branch rows:", nrow(raw), "\n")
raw <- raw[!is.na(RSSDID) & RSSDID != 0 & !is.na(CERT)]
chk <- raw[, .(n_rssd = uniqueN(RSSDID)), by = .(CERT, YEAR)]
cat("Total (CERT,YEAR) pairs:", nrow(chk), "\n")
cat("(CERT,YEAR) with >=2 distinct RSSDIDs:", sum(chk$n_rssd >= 2),
    " (", round(100 * mean(chk$n_rssd >= 2), 3), "%)\n", sep = "")
print(chk[, .N, by = n_rssd][order(n_rssd)])
chk2 <- raw[, .(n_cert = uniqueN(CERT)), by = .(RSSDID, YEAR)]
cat("\n(RSSDID,YEAR) pairs:", nrow(chk2), "\n")
cat("(RSSDID,YEAR) with >=2 distinct CERTs:", sum(chk2$n_cert >= 2),
    " (", round(100 * mean(chk2$n_cert >= 2), 3), "%)\n", sep = "")
print(chk2[, .N, by = n_cert][order(n_cert)])
