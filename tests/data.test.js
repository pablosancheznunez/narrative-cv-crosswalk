import { test } from "node:test";
import assert from "node:assert/strict";
import { crosswalk, frameworks, sources } from "./helpers.js";

test("mapping ids are unique", () => {
  const ids = crosswalk.mappings.map((m) => m.id);
  assert.equal(new Set(ids).size, ids.length);
});

test("every mapping points to an existing framework section and source record", () => {
  for (const m of crosswalk.mappings) {
    const fw = frameworks.find((f) => f.id === m.framework);
    assert.ok(fw, `${m.id}: unknown framework ${m.framework}`);
    assert.ok(fw.sections.some((s) => s.id === m.section), `${m.id}: unknown section ${m.section}`);
    assert.ok(sources[m.source]?.records.includes(m.record), `${m.id}: unknown record ${m.source}/${m.record}`);
    assert.ok(m.id.startsWith(`${m.framework}.${m.section}.${m.source}.`), `${m.id}: id must start with framework.section.source`);
  }
});

test("every section has a mapping or is explicitly narrative", () => {
  for (const fw of frameworks) {
    for (const s of fw.sections) {
      const n = crosswalk.mappings.filter((m) => m.framework === fw.id && m.section === s.id).length;
      if (s.no_automated_source) assert.equal(n, 0, `${fw.id}/${s.id} is narrative but has mappings`);
      else assert.ok(n > 0, `${fw.id}/${s.id} has no mapping and is not marked no_automated_source`);
    }
  }
});
