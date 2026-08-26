# Compare growth parameters between strains or conditions

Tests whether a growth parameter (growth rate `r` by default) differs
between groups — strains, media, treatments — doing the statistics at
the right level of replication. Technical replicates are averaged into
their biological replicate **before** any test, so wells never inflate
the sample size (the pseudoreplication mistake). Flagged wells and
failed fits are excluded first.

## Usage

``` r
gr_compare(
  plate,
  what = c("r", "K", "lag", "doubling_time", "N0", "t_rmax"),
  by = NULL,
  method = c("welch", "kruskal"),
  drop_flagged = TRUE,
  conf_level = 0.95
)
```

## Arguments

- plate:

  A `gr_plate` object after
  [`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md)
  (layout with metadata required;
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md)
  recommended).

- what:

  Which parameter to compare: `"r"` (default), `"K"`, `"lag"`,
  `"doubling_time"`, `"N0"`, or `"t_rmax"`.

- by:

  Character vector of metadata columns defining the groups. Default:
  every metadata column except `bio_rep` and `tech_rep`.

- method:

  `"welch"` (default) or `"kruskal"` (see Details).

- drop_flagged:

  If `TRUE` (default), wells flagged by
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) are
  excluded before averaging and testing.

- conf_level:

  Confidence level for the per-group intervals shown in `$groups` and by
  [`gr_plot_compare()`](https://loukesio.github.io/gRate/reference/gr_plot_compare.md).
  Default `0.95`.

## Value

An object of class `gr_compare`: a list with

- `$groups` — per-group tibble: n (replicates), mean, sd, se, ci_lo,
  ci_hi;

- `$overall` — the overall test (method, statistic, p_value);

- `$pairwise` — tibble of pairwise comparisons with adjusted p-values;

- `$data` — the replicate-level values the tests ran on;

- `$what`, `$by`, `$method`, `$unit` — what was compared and how.

## Details

The unit of replication is chosen automatically: if the layout
designates `bio_rep`, each biological replicate contributes one value
per group (its technical replicates averaged); without `bio_rep`, each
well is treated as a replicate — fine only if your wells really are
independent cultures.

With `method = "welch"` (default) the overall test is Welch's t-test for
two groups or Welch's ANOVA
([`stats::oneway.test()`](https://rdrr.io/r/stats/oneway.test.html)) for
more, followed by pairwise Welch t-tests with Holm adjustment.
`method = "kruskal"` uses the Kruskal-Wallis test and pairwise Wilcoxon
tests instead — for small or clearly non-normal samples.

## See also

[`gr_plot_compare()`](https://loukesio.github.io/gRate/reference/gr_plot_compare.md)
to visualise,
[`gr_fit_summary()`](https://loukesio.github.io/gRate/reference/gr_fit_summary.md)
for plain descriptive summaries.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate")) |>
  gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
  gr_qc() |>
  gr_fit()

cmp <- gr_compare(plate, what = "r", by = "strain")
cmp
#> <gr_compare> r by strain (unit: biological replicates)
#>   Welch's ANOVA: statistic = 0.622, p = 0.688
#> 
#> # A tibble: 6 × 7
#>   group        n  mean       sd       se ci_lo ci_hi
#>   <chr>    <int> <dbl>    <dbl>    <dbl> <dbl> <dbl>
#> 1 strain_1     4 0.616 0.000968 0.000484 0.614 0.617
#> 2 strain_2     4 0.617 0.000822 0.000411 0.615 0.618
#> 3 strain_3     4 0.616 0.00171  0.000857 0.613 0.619
#> 4 strain_4     4 0.616 0.00168  0.000842 0.614 0.619
#> 5 strain_5     4 0.616 0.00243  0.00122  0.612 0.620
#> 6 strain_6     4 0.616 0.000603 0.000301 0.615 0.617
#> 
#>   0 of 15 pairwise comparisons significant at 0.05 (Holm-adjusted); see $pairwise
cmp$pairwise
#> # A tibble: 15 × 4
#>    group1   group2        diff p_adj
#>    <chr>    <chr>        <dbl> <dbl>
#>  1 strain_2 strain_1  0.00117      1
#>  2 strain_3 strain_1  0.000367     1
#>  3 strain_4 strain_1  0.000661     1
#>  4 strain_5 strain_1  0.000120     1
#>  5 strain_6 strain_1  0.000884     1
#>  6 strain_3 strain_2 -0.000805     1
#>  7 strain_4 strain_2 -0.000511     1
#>  8 strain_5 strain_2 -0.00105      1
#>  9 strain_6 strain_2 -0.000288     1
#> 10 strain_4 strain_3  0.000294     1
#> 11 strain_5 strain_3 -0.000247     1
#> 12 strain_6 strain_3  0.000517     1
#> 13 strain_5 strain_4 -0.000541     1
#> 14 strain_6 strain_4  0.000223     1
#> 15 strain_6 strain_5  0.000764     1
```
