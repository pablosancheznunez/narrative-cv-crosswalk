import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
export const load = (path) => JSON.parse(readFileSync(new URL(path, root), "utf-8"));
export const rootPath = (path) => fileURLToPath(new URL(path, root));
export const frameworks = ["r4ri", "cva-aei"].map((id) => load(`r/inst/extdata/frameworks/${id}.json`));
export const crosswalk = load("r/inst/extdata/mappings.json");
export const sources = load("r/inst/extdata/sources.json");
