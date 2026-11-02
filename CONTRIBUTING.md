# Contributing

Thank you for helping improve the Narrative CV Crosswalk. Corrections to mappings, new frameworks and new evidence sources are especially welcome.

## Proposing a change to the crosswalk

Open an issue that states the framework section, the source and record, the evidence type and coverage you propose, and a reference (official template, instructions or API documentation). Changes to the crosswalk are reviewed by the maintainer and released as a new mapping version.

## Running the tests

- JavaScript engine and data: `node --test` (Node 22 or later, no dependencies).
- Data against the schemas: `pip install jsonschema && python tests/validate_schema.py`.
- R package: `R CMD build r && R CMD check --as-cran narrativecv_*.tar.gz`.
- Live API contracts (network): `node --test tests/live/contract.js`.

The R package must behave exactly like `src/*.js`: both are tested against the same recorded responses and expected reports.

## Changes that may be made without the maintainer's review

- Connector code in `src/connectors.js` and `r/R/connectors.R` when an API changes shape, together with the matching recorded responses in `tests/fixtures/` (copied to `r/inst/extdata/examples/`).
- Documentation, the web page layout and styles.

## Changes that always need the maintainer's review

- `data/`, `schema/`, `src/engine.js`, `r/R/engine.R` and `tests/regression/`, which define the crosswalk and its expected results.
- Workflows, `.maintenance.json`, `CODEOWNERS` and this file.

Tests are never weakened or deleted to make them pass.

## Principles

- Not found does not mean it does not exist: missing evidence is never presented as absence.
- No dependencies in the JavaScript; only `curl` and `jsonlite` in R.
