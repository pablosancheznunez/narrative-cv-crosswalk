# Maintenance instructions for AI agents

This repository is maintained partly by automated agents (see
pablosancheznunez/research-tools-ops). Follow these rules.

## Test commands

- `node --test` must pass. Node 22 or later (CI uses 24), no dependencies.
- `python tests/validate_schema.py` (needs `pip install jsonschema`).
- The R package in `r/` is checked in CI; keep `r/R/*.R` behaviour identical to `src/*.js`.

## What you may change on your own

- Connector code in `src/connectors.js` and `r/R/connectors.R` when an API changed shape, plus the matching recorded responses in `tests/fixtures/` (copy them to `r/tests/testthat/fixtures/`).
- Documentation, the web page layout and styles.

## What you must never change

- `data/`, `schema/`, `src/engine.js`, `r/R/engine.R` and `tests/regression/`: these define the crosswalk and its expected results. Propose changes in an issue instead.
- Workflows, `.maintenance.json`, `CODEOWNERS` and this file.
- Never weaken or delete a test to make it pass.

## Principles

- Not found does not mean it does not exist: never present missing evidence as absence.
- No dependencies in the JavaScript; only `curl` and `jsonlite` in R.
