# Test whether an object is a `gr_plate`

Test whether an object is a `gr_plate`

## Usage

``` r
is_gr_plate(x)
```

## Arguments

- x:

  An object.

## Value

`TRUE` if `x` is a `gr_plate`, otherwise `FALSE`.

## Examples

``` r
path <- system.file("extdata", "growth_long.csv", package = "gRate")
is_gr_plate(gr_read(path))
#> [1] TRUE
is_gr_plate(mtcars)
#> [1] FALSE
```
