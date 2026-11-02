import { collectEvidence, isValidOrcid } from "./connectors.js";
import { mapEvidence, reportRows, toCsv } from "./engine.js";

const $ = (id) => document.getElementById(id);
const STATUS_LABEL = {
  found: "Found",
  partial: "Partial",
  not_found_in_sources: "Not found in sources",
  source_unavailable: "Source unavailable",
  no_automated_source: "Narrative only",
};

const getJson = async (path) => {
  // Published under /data/; in a checkout the single source lives in the R package.
  let res = await fetch(path);
  if (!res.ok) res = await fetch(path.replace(/^data\//, "r/inst/extdata/"));
  return res.json();
};
const [crosswalk, frameworks] = await Promise.all([
  getJson("data/mappings.json"),
  Promise.all(["r4ri", "cva-aei"].map((id) => getJson(`data/frameworks/${id}.json`))),
]);
const frameworkById = Object.fromEntries(frameworks.map((f) => [f.id, f]));
let lastReport = null;

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") node.className = v;
    else node.setAttribute(k, v);
  }
  for (const c of children.flat()) node.append(c instanceof Node ? c : document.createTextNode(String(c ?? "")));
  return node;
}

function renderExplorer() {
  const fw = frameworkById[$("framework").value];
  $("version").textContent = `Mapping version ${crosswalk.mapping_version}, valid from ${crosswalk.valid_from} (${crosswalk.status}).`;
  const rows = [];
  for (const s of fw.sections) {
    const ms = crosswalk.mappings.filter((m) => m.framework === fw.id && m.section === s.id);
    if (!ms.length) rows.push(el("tr", {}, el("td", {}, s.name), el("td", { colspan: 4, class: "meta" }, "No automated source: documented by the researcher's narrative.")));
    for (const m of ms) {
      rows.push(el("tr", {}, el("td", {}, s.name), el("td", {}, `${m.source} · ${m.record}${m.types ? ` (${m.types.join(", ")})` : ""}`), el("td", {}, m.evidence_type), el("td", {}, m.coverage), el("td", { class: "meta" }, m.limitations)));
    }
  }
  $("mapping-table").replaceChildren(
    el("thead", {}, el("tr", {}, ["Section", "Source and record", "Evidence", "Coverage", "Limitations"].map((h) => el("th", {}, h)))),
    el("tbody", {}, rows),
  );
}

function renderReport(report) {
  $("sources").replaceChildren(
    ...report.sources_consulted.map((c) => el("li", { class: c.ok ? "" : "fail", title: c.error ?? "" }, `${c.source}: ${c.ok ? `${c.count} items` : "no answer"}`)),
  );
  $("sections").replaceChildren(
    ...report.sections.map((s) =>
      el("div", { class: "section card" },
        el("h3", {}, s.name, el("span", { class: `badge ${s.status}` }, STATUS_LABEL[s.status])),
        s.status === "no_automated_source" ? el("p", { class: "meta" }, "No infrastructure documents this section. It rests on the researcher's own account.") : "",
        ...s.mappings.map((m) =>
          el("details", {},
            el("summary", {}, `${m.source}: ${m.contribution_type} · ${m.count} item${m.count === 1 ? "" : "s"} · ${m.evidence_type}, ${m.coverage} coverage`),
            el("p", { class: "meta" }, m.limitations),
            m.items.length ? el("ul", {}, m.items.slice(0, 200).map((i) => el("li", {}, i.url ? el("a", { href: i.url, rel: "noopener" }, i.title || i.url) : i.title, i.year ? ` (${i.year})` : "", i.type ? el("span", { class: "meta" }, ` · ${i.type}`) : ""))) : "",
          ),
        ),
      ),
    ),
  );
  $("results").hidden = false;
}

function download(name, text, type) {
  const a = el("a", { href: URL.createObjectURL(new Blob([text], { type })), download: name });
  a.click();
  URL.revokeObjectURL(a.href);
}

async function run() {
  const orcid = $("orcid").value.trim().replace(/^https?:\/\/orcid\.org\//, "");
  if (!isValidOrcid(orcid)) {
    $("message").textContent = "That is not a valid ORCID iD (16 digits, last one may be X).";
    return;
  }
  history.replaceState(null, "", `#orcid=${orcid}&framework=${$("framework").value}`);
  $("message").textContent = "Querying ORCID, OpenAlex, DataCite and OpenAIRE…";
  $("form").querySelector("button").disabled = true;
  try {
    const { evidence, consulted } = await collectEvidence(orcid);
    lastReport = mapEvidence({ framework: frameworkById[$("framework").value], crosswalk, evidence, consulted, orcid, generatedAt: new Date().toISOString() });
    renderReport(lastReport);
    $("message").textContent = "";
  } catch (err) {
    $("message").textContent = `Something went wrong: ${err.message}`;
  } finally {
    $("form").querySelector("button").disabled = false;
  }
}

$("form").addEventListener("submit", (e) => {
  e.preventDefault();
  run();
});
$("framework").addEventListener("change", () => {
  renderExplorer();
  if (lastReport) run();
});
$("dl-json").addEventListener("click", () => download(`ncvc-${lastReport.orcid}-${lastReport.framework}.json`, JSON.stringify(lastReport, null, 2), "application/json"));
$("dl-csv").addEventListener("click", () => download(`ncvc-${lastReport.orcid}-${lastReport.framework}.csv`, toCsv(reportRows(lastReport)), "text/csv"));

const params = new URLSearchParams(location.hash.slice(1));
if (params.get("framework") && frameworkById[params.get("framework")]) $("framework").value = params.get("framework");
renderExplorer();
if (params.get("orcid")) {
  $("orcid").value = params.get("orcid");
  run();
}
