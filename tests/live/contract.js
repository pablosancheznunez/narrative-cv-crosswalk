// Weekly contract check against the live APIs. A failure means a source
// changed shape or stopped answering; the maintenance workflow then tries a repair.
import { test } from "node:test";
import assert from "node:assert/strict";
import { fetchers } from "../../src/connectors.js";

const ORCID = "0000-0002-1825-0097";
const fetchFn = (url, opts) => fetch(url, { ...opts, headers: { ...opts?.headers, "User-Agent": "narrative-cv-crosswalk (live contract check)" } });

for (const source of Object.keys(fetchers)) {
  test(`live: ${source} answers with items of the expected shape`, async () => {
    const items = await fetchers[source](ORCID, fetchFn);
    assert.ok(items.length > 0, `${source} returned no items`);
    assert.ok(items.some((i) => i.title), `${source} items have no titles`);
    assert.ok(items.every((i) => i.year === null || Number.isInteger(i.year)));
  });
}
