library(tidyverse)
library(synapser)
library(doMC)

# local
# home_dir     <- "/home/aelamb/repos/Tumor-Deconvolution-Challenge/"
# workflow_dir <- "/home/aelamb/repos/fastq_mixing_workflow_cwl/"
# work_dir     <- "/home/aelamb/tmp/tumor_deconvolution/GSE83115/"

# ec2
home_dir     <- "/home/ubuntu/Tumor-Deconvolution-Challenge/"
workflow_dir <- "/home/ubuntu/fastq_mixing_workflow_cwl/"
work_dir     <- "/home/ubuntu/"

manifest_id  <- "syn12177468"
file_view_id <- "syn12179146"
download_id  <- "syn12177447"

cell_lines_to_sample <- c("CD4+_T_cells_BGI",
                          "CD8+_T_cells_BGI")


kallisto_index_synapse_id <- "syn16784383"
synapse_config_file       <- ".synapseConfig"
upload_id                 <- "syn16784234"
mixer_total_reads         <- 80000000L


replicates <- 10
CD8_fractions <- c(0.0, 0.0005, 0.001, 0.005, 0.01, 0.02, 0.05)

setwd(home_dir)

source("scripts/utils.R")
setwd(work_dir)
synLogin()
n_cores <- detectCores() - 1

kallisto_threads <- as.integer(n_cores)


# existng files

existing_files <- str_c('select id, name from file where parentId=="', upload_id, '"') %>% 
    synQuery %>%
    use_series("results") %>% 
    map(data.frame) %>% 
    bind_rows %>% 
    as_data_frame %>% 
    filter(str_detect(file.name, "CD4_CD8")) %>% 
    use_series(file.name)


# run specific parameters
yaml_df <-
    data_frame("CD8_fractions" = CD8_fractions) %>%
    mutate(CD4_fractions = 1 - CD8_fractions) %>% 
    merge(data_frame("rep" = 1:replicates)) %>% 
    mutate(prefix = str_c("CD4_CD8_", CD8_fractions, "_rep_", rep)) %>% 
    mutate(yaml = str_c(prefix, ".yaml")) %>% 
    inset("mixer_seed", value = sample(1:10000, nrow(.))) %>% 
    filter(!prefix %in% existing_files)

# fastq files
manifest_df <- manifest_id %>% 
    create_df_from_synapse_id %>% 
    filter(sample_name %in% cell_lines_to_sample) %>% 
    select(run, sample_name) %>% 
    set_colnames(c("SRR_id", "cell_type"))

file_view_df <- file_view_id %>% 
    str_c("select id, name, parentId from ", .) %>% 
    synTableQuery %>% 
    as.data.frame %>% 
    filter(parentId == download_id) %>% 
    filter(str_detect(name, "fastq.gz$")) %>% 
    mutate(SRR_id = str_sub(name, end = 10)) %>% 
    mutate(pair = str_match(name, "_([12]).fastq")[,2]) %>% 
    inner_join(manifest_df) %>% 
    select(id, pair, cell_type) %>% 
    arrange(pair, cell_type)

fastq_p1_synapse_ids <- file_view_df %>% 
    filter(pair == 1) %>% 
    use_series(id)

fastq_p2_synapse_ids <- file_view_df %>% 
    filter(pair == 2) %>% 
    use_series(id)

source(str_c(workflow_dir, "utils/write_yaml.R"))

# create yamls
create_synapse_workflow_yaml_by_row <- function(row){
    create_synapse_workflow_yaml(
        yaml_file = row$yaml,
        synapse_config_file = synapse_config_file,
        output_name = row$prefix,
        fastq_p1_synapse_ids = fastq_p1_synapse_ids,
        fastq_p2_synapse_ids = fastq_p2_synapse_ids,
        mixer_fractions = c(row$CD4_fractions, row$CD8_fractions),
        upload_id = upload_id,
        kallisto_index_synapse_id = kallisto_index_synapse_id,
        mixer_seed = row$mixer_seed,
        mixer_total_reads = mixer_total_reads,
        kallisto_threads = kallisto_threads,
        annotations = list(
            "seed" = row$mixer_seed,
            "run" = row$rep))
}

yaml_df %>% 
    split(1:nrow(.)) %>% 
    walk(create_synapse_workflow_yaml_by_row)

