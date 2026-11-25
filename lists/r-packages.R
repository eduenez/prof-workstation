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

## Debian/Ubuntu's R lists the root-owned /usr/local/lib/R/site-library first and
## adds the per-user library only when its directory exists, so a plain
## install.packages() fails with "lib is not writable".  Create and use it.
if (file.access(.libPaths()[1], 2) != 0) {
    user_lib <- Sys.getenv("R_LIBS_USER")
    dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
    .libPaths(c(user_lib, .libPaths()))
}

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
    ## install.packages() only warns when a package fails; report it as a failure.
    missing <- setdiff(to_install, rownames(installed.packages()))
    if (length(missing) > 0L) {
        message("Failed to install: ", paste(missing, collapse = ", "))
        quit(status = 1L)
    }
}
