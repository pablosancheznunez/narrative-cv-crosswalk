fixture <- function(name) {
  jsonlite::fromJSON(test_path("fixtures", paste0(name, ".json")), simplifyVector = FALSE)
}

test_that("ORCID checksum", {
  expect_true(nc_valid_orcid("0000-0002-1825-0097"))
  expect_true(nc_valid_orcid("0000-0002-1694-233X"))
  expect_false(nc_valid_orcid("0000-0002-1825-0098"))
  expect_false(nc_valid_orcid("https://orcid.org/0000-0002-1825-0097"))
})

test_that("recorded responses normalize to evidence items", {
  for (src in c("orcid", "openalex", "datacite", "openaire")) {
    items <- get(paste0("nc_normalize_", src))(fixture(src))
    expect_gt(length(items), 0)
    for (it in items) {
      expect_named(it, c("source", "record", "type", "title", "year", "url"))
      expect_equal(it$source, src)
    }
  }
})

test_that("ORCID record yields person, works and employments", {
  items <- nc_normalize_orcid(fixture("orcid"))
  records <- vapply(items, function(i) i$record, "")
  expect_equal(sum(records == "person"), 1)
  expect_equal(items[[1]]$title, "Josiah Carberry")
  expect_equal(sum(records == "works"), 6)
  expect_equal(sum(records == "employments"), 2)
})

test_that("every section has a mapping or is narrative", {
  cw <- nc_crosswalk()
  for (id in nc_frameworks()) {
    fw <- nc_framework(id)
    for (s in fw$sections) {
      n <- sum(vapply(cw$mappings, function(m) m$framework == id && m$section == s$id, TRUE))
      if (isTRUE(s$no_automated_source)) expect_equal(n, 0) else expect_gt(n, 0)
    }
  }
})

# Conformance with the JavaScript engine: same fixtures, same expected reports.
evidence <- c(nc_normalize_orcid(fixture("orcid")), nc_normalize_openalex(fixture("openalex")),
              nc_normalize_datacite(fixture("datacite")), nc_normalize_openaire(fixture("openaire")))
consulted <- lapply(c("orcid", "openalex", "datacite", "openaire"), function(s) {
  list(source = s, ok = TRUE, count = sum(vapply(evidence, function(e) e$source == s, TRUE)),
       error = NULL, retrieved_at = "2026-11-02T00:00:00Z")
})
canonical <- function(x) {
  jsonlite::fromJSON(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA),
                     simplifyVector = FALSE)
}

for (id in nc_frameworks()) {
  test_that(paste("regression report matches the JavaScript engine:", id), {
    report <- nc_map(nc_framework(id), evidence, consulted, orcid = "0000-0002-1825-0097",
                     generated_at = "2026-11-02T00:00:00Z")
    expect_equal(canonical(report), fixture(paste0("carberry-", id)))
  })
}

test_that("a section whose only source failed is source_unavailable", {
  fw <- list(id = "fw", sections = list(list(id = "d", name = "D", no_automated_source = FALSE)))
  cw <- list(mapping_version = "9", mappings = list(list(id = "fw.d.datacite.dois", framework = "fw", section = "d",
    contribution_type = "x", source = "datacite", record = "dois", evidence_type = "direct",
    coverage = "partial", limitations = "x")))
  r <- nc_map(fw, list(), list(list(source = "datacite", ok = FALSE)), crosswalk = cw, generated_at = "t")
  expect_equal(r$sections[[1]]$status, "source_unavailable")
})
