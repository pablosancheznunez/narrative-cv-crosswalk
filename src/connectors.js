// Connectors to the four open infrastructures. Each source has a pure
// normalize function (tested against recorded responses) and a fetch function
// that works in browsers and in Node 18+. Every item is normalized to:
// { source, record, type, title, year, url }

const AFFILIATIONS = [
  "employments",
  "educations",
  "qualifications",
  "invited-positions",
  "distinctions",
  "memberships",
  "services",
];

export function isValidOrcid(id) {
  if (!/^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$/.test(id)) return false;
  const digits = id.replace(/-/g, "");
  let total = 0;
  for (const ch of digits.slice(0, 15)) total = (total + Number(ch)) * 2;
  const check = (12 - (total % 11)) % 11;
  return digits[15] === (check === 10 ? "X" : String(check));
}

const year = (date) => {
  const y = date?.year?.value;
  return y ? Number(y) : null;
};

const item = (source, record, type, title, yr, url) => ({
  source,
  record,
  type: type ?? null,
  title: title ?? null,
  year: Number.isFinite(yr) ? yr : null,
  url: url ?? null,
});

function doiUrl(externalIds) {
  const doi = (externalIds?.["external-id"] ?? []).find((x) => x["external-id-type"] === "doi");
  return doi ? `https://doi.org/${doi["external-id-value"]}` : null;
}

export function normalizeOrcid(json) {
  const out = [];
  const name = json.person?.name;
  const fullName = [name?.["given-names"]?.value, name?.["family-name"]?.value].filter(Boolean).join(" ");
  out.push(item("orcid", "person", null, fullName || json["orcid-identifier"]?.path, null, json["orcid-identifier"]?.uri));

  const acts = json["activities-summary"] ?? {};
  for (const group of acts.works?.group ?? []) {
    const w = group["work-summary"]?.[0];
    if (!w) continue;
    out.push(item("orcid", "works", w.type, w.title?.title?.value, year(w["publication-date"]), w.url?.value ?? doiUrl(w["external-ids"])));
  }
  for (const group of acts["peer-reviews"]?.group ?? []) {
    for (const prg of group["peer-review-group"] ?? []) {
      for (const r of prg["peer-review-summary"] ?? []) {
        out.push(item("orcid", "peer-reviews", r["reviewer-role"] ?? "reviewer", r["convening-organization"]?.name ?? r["review-group-id"], year(r["completion-date"]), r["review-url"]?.value));
      }
    }
  }
  for (const group of acts.fundings?.group ?? []) {
    const f = group["funding-summary"]?.[0];
    if (!f) continue;
    out.push(item("orcid", "fundings", f.type, f.title?.title?.value, year(f["start-date"]), f.url?.value));
  }
  for (const record of AFFILIATIONS) {
    for (const group of acts[record]?.["affiliation-group"] ?? []) {
      for (const wrapper of group.summaries ?? []) {
        const s = Object.values(wrapper)[0];
        const title = [s?.["role-title"], s?.["department-name"], s?.organization?.name].filter(Boolean).join(", ");
        out.push(item("orcid", record, null, title, year(s?.["start-date"]), s?.url?.value));
      }
    }
  }
  return out;
}

export function normalizeOpenalex(json) {
  return (json.results ?? []).map((w) => item("openalex", "works", w.type, w.title, w.publication_year, w.doi ?? w.id));
}

export function normalizeDatacite(json) {
  return (json.data ?? []).map((d) => {
    const a = d.attributes ?? {};
    return item("datacite", "dois", a.types?.resourceTypeGeneral, a.titles?.[0]?.title, a.publicationYear, a.doi ? `https://doi.org/${a.doi}` : a.url);
  });
}

export function normalizeOpenaire(json) {
  return (json.results ?? []).map((r) => {
    const doi = (r.pids ?? []).find((p) => p.scheme === "doi");
    const url = doi ? `https://doi.org/${doi.value}` : `https://explore.openaire.eu/search/result?id=${encodeURIComponent(r.id)}`;
    return item("openaire", "products", r.type, r.mainTitle, r.publicationDate ? Number(r.publicationDate.slice(0, 4)) : null, url);
  });
}

async function getJson(url, fetchFn, headers = {}) {
  const res = await fetchFn(url, { headers: { Accept: "application/json", ...headers } });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText} for ${url}`);
  return res.json();
}

const MAX_PAGES = 5;

export const fetchers = {
  async orcid(orcid, fetchFn) {
    return normalizeOrcid(await getJson(`https://pub.orcid.org/v3.0/${orcid}/record`, fetchFn));
  },
  async openalex(orcid, fetchFn) {
    // Basic paging: OpenAlex requires an API key for cursor paging.
    const items = [];
    for (let page = 1; page <= MAX_PAGES; page++) {
      const url = `https://api.openalex.org/works?filter=author.orcid:${orcid}&per-page=200&page=${page}&select=id,doi,title,type,publication_year,open_access`;
      const json = await getJson(url, fetchFn);
      items.push(...normalizeOpenalex(json));
      if (items.length >= (json.meta?.count ?? 0) || !json.results?.length) break;
    }
    return items;
  },
  async datacite(orcid, fetchFn) {
    return normalizeDatacite(await getJson(`https://api.datacite.org/dois?user-id=${orcid}&page[size]=1000`, fetchFn));
  },
  async openaire(orcid, fetchFn) {
    const items = [];
    for (let page = 1; page <= MAX_PAGES; page++) {
      const json = await getJson(`https://api.openaire.eu/graph/v1/researchProducts?authorOrcid=${orcid}&pageSize=100&page=${page}`, fetchFn);
      items.push(...normalizeOpenaire(json));
      if (items.length >= (json.header?.numFound ?? 0) || !json.results?.length) break;
    }
    return items;
  },
};

// Queries every source; a failing source is reported, never fatal.
export async function collectEvidence(orcid, { sources = Object.keys(fetchers), fetchFn = globalThis.fetch.bind(globalThis), now = () => new Date().toISOString() } = {}) {
  if (!isValidOrcid(orcid)) throw new Error(`Not a valid ORCID iD: ${orcid}`);
  const results = await Promise.allSettled(sources.map((s) => fetchers[s](orcid, fetchFn)));
  const evidence = [];
  const consulted = results.map((r, i) => {
    if (r.status === "fulfilled") evidence.push(...r.value);
    return {
      source: sources[i],
      ok: r.status === "fulfilled",
      count: r.status === "fulfilled" ? r.value.length : 0,
      error: r.status === "rejected" ? String(r.reason?.message ?? r.reason) : null,
      retrieved_at: now(),
    };
  });
  return { evidence, consulted };
}
