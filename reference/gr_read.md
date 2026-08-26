# Read a plate reader export into a `gr_plate` object

Parses raw growth curve data into the tidy `gr_plate` structure that
every other gRate function operates on. Two generic layouts are
supported:

## Usage

``` r
gr_read(
  x,
  format = c("auto", "wide", "long", "tecan", "biotek"),
  time_col = NULL,
  plate_id = NULL,
  ...
)
```

## Arguments

- x:

  Path to a CSV/TSV/Excel file, or a data frame that is already in wide
  or long layout.

- format:

  One of `"auto"`, `"wide"`, `"long"`. (`"tecan"` and `"biotek"` are
  reserved for upcoming instrument parsers.)

- time_col:

  For wide data: name of the time column. Defaults to a column named
  like time (`time`, `hours`, `hour`, `t`), or the first column.

- plate_id:

  Optional plate identifier stored in `$meta`. Defaults to the file name
  (without extension) when `x` is a path.

- ...:

  Additional arguments passed to
  [`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html) or
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html)
  when `x` is a path.

## Value

A [gr_plate](https://loukesio.github.io/gRate/reference/new_gr_plate.md)
object.

## Details

- **wide** — one row per timepoint: a time column plus one column per
  well (`A1`, `A01`, `B12`, ...). This is the layout most plate reader
  software exports to CSV.

- **long** — one row per well and timepoint, with columns for well,
  time, and measurement. Column names are matched case-insensitively
  (well: `well`; time: `time`, `hours`, `hour`, `t`; value: `value`,
  `od`, `od600`, `absorbance`, `measurement`, `abs`).

With `format = "auto"` (the default) the layout is detected from the
column names. Instrument-specific parsers for Tecan and BioTek exports
are planned; `format = "tecan"` and `format = "biotek"` currently stop
with an informative error because those parsers are only written against
real example exports, not guessed formats.

## See also

[`gr_layout()`](https://loukesio.github.io/gRate/reference/gr_layout.md)
to attach well metadata,
[`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) to flag
wells.

## Examples

``` r
# long format
path <- system.file("extdata", "growth_long.csv", package = "gRate")
gr_read(path)
#> <gr_plate> 96 wells x 49 timepoints
#>   time: 0 to 24 (interval 0.5)
#>   instrument: generic, plate: growth_long
#>   QC: not run (use gr_qc())

# wide format
path <- system.file("extdata", "growth_wide.csv", package = "gRate")
gr_read(path, format = "wide")
#> <gr_plate> 96 wells x 49 timepoints
#>   time: 0 to 24 (interval 0.5)
#>   instrument: generic, plate: growth_wide
#>   QC: not run (use gr_qc())
```
