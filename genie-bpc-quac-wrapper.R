# Description: Wrapper for the genie-bpc-quac package for monitoring and notifications
# Author: Haley Hunter-Zinck
# Date: 2022-03-05

# setup ----------------------------

tic = as.double(Sys.time())

library(glue)
library(dplyr)
library(yaml)
library(synapser)
source("fxns-wrapper.R")

status <- synLogin()

# parameters
config <- read_yaml("config-wrapper.yaml")
unit <- "hour"
value <- 1

# main ----------------------------

synid_folder_export <- config$synapse$exports$id
synid_folders_cohort <- get_synapse_folder_children(synid_folder_export, include_types = list("folder"))

for (cohort in config$cohorts) {
  
  synid_folders_site <- get_synapse_folder_children(as.character(synid_folders_cohort[cohort]), include_types = list("folder"))
  
  for (site in names(synid_folders_site)) {
    synid_files_site <- get_synapse_folder_children(as.character(synid_folders_site[site]), include_types = list("file"))
    synid_file_data <- synid_files_site[glue("{site} {cohort} Data")]
    
    if (is_synapse_entity_modified(as.character(synid_file_data), value = value, unit = unit)) {
      
      # run quality checks
      cmd <- glue("Rscript genie-bpc-quac.R -c {cohort} -s {site} -r upload -l error -u")
      system(cmd)
      
      # send notification
      msg <- send_notification(cohort, site)
    }
  }
}

# close out ----------------------------

toc = as.double(Sys.time())
print(glue("Runtime: {round(toc - tic)} s"))
