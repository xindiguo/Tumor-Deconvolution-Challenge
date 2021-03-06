library(plyr)
library(doMC)
library(tidyverse)
library(synapser)
library(data.table)
library(magrittr)
library(pheatmap)
library(preprocessCore)
library(ggfortify)

home_dir <- "/home/aelamb/repos/Tumor-Deconvolution-Challenge/"
tmp_dir  <- "/home/aelamb/tmp/tumor_deconvolution/E-MTAB-2319/"

count_id       <- "syn11958709"
annotation_id  <- "syn11968317"
count_id       <- "syn12031262"
genes_id       <- "syn11918430"
cs_results_id  <- "syn11968347"
mcp_results_id <- "syn11968348"

setwd(home_dir)
source("scripts/utils.R")
setwd(tmp_dir)
synLogin()
registerDoMC(cores = detectCores())

annotation_df <- create_df_from_synapse_id(annotation_id)
gene_df <-  create_df_from_synapse_id(genes_id)


mcp_genes <- gene_df %>% 
    filter(Method == "mcpcounter") %>%
    use_series("Hugo")

cs_genes <- gene_df %>% 
    filter(Method == "cibersort") %>%
    use_series("Hugo")


log_mat <-  count_id %>%
    create_df_from_synapse_id %>% 
    select(-ensembl_gene_id) %>% 
    filter(hgnc_symbol != "") %>% 
    group_by(hgnc_symbol) %>% 
    summarise_all(.funs = sum) %>% 
    ungroup %>% 
    df_to_matrix("hgnc_symbol") %>% 
    .[rowSums(.) > 0,] %>%  
    add(1) %>% 
    apply(2, calculate_cpm) %>% 
    log10 
    
zscore_mat <- log_mat %>% 
    quantile_normalize_matrix %>% 
    zscore_matrix

mcp_zscore_matrix <- zscore_mat %>% 
    .[rownames(.) %in% mcp_genes,]

cs_zscore_matrix <- zscore_mat %>% 
    .[rownames(.) %in% cs_genes,]

mcp_heatmap_row_df <- gene_df %>% 
    filter(Method == "mcpcounter") %>% 
    filter(Hugo %in% rownames(mcp_zscore_matrix)) %>% 
    select(-Method) %>% 
    arrange(cell_type) %>% 
    data.frame %>% 
    column_to_rownames("Hugo") %>% 
    set_names("Cell Type")

heatmap_col_df <- annotation_df %>% 
    data.frame %>% 
    column_to_rownames("sample")


png('E-MTAB-2319_mcpcounter_genes_heatmap.png', width = 4000, height = 4000)
pheatmap(
    mcp_zscore_matrix,
    main = "MCPCounter E-MTAB-2319",
    annotation_row = mcp_heatmap_row_df,
    annotation_col = heatmap_col_df,
    cluster_rows = F,
    scale = "none")
dev.off()

png('E-MTAB-2319_mcpcounter_genes_rows_clustered_heatmap.png', width = 4000, height = 4000)
pheatmap(
    mcp_zscore_matrix,
    main = "MCPCounter E-MTAB-2319",
    annotation_row = mcp_heatmap_row_df,
    annotation_col = heatmap_col_df,
    scale = "none")
dev.off()

png('E-MTAB-2319_cibersort_genes_heatmap.png', width = 4000, height = 4000)
pheatmap(
    cs_zscore_matrix,
    main = "Cibersort E-MTAB-2319",
    annotation_col = heatmap_col_df,
    scale = "none")
dev.off()

# -----------------------------------------------------------------------------


cs_result_df <- cs_results_id %>%
    create_df_from_synapse_id %>% 
    select(-c(`P-value`, `RMSE`, Correlation)) %>% 
    df_to_matrix("sample") %>% 
    .[,colSums(.) > 0] %>% 
    matrix_to_df("sample") %>% 
    set_colnames(str_replace_all(colnames(.), "\\.", " ")) %>% 
    gather("cibersort_cell_type", "predicted_fraction", `B cells naive`:Eosinophils) %>% 
    full_join(annotation_df, by = c("sample"))


png('E-MTAB-2319_cibersort_facet_scatterplot.png', height = 1000)
ggplot(cs_result_df, aes(x = cibersort_cell_type, y = predicted_fraction)) +
    geom_point() +
    facet_grid(cell_type ~ .) +
    ylab("Predicted fraction") +
    xlab("Cibersort cell type") +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90, size = 12)) +
    theme(axis.text.y = element_text(size = 12)) +
    theme(strip.text.y = element_text(size = 10, angle = 0)) +
    ggtitle("Cibersort E-MTAB-2319")
dev.off()


mcp_result_df <- mcp_results_id %>%
    download_from_synapse %>% 
    read.table %>% 
    t %>% 
    .[,colSums(.) > 0] %>% 
    matrix_to_df("sample") %>% 
    set_colnames(str_replace_all(colnames(.), "\\.", " ")) %>% 
    gather("mcpcounter_cell_type", "predicted_score", `T cells`:Fibroblasts) %>% 
    full_join(annotation_df, by = c("sample")) 

png('E-MTAB-2319_mcpcounter_facet_scatterplot.png', height = 1000)
ggplot(mcp_result_df, aes(x = mcpcounter_cell_type, y = predicted_score)) +
    geom_point() +
    facet_grid(cell_type ~ .) +
    ylab("Predicted score") +
    xlab("MCPCounter cell type") +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 90, size = 12)) +
    theme(axis.text.y = element_text(size = 12)) +
    theme(strip.text.y = element_text(size = 10, angle = 0)) +
    ggtitle("MCPCounter E-MTAB-2319")
dev.off()

# pca plots -------------------------------------------------------------------

pca_matrix <- log_mat %>% 
    t %>% 
    .[order(rownames(.)),]

png('E-MTAB-2319_PCA.png')
autoplot(
    prcomp(pca_matrix), 
    data = annotation_df, 
    shape = "cell_type", 
    size = 3,
    main = "E-MTAB-2319") +
    scale_shape_manual(values = 1:13) +
    theme_bw()
dev.off()
