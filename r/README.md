# narrativecv

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23881631.svg)](https://doi.org/10.5281/zenodo.23881631)

Map narrative CV sections (Royal Society *Résumé for Researchers*, Spanish *CVA*
of the Agencia Estatal de Investigación) to the evidence ORCID, OpenAlex,
DataCite and the OpenAIRE Graph hold about a researcher, with the type,
coverage and limitations of each source.

```r
# install.packages("remotes")
remotes::install_github("pablosancheznunez/narrative-cv-crosswalk", subdir = "r")

library(narrativecv)
report <- narrative_cv("0000-0002-1825-0097", "cva-aei")
report                  # status of every section
as.data.frame(report)   # one row per evidence item
```

Work offline with `nc_example_evidence()`; read the method and its limits in
`vignette("narrativecv")`; cite with `citation("narrativecv")`.

Not found does not mean it does not exist. The engine is tested against the
same recorded responses and expected reports as the JavaScript engine of the
[web tool](https://pablosancheznunez.com/narrative-cv-crosswalk/).
Dependencies: `curl` and `jsonlite`.
