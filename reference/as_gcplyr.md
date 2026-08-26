# Convert a `gr_plate` to gcplyr-style tidy data

Shorthand for `gr_export(plate, as = "gcplyr", ...)`: a long data frame
with `Well`, `Time`, `Measurements` and any metadata columns, matching
the tidy shape used throughout gcplyr.

## Usage

``` r
as_gcplyr(plate, drop_flagged = FALSE)
```

## Arguments

- plate:

  A `gr_plate` object.

- drop_flagged:

  If `TRUE`, wells flagged by
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) are
  removed from the export. Default `FALSE` — gRate flags, you decide.
  Requires
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) to
  have run.

## Value

A long data frame with columns `Well`, `Time`, `Measurements`, plus
metadata.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
head(as_gcplyr(plate))
#>   Well Time Measurements
#> 1   A1  0.0       0.0551
#> 2   A1  0.5       0.0566
#> 3   A1  1.0       0.0583
#> 4   A1  1.5       0.0608
#> 5   A1  2.0       0.0721
#> 6   A1  2.5       0.0818
```
