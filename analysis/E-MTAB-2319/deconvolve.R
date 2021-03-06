library(plyr)
library(doMC)
library(tidyverse)
library(synapser)
library(data.table)
library(magrittr)
library(MCPcounter)

home_dir <- "/home/aelamb/repos/Tumor-Deconvolution-Challenge/"
tmp_dir  <- "/home/aelamb/tmp/tumor_deconvolution/E-MTAB-2319/"

count_id      <- "syn12031262"

upload_id  <- "syn11968722"


setwd(home_dir)
source("scripts/utils.R")
setwd(tmp_dir)
synLogin()
registerDoMC(cores = detectCores())


cpm_matrix <- count_id %>%
    create_df_from_synapse_id %>% 
    select(-ensembl_gene_id) %>% 
    filter(hgnc_symbol != "") %>% 
    group_by(hgnc_symbol) %>% 
    summarise_all(.funs = sum) %>% 
    ungroup %>% 
    df_to_matrix("hgnc_symbol") %>% 
    .[rowSums(.) > 0,] %>%  
    add(1) %>% 
    apply(2, calculate_cpm) 
    
write.table(cpm_matrix , "cpm_matrix.tsv", sep = "\t", quote = F)
    
cpm_matrix %>% 
    matrix_to_df("hgnc_symbol") %>% 
    write_tsv("cpm.tsv")

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-cibersort/Dockstore.cwl", 
    "--mixture_file cpm.tsv", 
    "--sig_matrix_file /home/aelamb/repos/irwg/iatlas-tool-cibersort/sample.references.matrix.txt", 
    "--QN",
    "--output_file_string cibersort_results.tsv",
    sep = " "))

system(str_c(
    "cwltool /home/aelamb/repos/irwg/iatlas-tool-mcpcounter/Dockstore.cwl",
    "--input_expression_file cpm_matrix.tsv",
    "--output_file_string mcpcounter_results.tsv",
    "--features_type HUGO_symbols",
    sep = " "))

activity_obj <- Activity(
    name = "create",
    description = "create and upload deconvolution results using cibersort and mcpcounter cwl files",
    used = list(count_id),
    executed = list("https://github.com/Sage-Bionetworks/Tumor-Deconvolution-Challenge/blob/master/analysis/E-MTAB-2319/deconvolve.R")
)

upload_file_to_synapse("cibersort_results.tsv", upload_id, activity_obj = activity_obj)
upload_file_to_synapse("mcpcounter_results.tsv", upload_id, activity_obj = activity_obj)



