import { test } from "node:test";
import assert from "node:assert/strict";
import { mapEvidence, reportRows, toCsv } from "../src/engine.js";

const framework = {
  id: "fw",
  sections: [
    { id: "a", name: "A", no_automated_source: false },
    { id: "b", name: "B", no_automated_source: false },
    { id: "c", name: "C", no_automated_source: true },
    { id: "d", name: "D", no_automated_source: false },
  ],
};
const crosswalk = {
  mapping_version: "9.9.9",
  mappings: [
    { id: "fw.a.orcid.works", framework: "fw", section: "a", source: "orcid", record: "works", types: ["journal-article"], coverage: "partial" },
    { id: "fw.a.orcid.person", framework: "fw", section: "a", source: "orcid", record: "person", coverage: "full" },
    { id: "fw.b.openalex.works", framework: "fw", section: "b", source: "openalex", record: "works", coverage: "partial" },
    { id: "fw.d.datacite.dois", framework: "fw", section: "d", source: "datacite", record: "dois", coverage: "partial" },
  ],
};
const e = (source, record, type) => ({ source, record, type, title: "t", year: 2020, url: null });
const allOk = ["orcid", "openalex", "datacite"].map((source) => ({ source, ok: true }));
const run = (evidence, consulted = allOk) => mapEvidence({ framework, crosswalk, evidence, consulted, generatedAt: "2026-01-01T00:00:00Z" });
const status = (report, id) => report.sections.find((s) => s.id === id).status;

test("full-coverage evidence makes a section found", () => {
  assert.equal(status(run([e("orcid", "person", null)]), "a"), "found");
});

test("only partial-coverage evidence makes a section partial", () => {
  assert.equal(status(run([e("orcid", "works", "journal-article")]), "a"), "partial");
});

test("types filter excludes other types", () => {
  assert.equal(status(run([e("orcid", "works", "patent")]), "a"), "not_found_in_sources");
});

test("narrative sections are never searched", () => {
  const r = run([e("orcid", "person", null)]);
  assert.equal(status(r, "c"), "no_automated_source");
  assert.deepEqual(r.sections.find((s) => s.id === "c").mappings, []);
});

test("a section whose only source failed is source_unavailable, not absent", () => {
  const consulted = [{ source: "orcid", ok: true }, { source: "openalex", ok: true }, { source: "datacite", ok: false }];
  assert.equal(status(run([], consulted), "d"), "source_unavailable");
});

test("CSV export has one row per evidence item and escapes commas", () => {
  const csv = toCsv(reportRows(run([{ ...e("orcid", "person", null), title: "Doe, Jane" }])));
  assert.equal(csv.trim().split("\n").length, 2);
  assert.match(csv, /"Doe, Jane"/);
});
