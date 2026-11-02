#' Crosswalk data
#'
#' The frameworks, mappings and source descriptions shipped with the package.
#' They are identical to the files in the repository's `data/` folder (a test
#' in the repository fails if they drift apart).
#'
#' @param id Framework id: `"r4ri"` or `"cva-aei"`.
#' @return A list parsed from JSON.
#' @name crosswalk-data
NULL

read_extdata <- function(...) {
  path <- system.file("extdata", ..., package = "narrativecv", mustWork = TRUE)
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

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
