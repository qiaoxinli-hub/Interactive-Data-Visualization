library(dplyr)
library(plotly)
library(readr)
library(readxl)
library(tidyr)

get_script_path <- function() {
  frame_paths <- vapply(
    sys.frames(),
    function(frame) {
      if (is.null(frame$ofile)) NA_character_ else as.character(frame$ofile)
    },
    character(1)
  )
  frame_paths <- frame_paths[!is.na(frame_paths)]

  if (length(frame_paths) > 0) {
    return(tail(frame_paths, 1))
  }

  script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(script_argument) > 0) {
    return(sub("^--file=", "", script_argument[[1]]))
  }

  NULL
}

script_path <- get_script_path()
project_dir <- if (is.null(script_path)) {
  getwd()
} else {
  normalizePath(
    file.path(dirname(script_path), ".."),
    winslash = "/",
    mustWork = FALSE
  )
}

data_path <- file.path(project_dir, "data", "staadata.xlsx")
results_dir <- file.path(project_dir, "results")

if (!file.exists(data_path)) {
  stop(
    paste0(
      "Could not find ", data_path,
      ". Place staadata.xlsx in the project's data/ folder and run this script from RStudio."
    )
  )
}

dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

column_names <- c(
  "FIPS",
  "Area",
  "Year",
  "CivilianPopulation",
  "LaborForce",
  "LaborForceRate",
  "Employment",
  "EmploymentPopulationRatio",
  "Unemployment",
  "UnemploymentRate"
)

raw_data <- readxl::read_excel(
  path = data_path,
  sheet = 1,
  skip = 8,
  col_names = column_names,
  col_types = rep("text", length(column_names)),
  .name_repair = "minimal"
)

state_lookup <- tibble::tibble(
  Area = c(state.name, "District of Columbia"),
  state_abbr = c(state.abb, "DC")
)

metro_areas_to_exclude <- c("Los Angeles County", "New York city")

state_data <- raw_data %>%
  mutate(
    Area = trimws(Area),
    Year = readr::parse_number(Year)
  ) %>%
  filter(
    Year >= 1976,
    Year <= 2024,
    !Area %in% metro_areas_to_exclude
  ) %>%
  transmute(
    Area,
    Year = as.integer(Year),
    CivilianPopulation = readr::parse_number(CivilianPopulation),
    LaborForce = readr::parse_number(LaborForce),
    LaborForceRate = readr::parse_number(LaborForceRate),
    Employment = readr::parse_number(Employment),
    EmploymentPopulationRatio = readr::parse_number(EmploymentPopulationRatio),
    Unemployment = readr::parse_number(Unemployment),
    UnemploymentRate = readr::parse_number(UnemploymentRate)
  )

unmatched_areas <- setdiff(unique(state_data$Area), state_lookup$Area)
if (length(unmatched_areas) > 0) {
  stop(
    paste(
      "Unexpected non-state areas in the workbook:",
      paste(unmatched_areas, collapse = ", ")
    )
  )
}

state_data <- state_data %>%
  left_join(state_lookup, by = "Area") %>%
  select(
    Area,
    state_abbr,
    Year,
    CivilianPopulation,
    LaborForce,
    LaborForceRate,
    Employment,
    EmploymentPopulationRatio,
    Unemployment,
    UnemploymentRate
  )

if (!all(state_lookup$Area %in% state_data$Area)) {
  stop("The workbook must contain all 50 states and the District of Columbia.")
}

if (!setequal(unique(state_data$Year), 1976:2024)) {
  stop("The workbook must contain annual observations for every year from 1976 through 2024.")
}

if (anyDuplicated(state_data[c("Area", "Year")])) {
  stop("The workbook has duplicate area-year observations in the requested period.")
}

indicator_columns <- c(
  "LaborForceRate",
  "EmploymentPopulationRatio",
  "UnemploymentRate"
)

if (any(!complete.cases(state_data[indicator_columns]))) {
  stop("One or more requested annual indicator values are missing in the workbook.")
}

expected_row_count <- length(state_lookup$Area) * length(1976:2024)
if (nrow(state_data) != expected_row_count) {
  stop(
    sprintf(
      "Expected %s state-year rows for 50 states plus DC; found %s.",
      expected_row_count,
      nrow(state_data)
    )
  )
}

recovery_summary <- state_data %>%
  filter(Area %in% state.name, Year %in% c(2019, 2024)) %>%
  select(Area, state_abbr, Year, EmploymentPopulationRatio) %>%
  pivot_wider(
    names_from = Year,
    values_from = EmploymentPopulationRatio,
    names_prefix = "ratio_"
  ) %>%
  mutate(
    change_percentage_points = ratio_2024 - ratio_2019,
    recovered_to_2019 = change_percentage_points >= 0
  ) %>%
  arrange(change_percentage_points)

states_not_recovered <- recovery_summary %>%
  filter(!recovered_to_2019)

readr::write_csv(
  recovery_summary,
  file.path(results_dir, "employment_population_recovery_2019_2024.csv")
)

message(
  sprintf(
    "%s of 50 states had an employment-to-population ratio below their 2019 level in 2024.",
    nrow(states_not_recovered)
  )
)
print(
  states_not_recovered %>%
    transmute(
      State = Area,
      Abbreviation = state_abbr,
      ratio_2019 = round(ratio_2019, 1),
      ratio_2024 = round(ratio_2024, 1),
      change_percentage_points = round(change_percentage_points, 1)
    ),
  n = Inf
)

metric_labels <- c(
  EmploymentPopulationRatio = "Employment-to-population ratio",
  LaborForceRate = "Labor force participation rate",
  UnemploymentRate = "Unemployment rate"
)

state_names <- sort(state_lookup$Area)
trace_levels <- unlist(
  lapply(
    unname(metric_labels),
    function(metric) paste(metric, state_names, sep = " | ")
  ),
  use.names = FALSE
)

plot_data <- state_data %>%
  select(
    Area,
    state_abbr,
    Year,
    all_of(names(metric_labels))
  ) %>%
  pivot_longer(
    cols = all_of(names(metric_labels)),
    names_to = "MetricCode",
    values_to = "Value"
  ) %>%
  mutate(
    Metric = unname(metric_labels[MetricCode]),
    Metric = factor(Metric, levels = unname(metric_labels)),
    Area = factor(Area, levels = state_names),
    Trace = factor(
      paste(as.character(Metric), Area, sep = " | "),
      levels = trace_levels
    ),
    hover_text = paste0(
      "<b>", Area, " (", state_abbr, ")</b><br>",
      "Year: ", Year, "<br>",
      as.character(Metric), ": ", formatC(Value, format = "f", digits = 1), "%"
    )
  )

shared_data <- crosstalk::SharedData$new(
  plot_data,
  key = ~paste(Area, Year, MetricCode, sep = "::"),
  group = "state-employment-indicators"
)

employment_chart <- plot_ly(
  data = shared_data,
  x = ~Year,
  y = ~Value,
  split = ~Trace,
  type = "scatter",
  mode = "lines",
  text = ~hover_text,
  hoverinfo = "text",
  line = list(width = 1.5),
  showlegend = FALSE
) %>%
  plotly::plotly_build()

state_colors <- stats::setNames(
  grDevices::hcl.colors(length(state_names), palette = "Dark 3"),
  state_names
)
trace_areas <- rep(state_names, times = length(metric_labels))

for (trace_index in seq_along(trace_levels)) {
  employment_chart <- style(
    employment_chart,
    line = list(
      color = state_colors[[trace_areas[[trace_index]]]],
      width = 1.5
    ),
    traces = trace_index
  )
}

employment_chart <- employment_chart %>%
  layout(
    title = list(
      text = "U.S. State Employment Indicators, 1976–2024",
      x = 0.02,
      xanchor = "left",
      font = list(size = 20, color = "#1e293b")
    ),
    xaxis = list(
      title = "Year",
      tickmode = "auto",
      nticks = 10,
      tickangle = 0,
      automargin = TRUE,
      gridcolor = "#e2e8f0",
      zeroline = FALSE
    ),
    yaxis = list(
      title = "Rate (%)",
      gridcolor = "#e2e8f0",
      zeroline = FALSE
    ),
    shapes = list(
      list(
        type = "rect", xref = "x", yref = "paper",
        x0 = 2000.5, x1 = 2001.5, y0 = 0, y1 = 1,
        fillcolor = "rgba(148, 163, 184, 0.18)",
        line = list(width = 0), layer = "below"
      ),
      list(
        type = "rect", xref = "x", yref = "paper",
        x0 = 2007.5, x1 = 2009.5, y0 = 0, y1 = 1,
        fillcolor = "rgba(148, 163, 184, 0.18)",
        line = list(width = 0), layer = "below"
      ),
      list(
        type = "rect", xref = "x", yref = "paper",
        x0 = 2019.5, x1 = 2020.5, y0 = 0, y1 = 1,
        fillcolor = "rgba(148, 163, 184, 0.18)",
        line = list(width = 0), layer = "below"
      )
    ),
    annotations = list(
      list(
        x = 2001, y = 1, xref = "x", yref = "paper", yshift = 8,
        text = "Dot-com recession", showarrow = FALSE,
        xanchor = "center", yanchor = "bottom",
        font = list(size = 10, color = "#64748b")
      ),
      list(
        x = 2008.5, y = 1, xref = "x", yref = "paper", yshift = 8,
        text = "Great Recession", showarrow = FALSE,
        xanchor = "center", yanchor = "bottom",
        font = list(size = 10, color = "#64748b")
      ),
      list(
        x = 2020, y = 1, xref = "x", yref = "paper", yshift = 8,
        text = "COVID-19 recession", showarrow = FALSE,
        xanchor = "center", yanchor = "bottom",
        font = list(size = 10, color = "#64748b")
      )
    ),
    margin = list(l = 70, r = 18, t = 86, b = 55),
    hovermode = "closest",
    paper_bgcolor = "#ffffff",
    plot_bgcolor = "#ffffff",
    font = list(family = "Arial, sans-serif", size = 12, color = "#334155")
  ) %>%
  config(displaylogo = FALSE, responsive = TRUE)

employment_chart <- htmlwidgets::onRender(
  employment_chart,
  "function(el, x) {
    var resizePlot = function() { Plotly.Plots.resize(el); };
    window.requestAnimationFrame(resizePlot);
    window.setTimeout(resizePlot, 150);
    window.addEventListener('resize', resizePlot);
  }"
)

control_panel <- htmltools::tagList(
  htmltools::tags$div(
    class = "filter-block",
    crosstalk::filter_select(
      id = "metric-filter",
      label = "Indicator",
      sharedData = shared_data,
      group = ~Metric,
      multiple = FALSE,
      allLevels = TRUE
    )
  ),
  htmltools::tags$div(
    class = "filter-block",
    crosstalk::filter_select(
      id = "state-filter",
      label = "States",
      sharedData = shared_data,
      group = ~Area,
      multiple = TRUE,
      allLevels = TRUE
    )
  ),
  htmltools::tags$div(
    class = "filter-block",
    crosstalk::filter_slider(
      id = "year-filter",
      label = "Year range",
      sharedData = shared_data,
      column = ~Year,
      min = 1976,
      max = 2024,
      step = 1,
      round = 0,
      ticks = FALSE,
      sep = "",
      width = "100%"
    )
  )
)

layout_css <- c(
  "#employment-dashboard { display: grid; grid-template-columns: minmax(0, 1fr) 230px; gap: 16px; width: 100vw; max-width: none; margin-left: calc(50% - 50vw); height: 100vh; min-height: 600px; padding: 10px 16px; box-sizing: border-box; background: #ffffff; }",
  "#chart-panel { min-width: 0; height: calc(100vh - 20px); min-height: 560px; }",
  "#chart-panel .html-widget { width: 100% !important; height: calc(100vh - 20px) !important; min-height: 560px; }",
  "#chart-panel .plotly { width: 100% !important; height: 100% !important; }",
  "#filter-panel { min-width: 0; height: calc(100vh - 20px); box-sizing: border-box; padding: 18px 14px; overflow-y: auto; border: 1px solid #e2e8f0; border-radius: 12px; background: #f8fafc; }",
  "#filter-panel .filter-block { margin-bottom: 22px; }",
  "#filter-panel label { display: block; margin-bottom: 8px; color: #334155; font-size: 13px; font-weight: 600; }",
  "#filter-panel .selectize-input { min-height: 36px; padding: 8px 10px; border: 1px solid #cbd5e1; border-radius: 7px; box-shadow: none; font-size: 13px; }",
  "#filter-panel .selectize-input.focus { border-color: #64748b; box-shadow: 0 0 0 2px rgba(100, 116, 139, 0.12); }",
  "#filter-panel .irs { margin-top: 15px; }",
  "@media (max-width: 640px) { #employment-dashboard { width: 100%; margin-left: 0; height: auto; min-height: 100vh; grid-template-columns: minmax(0, 1fr); } #chart-panel { height: 70vh; min-height: 500px; } #chart-panel .html-widget { height: 70vh !important; min-height: 500px; } #filter-panel { height: auto; } }"
)

default_indicator_script <- c(
  "(function () {",
  "  var attempts = 0;",
  "  function selectDefaultIndicator() {",
  "    var select = document.querySelector('#metric-filter select') || document.querySelector('select#metric-filter');",
  "    if (select && select.selectize) {",
  "      select.selectize.setValue('Employment-to-population ratio');",
  "      return;",
  "    }",
  "    attempts += 1;",
  "    if (attempts < 200) window.setTimeout(selectDefaultIndicator, 50);",
  "  }",
  "  selectDefaultIndicator();",
  "}());"
)

dashboard <- htmltools::browsable(
  htmltools::tagList(
    htmltools::tags$style(htmltools::HTML(paste(layout_css, collapse = "\n"))),
    htmltools::tags$div(
      id = "employment-dashboard",
      htmltools::tags$div(
        id = "chart-panel",
        employment_chart
      ),
      htmltools::tags$aside(
        id = "filter-panel",
        control_panel
      )
    ),
    htmltools::tags$script(
      htmltools::HTML(paste(default_indicator_script, collapse = "\n"))
    )
  )
)

if (interactive()) {
  print(dashboard)
} else {
  htmltools::html_print(dashboard)
}

message(
  "Saved the 2019–2024 state recovery table to results/employment_population_recovery_2019_2024.csv."
)


