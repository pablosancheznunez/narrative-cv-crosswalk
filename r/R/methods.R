#' Inspect a narrative CV report
#'
#' `print()` shows the sources consulted and the status of every section.
#' `summary()` returns one row per section. `as.data.frame()` returns one row
#' per evidence item, with the same columns as the web tool's CSV export.
#'
#' @param x,object An `ncvc_report` from [nc_map()] or [narrative_cv()].
#' @param row.names,optional Ignored; present for compatibility.
#' @param ... Ignored.
#' @return `print()`: `x`, invisibly. `summary()` and `as.data.frame()`: a
#'   data frame.
#' @name ncvc_report
#' @examples
#' ex <- nc_example_evidence()
#' report <- nc_map(nc_framework("cva-aei"), ex$evidence, ex$consulted)
#' print(report)
#' summary(report)
#' head(as.data.frame(report)[, c("section", "source", "title", "year")])
NULL

#' @rdname ncvc_report
#' @export
print.ncvc_report <- function(x, ...) {
  name <- attr(x, "framework_name") %||% x$framework
  cat("Narrative CV evidence report\n")
  cat("Framework:   ", name, "\n", sep = "")
  if (!is.null(x$orcid)) cat("ORCID iD:    ", x$orcid, "\n", sep = "")
  cat("Crosswalk:   version ", x$mapping_version, ", generated ", x$generated_at, "\n", sep = "")
  src <- vapply(x$sources_consulted, function(c) {
    if (isTRUE(c$ok)) paste0(c$source, " (", c$count, ")") else paste0(c$source, " (unavailable)")
  }, "")
  cat("Sources:     ", paste(src, collapse = ", "), "\n\n", sep = "")
  s <- summary(x)
  width <- max(nchar(s$section))
  for (i in seq_len(nrow(s))) {
    cat(formatC(s$section[i], width = -width), "  ", formatC(s$status[i], width = -21),
        if (s$status[i] == "no_automated_source") "narrative only" else paste(s$items[i], "items"), "\n", sep = "")
  }
  cat("\nNot found does not mean it does not exist: sources only hold what is linked to the ORCID iD.\n")
  invisible(x)
}

#' @rdname ncvc_report
#' @export
summary.ncvc_report <- function(object, ...) {
  data.frame(
    section = vapply(object$sections, function(s) s$id, ""),
    status = vapply(object$sections, function(s) s$status, ""),
    mappings = vapply(object$sections, function(s) length(s$mappings), 0L),
    items = vapply(object$sections, function(s) sum(vapply(s$mappings, function(m) m$count, 0L)), 0L),
    stringsAsFactors = FALSE
  )
}

#' @rdname ncvc_report
#' @export
as.data.frame.ncvc_report <- function(x, row.names = NULL, optional = FALSE, ...) {
  na <- function(v) if (is.null(v)) NA else v
  rows <- list()
  for (s in x$sections) for (m in s$mappings) for (e in m$items) {
    rows[[length(rows) + 1]] <- data.frame(
      section = s$id, section_status = s$status, mapping = m$id,
      evidence_type = m$evidence_type, coverage = m$coverage, source = e$source,
      record = e$record, type = na(e$type), title = na(e$title), year = na(e$year),
      url = na(e$url), stringsAsFactors = FALSE)
  }
  if (!length(rows)) {
    return(data.frame(section = character(), section_status = character(), mapping = character(),
                      evidence_type = character(), coverage = character(), source = character(),
                      record = character(), type = character(), title = character(),
                      year = integer(), url = character(), stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}

#' @rdname ncvc_report
#' @export
nc_report_table <- function(x) as.data.frame.ncvc_report(x)
