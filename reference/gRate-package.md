# gRate: Growth Rates from Microbial Growth Curves, with Quality Control and Spatial Bias Correction

An end-to-end toolkit for 96-well plate reader growth curve experiments.
Reads raw plate reader exports, maps plate layouts to well metadata
including biological and technical replicates, flags problematic wells
(no growth, spikes, drift, late jumps, noise), estimates and corrects
spatial artifacts such as edge effects via median polish, fits growth
models per well (parametric logistic fits, or the nonparametric
'easylinear' method of Hall et al. (2014)
[doi:10.1093/molbev/mst187](https://doi.org/10.1093/molbev/mst187) ),
and summarises growth parameters across replicates. Tidy exporters are
provided for users who prefer fitting with 'growthcurver' or 'gcplyr'.

## See also

Useful links:

- <https://loukesio.github.io/gRate/>

- <https://github.com/loukesio/gRate>

- Report bugs at <https://github.com/loukesio/gRate/issues>

## Author

**Maintainer**: Loukas Theodosiou <loukesio@gmail.com>
