import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";

const rootUrl = new URL("../", import.meta.url);
const read = (path) => readFileSync(new URL(path, rootUrl), "utf8");
const exists = (path) => existsSync(new URL(path, rootUrl));

const index = read("src/pages/index.astro");
const postCard = read("src/components/PostCard.astro");
const packageJson = JSON.parse(read("package.json"));

assert.ok(exists("src/components/HomepageHero.astro"), "HomepageHero.astro must exist");
assert.ok(exists("src/styles/home.css"), "home.css must exist");
assert.match(index, /import HomepageHero from "\.\.\/components\/HomepageHero\.astro"/);
assert.match(index, /import "\.\.\/styles\/home\.css"/);
assert.match(index, /class="homepage"/);
assert.match(index, /variant="featured-primary"/);
assert.match(index, /variant="featured-secondary"/);
assert.match(
  postCard,
  /variant\?: "default" \| "featured-primary" \| "featured-secondary" \| "latest-lead"/,
);
assert.equal(packageJson.scripts["check:homepage-ui"], "node scripts/check-homepage-ui.mjs");
assert.match(index, /new IntersectionObserver/);
assert.match(index, /observer\.disconnect\(\)/);
assert.doesNotMatch(index, /window\.addEventListener\(["']scroll/);

if (exists("src/components/HomepageHero.astro") && exists("src/styles/home.css")) {
  const hero = read("src/components/HomepageHero.astro");
  const homeCss = read("src/styles/home.css");
  assert.match(hero, /class="home-hero"/);
  assert.match(hero, /class="home-hero-media"/);
  assert.match(homeCss, /prefers-reduced-motion: reduce/);
  assert.match(homeCss, /prefers-reduced-transparency: reduce/);
  assert.match(homeCss, /@supports not \(backdrop-filter: blur\(1px\)\)/);
  assert.doesNotMatch(`${index}\n${hero}`, /[—–]/);
}

console.log("Homepage UI checks passed");
