# Mirrors src/engine.js. Both must produce identical reports for the same
# input; tests compare each against the same expected files.

nc_matches <- function(mapping, e) {
  identical(e$source, mapping$source) && identical(e$record, mapping$record) &&
    (is.null(mapping$types) || (!is.null(e$type) && e$type %in% unlist(mapping$types)))
}

#' Map evidence onto a narrative CV framework
#'
#' Applies the crosswalk to evidence items and classifies every section of the
#' framework:
#'
#' * `found`: evidence matched a mapping with full coverage;
#' * `partial`: evidence matched, but only through partial-coverage mappings;
#' * `not_found_in_sources`: nothing in the sources consulted. **This does not
#'   mean the contribution does not exist**;
#' * `source_unavailable`: every source the section relies on failed;
#' * `no_automated_source`: the section is narrative and no infrastructure can
#'   document it.
#'
#' The function is pure: the same evidence always gives the same report, which
#' makes assessments reproducible when the evidence is archived.
#'
#' @param framework A framework from [nc_framework()].
#' @param evidence,consulted As returned by [nc_collect()] or
#'   [nc_example_evidence()].
#' @param crosswalk Mappings from [nc_crosswalk()].
#' @param orcid The ORCID iD, recorded in the report.
#' @param generated_at Timestamp recorded in the report (ISO 8601, UTC).
#' @return An object of class `ncvc_report`: a list with the structure of the
#'   JSON report of the web tool (schema `ncvc-report/1`). It has `print()`,
#'   `summary()` and `as.data.frame()` methods.
#' @seealso [narrative_cv()] to collect and map in one call.
#' @export
#' @examples
#' ex <- nc_example_evidence()
#' report <- nc_map(nc_framework("r4ri"), ex$evidence, ex$consulted,
#'                  orcid = "0000-0002-1825-0097")
#' report
#' summary(report)
nc_map <- function(framework, evidence, consulted, crosswalk = nc_crosswalk(),
                   orcid = NULL, generated_at = utc_now()) {
  if (!is.list(framework) || is.null(framework$sections)) stop("`framework` must come from nc_framework().", call. = FALSE)
  ok <- vapply(Filter(function(c) isTRUE(c$ok), consulted), function(c) c$source, "")
  sections <- lapply(framework$sections, function(section) {
    if (isTRUE(section$no_automated_source)) {
      return(list(id = section$id, name = section$name, status = "no_automated_source", mappings = list()))
    }
    ms <- Filter(function(m) m$framework == framework$id && m$section == section$id, crosswalk$mappings)
    mappings <- lapply(ms, function(m) {
      items <- Filter(function(e) nc_matches(m, e), evidence)
      list(id = m$id, contribution_type = m$contribution_type, source = m$source,
           evidence_type = m$evidence_type, coverage = m$coverage, limitations = m$limitations,
           source_available = m$source %in% ok, count = length(items), items = items)
    })
    counts <- vapply(mappings, function(m) m$count, 0L)
    full <- vapply(mappings, function(m) m$count > 0 && m$coverage == "full", TRUE)
    status <- if (any(counts > 0)) {
      if (any(full)) "found" else "partial"
    } else if (length(mappings) && !any(vapply(mappings, function(m) m$source_available, TRUE))) {
      "source_unavailable"
    } else {
      "not_found_in_sources"
    }
    list(id = section$id, name = section$name, status = status, mappings = mappings)
  })
  report <- list(schema = "ncvc-report/1", framework = framework$id,
                 mapping_version = crosswalk$mapping_version, orcid = orcid,
                 generated_at = generated_at, sources_consulted = consulted, sections = sections)
  structure(report, class = "ncvc_report", framework_name = framework$name)
}

#' Collect and map an ORCID iD in one call
#'
#' @param orcid An ORCID iD (bare or as a URL).
#' @param framework `"r4ri"` or `"cva-aei"`.
#' @param ... Passed to [nc_collect()].
#' @return An `ncvc_report`; see [nc_map()].
#' @export
#' @examples
#' \donttest{
#' report <- narrative_cv("0000-0002-1825-0097", "r4ri")
#' summary(report)
#' head(as.data.frame(report))
#' }
narrative_cv <- function(orcid, framework = c("r4ri", "cva-aei"), ...) {
  fw <- nc_framework(match.arg(framework))
  orcid <- nc_orcid(orcid)
  got <- nc_collect(orcid, ...)
  nc_map(fw, got$evidence, got$consulted, orcid = orcid)
}

#' Write a report as JSON
#'
#' Writes the report in the same format as the web tool's download, so that
#' assessments can be archived and compared.
#'
#' @param report An `ncvc_report`.
#' @param path File path.
#' @return `path`, invisibly.
#' @export
#' @examples
#' ex <- nc_example_evidence()
#' report <- nc_map(nc_framework("cva-aei"), ex$evidence, ex$consulted)
#' f <- tempfile(fileext = ".json")
#' nc_write_json(report, f)
#' unlink(f)
nc_write_json <- function(report, path) {
  jsonlite::write_json(unclass(report), path, auto_unbox = TRUE, null = "null",
                       na = "null", digits = NA, pretty = TRUE)
  invisible(path)
}
