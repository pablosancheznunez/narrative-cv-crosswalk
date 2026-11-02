import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
export const load = (path) => JSON.parse(readFileSync(new URL(path, root), "utf-8"));
export const rootPath = (path) => fileURLToPath(new URL(path, root));
export const frameworks = ["r4ri", "cva-aei"].map((id) => load(`data/frameworks/${id}.json`));
export const crosswalk = load("data/mappings.json");
export const sources = load("data/sources.json");
