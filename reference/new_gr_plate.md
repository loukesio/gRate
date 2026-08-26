# Construct a `gr_plate` object

`gr_plate` is the single data structure every gRate function takes and
returns. It is a list with three components:

## Usage

``` r
new_gr_plate(data, qc = NULL, meta = list())
```

## Arguments

- data:

  A data frame with columns `well`, `time`, `value`. `row` and `col` are
  derived from `well` if absent. Well ids are normalised (`"A01"`
  becomes `"A1"`).

- qc:

  Optional per-well QC tibble (normally left `NULL`;
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) fills
  it in).

- meta:

  Named list of plate-level metadata.

## Value

A `gr_plate` object.

## Details

- `$data` — a tidy tibble with one row per well and timepoint, columns
  `well`, `row`, `col`, `time`, `value`, plus any metadata columns added
  by
  [`gr_layout()`](https://loukesio.github.io/gRate/reference/gr_layout.md)
  and a `value_raw` column after
  [`gr_spatial()`](https://loukesio.github.io/gRate/reference/gr_spatial.md)
  correction.

- `$qc` — a per-well tibble of QC flags, filled in by
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md)
  (`NULL` before QC has run).

- `$meta` — a list of plate-level metadata: `instrument`, `plate_id`,
  `read_interval`, and bookkeeping added by other functions.

You rarely need to call `new_gr_plate()` yourself —
[`gr_read()`](https://loukesio.github.io/gRate/reference/gr_read.md)
builds the object from a raw export. It is exported so you can construct
a plate from data that is already tidy.

## Examples

``` r
df <- expand.grid(well = c("A1", "A2"), time = 0:5)
df$value <- 0.05 + 0.01 * df$time
plate <- new_gr_plate(df)
plate
#> <gr_plate> 2 wells x 6 timepoints
#>   time: 0 to 5 (interval 1)
#>   QC: not run (use gr_qc())
```
