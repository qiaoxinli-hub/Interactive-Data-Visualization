# U.S. State Employment Indicators, 1976–2024

## Research question

How did employment-to-population ratios change across U.S. states from 1976 through 2024, and which states remained below their 2019 level in 2024? The dashboard also compares labor-force participation and unemployment rates.

## Project structure

```text
Interactive-Data-Visualization/
├── README.md
├── code/interactive_datapreparation.R
├── data/staadata.xlsx
└── results/employment_population_recovery_2019_2024.csv
```

## Data and scope

The workbook is the BLS Local Area Unemployment Statistics annual-average series, *States and selected areas: Employment status of the civilian noninstitutional population*. The source and methodology are documented on the [BLS LAUS statewide data page](https://www.bls.gov/lau/rdscnp16.htm). It contains state and selected-area observations; the script removes Los Angeles County and New York City and keeps the 50 states and District of Columbia. The analysis window is 1976–2024.

The plotted indicators are the employment-to-population ratio, labor-force participation rate, and unemployment rate. The script validates the jurisdiction/year coverage and writes the state-level 2019-to-2024 employment-to-population comparison to `results/employment_population_recovery_2019_2024.csv`.

## Interactive dashboard

The Plotly/Crosstalk view includes a multi-select state filter, a metric selector, and a year-range slider. Hovering over a line reveals the jurisdiction, year, and rate. Gray bands mark the calendar-year observations associated with the 2001 recession, the 2007–2009 Great Recession, and the 2020 COVID-19 recession. These are contextual bands based on annual data, not estimates of causal effects.

## Replication

Use R 4.1 or later. Install packages once:

```r
install.packages(c(
  "dplyr", "plotly", "readr", "readxl", "tidyr",
  "crosstalk", "htmltools", "htmlwidgets"
))
```

Open this project in RStudio, set the working directory to its root, and run:

```r
source("code/interactive_datapreparation.R")
```

The script displays the dashboard in an interactive session and writes the recovery CSV to `results/`. In a non-interactive R session, it opens a temporary browser preview; it does not save a dashboard HTML file into the repository.

The Quarto blog post is in the sibling `mywebsite` repository at `blog/posts/post7/index.qmd`. It sources this analysis script, embeds the Plotly dashboard, calculates the displayed summaries, and reads the generated recovery CSV. To render the site locally, keep both repositories as siblings and run `quarto render` from the `mywebsite` project root.