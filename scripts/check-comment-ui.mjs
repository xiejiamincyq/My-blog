import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const component = await readFile(
  new URL("../src/components/SupabaseComments.astro", import.meta.url),
  "utf8",
);

assert.match(component, /image\.className = "comment-avatar"/);
assert.match(component, /:global\(\.comment-avatar\),\s*:global\(\.comment-avatar-fallback\)/);
assert.match(
  component,
  /:global\(\.comment-avatar\),\s*:global\(\.comment-avatar-fallback\)[\s\S]*?width: 32px;[\s\S]*?height: 32px;/,
);
assert.match(component, /:global\(\.comment-avatar\)\s*\{[\s\S]*?object-fit: cover;/);

console.log("Comment UI regression checks passed.");
