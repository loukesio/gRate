# Instrument-native parsers, written against real example exports:
# a BioTek Gen5 kinetic export from a Synergy H1 (metadata header, then one
# block per read with wells as COLUMNS and time as Excel day-fractions) and a
# Tecan i-control kinetic export (transposed: "Cycle Nr." / "Time [s]" /
# "Temp." rows, then one row per WELL with cycles as columns).

# Read a file as an untyped character matrix, preserving layout.
gr_read_raw <- function(path, ...) {
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("xls", "xlsx")) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop("Reading Excel files requires the 'readxl' package.",
           call. = FALSE)
    }
    df <- readxl::read_excel(path, col_names = FALSE,
                             col_types = "text",
                             .name_repair = "minimal", ...)
    as.matrix(df)
  } else {
    sep <- if (ext == "tsv") "\t" else ","
    # read.table sizes columns from the first lines; instrument headers are
    # narrow, so count the widest line explicitly.
    n_col <- max(utils::count.fields(path, sep = sep, quote = "\"",
                                     blank.lines.skip = FALSE),
                 na.rm = TRUE)
    df <- utils::read.table(path, sep = sep, header = FALSE,
                            colClasses = "character", fill = TRUE,
                            stringsAsFactors = FALSE, quote = "\"",
                            blank.lines.skip = FALSE,
                            col.names = paste0("V", seq_len(n_col)), ...)
    as.matrix(df)
  }
}

# Cheap sniff of instrument formats on the raw matrix (for format = "auto").
gr_sniff_instrument <- function(mat) {
  head_cells <- as.character(mat[seq_len(min(60, nrow(mat))), ])
  head_cells <- head_cells[!is.na(head_cells)]
  if (any(grepl("^Cycle Nr\\.?$", head_cells)) ||
      any(grepl("^Time \\[", head_cells))) {
    return("tecan")
  }
  if (any(grepl("^Software Version$", head_cells)) ||
      any(grepl("^Procedure Details$", head_cells)) ||
      any(grepl("^Reader Type:?$", head_cells))) {
    return("biotek")
  }
  NULL
}

# Convert instrument time values to hours.
# unit "auto" resolves per format: Gen5 exports Excel day-fractions; Tecan
# labels its unit in the header ("Time [s]").
gr_time_to_hours <- function(x, unit) {
  x <- as.numeric(x)
  switch(
    unit,
    hours = x,
    days = x * 24,
    minutes = x / 60,
    seconds = x / 3600,
    stop("Unknown time unit '", unit, "'.", call. = FALSE)
  )
}

gr_check_96 <- function(wells) {
  bad <- !grepl(gr_well_regex, wells)
  if (any(bad)) {
    looks_384 <- any(grepl("^[I-Pi-p]\\d+$", wells) |
                       grepl("^[A-Pa-p](1[3-9]|2[0-4])$", wells))
    stop(
      "Found well id(s) outside a 96-well plate (e.g. ",
      wells[bad][1], "). ",
      if (looks_384) "384-well plates are not supported (yet)." else "",
      call. = FALSE
    )
  }
  invisible(wells)
}

# ---------------------------------------------------------------------------
# BioTek Gen5: locate kinetic blocks by their header row ("Time", optional
# temperature column, then well ids). Block name comes from the temperature
# column header ("T(degree) Read 3:630" -> "Read 3:630") or the nearest
# preceding cell in column 1.
gr_parse_biotek <- function(mat, read = NULL, time_unit = "auto") {
  n_col <- ncol(mat)
  is_header <- vapply(seq_len(nrow(mat)), function(i) {
    row <- as.character(mat[i, ])
    t_pos <- which(!is.na(row) & row == "Time")
    if (length(t_pos) == 0) return(FALSE)
    rest <- row[(t_pos[1] + 1):n_col]
    any(grepl(gr_well_regex, rest[!is.na(rest)]))
  }, logical(1))
  headers <- which(is_header)

  if (length(headers) == 0) {
    stop(
      "No kinetic data block found: expected a header row with 'Time' ",
      "followed by well columns (A1, A2, ...), as in Gen5 kinetic exports.",
      call. = FALSE
    )
  }

  block_name <- vapply(headers, function(i) {
    row <- as.character(mat[i, ])
    temp_col <- grep("^T\u00b0 ?", row)
    if (length(temp_col) > 0) {
      return(trimws(sub("^T\u00b0 ?", "", row[temp_col[1]])))
    }
    for (j in rev(seq_len(i - 1))) {
      cell <- mat[j, 1]
      if (!is.na(cell) && nzchar(trimws(cell))) return(trimws(cell))
    }
    paste("read", match(i, headers))
  }, character(1))

  pick <- gr_pick_block(block_name, read)
  h <- headers[pick]
  row <- as.character(mat[h, ])
  t_pos <- which(!is.na(row) & row == "Time")[1]
  well_cols <- which(grepl(gr_well_regex, row) & seq_len(n_col) > t_pos)
  temp_col <- grep("^T\u00b0 ?", row)

  # Data rows run until the first row with no time value.
  data_rows <- integer(0)
  i <- h + 1
  while (i <= nrow(mat) && !is.na(mat[i, t_pos]) &&
         nzchar(trimws(mat[i, t_pos]))) {
    data_rows <- c(data_rows, i)
    i <- i + 1
  }
  if (length(data_rows) == 0) {
    stop("Kinetic block '", block_name[pick], "' contains no data rows.",
         call. = FALSE)
  }

  time_raw <- mat[data_rows, t_pos]
  time <- if (all(grepl("^\\d{1,3}:\\d{2}(:\\d{2})?$", time_raw))) {
    gr_parse_time(time_raw)  # clock strings in CSV exports
  } else if (time_unit == "auto") {
    # Gen5 Excel exports store time as day-fractions.
    gr_time_to_hours(time_raw, "days")
  } else {
    gr_time_to_hours(time_raw, time_unit)
  }

  wells <- gr_norm_well(row[well_cols])
  values <- suppressWarnings(
    matrix(as.numeric(mat[data_rows, well_cols]),
           nrow = length(data_rows))
  )
  if (anyNA(values)) {
    warning("Non-numeric readings (e.g. OVRFLW) set to NA.", call. = FALSE)
  }

  temperature <- if (length(temp_col) > 0) {
    mean(suppressWarnings(as.numeric(mat[data_rows, temp_col[1]])),
         na.rm = TRUE)
  } else {
    NA_real_
  }

  list(
    data = data.frame(
      well = rep(wells, each = length(time)),
      time = rep(time, times = length(wells)),
      value = as.vector(values)
    ),
    read = unname(block_name[pick]),
    reads = unname(block_name),
    temperature = temperature
  )
}

# ---------------------------------------------------------------------------
# Tecan i-control: transposed blocks. A block starts at a "Time [unit]" row
# (usually preceded by "Cycle Nr." and followed by "Temp."), then one row per
# well until the first row whose first cell is not a well id. Block name is
# the nearest preceding single non-empty cell (the label), if any.
gr_parse_tecan <- function(mat, read = NULL, time_unit = "auto") {
  first_col <- trimws(as.character(mat[, 1]))
  first_col[is.na(first_col)] <- ""
  time_rows <- grep("^Time \\[[^]]+\\]$", first_col)

  if (length(time_rows) == 0) {
    stop(
      "No kinetic data block found: expected a 'Time [s]' row followed by ",
      "one row per well, as in i-control kinetic exports.",
      call. = FALSE
    )
  }

  block_name <- vapply(seq_along(time_rows), function(k) {
    i <- time_rows[k]
    for (j in rev(seq_len(i - 1))) {
      cell <- first_col[j]
      if (grepl("^Cycle Nr\\.?$", cell)) next
      if (nzchar(cell) && !grepl("^[A-Z]\\d+$", cell)) return(cell)
      if (grepl("^[A-Z]\\d+$", cell)) break
    }
    paste("read", k)
  }, character(1))

  pick <- gr_pick_block(block_name, read)
  t_row <- time_rows[pick]

  unit <- if (time_unit == "auto") {
    switch(sub("^Time \\[([^]]+)\\]$", "\\1", first_col[t_row]),
           s = "seconds", sec = "seconds", min = "minutes",
           h = "hours", "hours")
  } else {
    time_unit
  }

  n_cycles <- max(which(!is.na(mat[t_row, ]) &
                          nzchar(trimws(mat[t_row, ]))))
  time <- gr_time_to_hours(mat[t_row, 2:n_cycles], unit)

  # Well rows follow the Time (and optional Temp.) row.
  i <- t_row + 1
  temperature <- NA_real_
  if (i <= nrow(mat) && grepl("^Temp\\.", first_col[i])) {
    temperature <- mean(suppressWarnings(as.numeric(mat[i, 2:n_cycles])),
                        na.rm = TRUE)
    i <- i + 1
  }
  well_rows <- integer(0)
  while (i <= nrow(mat) && grepl("^[A-Za-z]\\d+$", first_col[i])) {
    well_rows <- c(well_rows, i)
    i <- i + 1
  }
  if (length(well_rows) == 0) {
    stop("Kinetic block '", block_name[pick], "' contains no well rows.",
         call. = FALSE)
  }

  gr_check_96(first_col[well_rows])
  wells <- gr_norm_well(first_col[well_rows])
  values <- suppressWarnings(
    matrix(as.numeric(mat[well_rows, 2:n_cycles]),
           nrow = length(well_rows), byrow = FALSE)
  )
  if (anyNA(values)) {
    warning("Non-numeric readings (e.g. OVER) set to NA.", call. = FALSE)
  }

  list(
    data = data.frame(
      well = rep(wells, times = length(time)),
      time = rep(time, each = length(wells)),
      value = as.vector(values)
    ),
    read = unname(block_name[pick]),
    reads = unname(block_name),
    temperature = temperature
  )
}

# Choose one block among the named ones: NULL -> first (with a message when
# there are several); otherwise substring match on the block names.
gr_pick_block <- function(block_name, read) {
  if (is.null(read)) {
    if (length(block_name) > 1) {
      message(
        "File contains ", length(block_name), " kinetic reads: ",
        paste(shQuote(block_name), collapse = ", "),
        ". Using the first; pick another with read = \"<name>\"."
      )
    }
    return(1L)
  }
  hit <- grep(read, block_name, fixed = TRUE)
  if (length(hit) == 0) {
    stop("No kinetic read matching '", read, "'. Available: ",
         paste(shQuote(block_name), collapse = ", "), call. = FALSE)
  }
  hit[1]
}
