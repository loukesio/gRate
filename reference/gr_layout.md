# Attach a plate layout (well metadata) to a `gr_plate`

Joins experimental design information — strain, treatment, replicate,
anything per-well — onto the plate data. Two layout formats are
accepted:

## Usage

``` r
gr_layout(
  plate,
  layout,
  name = "content",
  bio_rep = NULL,
  tech_rep = NULL,
  ...
)
```

## Arguments

- plate:

  A `gr_plate` object.

- layout:

  A data frame or path to a CSV/TSV/Excel file, in long or grid format.

- name:

  Name for the metadata column created from a grid layout (default
  `"content"`). Ignored for long layouts.

- bio_rep:

  Optional name of the layout column identifying biological replicates;
  it is renamed to `bio_rep`.

- tech_rep:

  Optional name of the layout column identifying technical replicates;
  it is renamed to `tech_rep`.

- ...:

  Additional arguments passed to the file reader when `layout` is a
  path.

## Value

The `gr_plate` with metadata columns added to `$data`.

## Details

- **long** — a data frame or CSV with a `well` column plus one column
  per metadata variable. This is the recommended format because it
  carries any number of variables at once.

- **grid** — an 8 x 12 table mirroring the physical plate (optionally
  with a leading column of row letters A-H), where each cell holds one
  value. The values become a single metadata column named by `name`.
  Call `gr_layout()` repeatedly to add several grid variables.

The format is detected automatically: a table with a `well` column is
treated as long, an 8-row table with 12 value columns as a grid.

### Biological and technical replicates

gRate treats two metadata columns as special: `bio_rep` (biological
replicate — independent cultures) and `tech_rep` (technical replicate —
the same culture measured in several wells). Layout columns already
named `bio_rep` / `tech_rep` are picked up automatically; otherwise
point the `bio_rep` / `tech_rep` arguments at the layout columns holding
them and they are renamed on the way in. Once designated, they show up
in
[print()](https://loukesio.github.io/gRate/reference/new_gr_plate.md),
can colour
[`gr_plot_curves()`](https://loukesio.github.io/gRate/reference/gr_plot_curves.md),
and technical replicates can be averaged on export
(`gr_export(collapse_tech = TRUE)`).

## See also

[`gr_read()`](https://loukesio.github.io/gRate/reference/gr_read.md),
[`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md)

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))

# long layout: well + any number of metadata columns
plate <- gr_layout(
  plate,
  system.file("extdata", "layout_long.csv", package = "gRate")
)
plate
#> <gr_plate> 96 wells x 49 timepoints
#>   time: 0 to 24 (interval 0.5)
#>   instrument: generic, plate: growth_long
#>   metadata: strain, medium, bio_rep, tech_rep 
#>   replicates: 4 biological x 2 technical
#>   QC: not run (use gr_qc())

# grid layout: an 8x12 table of values, one variable at a time
plate <- gr_layout(
  plate,
  system.file("extdata", "layout_grid.csv", package = "gRate"),
  name = "strain_grid"
)
head(plate$data)
#> # A tibble: 6 × 10
#>   well  row     col  time  value strain   medium bio_rep tech_rep strain_grid
#>   <chr> <chr> <int> <dbl>  <dbl> <chr>    <chr>    <int>    <int> <chr>      
#> 1 A1    A         1   0   0.0551 strain_1 LB           1        1 strain_1   
#> 2 A1    A         1   0.5 0.0566 strain_1 LB           1        1 strain_1   
#> 3 A1    A         1   1   0.0583 strain_1 LB           1        1 strain_1   
#> 4 A1    A         1   1.5 0.0608 strain_1 LB           1        1 strain_1   
#> 5 A1    A         1   2   0.0721 strain_1 LB           1        1 strain_1   
#> 6 A1    A         1   2.5 0.0818 strain_1 LB           1        1 strain_1   
```
