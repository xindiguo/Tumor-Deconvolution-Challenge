library(synapseClient)
library(tidyverse)
library(data.table)
library(magrittr)

repo_dir  <- "/home/aelamb/repos/Tumor-Deconvolution-Challenge/"
tmp_dir   <- "/home/aelamb/tmp/tumor_deconvolution/GSE65134/"
upload_id <- "syn15665000"

expr_id      <- "syn15667757"
norm_expr_id <- "syn15667827"


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
    "--output_file_string cibersort_results.tsv",
    sep = " "))

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-cibersort/Dockstore.cwl", 
    "--mixture_file expr.tsv", 
    "--sig_matrix_file /home/aelamb/repos/irwg/iatlas-tool-cibersort/sample.references.matrix.txt", 
    "--output_file_string cibersort_abs_results.tsv",
    "--absolute",
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
    executed = list("https://github.com/Sage-Bionetworks/Tumor-Deconvolution-Challenge/blob/master/analysis/GSE65134/fastq_mixing_CD4_CD8/deconvolve.R")
)


upload_file_to_synapse("cibersort_results.tsv", upload_id, activity_obj = activity_obj)
upload_file_to_synapse("cibersort_abs_results.tsv", upload_id, activity_obj = activity_obj)
upload_file_to_synapse("mcpcounter_results.tsv", upload_id, activity_obj = activity_obj)



norm_expr_df <- norm_expr_id %>% 
    create_df_from_synapse_id 

write_tsv(norm_expr_df, "norm_expr.tsv")

norm_expr_df %>% 
    df_to_matrix("Hugo") %>% 
    write.table("norm_expr_matrix.tsv", sep = "\t", quote = F)

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-cibersort/Dockstore.cwl", 
    "--mixture_file norm_expr.tsv", 
    "--sig_matrix_file /home/aelamb/repos/irwg/iatlas-tool-cibersort/sample.references.matrix.txt", 
    "--output_file_string cibersort_norm_results.tsv",
    sep = " "))

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-cibersort/Dockstore.cwl", 
    "--mixture_file expr.tsv", 
    "--sig_matrix_file /home/aelamb/repos/irwg/iatlas-tool-cibersort/sample.references.matrix.txt", 
    "--output_file_string cibersort_abs_norm_results.tsv",
    "--absolute",
    sep = " "))

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-mcpcounter/Dockstore.cwl",
    "--input_expression_file expr_matrix.tsv",
    "--output_file_string mcpcounter_norm_results.tsv",
    "--features_type HUGO_symbols",
    sep = " "))

activity_obj2 <- Activity(
    name = "create",
    description = "create and upload deconvolution results using cibersort and mcpcounter cwl files",
    used = list(norm_expr_id),
    executed = list("https://github.com/Sage-Bionetworks/Tumor-Deconvolution-Challenge/blob/master/analysis/GSE65134/fastq_mixing_CD4_CD8/deconvolve.R")
)

upload_file_to_synapse("cibersort_norm_results.tsv", upload_id, activity_obj = activity_obj2)
upload_file_to_synapse("cibersort_abs_norm_results.tsv", upload_id, activity_obj = activity_obj2)
upload_file_to_synapse("mcpcounter_norm_results.tsv", upload_id, activity_obj = activity_obj2)

