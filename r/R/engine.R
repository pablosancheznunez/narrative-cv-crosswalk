# Mirrors src/engine.js. Both must produce identical reports for the same
# input; tests compare each against the same expected files.

nc_matches <- function(mapping, e) {
  identical(e$source, mapping$source) && identical(e$record, mapping$record) &&
    (is.null(mapping$types) || (!is.null(e$type) && e$type %in% unlist(mapping$types)))
}

#' Map evidence onto a narrative CV framework
#'
#' @param framework A framework from [nc_framework()].
#' @param evidence,consulted As returned by [nc_collect()].
#' @param crosswalk Mappings from [nc_crosswalk()].
#' @param orcid The ORCID iD, recorded in the report.
#' @param generated_at Timestamp recorded in the report.
#' @return A report list with the same structure as the JSON report of the web
#'   tool (schema `ncvc-report/1`).
#' @export
nc_map <- function(framework, evidence, consulted, crosswalk = nc_crosswalk(),
                   orcid = NULL,
                   generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
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
  list(schema = "ncvc-report/1", framework = framework$id,
       mapping_version = crosswalk$mapping_version, orcid = orcid,
       generated_at = generated_at, sources_consulted = consulted, sections = sections)
}

#' Report as a data frame
#'
#' One row per evidence item, the same columns as the web tool's CSV export.
#'
#' @param report A report from [nc_map()].
#' @return A data frame.
#' @export
nc_report_table <- function(report) {
  rows <- list()
  na <- function(x) if (is.null(x)) NA else x
  for (s in report$sections) for (m in s$mappings) for (e in m$items) {
    rows[[length(rows) + 1]] <- data.frame(
      section = s$id, section_status = s$status, mapping = m$id,
      evidence_type = m$evidence_type, coverage = m$coverage, source = e$source,
      record = e$record, type = na(e$type), title = na(e$title), year = na(e$year),
      url = na(e$url), stringsAsFactors = FALSE)
  }
  if (!length(rows)) return(data.frame())
  do.call(rbind, rows)
}

#' Map an ORCID iD in one call
#'
#' @param orcid A bare ORCID iD.
#' @param framework `"r4ri"` or `"cva-aei"`.
#' @return A report list; see [nc_map()].
#' @export
#' @examples
#' \dontrun{
#' report <- narrative_cv("0000-0002-1825-0097", "r4ri")
#' head(nc_report_table(report))
#' }
narrative_cv <- function(orcid, framework = c("r4ri", "cva-aei")) {
  fw <- nc_framework(match.arg(framework))
  got <- nc_collect(orcid)
  nc_map(fw, got$evidence, got$consulted, orcid = orcid)
}
