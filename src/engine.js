// Applies the crosswalk to normalized evidence. Pure: same input, same report.
//
// Section status:
//   found                 evidence matched a mapping with full coverage
//   partial               evidence matched, but only through partial-coverage mappings
//   not_found_in_sources  no evidence in the sources consulted (it may still exist)
//   source_unavailable    every source this section relies on failed to answer
//   no_automated_source   the section is narrative; no infrastructure can document it

export const REPORT_SCHEMA = "ncvc-report/1";

export function matches(mapping, e) {
  return e.source === mapping.source && e.record === mapping.record && (!mapping.types || mapping.types.includes(e.type));
}

export function mapEvidence({ framework, crosswalk, evidence, consulted, orcid = null, generatedAt }) {
  const ok = new Set(consulted.filter((c) => c.ok).map((c) => c.source));
  const sections = framework.sections.map((section) => {
    if (section.no_automated_source) {
      return { id: section.id, name: section.name, status: "no_automated_source", mappings: [] };
    }
    const mappings = crosswalk.mappings
      .filter((m) => m.framework === framework.id && m.section === section.id)
      .map((m) => {
        const items = evidence.filter((e) => matches(m, e));
        return {
          id: m.id,
          contribution_type: m.contribution_type,
          source: m.source,
          evidence_type: m.evidence_type,
          coverage: m.coverage,
          limitations: m.limitations,
          source_available: ok.has(m.source),
          count: items.length,
          items,
        };
      });
    let status;
    if (mappings.some((m) => m.count > 0)) {
      status = mappings.some((m) => m.count > 0 && m.coverage === "full") ? "found" : "partial";
    } else if (mappings.length > 0 && mappings.every((m) => !m.source_available)) {
      status = "source_unavailable";
    } else {
      status = "not_found_in_sources";
    }
    return { id: section.id, name: section.name, status, mappings };
  });
  return {
    schema: REPORT_SCHEMA,
    framework: framework.id,
    mapping_version: crosswalk.mapping_version,
    orcid,
    generated_at: generatedAt,
    sources_consulted: consulted,
    sections,
  };
}

// Flat table of the report, one row per evidence item, for CSV export.
export function reportRows(report) {
  const rows = [];
  for (const s of report.sections) {
    for (const m of s.mappings) {
      for (const e of m.items) {
        rows.push({ section: s.id, section_status: s.status, mapping: m.id, evidence_type: m.evidence_type, coverage: m.coverage, source: e.source, record: e.record, type: e.type, title: e.title, year: e.year, url: e.url });
      }
    }
  }
  return rows;
}

export function toCsv(rows) {
  if (!rows.length) return "";
  const cols = Object.keys(rows[0]);
  const cell = (v) => {
    const s = v == null ? "" : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [cols.join(","), ...rows.map((r) => cols.map((c) => cell(r[c])).join(","))].join("\n") + "\n";
}
