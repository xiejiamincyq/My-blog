# Comment UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix oversized dynamically rendered comment avatars and deliver a polished layered-card comments UI with distinct dark and light theme treatments.

**Architecture:** Keep the existing Supabase client-side rendering and data flow unchanged. Make the selectors for DOM nodes produced by `renderComment()` global to the component so Astro's scoped CSS does not exclude runtime-created nodes. Add a small Node regression script that verifies the avatar class and its fixed 32px global styling stay coupled.

**Tech Stack:** Astro 7, component-scoped CSS with `:global()`, browser DOM APIs, Node.js built-in `node:fs` and `node:assert`.

## Global Constraints

- Do not change Supabase schema, authentication, comment ordering, publishing behavior, or the admin comment UI.
- Dynamic comments use the existing `comment-avatar`, `comment-avatar-fallback`, `comment-card`, `comment-meta`, `comment-author`, and `comment-body` class names.
- Avatar width and height are exactly 32px and images use `object-fit: cover`.
- Dark theme uses a deep translucent blue-black gradient and cyan border; light theme uses a translucent white surface, teal-tinted border, and soft blue-gray shadow.
- Preserve the existing mobile breakpoint at 620px.

---

### Task 1: Add a regression check for runtime comment styles

**Files:**
- Create: `scripts/check-comment-ui.mjs`
- Modify: `package.json`

**Interfaces:**
- Consumes: `src/components/SupabaseComments.astro` as UTF-8 source text.
- Produces: `npm run check:comment-ui`, exiting with code 0 when runtime comment classes are globally styled and fixed avatar dimensions are present.

- [ ] **Step 1: Write the failing regression check**

Create `scripts/check-comment-ui.mjs`:

```js
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const component = await readFile(new URL("../src/components/SupabaseComments.astro", import.meta.url), "utf8");

assert.match(component, /image\.className = "comment-avatar"/);
assert.match(component, /:global\(\.comment-avatar\),\s*:global\(\.comment-avatar-fallback\)/);
assert.match(component, /:global\(\.comment-avatar\),\s*:global\(\.comment-avatar-fallback\)[\s\S]*?width: 32px;[\s\S]*?height: 32px;/);
assert.match(component, /:global\(\.comment-avatar\)\s*\{[\s\S]*?object-fit: cover;/);

console.log("Comment UI regression checks passed.");
```

Add this script entry to `package.json`:

```json
"check:comment-ui": "node scripts/check-comment-ui.mjs"
```

- [ ] **Step 2: Run the regression check to verify it fails**

Run: `npm run check:comment-ui`

Expected: the command fails because `SupabaseComments.astro` still has scoped `.comment-avatar` selectors and 34px dimensions.

- [ ] **Step 3: Commit the failing test only if the repository policy supports red commits**

Do not commit a known-failing test in this repository; continue directly to Task 2 so the next commit is buildable.

### Task 2: Make dynamic comment styles global and apply layered theme variants

**Files:**
- Modify: `src/components/SupabaseComments.astro:42-212`
- Test: `scripts/check-comment-ui.mjs`

**Interfaces:**
- Consumes: the class names applied in `renderComment()`.
- Produces: global rules that match dynamic avatar and card nodes in both themes.

- [ ] **Step 1: Update the runtime-node selectors and dimensions**

Replace the dynamic-node rules in `SupabaseComments.astro` with global selectors. Keep the form and heading selectors scoped because they are static Astro markup.

```css
:global(.comment-list) {
  display: grid;
  gap: 14px;
  margin-top: 22px;
}

:global(.comment-card) {
  border: 1px solid rgba(126, 240, 255, 0.2);
  border-radius: 12px;
  background: linear-gradient(145deg, rgba(12, 22, 38, 0.9), rgba(7, 13, 25, 0.72));
  padding: 18px;
  box-shadow: 0 14px 32px rgba(0, 0, 0, 0.22);
}

:global(.comment-meta) {
  display: grid;
  grid-template-columns: 32px minmax(0, 1fr);
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
}

:global(.comment-author) {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 4px 10px;
  min-width: 0;
}

:global(.comment-author strong) {
  color: var(--text);
  line-height: 1.25;
}

:global(.comment-author time) {
  color: var(--muted);
  font-size: 13px;
}

:global(.comment-avatar),
:global(.comment-avatar-fallback) {
  display: inline-grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border: 1px solid rgba(138, 245, 255, 0.3);
  border-radius: 999px;
}

:global(.comment-avatar) {
  object-fit: cover;
}

:global(.comment-avatar-fallback) {
  background: linear-gradient(135deg, rgba(71, 233, 255, 0.2), rgba(255, 95, 200, 0.18));
  color: var(--accent-strong);
  font-size: 13px;
  font-weight: 800;
}

:global(.comment-body) {
  margin: 0;
  color: var(--text);
  line-height: 1.8;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
```

- [ ] **Step 2: Add a distinct light-theme variant**

Replace the existing light comment-card selector with:

```css
[data-theme="light"] :global(.comment-card) {
  border-color: rgba(13, 125, 110, 0.18);
  background: linear-gradient(145deg, rgba(255, 255, 255, 0.9), rgba(242, 248, 250, 0.78));
  box-shadow: 0 12px 28px rgba(49, 90, 112, 0.1);
}

[data-theme="light"] :global(.comment-avatar),
[data-theme="light"] :global(.comment-avatar-fallback) {
  border-color: rgba(13, 125, 110, 0.2);
}
```

- [ ] **Step 3: Run the regression check to verify it passes**

Run: `npm run check:comment-ui`

Expected: `Comment UI regression checks passed.` and exit code 0.

- [ ] **Step 4: Format the changed files**

Run: `npx prettier --write src/components/SupabaseComments.astro scripts/check-comment-ui.mjs package.json`

Expected: Prettier completes without errors.

- [ ] **Step 5: Commit the implementation**

```bash
git add src/components/SupabaseComments.astro scripts/check-comment-ui.mjs package.json
git commit -m "Fix comment avatar styles"
```

### Task 3: Verify the component in production conditions

**Files:**
- Verify: `src/components/SupabaseComments.astro`
- Verify: `scripts/check-comment-ui.mjs`

**Interfaces:**
- Consumes: the implementation from Tasks 1 and 2.
- Produces: build and type-check evidence for the final handoff.

- [ ] **Step 1: Run static UI regression validation**

Run: `npm run check:comment-ui`

Expected: `Comment UI regression checks passed.` and exit code 0.

- [ ] **Step 2: Run Astro type checking**

Run: `npm run typecheck`

Expected: exit code 0 with no new errors in `SupabaseComments.astro`.

- [ ] **Step 3: Run the production build**

Run: `npm run build`

Expected: Astro completes the production build with exit code 0.

- [ ] **Step 4: Visually inspect both themes and viewport widths**

Run: `npm run dev`

Inspect an article page with visible comments in dark and light themes at desktop width and 375px width. Confirm avatar circles render at 32px, cards use the appropriate theme surface, and the heading/form action layout stacks below 620px.

- [ ] **Step 5: Commit any verification-only correction**

If inspection found no issue, do not create a commit. If one small correction was necessary, stage only the corrected implementation files and commit it with `Fix comment UI responsive styling`.
