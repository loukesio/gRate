# Internal helpers shared across the package. None of these are exported.

# Regex for a 96-well id: row letter A-H, column 1-12, optional zero padding.
gr_well_regex <- "^[A-Ha-h](0?[1-9]|1[0-2])$"

# Normalise well ids: "a01", "A01", "A1" all become "A1".
gr_norm_well <- function(x) {
  x <- trimws(as.character(x))
  bad <- !grepl(gr_well_regex, x)
  if (any(bad)) {
    stop(
      "Invalid well id(s): ", paste(unique(x[bad]), collapse = ", "),
      ". Expected 96-well ids like 'A1' or 'A01' (rows A-H, columns 1-12).",
      call. = FALSE
    )
  }
  row <- toupper(substr(x, 1, 1))
  col <- as.integer(sub("^[A-Ha-h]", "", x))
  paste0(row, col)
}

gr_well_row <- function(well) substr(well, 1, 1)

gr_well_col <- function(well) as.integer(sub("^[A-H]", "", well))

# All 96 well ids in row-major order: A1..A12, B1..B12, ...
gr_all_wells <- function() {
  as.vector(t(outer(LETTERS[1:8], 1:12, paste0)))
}

# Wells on the outer ring of a 96-well plate.
gr_edge_wells <- function() {
  wells <- gr_all_wells()
  wells[gr_well_row(wells) %in% c("A", "H") | gr_well_col(wells) %in% c(1, 12)]
}

# Read a delimited or Excel file into a plain data.frame.
gr_read_table <- function(path, ...) {
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("xls", "xlsx")) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop(
        "Reading Excel files requires the 'readxl' package. ",
        "Install it with install.packages(\"readxl\").",
        call. = FALSE
      )
    }
    as.data.frame(readxl::read_excel(path, ...))
  } else {
    sep <- if (ext == "tsv") "\t" else ","
    utils::read.csv(path, sep = sep, check.names = FALSE,
                    stringsAsFactors = FALSE, ...)
  }
}

# Find the first column of `df` whose name matches any of `candidates`
# (case-insensitive). Returns the column name or NULL.
gr_match_col <- function(df, candidates) {
  hit <- match(candidates, tolower(names(df)))
  hit <- hit[!is.na(hit)]
  if (length(hit) == 0) NULL else names(df)[hit[1]]
}

# Trapezoidal area under a curve.
gr_auc <- function(time, value) {
  ord <- order(time)
  time <- time[ord]
  value <- value[ord]
  sum(diff(time) * (utils::head(value, -1) + utils::tail(value, -1)) / 2)
}
