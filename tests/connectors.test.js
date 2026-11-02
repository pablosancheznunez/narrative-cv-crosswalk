import { test } from "node:test";
import assert from "node:assert/strict";
import { collectEvidence, isValidOrcid, normalizeDatacite, normalizeOpenaire, normalizeOpenalex, normalizeOrcid } from "../src/connectors.js";
import { load } from "./helpers.js";

const KEYS = ["record", "source", "title", "type", "url", "year"];

test("ORCID checksum", () => {
  assert.ok(isValidOrcid("0000-0002-1825-0097"));
  assert.ok(isValidOrcid("0000-0001-5109-3700"));
  assert.ok(isValidOrcid("0000-0002-1694-233X"));
  assert.ok(!isValidOrcid("0000-0002-1825-0098"));
  assert.ok(!isValidOrcid("https://orcid.org/0000-0002-1825-0097"));
});

const normalizers = { orcid: normalizeOrcid, openalex: normalizeOpenalex, datacite: normalizeDatacite, openaire: normalizeOpenaire };

for (const [name, normalize] of Object.entries(normalizers)) {
  test(`${name}: recorded response normalizes to evidence items`, () => {
    const items = normalize(load(`tests/fixtures/${name}.json`));
    assert.ok(items.length > 0);
    for (const it of items) {
      assert.deepEqual(Object.keys(it).sort(), KEYS);
      assert.equal(it.source, name);
      assert.ok(it.year === null || Number.isInteger(it.year));
    }
  });
}

test("ORCID record yields person, works, employments and peer reviews", () => {
  const items = normalizeOrcid(load("tests/fixtures/orcid.json"));
  const count = (r) => items.filter((i) => i.record === r).length;
  assert.equal(count("person"), 1);
  assert.equal(items.find((i) => i.record === "person").title, "Josiah Carberry");
  assert.equal(count("works"), 6);
  assert.equal(count("employments"), 2);
  assert.ok(count("peer-reviews") >= 1);
});

test("a failing source is reported, not fatal", async () => {
  const fetchFn = async (url) => {
    if (url.includes("openalex")) return { ok: false, status: 503, statusText: "Unavailable" };
    const name = ["orcid", "datacite", "openaire"].find((n) => url.includes(n));
    return { ok: true, json: async () => load(`tests/fixtures/${name}.json`) };
  };
  const { evidence, consulted } = await collectEvidence("0000-0002-1825-0097", { fetchFn, now: () => "t" });
  const ox = consulted.find((c) => c.source === "openalex");
  assert.equal(ox.ok, false);
  assert.match(ox.error, /503/);
  assert.ok(evidence.some((e) => e.source === "orcid"));
});

test("an invalid ORCID iD is rejected before any request", async () => {
  await assert.rejects(collectEvidence("1234", { fetchFn: () => assert.fail("no request expected") }));
});
