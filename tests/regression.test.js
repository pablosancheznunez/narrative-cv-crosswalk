// Recorded responses for ORCID's public test record (Josiah Carberry) must keep
// producing exactly the stored reports. The expected files are high risk:
// only a person regenerates them, with UPDATE=1 node --test tests/regression.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { normalizeDatacite, normalizeOpenaire, normalizeOpenalex, normalizeOrcid } from "../src/connectors.js";
import { mapEvidence } from "../src/engine.js";
import { crosswalk, frameworks, load, rootPath } from "./helpers.js";

const evidence = [
  ...normalizeOrcid(load("tests/fixtures/orcid.json")),
  ...normalizeOpenalex(load("tests/fixtures/openalex.json")),
  ...normalizeDatacite(load("tests/fixtures/datacite.json")),
  ...normalizeOpenaire(load("tests/fixtures/openaire.json")),
];
const consulted = ["orcid", "openalex", "datacite", "openaire"].map((source) => ({
  source,
  ok: true,
  count: evidence.filter((e) => e.source === source).length,
  error: null,
  retrieved_at: "2026-11-02T00:00:00Z",
}));

for (const framework of frameworks) {
  test(`regression: ${framework.id} report for the ORCID test record`, () => {
    const report = mapEvidence({ framework, crosswalk, evidence, consulted, orcid: "0000-0002-1825-0097", generatedAt: "2026-11-02T00:00:00Z" });
    const file = `tests/regression/carberry-${framework.id}.json`;
    if (process.env.UPDATE) writeFileSync(rootPath(file), JSON.stringify(report, null, 1) + "\n");
    assert.deepEqual(report, load(file));
  });
}
