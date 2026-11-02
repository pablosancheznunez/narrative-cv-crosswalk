## Submission

First submission of narrativecv.

## Test environments

* GitHub Actions: Ubuntu (R devel, release, oldrel-1), macOS (release),
  Windows (release).
* Local: Windows 11, R 4.6.2.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes for CRAN

* Examples, tests and the vignette use recorded API responses shipped in
  `inst/extdata/examples`, so they run without internet access. Functions
  that query the web are wrapped in `\donttest{}`.
* Functions that use internet resources fail gracefully: an unreachable
  source is reported in the result and a message, never as an error.
