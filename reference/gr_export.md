# Export a `gr_plate` for downstream analysis

Turns a processed plate back into a plain data frame, in the shape a
downstream tool expects:

## Usage

``` r
gr_export(
  plate,
  as = c("tidy", "growthcurver", "gcplyr"),
  drop_flagged = FALSE,
  collapse_tech = FALSE
)
```

## Arguments

- plate:

  A `gr_plate` object.

- as:

  Output shape: `"tidy"`, `"growthcurver"`, or `"gcplyr"`.

- drop_flagged:

  If `TRUE`, wells flagged by
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) are
  removed from the export. Default `FALSE` — gRate flags, you decide.
  Requires
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) to
  have run.

- collapse_tech:

  If `TRUE`, technical replicates are averaged: rows are grouped by
  every metadata column except the well identity and `tech_rep`, plus
  time, and `value` becomes their mean. Requires a `tech_rep` column
  (designate one with
  [`gr_layout()`](https://loukesio.github.io/gRate/reference/gr_layout.md))
  and only makes sense for the tidy shape, since averaged curves no
  longer belong to a single well. The result gains `n_wells` (wells
  averaged) and, if QC has run, `flagged` is `TRUE` when *any*
  contributing well was flagged (combine with `drop_flagged = TRUE` to
  average only clean wells).

## Value

A data frame in the requested shape.

## Details

- `"tidy"` (default) — one row per well and timepoint, with all metadata
  columns and, when
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) has
  run, `flagged` and `reasons` joined in.

- `"growthcurver"` — a wide data frame with a `time` column and one
  column per well, ready for
  [`growthcurver::SummarizeGrowthByPlate()`](https://rdrr.io/pkg/growthcurver/man/SummarizeGrowthByPlate.html).

- `"gcplyr"` — a long data frame with columns `Well`, `Time`,
  `Measurements` (plus metadata), the tidy shape gcplyr's design
  functions expect.

## See also

[`as_growthcurver()`](https://loukesio.github.io/gRate/reference/as_growthcurver.md),
[`as_gcplyr()`](https://loukesio.github.io/gRate/reference/as_gcplyr.md)

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
plate <- gr_qc(plate)

head(gr_export(plate))
#> # A tibble: 6 × 7
#>   well  row     col  time  value flagged reasons
#>   <chr> <chr> <int> <dbl>  <dbl> <lgl>   <chr>  
#> 1 A1    A         1   0   0.0551 FALSE   ""     
#> 2 A1    A         1   0.5 0.0566 FALSE   ""     
#> 3 A1    A         1   1   0.0583 FALSE   ""     
#> 4 A1    A         1   1.5 0.0608 FALSE   ""     
#> 5 A1    A         1   2   0.0721 FALSE   ""     
#> 6 A1    A         1   2.5 0.0818 FALSE   ""     
gc_input <- gr_export(plate, as = "growthcurver", drop_flagged = TRUE)
names(gc_input)[1:5]
#> [1] "time" "A1"   "A2"   "A3"   "A4"  
```
