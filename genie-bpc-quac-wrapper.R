# Description: Wrapper for the genie-bpc-quac package for monitoring and notifications
# Author: Haley Hunter-Zinck
# Date: 2022-03-05

# pre-setup  ---------------------------

library(argparse)
library(glue)

choices_unit <- c("day", "hour")

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

parser <- ArgumentParser()
parser$add_argument("-v", "--value", dest = "value", type = "integer", default = 1,
                    help = "Number of time units (default: 1)", required = F)
parser$add_argument("-u", "--unit", dest = "unit", type = "character", choices = choices_unit, default = choices_unit[1],
                    help = glue("Time unit (default: {choices_unit[1]})"), required = F)
parser$add_argument("-t", "--testing", dest = "testing", action = "store_true", default = F,
                    help = "Run on synthetic test uploads", required = F)
parser$add_argument("-d", "--verbose", dest = "verbose", action = "store_true", default = F,
                    help = "Verbose reporting on script progress to the user", required = F)
args <- parser$parse_args()

value <- args$value
unit <- args$unit
testing <- args$testing
verbose <- args$verbose

# check user input  ---------------------

waitifnot(args$value > 0,
          msg = c(glue("Error: --value ({args$value}) must be positive."), 
                  "Usage: Rscript genie-bpc-quac-wrapper.R -h"))

# setup ----------------------------

tic = as.double(Sys.time())

library(dplyr)
library(yaml)
library(rjson)
library(synapser)
source("fxns-wrapper.R")

status <- synLogin()

# parameters
config <- read_yaml("config-wrapper.yaml")
reports <- config$report

# parameter overview
if (verbose) {
  print(glue("Parameters: "))
  print(glue("- value:\t{value}"))
  print(glue("- unit:\t{unit}"))
  print(glue("- testing:\t{testing}"))
  print(glue("- verbose:\t{verbose}"))
}

# main ----------------------------

if (verbose) {
  print(glue("{now(timeOnly = T)}: gathering cohort folders..."))
}

synid_folder_export <- ""
if (testing) {
  synid_folder_export <- config$synapse$testing$id
} else {
  synid_folder_export <- config$synapse$exports$id
}
synid_folders_cohort <- get_synapse_folder_children(synid_folder_export, include_types = list("folder"))

for (cohort in config$cohorts) {
  
  if (verbose) {
    print(glue("  {now(timeOnly = T)}: gathering site folders for cohort {cohort}..."))
  }
  
  synid_folders_site <- get_synapse_folder_children(as.character(synid_folders_cohort[cohort]), include_types = list("folder"))
  
  for (site in names(synid_folders_site)) {
    
    if (verbose) {
      print(glue("    {now(timeOnly = T)}: monitoring site {site}..."))
    }
    
    synid_files_site <- get_synapse_folder_children(as.character(synid_folders_site[site]), include_types = list("file"))
    idx <- grep(pattern = glue("{site} {cohort} Data"), x = names(synid_files_site))
    synid_file_data <- synid_files_site[idx]
    
    mod_flag <- any(sapply(as.character(synid_file_data), is_synapse_entity_modified, value = value, unit = unit))
    if (mod_flag) {
      
      if (verbose) {
        print(glue("      {now(timeOnly = T)}: detected {cohort}-{site} ({as.character(synid_file_data)}) modified..."))
      }
      
      for (report in reports) {
        if (verbose) {
          print(glue("      {now(timeOnly = T)}: running {cohort}-{site} ({as.character(synid_file_data)}) {report} report..."))
        }
        
        # run {report} quality checks
        cmd <- glue("Rscript genie-bpc-quac.R -c {cohort} -s {site} -r {report} -l error -u")
        system(cmd)
      }
      
      if (verbose) {
        print(glue("      {now(timeOnly = T)}: sending notification for {cohort}-{site} reports..."))
      }
      
      # send notification
      msg <- send_notification(cohort, site, reports = reports)
    } else {
      if (verbose) {
        print(glue("      {now(timeOnly = T)}:  {cohort}-{site} ({as.character(synid_file_data)}) not modified...skipping."))
      }
    }
  }
}

# close out ----------------------------

toc = as.double(Sys.time())
if (verbose) {
  print(glue("{now(timeOnly = T)}: runtime {round(toc - tic)} s"))
}
