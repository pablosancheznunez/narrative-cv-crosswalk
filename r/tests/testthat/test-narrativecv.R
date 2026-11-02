example <- function(name) {
  jsonlite::fromJSON(system.file("extdata", "examples", paste0(name, ".json"), package = "narrativecv"),
                     simplifyVector = FALSE)
}
expected <- function(id) {
  jsonlite::fromJSON(test_path("fixtures", paste0("carberry-", id, ".json")), simplifyVector = FALSE)
}
canonical <- function(x) {
  jsonlite::fromJSON(jsonlite::toJSON(unclass(x), auto_unbox = TRUE, null = "null", na = "null", digits = NA),
                     simplifyVector = FALSE)
}

test_that("ORCID iDs are validated and normalised", {
  expect_true(nc_valid_orcid("0000-0002-1825-0097"))
  expect_true(nc_valid_orcid("0000-0002-1694-233X"))
  expect_false(nc_valid_orcid("0000-0002-1825-0098"))
  expect_false(nc_valid_orcid(NA_character_))
  expect_false(nc_valid_orcid(c("0000-0002-1825-0097", "0000-0002-1825-0097")))
  expect_equal(nc_orcid("https://orcid.org/0000-0002-1825-0097"), "0000-0002-1825-0097")
  expect_error(nc_orcid("1234"), "Not a valid ORCID")
})

test_that("recorded responses normalise to evidence items", {
  for (src in c("orcid", "openalex", "datacite", "openaire")) {
    items <- get(paste0("nc_normalize_", src))(example(src))
    expect_gt(length(items), 0)
    for (it in items) {
      expect_named(it, c("source", "record", "type", "title", "year", "url"))
      expect_equal(it$source, src)
      expect_true(is.null(it$year) || is.integer(it$year))
    }
  }
})

test_that("ORCID record yields person, works and employments", {
  items <- nc_normalize_orcid(example("orcid"))
  records <- vapply(items, function(i) i$record, "")
  expect_equal(sum(records == "person"), 1)
  expect_equal(items[[1]]$title, "Josiah Carberry")
  expect_equal(sum(records == "works"), 6)
  expect_equal(sum(records == "employments"), 2)
})

test_that("normalisers tolerate empty responses", {
  expect_equal(nc_normalize_openalex(list()), list())
  expect_equal(nc_normalize_datacite(list(data = list())), list())
  expect_length(nc_normalize_orcid(list(`orcid-identifier` = list(path = "x"))), 1)
})

test_that("every section has a mapping or is narrative", {
  tab <- nc_crosswalk_table()
  for (id in nc_frameworks()) {
    for (s in nc_framework(id)$sections) {
      n <- sum(tab$framework == id & tab$section == s$id)
      if (isTRUE(s$no_automated_source)) expect_equal(n, 0) else expect_gt(n, 0)
    }
  }
  expect_false(anyDuplicated(tab$id) > 0)
})

for (id in nc_frameworks()) {
  test_that(paste("report matches the JavaScript engine exactly:", id), {
    ex <- nc_example_evidence()
    report <- nc_map(nc_framework(id), ex$evidence, ex$consulted, orcid = "0000-0002-1825-0097",
                     generated_at = "2026-11-02T00:00:00Z")
    expect_s3_class(report, "ncvc_report")
    expect_equal(canonical(report), expected(id))
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

test_that("methods summarise the report", {
  ex <- nc_example_evidence()
  report <- nc_map(nc_framework("cva-aei"), ex$evidence, ex$consulted, generated_at = "t")
  s <- summary(report)
  expect_equal(nrow(s), length(nc_framework("cva-aei")$sections))
  expect_equal(s$status[s$section == "b-summary"], "no_automated_source")
  df <- as.data.frame(report)
  expect_equal(nrow(df), sum(s$items))
  expect_output(print(report), "Not found does not mean it does not exist")
  empty <- nc_map(nc_framework("r4ri"), list(), ex$consulted, generated_at = "t")
  expect_equal(nrow(as.data.frame(empty)), 0)
})

test_that("reports are written as JSON", {
  ex <- nc_example_evidence()
  report <- nc_map(nc_framework("r4ri"), ex$evidence, ex$consulted, generated_at = "t")
  f <- tempfile(fileext = ".json")
  on.exit(unlink(f))
  nc_write_json(report, f)
  expect_equal(jsonlite::fromJSON(f)$schema, "ncvc-report/1")
})

test_that("an unreachable source is reported, not raised", {
  skip_on_cran()
  skip_if_offline("pub.orcid.org")
  got <- suppressMessages(nc_collect("0000-0002-1825-0097", sources = "orcid", timeout = 30))
  expect_true(got$consulted[[1]]$ok)
  expect_gt(got$consulted[[1]]$count, 0)
})
