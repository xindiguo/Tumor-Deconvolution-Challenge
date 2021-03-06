library(plyr)
library(doMC)
library(tidyverse)
library(synapser)
library(data.table)
library(magrittr)

home_dir <- "/home/aelamb/repos/Tumor-Deconvolution-Challenge/"
tmp_dir  <- "/home/aelamb/tmp/tumor_deconvolution/GSE76371/"

expr_id    <- "syn12036854"
upload_id  <- "syn12036855"


setwd(home_dir)
source("scripts/utils.R")
setwd(tmp_dir)
synLogin()
registerDoMC(cores = detectCores())

cpm_matrix <- expr_id %>%
    create_df_from_synapse_id() %>% 
    group_by(Hugo) %>% 
    summarise_all(sum) %>% 
    df_to_matrix("Hugo") %>% 
    calculate_cpm

write.table(cpm_matrix, "expr_matrix.tsv", sep = "\t", quote = F)

cpm_matrix %>% 
    matrix_to_df("Hugo") %>% 
    write_tsv("expr.tsv")

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-cibersort/Dockstore.cwl", 
    "--mixture_file expr.tsv", 
    "--sig_matrix_file /home/aelamb/repos/irwg/iatlas-tool-cibersort/sample.references.matrix.txt", 
    "--QN",
    "--output_file_string cibersort_results.tsv",
    sep = " "))

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-mcpcounter/Dockstore.cwl",
    "--input_expression_file expr_matrix.tsv",
    "--output_file_string mcpcounter_results.tsv",
    "--features_type HUGO_symbols",
    sep = " "))

activity_obj <- Activity(
    name = "create",
    description = "create and upload deconvolution results using cibersort and mcpcounter cwl files",
    used = list(expr_id),
    executed = list("https://github.com/Sage-Bionetworks/Tumor-Deconvolution-Challenge/blob/master/analysis/GSE76371/deconvolve.R")
)

upload_file_to_synapse("cibersort_results.tsv", upload_id, activity_obj = activity_obj)
upload_file_to_synapse("mcpcounter_results.tsv", upload_id, activity_obj = activity_obj)



