import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;
const specIds = readFileSync(join(root, "scripts/requirement-ids.txt"), "utf8").split("\n").map((s) => s.trim()).filter(Boolean);
if (specIds.length < 160) {
  console.error(`requirement-ids.txt lists ${specIds.length} requirements, expected at least 160`);
  process.exit(1);
}

function files(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name === ".git" || name === "site") continue;
    const path = join(dir, name);
    if (statSync(path).isDirectory()) files(path, out);
    else if (/\.(ts|tsx|md|sql|mjs)$/.test(name) && !path.endsWith("traceability.mjs")) out.push(path);
  }
  return out;
}

const corpus = files(root).map((path) => readFileSync(path, "utf8")).join("\n");
const missing = specIds.filter((id) => !corpus.includes(id));
if (missing.length) {
  console.error("requirements with no test or QA entry:", missing.join(", "));
  process.exit(1);
}
console.log(`traceability ok: ${specIds.length} requirements referenced`);
