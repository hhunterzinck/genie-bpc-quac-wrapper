# Description: Wrapper for the genie-bpc-quac package for monitoring and notifications
# Author: Haley Hunter-Zinck
# Date: 2022-03-05

# pre-setup  ---------------------------

library(optparse)
library(glue)

valid_unit <- c("day", "hour")

waitifnot <- function(cond, msg) {
  if (!cond) {
    
    for (str in msg) {
      message(str)
    }
    message("Press control-C to exit and try again.")
    
    while(T) {}
  }
}

# user input ----------------------------

option_list <- list( 
  make_option(c("-v", "--value"), type = "integer", default = 1,
              help="Number of time units (default: 1)"),
  make_option(c("-u", "--unit"), type = "character", default = "day",
              help=glue("Time unit (default: {valid_unit[1]}; choices: {paste0(valid_unit, collapse = ' ')})"))
)
opt <- parse_args(OptionParser(option_list=option_list))

value <- opt$value
unit <- opt$unit

# check user input  ---------------------

waitifnot(is.element(opt$unit, valid_unit),
          msg = c(glue("Error: '{opt$unit}' is not in valid time unit choices (choices: {paste0(valid_unit, collapse = ' ')}). "), 
                  "Usage: Rscript genie-bpc-quac-wrapper.R -h"))

waitifnot(opt$value > 0,
          msg = c(glue("Error: time unit value ({opt$value}) must be positive."), 
                  "Usage: Rscript genie-bpc-quac-wrapper.R -h"))

# setup ----------------------------

tic = as.double(Sys.time())

library(dplyr)
library(yaml)
library(synapser)
source("fxns-wrapper.R")

status <- synLogin()

# parameters
config <- read_yaml("config-wrapper.yaml")

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
