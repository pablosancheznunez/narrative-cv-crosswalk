# narrativecv

R interface to the [Narrative CV Crosswalk](https://github.com/pablosancheznunez/narrative-cv-crosswalk).

```r
remotes::install_github("pablosancheznunez/narrative-cv-crosswalk", subdir = "r")
library(narrativecv)
report <- narrative_cv("0000-0002-1825-0097", "cva-aei")
nc_report_table(report)
```

Depends only on `curl` and `jsonlite`. Its engine is tested against the same
recorded responses and expected reports as the JavaScript engine of the web tool.
