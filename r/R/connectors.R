# Connectors to ORCID, OpenAlex, DataCite and the OpenAIRE Graph. They mirror
# src/connectors.js: every evidence item is
# list(source, record, type, title, year, url).

nc_sources <- c("orcid", "openalex", "datacite", "openaire")

affiliations <- c("employments", "educations", "qualifications",
                  "invited-positions", "distinctions", "memberships", "services")

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Validate and normalise an ORCID iD
#'
#' `nc_valid_orcid()` checks the format and the ISO 7064 11,2 check digit.
#' `nc_orcid()` also accepts the `https://orcid.org/` form and returns the bare
#' identifier, or fails with an informative error.
#'
#' @param id An ORCID iD, bare (`"0000-0002-1825-0097"`) or as a URL.
#' @return `nc_valid_orcid()`: `TRUE` or `FALSE`. `nc_orcid()`: the bare iD.
#' @export
#' @examples
#' nc_valid_orcid("0000-0002-1825-0097")
#' nc_valid_orcid("0000-0002-1825-0098")
#' nc_orcid("https://orcid.org/0000-0002-1825-0097")
nc_valid_orcid <- function(id) {
  if (!is.character(id) || length(id) != 1 || is.na(id) ||
      !grepl("^\\d{4}-\\d{4}-\\d{4}-\\d{3}[0-9X]$", id)) return(FALSE)
  digits <- strsplit(gsub("-", "", id), "")[[1]]
  total <- 0
  for (d in digits[1:15]) total <- (total + as.integer(d)) * 2
  check <- (12 - (total %% 11)) %% 11
  digits[16] == if (check == 10) "X" else as.character(check)
}

#' @rdname nc_valid_orcid
#' @export
nc_orcid <- function(id) {
  bare <- sub("^https?://(www\\.)?orcid\\.org/", "", trimws(as.character(id)[1]))
  if (!nc_valid_orcid(bare)) stop("Not a valid ORCID iD: ", id, call. = FALSE)
  bare
}

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

#' Normalise API responses into evidence items
#'
#' Turn a parsed JSON response (from `jsonlite::fromJSON(simplifyVector =
#' FALSE)`) into a list of evidence items, each a list with `source`,
#' `record`, `type`, `title`, `year` and `url`. These functions do not use the
#' network; [nc_collect()] calls them on live responses.
#'
#' @param json A parsed response of the corresponding API.
#' @return A list of evidence items.
#' @name normalize
#' @examples
#' ex <- system.file("extdata", "examples", "orcid.json", package = "narrativecv")
#' items <- nc_normalize_orcid(jsonlite::fromJSON(ex, simplifyVector = FALSE))
#' length(items)
#' items[[1]]
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

user_agent <- function() {
  paste0("narrativecv/", utils::packageVersion("narrativecv"),
         " (https://github.com/pablosancheznunez/narrative-cv-crosswalk)")
}

get_json <- function(url, timeout) {
  h <- curl::new_handle(timeout = timeout, useragent = user_agent())
  curl::handle_setheaders(h, Accept = "application/json")
  res <- curl::curl_fetch_memory(url, handle = h)
  if (res$status_code >= 400) stop("HTTP ", res$status_code, " for ", url, call. = FALSE)
  jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE)
}

max_pages <- 5

fetch_source <- function(source, orcid, timeout, mailto) {
  polite <- if (is.null(mailto)) "" else paste0("&mailto=", utils::URLencode(mailto, reserved = TRUE))
  switch(source,
    orcid = nc_normalize_orcid(get_json(paste0("https://pub.orcid.org/v3.0/", orcid, "/record"), timeout)),
    openalex = {
      # Basic paging: OpenAlex requires an API key for cursor paging.
      items <- list()
      for (page in seq_len(max_pages)) {
        json <- get_json(sprintf("https://api.openalex.org/works?filter=author.orcid:%s&per-page=200&page=%d&select=id,doi,title,type,publication_year,open_access%s",
                                 orcid, page, polite), timeout)
        items <- c(items, nc_normalize_openalex(json))
        if (length(items) >= (json$meta$count %||% 0) || !length(json$results)) break
      }
      items
    },
    datacite = nc_normalize_datacite(get_json(paste0("https://api.datacite.org/dois?user-id=", orcid, "&page[size]=1000"), timeout)),
    openaire = {
      items <- list()
      for (page in seq_len(max_pages)) {
        json <- get_json(sprintf("https://api.openaire.eu/graph/v1/researchProducts?authorOrcid=%s&pageSize=100&page=%d", orcid, page), timeout)
        items <- c(items, nc_normalize_openaire(json))
        if (length(items) >= (json$header$numFound %||% 0) || !length(json$results)) break
      }
      items
    }
  )
}

utc_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

#' Collect evidence for an ORCID iD
#'
#' Queries the public APIs of ORCID, OpenAlex, DataCite and the OpenAIRE Graph.
#' A source that fails or times out is reported in `consulted` with its error;
#' it never stops the collection. Up to 1000 works are read from OpenAlex and
#' OpenAIRE, and 1000 DOIs from DataCite.
#'
#' @param orcid An ORCID iD (bare or as a URL).
#' @param sources Sources to query; any of `"orcid"`, `"openalex"`,
#'   `"datacite"`, `"openaire"`.
#' @param timeout Seconds before a request is abandoned.
#' @param mailto Optional contact e-mail sent to OpenAlex, which gives access
#'   to its faster "polite pool". Defaults to the option `narrativecv.mailto`.
#' @return A list with `evidence` (evidence items, see [normalize]) and
#'   `consulted` (one entry per source with `ok`, `count`, `error` and
#'   `retrieved_at`).
#' @seealso [nc_map()], [narrative_cv()]
#' @export
#' @examples
#' \donttest{
#' got <- nc_collect("0000-0002-1825-0097", sources = "orcid")
#' got$consulted
#' }
nc_collect <- function(orcid, sources = nc_sources, timeout = 30,
                       mailto = getOption("narrativecv.mailto")) {
  orcid <- nc_orcid(orcid)
  sources <- match.arg(sources, nc_sources, several.ok = TRUE)
  evidence <- list()
  consulted <- lapply(sources, function(s) {
    res <- tryCatch(fetch_source(s, orcid, timeout, mailto), error = function(e) e)
    ok <- !inherits(res, "error")
    if (ok) evidence <<- c(evidence, res)
    list(source = s, ok = ok, count = if (ok) length(res) else 0L,
         error = if (ok) NULL else conditionMessage(res),
         retrieved_at = utc_now())
  })
  failed <- vapply(Filter(function(c) !c$ok, consulted), function(c) c$source, "")
  if (length(failed)) {
    message("Could not reach: ", paste(failed, collapse = ", "),
            ". Sections that rely only on them are reported as 'source_unavailable'.")
  }
  list(evidence = evidence, consulted = consulted)
}
