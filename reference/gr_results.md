# The results table: growth parameters joined with your metadata

Returns the table you actually want after a fit: one row per well with
the experimental metadata from
[`gr_layout()`](https://loukesio.github.io/gRate/reference/gr_layout.md)
(strain, medium, replicates, ...), the growth parameters from
[`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md), and
the QC verdict from
[`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) — ready
for plotting, statistics, or saving.

## Usage

``` r
gr_results(
  plate,
  params = c("r", "K", "lag", "doubling_time"),
  drop_flagged = FALSE,
  file = NULL
)
```

## Arguments

- plate:

  A `gr_plate` object after
  [`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md).

- params:

  Which fit parameters to include, any of `"r"`, `"K"`, `"lag"`,
  `"doubling_time"`, `"N0"`, `"t_rmax"`, `"sigma"`. Defaults to the
  first four — the ones most analyses care about.

- drop_flagged:

  If `TRUE`, wells flagged by
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) are
  removed. Default `FALSE` — the `flagged` and `reasons` columns are
  included instead, so nothing disappears silently.

- file:

  Optional path; if given, the table is also written there as a CSV and
  the tibble returned invisibly.

## Value

A tibble with columns `well`, `row`, `col`, the metadata columns, the
requested parameters (with their `_lo`/`_hi` bootstrap intervals when
[`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md) was
run with `boot > 0`), `fit_ok`, `note`, and (when QC has run) `flagged`
and `reasons`.

## Details

This differs from `plate$fit` (parameters only, no metadata) and from
[`gr_fit_summary()`](https://loukesio.github.io/gRate/reference/gr_fit_summary.md)
(already averaged over replicates): `gr_results()` is the full per-well
table that sits between the two.

## See also

[`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md),
[`gr_fit_summary()`](https://loukesio.github.io/gRate/reference/gr_fit_summary.md)

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate")) |>
  gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
  gr_qc() |>
  gr_fit()

gr_results(plate)
#> # A tibble: 96 × 15
#>    well  row     col strain   medium bio_rep tech_rep     r     K   lag
#>    <chr> <chr> <int> <chr>    <chr>    <int>    <int> <dbl> <dbl> <dbl>
#>  1 A1    A         1 strain_1 LB           1        1 0.621 1.05   4.82
#>  2 A2    A         2 strain_1 LB           1        2 0.618 1.02   4.81
#>  3 A3    A         3 strain_2 LB           1        1 0.617 1.03   4.81
#>  4 A4    A         4 strain_2 LB           1        2 0.615 1.02   4.79
#>  5 A5    A         5 strain_3 LB           1        1 0.617 1.05   4.82
#>  6 A6    A         6 strain_3 LB           1        2 0.615 0.977  4.79
#>  7 A7    A         7 strain_4 LB           1        1 0.616 1.04   4.80
#>  8 A8    A         8 strain_4 LB           1        2 0.617 1.04   4.81
#>  9 A9    A         9 strain_5 LB           1        1 0.610 1.03   4.77
#> 10 A10   A        10 strain_5 LB           1        2 0.613 1.00   4.78
#> # ℹ 86 more rows
#> # ℹ 5 more variables: doubling_time <dbl>, fit_ok <lgl>, note <chr>,
#> #   flagged <lgl>, reasons <chr>
gr_results(plate, params = c("r", "K"), drop_flagged = TRUE)
#> # A tibble: 91 × 11
#>    well  row     col strain   medium bio_rep tech_rep     r     K fit_ok note 
#>    <chr> <chr> <int> <chr>    <chr>    <int>    <int> <dbl> <dbl> <lgl>  <chr>
#>  1 A1    A         1 strain_1 LB           1        1 0.621 1.05  TRUE   ""   
#>  2 A2    A         2 strain_1 LB           1        2 0.618 1.02  TRUE   ""   
#>  3 A3    A         3 strain_2 LB           1        1 0.617 1.03  TRUE   ""   
#>  4 A4    A         4 strain_2 LB           1        2 0.615 1.02  TRUE   ""   
#>  5 A5    A         5 strain_3 LB           1        1 0.617 1.05  TRUE   ""   
#>  6 A6    A         6 strain_3 LB           1        2 0.615 0.977 TRUE   ""   
#>  7 A7    A         7 strain_4 LB           1        1 0.616 1.04  TRUE   ""   
#>  8 A8    A         8 strain_4 LB           1        2 0.617 1.04  TRUE   ""   
#>  9 A9    A         9 strain_5 LB           1        1 0.610 1.03  TRUE   ""   
#> 10 A10   A        10 strain_5 LB           1        2 0.613 1.00  TRUE   ""   
#> # ℹ 81 more rows
if (FALSE) { # \dontrun{
gr_results(plate, file = "run1_growth_parameters.csv")
} # }
```
