# Convert a `gr_plate` to growthcurver input

Shorthand for `gr_export(plate, as = "growthcurver", ...)`: a wide data
frame with a `time` column and one column per well, the format
[`growthcurver::SummarizeGrowthByPlate()`](https://rdrr.io/pkg/growthcurver/man/SummarizeGrowthByPlate.html)
takes directly.

## Usage

``` r
as_growthcurver(plate, drop_flagged = FALSE)
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

A wide data frame (`time` + one column per well).

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
plate <- gr_qc(plate)
d <- as_growthcurver(plate, drop_flagged = TRUE)
if (FALSE) { # \dontrun{
growthcurver::SummarizeGrowthByPlate(d)
} # }
```
