library(data.table)
reg_files <- list.files("data", pattern="^reg_main_\\d{8}\\.rds$", full.names=TRUE)
dt <- setDT(readRDS(reg_files[which.max(file.mtime(reg_files))]))
cat(paste(names(dt), collapse="\n"))
