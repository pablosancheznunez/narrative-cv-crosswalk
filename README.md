# Narrative CV Crosswalk

An open, versioned mapping between the sections of narrative CVs and the evidence that open research infrastructures hold about a researcher.

**Use it in the browser:** <https://pablosancheznunez.github.io/narrative-cv-crosswalk/>. Enter an ORCID iD; the page queries ORCID, OpenAlex, DataCite and the OpenAIRE Graph directly from your browser and shows, section by section, what each source can document.

Narrative CVs (such as the Royal Society's *Résumé for Researchers* or the Spanish *CVA* of the Agencia Estatal de Investigación) ask researchers to describe contributions that metrics miss. Some of those contributions leave traces in open infrastructures; many do not. The crosswalk makes that explicit, with the coverage and limitations of each source, so that evaluators know what was checked and what only the researcher can tell. **Not found does not mean it does not exist.**

## What is in the repository

| Path | What it is |
| --- | --- |
| [`data/mappings.json`](data/mappings.json) | The crosswalk: one entry per framework section × source record, with evidence type, coverage and limitations |
| [`data/frameworks/`](data/frameworks/) | The narrative CV frameworks and their sections |
| [`schema/`](schema/) | JSON Schemas for the data |
| [`src/`](src/) | The engine and connectors (plain JavaScript, no dependencies), used by the web page and the tests |
| [`r/`](r/) | The `narrativecv` R package |

The JSON files are the product. Use them from any language without installing anything:

```r
crosswalk <- jsonlite::fromJSON("https://pablosancheznunez.github.io/narrative-cv-crosswalk/data/mappings.json")
```

## R package

```r
# install.packages("remotes")
remotes::install_github("pablosancheznunez/narrative-cv-crosswalk", subdir = "r")

library(narrativecv)
report <- narrative_cv("0000-0002-1825-0097", "r4ri")
nc_report_table(report)
```

The R package and the JavaScript engine are tested against the same recorded responses and must produce identical reports.

## Section status

| Status | Meaning |
| --- | --- |
| `found` | Evidence matched a mapping with full coverage |
| `partial` | Evidence matched, but every source involved has partial coverage |
| `not_found_in_sources` | Nothing in the sources consulted; it may still exist |
| `source_unavailable` | Every source the section relies on failed to answer |
| `no_automated_source` | Narrative only: no infrastructure documents this section |

## Status of the mappings

Version 0.1.0 is a **draft pending expert review**. Contributions and corrections are welcome through issues. The crosswalk is designed as an interoperable resource that could contribute to initiatives such as ARION (coordinated by OpenAIRE); it is not an official part of them.

## Maintenance

Maintained with as little human time as possible by [research-tools-ops](https://github.com/pablosancheznunez/research-tools-ops): weekly live checks against the four APIs, automatic repair proposals, Dependabot, and a monthly release when something changed. Changes to the mappings, schemas, engine or expected results always need the maintainer's approval.

## Tests

```bash
node --test tests/              # engine, connectors, data integrity, regression
node --test tests/live/contract.js   # live APIs
python tests/validate_schema.py      # needs: pip install jsonschema
```

## Citation and license

See [`CITATION.cff`](CITATION.cff). Code: MIT. Data (`data/`, `schema/`): CC BY 4.0.
