# Analysis of the PreRME data
# Jakob Weickmann - 22.11.2020

# load packages
packages <- c("outliers","ggplot2",
              "ggrepel", "ggtext",
              "lme4", "lmerTest", "emmeans",
              "fitdistrplus", "data.table")

# Install packages not yet installed
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages])
}

# Packages loading
invisible(lapply(packages, library, character.only = TRUE))

# -------------------------------------
# DATA IMPORT
# ------------------------------------

data_dir <- setwd("../data/")
filePaths <- list.files(data_dir, "\\.csv$", full.names = TRUE)
listData <- lapply(filePaths, fread)
dataRaw <- rbindlist(listData)

# set factorial variables to factors in the data.table
factors <- c("MODE")
setDT(dataRaw)[, (factors) := lapply(.SD, as.factor), .SDcols = factors]

# ------------------------------------
# Preprocessing
# ------------------------------------

# select only those data that have been filled in during the last iteration of the questionnaire
dateOfInterview <- '2020-11-18'
dataInterview <- dataRaw[dataRaw$MODE == 'interview' & dataRaw$STARTED >= dateOfInterview]


















