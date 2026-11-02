read_extdata <- function(...) {
  path <- system.file("extdata", ..., package = "narrativecv", mustWork = TRUE)
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

#' Crosswalk data
#'
#' The frameworks and mappings shipped with the package. They are the single
#' source of the crosswalk, also published as JSON at
#' <https://pablosancheznunez.com/narrative-cv-crosswalk/data/mappings.json>.
#'
#' * `nc_crosswalk()` returns the mappings as parsed JSON.
#' * `nc_crosswalk_table()` returns them as a data frame, one row per mapping,
#'   convenient for analysis.
#' * `nc_framework()` returns a framework and its sections.
#'
#' @param id Framework id: `"r4ri"` (Royal Society Résumé for Researchers) or
#'   `"cva-aei"` (Spanish Currículum Vitae Abreviado of the Agencia Estatal de
#'   Investigación).
#' @param framework Optional framework id to filter the table.
#' @return Parsed JSON (lists) or a data frame.
#' @name crosswalk-data
#' @examples
#' cw <- nc_crosswalk()
#' cw$mapping_version
#' fw <- nc_framework("cva-aei")
#' vapply(fw$sections, function(s) s$id, "")
#' head(nc_crosswalk_table("r4ri")[, c("section", "source", "record", "coverage")])
NULL

#' @rdname crosswalk-data
#' @export
nc_crosswalk <- function() read_extdata("mappings.json")

#' @rdname crosswalk-data
#' @export
nc_framework <- function(id = c("r4ri", "cva-aei")) {
  id <- match.arg(id)
  read_extdata("frameworks", paste0(id, ".json"))
}

#' @rdname crosswalk-data
#' @export
nc_frameworks <- function() c("r4ri", "cva-aei")

#' @rdname crosswalk-data
#' @export
nc_crosswalk_table <- function(framework = NULL) {
  ms <- nc_crosswalk()$mappings
  if (!is.null(framework)) {
    framework <- match.arg(framework, nc_frameworks())
    ms <- Filter(function(m) m$framework == framework, ms)
  }
  data.frame(
    id = vapply(ms, function(m) m$id, ""),
    framework = vapply(ms, function(m) m$framework, ""),
    section = vapply(ms, function(m) m$section, ""),
    contribution_type = vapply(ms, function(m) m$contribution_type, ""),
    source = vapply(ms, function(m) m$source, ""),
    record = vapply(ms, function(m) m$record, ""),
    types = vapply(ms, function(m) if (is.null(m$types)) NA_character_ else paste(unlist(m$types), collapse = ", "), ""),
    evidence_type = vapply(ms, function(m) m$evidence_type, ""),
    coverage = vapply(ms, function(m) m$coverage, ""),
    limitations = vapply(ms, function(m) m$limitations, ""),
    stringsAsFactors = FALSE
  )
}

#' Example evidence
#'
#' Recorded responses of the four APIs for ORCID's public test record (Josiah
#' Carberry, `0000-0002-1825-0097`), normalised into evidence. Use it to try
#' the package, and in examples and tests, without network access.
#'
#' @return A list with `evidence` and `consulted`, like [nc_collect()].
#' @export
#' @examples
#' ex <- nc_example_evidence()
#' length(ex$evidence)
#' vapply(ex$consulted, function(c) paste(c$source, c$count), "")
nc_example_evidence <- function() {
  ex <- function(name) read_extdata("examples", paste0(name, ".json"))
  evidence <- c(nc_normalize_orcid(ex("orcid")), nc_normalize_openalex(ex("openalex")),
                nc_normalize_datacite(ex("datacite")), nc_normalize_openaire(ex("openaire")))
  consulted <- lapply(nc_sources, function(s) {
    list(source = s, ok = TRUE, count = sum(vapply(evidence, function(e) e$source == s, TRUE)),
         error = NULL, retrieved_at = "2026-11-02T00:00:00Z")
  })
  list(evidence = evidence, consulted = consulted)
}
