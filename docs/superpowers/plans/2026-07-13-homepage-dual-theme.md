# Homepage Dual-Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Astro homepage as a coordinated light digital garden and dark liquid-night experience with restrained web liquid glass, while preserving content, routes, SEO, search, and theme behavior.

**Architecture:** Keep data fetching in `src/pages/index.astro`, add homepage-only composition in `src/components/HomepageHero.astro` and `src/styles/home.css`, and extend shared components through small variant props or theme tokens. Use native Astro, CSS, and IntersectionObserver only; no new runtime package is needed.

**Tech Stack:** Astro 7, TypeScript 6, native CSS, Astro Assets, Node assertion scripts, Pagefind.

## Global Constraints

- Preserve route paths, navigation labels, article content, SEO metadata, RSS, theme persistence, search behavior, authentication, comments, view counts, and Supabase integrations.
- Light mode uses a mist-blue canvas, blue-green structure, mint primary accent, and acid-yellow supporting highlight.
- Dark mode uses a near-black violet canvas, off-white text, magenta primary accent, and acid-yellow supporting highlight.
- `DESIGN_VARIANCE: 8`, `MOTION_INTENSITY: 6`, `VISUAL_DENSITY: 4`.
- Use one palette per mode, one 18px primary surface radius, 12px compact controls, and pill geometry only for buttons and controls.
- Web liquid glass is limited to the floating header, search, theme toggle, and one featured-story surface.
- Do not add third-party dependencies, window-level scroll listeners, fake screenshots, duplicate CTA intents, or visible em dash and en dash separators.
- Preserve reduced-motion support and add reduced-transparency and no-backdrop-filter fallbacks.
- `npm run build` and `npm run typecheck` must pass before completion.

---

### Task 1: Add Homepage Structure Regression Checks

**Files:**
- Create: `scripts/check-homepage-ui.mjs`
- Modify: `package.json`

**Interfaces:**
- Consumes: source files at `src/pages/index.astro`, `src/components/HomepageHero.astro`, `src/components/PostCard.astro`, and `src/styles/home.css`.
- Produces: npm script `check:homepage-ui` that exits nonzero when required homepage structure or accessibility fallbacks disappear.

- [ ] **Step 1: Write the failing source-level regression check**

Create `scripts/check-homepage-ui.mjs`:

```js
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
const index = read("src/pages/index.astro");
const postCard = read("src/components/PostCard.astro");
const packageJson = JSON.parse(read("package.json"));

assert.match(index, /import HomepageHero from "\.\.\/components\/HomepageHero\.astro"/);
assert.match(index, /import "\.\.\/styles\/home\.css"/);
assert.match(index, /class="homepage"/);
assert.match(index, /variant="featured-primary"/);
assert.match(index, /variant="featured-secondary"/);
assert.match(postCard, /variant\?: "default" \| "featured-primary" \| "featured-secondary" \| "latest-lead"/);
assert.equal(packageJson.scripts["check:homepage-ui"], "node scripts/check-homepage-ui.mjs");

const hero = read("src/components/HomepageHero.astro");
const homeCss = read("src/styles/home.css");
assert.match(hero, /class="home-hero"/);
assert.match(hero, /class="home-hero-media"/);
assert.match(homeCss, /prefers-reduced-motion: reduce/);
assert.match(homeCss, /prefers-reduced-transparency: reduce/);
assert.match(homeCss, /@supports not \(backdrop-filter: blur\(1px\)\)/);
assert.doesNotMatch(`${index}\n${hero}`, /[—–]/);

console.log("Homepage UI checks passed");
```

Add this entry under `scripts` in `package.json`:

```json
"check:homepage-ui": "node scripts/check-homepage-ui.mjs"
```

- [ ] **Step 2: Run the check to verify it fails for missing homepage files**

Run: `npm run check:homepage-ui`

Expected: FAIL because `HomepageHero.astro` or `home.css` does not exist.

- [ ] **Step 3: Commit the failing check**

```bash
git add scripts/check-homepage-ui.mjs package.json
git commit -m "Add homepage UI regression checks"
```

### Task 2: Add Explicit Post Card Variants

**Files:**
- Modify: `src/components/PostCard.astro`
- Modify: `src/styles/global.css`

**Interfaces:**
- Consumes: `CollectionEntry<"blog">` through the existing `post` prop.
- Produces: optional `variant` prop with values `default`, `featured-primary`, `featured-secondary`, and `latest-lead`; existing consumers remain unchanged through the `default` value.

- [ ] **Step 1: Extend the component interface and class output**

Update the prop declaration and destructuring in `PostCard.astro`:

```astro
interface Props {
  post: CollectionEntry<"blog">;
  variant?: "default" | "featured-primary" | "featured-secondary" | "latest-lead";
}

const { post, variant = "default" } = Astro.props;
```

Change the article opening tag to:

```astro
<article class:list={["post-card", `post-card--${variant}`]}>
```

- [ ] **Step 2: Add variant-safe shared rules**

Append these compatibility rules near the existing post-card rules in `global.css`:

```css
.post-card--featured-primary,
.post-card--featured-secondary,
.post-card--latest-lead {
  min-width: 0;
}

.post-card--featured-primary .post-card-image,
.post-card--latest-lead .post-card-image {
  aspect-ratio: 4 / 3;
}
```

- [ ] **Step 3: Run existing validation**

Run: `npm run typecheck`

Expected: PASS with zero errors.

Run: `npm run build`

Expected: PASS and Pagefind completes.

- [ ] **Step 4: Commit the variant interface**

```bash
git add src/components/PostCard.astro src/styles/global.css
git commit -m "Add editorial post card variants"
```

### Task 3: Build the Asymmetric Homepage Composition

**Files:**
- Create: `src/components/HomepageHero.astro`
- Create: `src/styles/home.css`
- Modify: `src/pages/index.astro`

**Interfaces:**
- Consumes: `postCount: number`, optional `heroImage`, and existing route helper `sitePath`.
- Produces: `.homepage`, `.home-hero`, `.home-search`, `.featured-layout`, and `.latest-layout` composition hooks used only by `home.css`.

- [ ] **Step 1: Create the semantic hero component**

Create `src/components/HomepageHero.astro`:

```astro
---
import { Image } from "astro:assets";
import { sitePath } from "../lib/paths";
import type { ImageMetadata } from "astro";

interface Props {
  postCount: number;
  heroImage?: ImageMetadata;
}

const { postCount, heroImage } = Astro.props;
---

<section class="home-hero" aria-labelledby="home-title">
  <div class="home-hero-copy">
    <p class="home-eyebrow">个人博客</p>
    <h1 id="home-title">给思考留一块<br />会呼吸的地方</h1>
    <p class="home-hero-lede">记录技术、阅读、生活观察，以及仍在生长的问题。</p>
    <div class="hero-actions">
      <a class="button primary" href={sitePath("/blog/")}>阅读文章</a>
      <a class="button secondary" href={sitePath("/about/")}>了解我</a>
    </div>
  </div>
  <div class="home-hero-media">
    {heroImage ? (
      <Image
        src={heroImage}
        alt="博客精选文章视觉"
        widths={[640, 960]}
        sizes="(max-width: 760px) 100vw, 48vw"
        loading="eager"
        decoding="async"
      />
    ) : (
      <div class="home-hero-media-fallback" aria-hidden="true"></div>
    )}
    <p class="home-hero-count"><strong>{postCount}</strong><span>篇文章持续生长</span></p>
  </div>
</section>
```

- [ ] **Step 2: Replace the homepage section composition**

In `src/pages/index.astro`:

```astro
---
import BaseLayout from "../layouts/BaseLayout.astro";
import HomepageHero from "../components/HomepageHero.astro";
import PostCard from "../components/PostCard.astro";
import Search from "../components/Search.astro";
import "../styles/home.css";
import { getPublishedPosts } from "../lib/posts";
import { sitePath } from "../lib/paths";

const posts = await getPublishedPosts();
const featuredPosts = posts.filter((post) => post.data.featured).slice(0, 2);
const latestPosts = posts.slice(0, 4);
const heroImage = featuredPosts[0]?.data.heroImage ?? latestPosts[0]?.data.heroImage;
---

<BaseLayout>
  <div class="homepage">
    <HomepageHero postCount={posts.length} heroImage={heroImage} />
    <section class="home-search" aria-label="站内搜索"><Search /></section>
    {featuredPosts.length > 0 && (
      <section class="home-section" aria-labelledby="featured-title">
        <div class="home-section-heading"><h2 id="featured-title">从这些文章开始</h2></div>
        <div class="featured-layout">
          {featuredPosts.map((post, index) => (
            <PostCard post={post} variant={index === 0 ? "featured-primary" : "featured-secondary"} />
          ))}
        </div>
      </section>
    )}
    <section class="home-section" aria-labelledby="latest-title">
      <div class="home-section-heading home-section-heading--action">
        <h2 id="latest-title">最近写下</h2>
        <a class="text-link" href={sitePath("/blog/")}>全部文章</a>
      </div>
      {latestPosts.length ? (
        <div class="latest-layout">
          {latestPosts.map((post, index) => (
            <PostCard post={post} variant={index === 0 ? "latest-lead" : "default"} />
          ))}
        </div>
      ) : (
        <p class="home-empty">第一篇文章正在路上。</p>
      )}
    </section>
  </div>
</BaseLayout>
```

- [ ] **Step 3: Add the responsive structural CSS**

Create `src/styles/home.css` with the layout foundation:

```css
.homepage { --home-radius: 18px; }
.home-hero { display:grid; grid-template-columns:minmax(0,1.05fr) minmax(320px,.95fr); align-items:center; gap:clamp(36px,7vw,96px); min-height:calc(100dvh - 96px); padding:clamp(48px,8vh,88px) 0 72px; }
.home-hero-copy { position:relative; z-index:1; max-width:680px; }
.home-eyebrow { margin:0 0 16px; color:var(--accent); font-size:12px; font-weight:800; letter-spacing:.12em; }
.home-hero h1 { max-width:720px; font-size:clamp(46px,6.5vw,84px); line-height:.98; letter-spacing:-.065em; }
.home-hero-lede { max-width:24em; margin:24px 0 0; color:var(--muted); font-size:clamp(17px,2vw,20px); }
.home-hero-media { position:relative; aspect-ratio:4/5; overflow:hidden; border-radius:38% 62% 55% 45% / 42% 38% 62% 58%; background:var(--surface-soft); }
.home-hero-media img { width:100%; height:100%; object-fit:cover; }
.home-hero-count { position:absolute; right:18px; bottom:18px; display:grid; margin:0; padding:14px 16px; border-radius:12px; background:var(--glass-fill); color:var(--text); backdrop-filter:blur(18px) saturate(145%); }
.home-hero-count strong { font-size:28px; line-height:1; }
.home-hero-count span { color:var(--muted); font-size:12px; }
.home-search { position:relative; z-index:5; margin:-34px 0 80px; }
.home-search .search-wrapper { width:min(100%,680px); }
.home-section { padding:64px 0; }
.home-section-heading { margin-bottom:28px; }
.home-section-heading--action { display:flex; align-items:end; justify-content:space-between; gap:24px; }
.featured-layout { display:grid; grid-template-columns:minmax(0,1.35fr) minmax(280px,.65fr); gap:20px; }
.latest-layout { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:20px; }
.latest-layout .post-card--latest-lead { grid-row:span 2; }
@media (max-width:760px) { .home-hero { grid-template-columns:1fr; min-height:auto; padding:44px 0 56px; } .home-hero-media { width:100%; aspect-ratio:4/3; } .home-search { margin:-18px 0 48px; } .featured-layout,.latest-layout { grid-template-columns:1fr; } .latest-layout .post-card--latest-lead { grid-row:auto; } .home-section-heading--action { align-items:flex-start; flex-direction:column; } }
```

- [ ] **Step 4: Run the structural check**

Run: `npm run check:homepage-ui`

Expected: PASS and print `Homepage UI checks passed`.

- [ ] **Step 5: Commit the homepage composition**

```bash
git add src/components/HomepageHero.astro src/pages/index.astro src/styles/home.css
git commit -m "Recompose the blog homepage"
```

### Task 4: Implement Dual Theme Tokens and Restrained Liquid Glass

**Files:**
- Modify: `src/styles/global.css`
- Modify: `src/styles/home.css`
- Modify: `src/components/ThemeToggle.astro`
- Modify: `src/components/Search.astro`

**Interfaces:**
- Consumes: existing `[data-theme="light"]` theme state and CSS custom properties.
- Produces: `--glass-fill`, `--glass-border`, `--glass-highlight`, `--ambient-1`, and `--ambient-2` tokens used by header, search, toggle, hero annotation, and featured primary story.

- [ ] **Step 1: Replace root palette tokens without changing token consumers**

Define dark defaults in `:root`:

```css
--bg:#120d19; --surface:#1c1426; --surface-strong:#21172d; --surface-soft:#291c35;
--text:#fbf3ff; --muted:#bdaec8; --line:rgba(255,153,221,.18);
--accent:#ff72c7; --accent-strong:#ff9bd8; --warm:#ff72c7; --sun:#ddff5c; --sea:#9d84ff;
--glass-fill:rgba(35,20,48,.58); --glass-border:rgba(255,211,241,.24); --glass-highlight:rgba(255,255,255,.34);
--ambient-1:rgba(255,64,190,.22); --ambient-2:rgba(126,91,255,.20);
```

Define light overrides in `[data-theme="light"]`:

```css
--bg:#dfeaf0; --surface:#f4fafb; --surface-strong:#f8fcfd; --surface-soft:#cde2e4;
--text:#15303a; --muted:#55717a; --line:rgba(18,101,97,.18);
--accent:#087f76; --accent-strong:#055f59; --warm:#087f76; --sun:#a5b900; --sea:#4779a8;
--glass-fill:rgba(242,252,251,.62); --glass-border:rgba(255,255,255,.72); --glass-highlight:rgba(255,255,255,.82);
--ambient-1:rgba(89,196,176,.24); --ambient-2:rgba(198,221,74,.18);
```

- [ ] **Step 2: Convert only approved surfaces to liquid glass**

Use the same material recipe for `.site-header`, `.search-bar`, `#theme-toggle`, `.home-hero-count`, and `.homepage .post-card--featured-primary`:

```css
background:linear-gradient(135deg,var(--glass-highlight),transparent 45%),var(--glass-fill);
border:1px solid var(--glass-border);
backdrop-filter:blur(22px) saturate(155%);
-webkit-backdrop-filter:blur(22px) saturate(155%);
box-shadow:inset 0 1px 0 var(--glass-highlight),0 20px 54px color-mix(in srgb,var(--bg) 62%,transparent);
```

Keep ordinary `.post-card` surfaces opaque or nearly opaque. Add a localized pseudo-element reflection to the featured primary card and search bar only; it must use `pointer-events:none`.

- [ ] **Step 3: Add required fallback media and support rules**

Append to `home.css`:

```css
@supports not (backdrop-filter: blur(1px)) { .site-header,.search-bar,#theme-toggle,.home-hero-count,.homepage .post-card--featured-primary { background:var(--surface-strong); } }
@media (prefers-reduced-transparency: reduce) { .site-header,.search-bar,#theme-toggle,.home-hero-count,.homepage .post-card--featured-primary { background:var(--surface-strong); backdrop-filter:none; -webkit-backdrop-filter:none; } }
@media (prefers-reduced-motion: reduce) { .homepage *, .homepage *::before, .homepage *::after { scroll-behavior:auto !important; animation-duration:.01ms !important; animation-iteration-count:1 !important; transition-duration:.01ms !important; } }
```

- [ ] **Step 4: Restyle search states and theme toggle**

Keep all existing IDs and event listeners. Change only component CSS so focus, result, loading, empty, and error states use the new tokens. The toggle remains a 44px minimum touch target and continues to update `data-theme`, `colorScheme`, and `localStorage` exactly as before.

- [ ] **Step 5: Run checks**

Run: `npm run check:homepage-ui`

Expected: PASS.

Run: `npm run typecheck`

Expected: PASS with zero errors.

- [ ] **Step 6: Commit the dual-theme material system**

```bash
git add src/styles/global.css src/styles/home.css src/components/Search.astro src/components/ThemeToggle.astro
git commit -m "Style the dual-theme liquid interface"
```

### Task 5: Add Motivated Reveal Motion and Complete Verification

**Files:**
- Modify: `src/pages/index.astro`
- Modify: `src/styles/home.css`
- Modify: `scripts/check-homepage-ui.mjs`

**Interfaces:**
- Consumes: elements marked with `[data-home-reveal]`.
- Produces: one-time `.is-visible` state through IntersectionObserver; reduced-motion users receive visible content without transforms.

- [ ] **Step 1: Extend the regression check for safe motion**

Add to `scripts/check-homepage-ui.mjs`:

```js
assert.match(index, /new IntersectionObserver/);
assert.match(index, /observer\.disconnect\(\)/);
assert.doesNotMatch(index, /window\.addEventListener\(["']scroll/);
```

Run: `npm run check:homepage-ui`

Expected: FAIL because the observer is not implemented.

- [ ] **Step 2: Add one-time reveal hooks and observer**

Add `data-home-reveal` to the hero copy, hero media, featured layout, and latest layout. Add this script at the end of `index.astro`:

```astro
<script>
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const revealItems = document.querySelectorAll<HTMLElement>("[data-home-reveal]");

  if (reducedMotion) {
    revealItems.forEach((item) => item.classList.add("is-visible"));
  } else {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.16 },
    );
    revealItems.forEach((item) => observer.observe(item));
    document.addEventListener("astro:before-swap", () => observer.disconnect(), { once: true });
  }
</script>
```

Add the paired CSS:

```css
[data-home-reveal] { opacity:0; transform:translateY(18px); transition:opacity 600ms ease,transform 600ms cubic-bezier(.2,.75,.25,1); }
[data-home-reveal].is-visible { opacity:1; transform:none; }
@media (prefers-reduced-motion:reduce) { [data-home-reveal] { opacity:1; transform:none; } }
```

- [ ] **Step 3: Run automated verification**

Run: `npm run check:homepage-ui`

Expected: PASS.

Run: `npm run typecheck`

Expected: PASS with zero errors.

Run: `npm run build`

Expected: PASS, static pages generated, and Pagefind index produced.

- [ ] **Step 4: Run desktop and mobile visual verification**

Run: `npm run dev`.

Inspect the homepage at approximately 1440px and 390px widths in both light and dark modes. Verify:

- Header remains one line at desktop and does not overflow at mobile.
- Hero headline stays within two desktop lines and both CTAs are visible in the initial viewport.
- Featured and latest layouts collapse to one column below 768px.
- Theme toggle persists after reload.
- Search focus, loading, empty, populated, Escape, outside click, and Ctrl/Cmd K behaviors still work.
- Keyboard focus is visible and traversal order is logical.
- Disabling backdrop-filter and enabling reduced motion or transparency leaves all content readable.
- No visible homepage string uses an em dash or en dash separator.

- [ ] **Step 5: Commit the verified interaction layer**

```bash
git add src/pages/index.astro src/styles/home.css scripts/check-homepage-ui.mjs
git commit -m "Add accessible homepage reveal motion"
```

- [ ] **Step 6: Review final scope**

Run: `git diff --check HEAD~4 HEAD`.

Expected: no whitespace errors.

Run: `git status --short`.

Expected: only pre-existing unrelated user files remain modified or untracked.
