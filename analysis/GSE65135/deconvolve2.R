library(synapseClient)
library(tidyverse)
library(data.table)
library(magrittr)

repo_dir  <- "/home/aelamb/repos/Tumor-Deconvolution-Challenge/"
tmp_dir   <- "/home/aelamb/tmp/tumor_deconvolution/GSE65135/"
upload_id <- "syn15664999"

expr_id      <- "syn16784413"

source(str_c(repo_dir, "scripts/synapseClient_functions.R"))
source(str_c(repo_dir, "scripts/matrix_functions.R"))
setwd(tmp_dir)
synapseLogin()


expr_df <- expr_id %>% 
    create_df_from_synapse_id 

write_tsv(expr_df, "expr.tsv")

expr_df %>% 
    df_to_matrix("Hugo") %>% 
    write.table("expr_matrix.tsv", sep = "\t", quote = F)

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-cibersort/Dockstore.cwl", 
    "--mixture_file expr.tsv", 
    "--sig_matrix_file /home/aelamb/repos/irwg/iatlas-tool-cibersort/sample.references.matrix.txt", 
    "--output_file_string cibersort_results_from_cel.tsv",
    sep = " "))

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-mcpcounter/Dockstore.cwl",
    "--input_expression_file expr_matrix.tsv",
    "--output_file_string mcpcounter_results_from_cel.tsv",
    "--features_type HUGO_symbols",
    sep = " "))

activity_obj <- Activity(
    name = "create",
    description = "create and upload deconvolution results using cibersort and mcpcounter cwl files",
    used = list(expr_id),
    executed = list("https://github.com/Sage-Bionetworks/Tumor-Deconvolution-Challenge/blob/master/analysis/GSE65135/fastq_mixing_CD4_CD8/deconvolve.R")
)

upload_file_to_synapse("cibersort_results_from_cel.tsv", upload_id, activity_obj = activity_obj)
upload_file_to_synapse("mcpcounter_results_from_cel.tsv", upload_id, activity_obj = activity_obj)
