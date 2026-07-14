import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";

const rootUrl = new URL("../", import.meta.url);
const read = (path) => readFileSync(new URL(path, rootUrl), "utf8");
const exists = (path) => existsSync(new URL(path, rootUrl));

const index = read("src/pages/index.astro");
const postCard = read("src/components/PostCard.astro");
const baseLayout = read("src/layouts/BaseLayout.astro");
const themeToggle = read("src/components/ThemeToggle.astro");
const packageJson = JSON.parse(read("package.json"));

assert.ok(exists("src/components/HomepageHero.astro"), "HomepageHero.astro must exist");
assert.ok(exists("src/styles/home.css"), "home.css must exist");
assert.ok(exists("src/assets/digital-garden-hero-day.png"), "daytime hero artwork must exist");
assert.ok(exists("src/assets/digital-garden-hero-night.png"), "nighttime hero artwork must exist");
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
assert.match(index, /import digitalGardenHeroDay from "\.\.\/assets\/digital-garden-hero-day\.png"/);
assert.match(index, /import digitalGardenHero from "\.\.\/assets\/digital-garden-hero-night\.png"/);
assert.match(index, /lightHeroImage=\{digitalGardenHeroDay\}/);
assert.match(themeToggle, />☾<\/span>/);
assert.match(themeToggle, />☀<\/span>/);
assert.doesNotMatch(themeToggle, />夜<\/span>|>昼<\/span>/);
assert.match(themeToggle, /:global\(\[data-theme="light"\]\) \.theme-icon-light/);
assert.match(baseLayout, /timeZone: "Asia\/Shanghai"/);
assert.match(baseLayout, /stored === "light" \|\| stored === "dark"/);
assert.match(baseLayout, /sessionStorage\.getItem\("theme"\)/);
assert.match(themeToggle, /sessionStorage\.setItem\("theme", next\)/);

if (exists("src/components/HomepageHero.astro") && exists("src/styles/home.css")) {
  const hero = read("src/components/HomepageHero.astro");
  const homeCss = read("src/styles/home.css");
  assert.match(hero, /class="home-hero"/);
  assert.match(hero, /class="home-hero-visual" data-home-reveal/);
  assert.match(hero, /class="home-hero-media"/);
  assert.doesNotMatch(hero, /class="home-hero-media" data-home-reveal/);
  assert.doesNotMatch(hero, /home-hero-count|postCount/);
  assert.match(index, /class="home-search-layout"[\s\S]*?<Search \/>[\s\S]*?class="home-hero-count"/);
  assert.match(homeCss, /\.home-hero-visual\s*\{[\s\S]*?overflow:\s*visible/);
  assert.match(homeCss, /\.home-search-layout\s*\{[\s\S]*?grid-template-columns/);
  assert.match(homeCss, /\.home-hero-count strong\s*\{[\s\S]*?font-size:\s*36px/);
  assert.match(homeCss, /@property --hero-corner-tl/);
  assert.match(homeCss, /home-hero-corner-tl 11s/);
  assert.match(homeCss, /home-hero-corner-tr 13\.7s/);
  assert.match(homeCss, /home-hero-corner-br 17\.3s/);
  assert.match(homeCss, /home-hero-corner-bl 19\.1s/);
  assert.match(homeCss, /prefers-reduced-motion: reduce/);
  assert.match(
    homeCss,
    /@media \(prefers-reduced-motion: reduce\)[\s\S]*?\.home-hero-media\s*\{[\s\S]*?animation:\s*none/,
  );
  assert.match(homeCss, /prefers-reduced-transparency: reduce/);
  assert.match(homeCss, /@supports not \(backdrop-filter: blur\(1px\)\)/);
  assert.doesNotMatch(`${index}\n${hero}`, /[—–]/);
}

console.log("Homepage UI checks passed");
