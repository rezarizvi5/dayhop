import { readFileSync } from "node:fs";

const files = ["app/kid.tsx", "app/play.tsx", "src/ui/Gate.tsx"];
const banned = ["posthog", "@sentry", "analytics", "expo-tracking"];
let failed = false;
for (const file of files) {
  const text = readFileSync(new URL("../" + file, import.meta.url), "utf8");
  for (const word of banned) {
    if (text.toLowerCase().includes(word)) {
      console.error(`${file} mentions ${word}. Kid Mode must not send analytics.`);
      failed = true;
    }
  }
}
if (failed) process.exit(1);
console.log("kid mode lint ok");
