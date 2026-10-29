# U.S. State Employment Indicators, 1976–2024

An interactive exploration of long-run employment conditions across the 50 U.S. states and the District of Columbia（DC）. The dashboard compares three annual labor-market indicators from 1976 through 2024 and allows users to filter the results by indicator, state, and year range.

## Research Questions

- How have employment-to-population ratios changed across U.S. states from 1976 through 2024?
- Which states had not returned to their 2019 employment-to-population ratio by 2024?
- How have labor-force participation and unemployment rates evolved across states during major economic recessions?


## Project structure

```text
Interactive-Data-Visualization/
├── README.md
├── Interactive-Data-Visualization.Rproj
├── code/
│   └── interactive_datapreparation.R
├── data/
│   └── staadata.xlsx
├── results/
│   └── employment_population_recovery_2019_2024.csv
├── ER_2000to2024.png
├── LFR_2000to2024.png
├── UR_2000to2024.png
└── interactive graph.html
```

## Data and scope

The workbook is the BLS Local Area Unemployment Statistics annual-average series, *States and selected areas: Employment status of the civilian noninstitutional population*. The source and methodology are documented on the [BLS LAUS statewide data page](https://www.bls.gov/lau/rdscnp16.htm). It contains state and selected-area observations; the script removes Los Angeles County and New York City and keeps the 50 states and District of Columbia. The analysis window is 1976–2024.

The plotted indicators are the employment-to-population ratio, labor-force participation rate, and unemployment rate.
1. **Employment-to-population ratio:** The percentage of the civilian noninstitutional population that is employed.
2. **Labor-force participation rate:** The percentage of the civilian noninstitutional population that is either employed or unemployed and actively participating in the labor force.
3. **Unemployment rate:** The percentage of the labor force that is unemployed.

## Key Findings of 2019–2024 Employment Recovery

The analysis identifies substantial differences in employment recovery across U.S. states between 2019 and 2024.

- **39 of 50 states** had an employment-to-population ratio below their 2019 level in 2024.
- **11 states** had returned to or exceeded their 2019 level.
- Maryland recorded the largest decline, at **3.4 percentage points**.
- New Hampshire and Iowa experienced declines of **3.3 and 3.2 percentage points**, respectively.
- Oklahoma recorded the largest increase, at **1.9 percentage points**.

The full state-level comparison is available in `results/employment_population_recovery_2019_2024.csv`.


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

The script displays the dashboard in an interactive session and writes the recovery CSV to `results/`. The accompanying Quarto blog post is maintained in the sibling `mywebsite` repository at:

```text
blog/posts/post7/index.qmd
```

The post sources the analysis script, embeds the Plotly dashboard, calculates summary statistics, and reads the generated recovery CSV.

To render the website locally, keep the `Interactive-Data-Visualization` and `mywebsite` repositories in sibling folders, then run the following command from the `mywebsite` project root:

```bash
quarto render
```

