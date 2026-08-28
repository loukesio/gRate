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
  read = NULL,
  time_unit = c("auto", "hours", "days", "minutes", "seconds"),
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

- read:

  For instrument formats with several kinetic reads: substring selecting
  the read to import (e.g. `read = "GFP"` or `read = "630"`). Default:
  the first read, with a message naming the others.

- time_unit:

  For instrument formats: `"auto"` (default — Gen5 Excel day-fractions
  and the unit in Tecan's `Time [...]` header are handled), or one of
  `"hours"`, `"days"`, `"minutes"`, `"seconds"` to override.

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

Two instrument-native formats are parsed directly, each written against
a real example export:

- **biotek** — BioTek Gen5 kinetic exports (Excel or CSV): the metadata
  header is skipped, kinetic blocks are located by their
  `Time | T(degree) | A1 ...` header rows, Excel day-fraction times
  become hours, and the mean temperature is kept in `$meta`.

- **tecan** — Tecan i-control kinetic exports (Excel or CSV/TSV): the
  transposed layout (`Cycle Nr.` / `Time [s]` / `Temp.` rows, then one
  row per well) is pivoted, with the time unit taken from the
  `Time [...]` header.

Files with several kinetic reads (e.g. OD600 plus a fluorescence
channel) use the first read by default and name the others; pick one
with `read`. With `format = "auto"` (the default), instrument files are
recognised by their signature rows, and everything else falls back to
wide/long column detection.

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

# instrument exports (Gen5 / i-control shaped examples are bundled)
gr_read(system.file("extdata", "biotek_gen5.csv", package = "gRate"))
#> <gr_plate> 96 wells x 49 timepoints
#>   time: 0 to 24 (interval 0.5)
#>   instrument: BioTek Gen5, plate: biotek_gen5
#>   QC: not run (use gr_qc())
gr_read(system.file("extdata", "tecan_icontrol.csv", package = "gRate"))
#> <gr_plate> 96 wells x 49 timepoints
#>   time: 0 to 24 (interval 0.5)
#>   instrument: Tecan i-control, plate: tecan_icontrol
#>   QC: not run (use gr_qc())
```
