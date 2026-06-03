## r-packages.R — Bootstrap R package installation.
## Run with: Rscript lists/r-packages.R

pkgs <- c(
    ## Tidyverse core
    "tidyverse",
    "ggplot2",
    "dplyr",
    "tidyr",
    "readr",
    "purrr",
    "tibble",
    "stringr",
    "forcats",
    "lubridate",

    ## Documents and reproducibility
    "rmarkdown",
    "knitr",
    "bookdown",
    "quarto",
    "tinytex",

    ## Statistics
    "lme4",
    "emmeans",
    "broom",
    "car",
    "MASS",
    "Matrix",
    "nlme",
    "survival",

    ## Visualization
    "ggthemes",
    "patchwork",
    "scales",
    "ggrepel",
    "viridis",
    "corrplot",

    ## Data import
    "haven",
    "readxl",
    "openxlsx",
    "jsonlite",
    "httr2",

    ## Development
    "devtools",
    "usethis",
    "testthat",
    "roxygen2",
    "pkgdown",
    "lintr",
    "styler",

    ## Utilities
    "here",
    "fs",
    "glue",
    "cli",
    "rlang"
)

already  <- rownames(installed.packages())
to_install <- setdiff(pkgs, already)

if (length(to_install) == 0L) {
    message("All R packages already installed.")
} else {
    message(sprintf("Installing %d package(s): %s",
                    length(to_install),
                    paste(to_install, collapse = ", ")))
    install.packages(
        to_install,
        repos  = "https://cloud.r-project.org",
        Ncpus  = parallel::detectCores()
    )
}
