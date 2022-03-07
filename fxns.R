# Description: Functions for wrapper for quality assurance checklist.
# Author: Haley Hunter-Zinck
# Date: 2022-03-05

config <- read_yaml("config.yaml")

# functions ----------------------------

#' Extract personal access token from .synapseConfig
#' located at a custom path. 
#' 
#' @param path Path to .synapseConfig
#' @return personal acccess token
get_auth_token <- function(path) {
  
  lines <- scan(path, what = "character", sep = "\t", quiet = T)
  line <- grep(pattern = "^authtoken = ", x = lines, value = T)
  
  token <- strsplit(line, split = ' ')[[1]][3]
  return(token)
}

#' Override of synapser::synLogin() function to accept 
#' custom path to .synapseConfig file or personal authentication
#' token.  If no arguments are supplied, performs standard synLogin().
#' 
#' @param auth full path to .synapseConfig file or authentication token
#' @param silent verbosity control on login
#' @return TRUE for successful login; F otherwise
synLogin <- function(auth = NA, silent = T) {
  
  secret <- Sys.getenv("SCHEDULED_JOB_SECRETS")
  if (secret != "") {
    # Synapse token stored as secret in json string
    syn = synapser::synLogin(silent = T, authToken = fromJSON(secret)$SYNAPSE_AUTH_TOKEN)
  } else if (auth == "~/.synapseConfig" || is.na(auth)) {
    # default Synapse behavior
    syn <- synapser::synLogin(silent = silent)
  } else {
    
    # in case pat passed directly
    token <- auth
    
    # extract token from custom path to .synapseConfig
    if (grepl(x = auth, pattern = "\\.synapseConfig$")) {
      token = get_auth_token(auth)
      
      if (is.na(token)) {
        return(F)
      }
    }
    
    # login with token
    syn <- tryCatch({
      synapser::synLogin(authToken = token, silent = silent)
    }, error = function(cond) {
      return(F)
    })
  }
  
  # NULL returned indicates successful login
  if (is.null(syn)) {
    return(T)
  }
  return(F)
}

#' Determine if a Synapse entity has been modified within a certain time in the past.
#' 
#' @param synapse_id Synape ID of entity
#' @param value Integer specifying the number of time units
#' @param unit String specifying time unit
#' @return TRUE if entity has been modified in value unit from current time; otherwise, false
is_synapse_entity_modified <- function(synapse_id, value, unit = c("day", "hour")) {
  
  entity <- synGet(synapse_id, downloadFile = F)
  utc_mod <- as.POSIXct(entity$properties$modifiedOn, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  utc_now <- format.POSIXct(Sys.time(), tz = "UTC")
  
  delta <- as.double(difftime(utc_now, utc_mod, tz = "UTC", units = "hours"))
  
  if (unit == "day" && delta < value * 24) {
    return(T)
  }
  
  if (unit == "hour" && delta < value) {
    return(T)
  }
  
  return(F)
}

#' Get all child entities of a synapse folder.
#' 
#' @param synapse_id Synapse ID of the folder
#' @param include_types Types of child entities to return
#' @return Vector with values as Synapse IDs and names as entity names.
get_synapse_folder_children <- function(synapse_id, 
                                        include_types=list("folder", "file", "table", "link", "entityview", "dockerrepo")) {
  
  ent <- as.list(synGetChildren(synapse_id, includeTypes = include_types))
  
  children <- c()
  
  if (length(ent) > 0) {
    for (i in 1:length(ent)) {
      children[ent[[i]]$name] <- ent[[i]]$id
    }
  }
  
  return(children)
}

#' Determine if a Synapse user identifier is a valid user ID number (rather than
#' a user name string or non-existant ID number).
#' 
#' @param user Synapse user ID number of user name
#' @return TRUE is represents a valid user ID; FALSE otherwise
is_synapse_user_id <- function(user) {
  res <- tryCatch ({
    as.logical(length(synRestGET(glue("/user/{user}/bundle?mask=0x1"))))
  }, error = function(cond) {
    return(F)
  })
  
  return(res)
}

#' Get the user Synapse ID number from the user's Synapse user name.
#' 
#' @param user_name Synapse user name
#' @return Synapse user ID number
#' @example get_synapse_user_id("my_user_name")
get_synapse_user_id <- function(user_name) {
  
  if (is_synapse_user_id(user_name)) {
    return(user_name)
  }
  
  return(synGetUserProfile(user_name)$ownerId)
}

send_notification <- function(cohort, site) {
  user_names <- config$contacts[[site]]
  user_ids <- as.character(sapply(user_names, get_synapse_user_id))
  
  synid_folders_cohort <- get_synapse_folder_children(config$synapse$reports$id, include_types = list("folder"))
  synid_folder_cohort <- as.character(synid_folders_cohort[cohort])
  
  synid_files_cohort <- get_synapse_folder_children(synid_folder_cohort, include_types = list("file"))
  synid_file_report <- as.character(synid_files_cohort[tolower(glue("{cohort}_{site}_upload_error.csv"))])
  
  url <- glue("https://www.synapse.org/#!Synapse:{synid_file_report}")
  subject <- glue("New BPC {cohort} QA report available")
  body <- glue("A new QA report for your recent BPC {cohort} upload is available at the link below:\n\n{url}\n\nPlease correct the errors noted in the report and respond to this email with any questions.\n\nThank you,\nSage Bionetworks")
  
  res <- synSendMessage(userIds = list(user_ids), messageSubject = subject, messageBody = body)
  
  return(res)
}