# Per-well summary statistics

Computes simple per-well summaries of the growth curves: baseline (mean
of the first `n_baseline` readings), maximum value, rise above baseline,
and area under the curve. Used internally by
[`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md),
[`gr_spatial()`](https://loukesio.github.io/gRate/reference/gr_spatial.md)
and
[`gr_plot_plate()`](https://loukesio.github.io/gRate/reference/gr_plot_plate.md),
and handy on its own for a quick look at a plate.

## Usage

``` r
gr_summarise(plate, n_baseline = 3)
```

## Arguments

- plate:

  A `gr_plate` object.

- n_baseline:

  Number of initial timepoints averaged to estimate the baseline of each
  well.

## Value

A tibble with one row per well and columns `well`, `row`, `col`,
`baseline`, `max_od`, `delta_od` (max minus baseline), and `auc`.

## Examples

``` r
path <- system.file("extdata", "growth_long.csv", package = "gRate")
plate <- gr_read(path)
gr_summarise(plate)
#> # A tibble: 96 × 7
#>    well  row     col baseline max_od delta_od   auc
#>    <chr> <chr> <int>    <dbl>  <dbl>    <dbl> <dbl>
#>  1 A1    A         1   0.0567   1.11    1.05   18.0
#>  2 A10   A        10   0.0538   1.06    1.01   17.2
#>  3 A11   A        11   0.0532   1.09    1.04   17.7
#>  4 A12   A        12   0.0548   1.02    0.964  16.6
#>  5 A2    A         2   0.0551   1.08    1.02   17.5
#>  6 A3    A         3   0.0548   1.09    1.04   17.7
#>  7 A4    A         4   0.0519   1.08    1.02   17.5
#>  8 A5    A         5   0.0545   1.11    1.06   18.1
#>  9 A6    A         6   0.0525   1.04    0.983  16.8
#> 10 A7    A         7   0.0539   1.10    1.04   17.8
#> # ℹ 86 more rows
```
