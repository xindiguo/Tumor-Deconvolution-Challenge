library(plyr)
library(doMC)
library(tidyverse)
library(SRAdb)
library(DBI)
library(synapser)

# local
home_dir  <- "/home/aelamb/repos/Tumor-Deconvolution-Challenge/"
tmp_dir   <- "/home/aelamb/tmp/tumor_deconvolution/GSE75384/"
sra_db    <- "/home/aelamb/SRAmetadb.sqlite"

#ec2
# home_dir  <- "/home/ubuntu/Tumor-Deconvolution-Challenge/"
# tmp_dir   <- "/home/ubuntu/tmp/"
# sra_db    <- "/home/ubuntu/tmp/SRAmetadb.sqlite"

study_id   <- "SRP065216"
upload_id  <- "syn12333643"
cell_types <- c(
    "Bcell", 
    "CD4Tcell",
    "CD8Tcell",
    "Mono",
    "NKcell")

setwd(home_dir)
source("scripts/utils.R")
setwd(tmp_dir)
synLogin()
registerDoMC(cores = detectCores() - 1)

activity_obj <- Activity(
    name = "upload",
    description = "upload raw fastq files from SRA",
    executed = list("https://github.com/Sage-Bionetworks/Tumor-Deconvolution-Challenge/blob/master/analysis/GSE74246/transfer_fastq_files_to_synapse.R"),
    used = list("https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE74246")
)


if(!file.exists(sra_db)){
    sra_db <- getSRAdbFile()
}

con <- dbConnect(RSQLite::SQLite(), sra_db)


sra_df <- study_id %>% 
    listSRAfile(con) %>% 
    select(sample, run)

submission_id <- study_id %>% 
    str_c("select * from study where study_accession = '", ., "'") %>% 
    dbGetQuery(con, .) %>% 
    use_series(submission_accession)

manifest_df <- submission_id %>% 
    str_c(
        "select sample_alias, sample_accession, sample_attribute from sample ",
        "where submission_accession = '", 
        ., 
        "'") %>% 
    dbGetQuery(con, .) %>% 
    left_join(sra_df, by = c("sample_accession" = "sample")) %>% 
    set_colnames(c("sample", "SRS_id", "sample_attribute", "SRR_id")) %>% 
    select(sample, SRS_id, SRR_id, sample_attribute) %>% 
    separate(
        sample_attribute,
        sep = " \\|\\| ",
        into = c("cell_type", "cell_description", "patient"),
        extra = "drop") %>%
    mutate(cell_type = str_remove_all(cell_type, "source_name: ")) %>% 
    mutate(cell_description = str_remove_all(cell_description, "cell type: ")) %>% 
    mutate(patient = str_remove_all(patient, "donorid: ")) %>% 
    filter(cell_type %in% cell_types)  
    
transfer_to_synapse <- function(sra){
    getFASTQfile(sra, con)
    fastqs <- list.files(full.names = T) %>% 
        keep(str_detect(., "fastq"))
    walk(fastqs, upload_file_to_synapse, upload_id, activity_obj = activity_obj)
    walk(fastqs, file.remove)
}

walk(manifest_df$SRR_id, transfer_to_synapse)


write_tsv(manifest_df, "manifest.tsv")
upload_file_to_synapse("manifest.tsv", upload_id, activity_obj = activity_obj)



