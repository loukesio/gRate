# Summarise growth parameters across replicates

Aggregates the per-well growth parameters from
[`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md) over
experimental conditions: mean and standard deviation of `r`, `K`, `lag`,
and `doubling_time`, with the number of wells behind each estimate. This
is the step most fitting packages leave to you — combining technical and
biological replicates *after* excluding wells that QC flagged or whose
fit failed.

## Usage

``` r
gr_fit_summary(plate, by = NULL, drop_flagged = TRUE)
```

## Arguments

- plate:

  A `gr_plate` object after
  [`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md).

- by:

  Character vector of metadata columns to group by. Default: all
  metadata columns except `bio_rep` and `tech_rep`. With no metadata at
  all, a single overall summary row is returned.

- drop_flagged:

  If `TRUE` (default), wells flagged by
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) are
  excluded before averaging. Failed fits are always excluded.

## Value

A tibble with the grouping columns, `n_wells`, and `<param>_mean` /
`<param>_sd` for `r`, `K`, `lag`, and `doubling_time`.

## Details

By default wells are grouped by every metadata column added with
[`gr_layout()`](https://loukesio.github.io/gRate/reference/gr_layout.md)
except the replicate identifiers (`bio_rep`, `tech_rep`), so replicates
of the same condition are averaged together. Pass `by` to group
differently — e.g. `by = c("strain", "medium", "bio_rep")` keeps
biological replicates separate and averages only technical ones.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate")) |>
  gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
  gr_qc() |>
  gr_fit()
gr_fit_summary(plate)
#> # A tibble: 12 × 11
#>    strain   medium n_wells r_mean    r_sd K_mean   K_sd lag_mean  lag_sd
#>    <chr>    <chr>    <int>  <dbl>   <dbl>  <dbl>  <dbl>    <dbl>   <dbl>
#>  1 strain_1 LB           8  0.616 0.00258   1.07 0.0935     4.80 0.0241 
#>  2 strain_1 M9           8  0.615 0.00203   1.09 0.0831     4.80 0.0163 
#>  3 strain_2 LB           7  0.616 0.00215   1.11 0.0647     4.80 0.0155 
#>  4 strain_2 M9           8  0.617 0.00292   1.15 0.111      4.81 0.0179 
#>  5 strain_3 LB           7  0.615 0.00273   1.14 0.0899     4.80 0.0159 
#>  6 strain_3 M9           7  0.616 0.00177   1.14 0.109      4.80 0.00631
#>  7 strain_4 LB           8  0.615 0.00176   1.17 0.0796     4.80 0.0144 
#>  8 strain_4 M9           7  0.617 0.00257   1.12 0.0607     4.81 0.0154 
#>  9 strain_5 LB           7  0.614 0.00279   1.14 0.0897     4.78 0.0233 
#> 10 strain_5 M9           8  0.617 0.00296   1.16 0.0843     4.81 0.0219 
#> 11 strain_6 LB           8  0.616 0.00224   1.07 0.108      4.81 0.0171 
#> 12 strain_6 M9           8  0.616 0.00141   1.08 0.0956     4.81 0.0148 
#> # ℹ 2 more variables: doubling_time_mean <dbl>, doubling_time_sd <dbl>
gr_fit_summary(plate, by = c("strain", "medium", "bio_rep"))
#> # A tibble: 48 × 12
#>    strain   medium bio_rep n_wells r_mean       r_sd K_mean     K_sd lag_mean
#>    <chr>    <chr>    <int>   <int>  <dbl>      <dbl>  <dbl>    <dbl>    <dbl>
#>  1 strain_1 LB           1       2  0.619  0.00226     1.03  0.0197      4.81
#>  2 strain_1 LB           2       2  0.614  0.00137     1.10  0.148       4.78
#>  3 strain_1 LB           3       2  0.615  0.00157     1.07  0.104       4.79
#>  4 strain_1 LB           4       2  0.616  0.00222     1.09  0.150       4.81
#>  5 strain_1 M9           1       2  0.615  0.00133     1.09  0.110       4.80
#>  6 strain_1 M9           2       2  0.617  0.000230    1.14  0.132       4.81
#>  7 strain_1 M9           3       2  0.615  0.0000216   1.12  0.0802      4.80
#>  8 strain_1 M9           4       2  0.614  0.00387     1.04  0.0331      4.79
#>  9 strain_2 LB           1       2  0.616  0.00127     1.03  0.00773     4.80
#> 10 strain_2 LB           2       1  0.615 NA           1.20 NA           4.78
#> # ℹ 38 more rows
#> # ℹ 3 more variables: lag_sd <dbl>, doubling_time_mean <dbl>,
#> #   doubling_time_sd <dbl>
```
