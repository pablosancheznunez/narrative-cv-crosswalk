# Connectors to ORCID, OpenAlex, DataCite and OpenAIRE. They mirror
# src/connectors.js line for line: every item is
# list(source, record, type, title, year, url).

affiliations <- c("employments", "educations", "qualifications",
                  "invited-positions", "distinctions", "memberships", "services")

#' Check an ORCID iD
#'
#' @param id A bare ORCID iD such as `"0000-0002-1825-0097"`.
#' @return `TRUE` if the format and the ISO 7064 check digit are valid.
#' @export
#' @examples
#' nc_valid_orcid("0000-0002-1825-0097")
nc_valid_orcid <- function(id) {
  if (!is.character(id) || length(id) != 1 ||
      !grepl("^\\d{4}-\\d{4}-\\d{4}-\\d{3}[0-9X]$", id)) return(FALSE)
  digits <- strsplit(gsub("-", "", id), "")[[1]]
  total <- 0
  for (d in digits[1:15]) total <- (total + as.integer(d)) * 2
  check <- (12 - (total %% 11)) %% 11
  digits[16] == if (check == 10) "X" else as.character(check)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

ev_item <- function(source, record, type, title, year, url) {
  year <- suppressWarnings(as.integer(year %||% NA))
  list(source = source, record = record, type = type %||% NULL,
       title = title %||% NULL,
       year = if (length(year) == 1 && !is.na(year)) year else NULL,
       url = url %||% NULL)
}

date_year <- function(d) d$year$value

doi_url <- function(external_ids) {
  for (x in external_ids[["external-id"]] %||% list()) {
    if (identical(x[["external-id-type"]], "doi")) {
      return(paste0("https://doi.org/", x[["external-id-value"]]))
    }
  }
  NULL
}

nonempty <- function(x) {
  x <- unlist(x)
  x[nzchar(x)]
}

#' Normalize recorded API responses
#'
#' Turn a parsed JSON response (`jsonlite::fromJSON(simplifyVector = FALSE)`)
#' into evidence items.
#'
#' @param json A parsed response.
#' @return A list of evidence items.
#' @name normalize
NULL

#' @rdname normalize
#' @export
nc_normalize_orcid <- function(json) {
  out <- list()
  nm <- json$person$name
  full <- paste(nonempty(list(nm[["given-names"]]$value, nm[["family-name"]]$value)), collapse = " ")
  if (!nzchar(full)) full <- json[["orcid-identifier"]]$path
  out[[1]] <- ev_item("orcid", "person", NULL, full, NULL, json[["orcid-identifier"]]$uri)

  acts <- json[["activities-summary"]] %||% list()
  for (g in acts$works$group %||% list()) {
    w <- g[["work-summary"]][[1]]
    if (is.null(w)) next
    out[[length(out) + 1]] <- ev_item("orcid", "works", w$type, w$title$title$value,
                                      date_year(w[["publication-date"]]),
                                      w$url$value %||% doi_url(w[["external-ids"]]))
  }
  for (g in acts[["peer-reviews"]]$group %||% list()) {
    for (prg in g[["peer-review-group"]] %||% list()) {
      for (r in prg[["peer-review-summary"]] %||% list()) {
        out[[length(out) + 1]] <- ev_item("orcid", "peer-reviews", r[["reviewer-role"]] %||% "reviewer",
                                          r[["convening-organization"]]$name %||% r[["review-group-id"]],
                                          date_year(r[["completion-date"]]), r[["review-url"]]$value)
      }
    }
  }
  for (g in acts$fundings$group %||% list()) {
    f <- g[["funding-summary"]][[1]]
    if (is.null(f)) next
    out[[length(out) + 1]] <- ev_item("orcid", "fundings", f$type, f$title$title$value,
                                      date_year(f[["start-date"]]), f$url$value)
  }
  for (rec in affiliations) {
    for (g in acts[[rec]][["affiliation-group"]] %||% list()) {
      for (wrapper in g$summaries %||% list()) {
        s <- wrapper[[1]]
        title <- paste(nonempty(list(s[["role-title"]], s[["department-name"]], s$organization$name)), collapse = ", ")
        out[[length(out) + 1]] <- ev_item("orcid", rec, NULL, title, date_year(s[["start-date"]]), s$url$value)
      }
    }
  }
  out
}

#' @rdname normalize
#' @export
nc_normalize_openalex <- function(json) {
  lapply(json$results %||% list(), function(w) {
    ev_item("openalex", "works", w$type, w$title, w$publication_year, w$doi %||% w$id)
  })
}

#' @rdname normalize
#' @export
nc_normalize_datacite <- function(json) {
  lapply(json$data %||% list(), function(d) {
    a <- d$attributes %||% list()
    url <- if (!is.null(a$doi)) paste0("https://doi.org/", a$doi) else a$url
    ev_item("datacite", "dois", a$types$resourceTypeGeneral, a$titles[[1]]$title, a$publicationYear, url)
  })
}

#' @rdname normalize
#' @export
nc_normalize_openaire <- function(json) {
  lapply(json$results %||% list(), function(r) {
    doi <- Filter(function(p) identical(p$scheme, "doi"), r$pids %||% list())
    url <- if (length(doi)) paste0("https://doi.org/", doi[[1]]$value) else
      paste0("https://explore.openaire.eu/search/result?id=", utils::URLencode(r$id, reserved = TRUE))
    year <- if (!is.null(r$publicationDate)) substr(r$publicationDate, 1, 4) else NULL
    ev_item("openaire", "products", r$type, r$mainTitle, year, url)
  })
}

get_json <- function(url) {
  h <- curl::new_handle()
  curl::handle_setheaders(h, Accept = "application/json",
                          `User-Agent` = "narrativecv R package (https://github.com/pablosancheznunez/narrative-cv-crosswalk)")
  res <- curl::curl_fetch_memory(url, handle = h)
  if (res$status_code >= 400) stop(res$status_code, " for ", url, call. = FALSE)
  jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE)
}

max_pages <- 5

fetchers <- list(
  orcid = function(orcid) nc_normalize_orcid(get_json(paste0("https://pub.orcid.org/v3.0/", orcid, "/record"))),
  openalex = function(orcid) {
    items <- list()
    for (page in seq_len(max_pages)) {
      json <- get_json(sprintf("https://api.openalex.org/works?filter=author.orcid:%s&per-page=200&page=%d&select=id,doi,title,type,publication_year,open_access", orcid, page))
      items <- c(items, nc_normalize_openalex(json))
      if (length(items) >= (json$meta$count %||% 0) || !length(json$results)) break
    }
    items
  },
  datacite = function(orcid) nc_normalize_datacite(get_json(paste0("https://api.datacite.org/dois?user-id=", orcid, "&page[size]=1000"))),
  openaire = function(orcid) {
    items <- list()
    for (page in seq_len(max_pages)) {
      json <- get_json(sprintf("https://api.openaire.eu/graph/v1/researchProducts?authorOrcid=%s&pageSize=100&page=%d", orcid, page))
      items <- c(items, nc_normalize_openaire(json))
      if (length(items) >= (json$header$numFound %||% 0) || !length(json$results)) break
    }
    items
  }
)

#' Collect evidence for an ORCID iD
#'
#' Queries ORCID, OpenAlex, DataCite and the OpenAIRE Graph. A source that
#' fails is reported in `consulted`, never fatal.
#'
#' @param orcid A bare ORCID iD.
#' @param sources Which sources to query.
#' @return A list with `evidence` (items) and `consulted` (one entry per source).
#' @export
nc_collect <- function(orcid, sources = names(fetchers)) {
  if (!nc_valid_orcid(orcid)) stop("Not a valid ORCID iD: ", orcid, call. = FALSE)
  evidence <- list()
  consulted <- lapply(sources, function(s) {
    res <- tryCatch(fetchers[[s]](orcid), error = function(e) e)
    ok <- !inherits(res, "error")
    if (ok) evidence <<- c(evidence, res)
    list(source = s, ok = ok, count = if (ok) length(res) else 0L,
         error = if (ok) NULL else conditionMessage(res),
         retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  })
  list(evidence = evidence, consulted = consulted)
}
