# narrativecv 0.1.0

* First release, prepared for CRAN.
* `narrative_cv()` collects evidence from ORCID, OpenAlex, DataCite and the
  OpenAIRE Graph and maps it onto the R4RI or CVA framework.
* `nc_map()` is pure and reproducible; `print()`, `summary()` and
  `as.data.frame()` methods for the resulting `ncvc_report`.
* Crosswalk version 0.2.0, checked against the AEI instructions for the CVA
  (2025 call) and the Royal Society R4RI template (2019).
* `nc_example_evidence()` provides recorded responses for offline use.
* Sources that fail are reported as such and never stop the collection.
