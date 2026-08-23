#' Read a plate reader export into a `gr_plate` object
#'
#' Parses raw growth curve data into the tidy `gr_plate` structure that every
#' other gRate function operates on. Two generic layouts are supported:
#'
#' * **wide** — one row per timepoint: a time column plus one column per well
#'   (`A1`, `A01`, `B12`, ...). This is the layout most plate reader software
#'   exports to CSV.
#' * **long** — one row per well and timepoint, with columns for well, time,
#'   and measurement. Column names are matched case-insensitively (well:
#'   `well`; time: `time`, `hours`, `hour`, `t`; value: `value`, `od`, `od600`,
#'   `absorbance`, `measurement`, `abs`).
#'
#' With `format = "auto"` (the default) the layout is detected from the column
#' names. Instrument-specific parsers for Tecan and BioTek exports are planned;
#' `format = "tecan"` and `format = "biotek"` currently stop with an
#' informative error because those parsers are only written against real
#' example exports, not guessed formats.
#'
#' @param x Path to a CSV/TSV/Excel file, or a data frame that is already in
#'   wide or long layout.
#' @param format One of `"auto"`, `"wide"`, `"long"`. (`"tecan"` and
#'   `"biotek"` are reserved for upcoming instrument parsers.)
#' @param time_col For wide data: name of the time column. Defaults to a column
#'   named like time (`time`, `hours`, `hour`, `t`), or the first column.
#' @param plate_id Optional plate identifier stored in `$meta`. Defaults to the
#'   file name (without extension) when `x` is a path.
#' @param ... Additional arguments passed to [utils::read.csv()] or
#'   [readxl::read_excel()] when `x` is a path.
#'
#' @return A [gr_plate][new_gr_plate] object.
#' @export
#' @seealso [gr_layout()] to attach well metadata, [gr_qc()] to flag wells.
#' @examples
#' # long format
#' path <- system.file("extdata", "growth_long.csv", package = "gRate")
#' gr_read(path)
#'
#' # wide format
#' path <- system.file("extdata", "growth_wide.csv", package = "gRate")
#' gr_read(path, format = "wide")
gr_read <- function(x,
                    format = c("auto", "wide", "long", "tecan", "biotek"),
                    time_col = NULL,
                    plate_id = NULL,
                    ...) {
  format <- match.arg(format)

  if (format %in% c("tecan", "biotek")) {
    stop(
      "The '", format, "' parser is not implemented yet: instrument parsers ",
      "are only written against real example exports. Please read your data ",
      "as a generic wide or long table for now (format = \"wide\" or ",
      "\"long\"), and consider contributing an example export file.",
      call. = FALSE
    )
  }

  if (is.character(x) && length(x) == 1) {
    if (is.null(plate_id)) {
      plate_id <- tools::file_path_sans_ext(basename(x))
    }
    df <- gr_read_table(x, ...)
  } else if (is.data.frame(x)) {
    df <- as.data.frame(x, check.names = FALSE)
  } else {
    stop("`x` must be a file path or a data frame.", call. = FALSE)
  }

  if (format == "auto") {
    format <- gr_detect_format(df)
  }

  data <- switch(
    format,
    wide = gr_parse_wide(df, time_col = time_col),
    long = gr_parse_long(df)
  )

  new_gr_plate(
    data,
    meta = list(
      instrument = "generic",
      plate_id = plate_id,
      source_format = format
    )
  )
}

# Internal: guess wide vs long from the column names.
gr_detect_format <- function(df) {
  has_well_col <- !is.null(gr_match_col(df, "well"))
  n_well_named <- sum(grepl(gr_well_regex, names(df)))

  if (has_well_col) {
    "long"
  } else if (n_well_named >= 2) {
    "wide"
  } else {
    stop(
      "Could not detect the data layout: no 'well' column (long format) and ",
      "no well-named columns like 'A1' (wide format) found. ",
      "Specify format = \"wide\" or format = \"long\" explicitly.",
      call. = FALSE
    )
  }
}

gr_time_candidates <- c("time", "hours", "hour", "t")
gr_value_candidates <- c("value", "od", "od600", "absorbance", "measurement", "abs")

# Internal: wide layout -> long tibble with well/time/value.
gr_parse_wide <- function(df, time_col = NULL) {
  if (is.null(time_col)) {
    time_col <- gr_match_col(df, gr_time_candidates)
    if (is.null(time_col)) time_col <- names(df)[1]
  }
  if (!time_col %in% names(df)) {
    stop("Time column '", time_col, "' not found in the data.", call. = FALSE)
  }

  well_cols <- setdiff(names(df)[grepl(gr_well_regex, names(df))], time_col)
  if (length(well_cols) == 0) {
    stop(
      "No well columns found: expected column names like 'A1' or 'A01'.",
      call. = FALSE
    )
  }
  ignored <- setdiff(names(df), c(time_col, well_cols))
  if (length(ignored) > 0) {
    warning(
      "Ignoring column(s) that are neither time nor wells: ",
      paste(ignored, collapse = ", "),
      call. = FALSE
    )
  }

  df[[time_col]] <- gr_parse_time(df[[time_col]])

  df |>
    dplyr::select(dplyr::all_of(c(time_col, well_cols))) |>
    tidyr::pivot_longer(
      cols = dplyr::all_of(well_cols),
      names_to = "well",
      values_to = "value"
    ) |>
    dplyr::rename(time = dplyr::all_of(time_col))
}

# Internal: long layout -> tibble with well/time/value plus extra columns.
gr_parse_long <- function(df) {
  well_col <- gr_match_col(df, "well")
  time_col <- gr_match_col(df, gr_time_candidates)
  value_col <- gr_match_col(df, gr_value_candidates)

  missing <- c(
    if (is.null(well_col)) "well",
    if (is.null(time_col)) "time",
    if (is.null(value_col)) "value/OD/measurement"
  )
  if (length(missing) > 0) {
    stop(
      "Long-format data must contain well, time, and value columns; ",
      "could not find: ", paste(missing, collapse = ", "), ".",
      call. = FALSE
    )
  }

  df <- dplyr::rename(
    df,
    well = dplyr::all_of(well_col),
    time = dplyr::all_of(time_col),
    value = dplyr::all_of(value_col)
  )
  df$time <- gr_parse_time(df$time)
  # Drop derived columns if present; new_gr_plate() recomputes them.
  df[setdiff(names(df), c("row", "col"))]
}

# Internal: accept numeric times or "HH:MM:SS" clock strings (hours out).
gr_parse_time <- function(x) {
  if (is.numeric(x)) {
    return(x)
  }
  x <- trimws(as.character(x))
  if (all(grepl("^\\d{1,3}:\\d{2}(:\\d{2})?$", x))) {
    parts <- strsplit(x, ":", fixed = TRUE)
    return(vapply(parts, function(p) {
      p <- as.numeric(p)
      p[1] + p[2] / 60 + if (length(p) == 3) p[3] / 3600 else 0
    }, numeric(1)))
  }
  out <- suppressWarnings(as.numeric(x))
  if (anyNA(out)) {
    stop(
      "Could not parse the time column as numbers or 'HH:MM:SS' strings.",
      call. = FALSE
    )
  }
  out
}
