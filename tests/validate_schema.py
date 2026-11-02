"""Validate the crosswalk data against its JSON Schemas (run in CI)."""

import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

root = Path(__file__).resolve().parents[1]
load = lambda p: json.loads((root / p).read_text(encoding="utf-8"))

checks = [("schema/mappings.schema.json", "r/inst/extdata/mappings.json")]
checks += [("schema/framework.schema.json", str(p.relative_to(root))) for p in sorted((root / "r/inst/extdata/frameworks").glob("*.json"))]

failed = False
for schema_path, data_path in checks:
    validator = Draft202012Validator(load(schema_path), format_checker=FormatChecker())
    for error in validator.iter_errors(load(data_path)):
        failed = True
        print(f"{data_path}: {'/'.join(map(str, error.path))}: {error.message}")
    print(f"checked {data_path}")
sys.exit(1 if failed else 0)
