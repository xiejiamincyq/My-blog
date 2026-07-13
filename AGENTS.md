# Repository Guidelines

## Project Structure & Module Organization

This is an Astro static blog. Source files live in `src/`: pages are in `src/pages`, shared layouts in `src/layouts`, reusable UI in `src/components`, content collections in `src/content`, and helpers in `src/lib`. Global styling is in `src/styles/global.css`. Static assets served as-is belong in `public/`, including images and `favicon.svg`. Build helpers are in `scripts/`. Generated output in `dist/`, Astro cache in `.astro/`, and dependencies in `node_modules/` should not be edited or committed.

## Build, Test, and Development Commands

Use npm scripts from the repository root:

```bash
npm run dev
npm run build
npm run preview
```

`npm run dev` starts the local Astro development server. `npm run build` creates the static site in `dist/` and should pass before publishing. `npm run preview` serves the built output for a production-like local check.

## Coding Style & Naming Conventions

Use two-space indentation in Astro, TypeScript, CSS, and Markdown frontmatter. Prefer clear component names in PascalCase, such as `PostCard.astro` and `BlogPostLayout.astro`. Page routes should follow Astro conventions: `src/pages/blog/[slug].astro`, `src/pages/tags/[tag].astro`, and folder `index.astro` files for route roots. Keep content slugs lowercase and hyphenated. Add shared logic to `src/lib` rather than duplicating it across pages.

## Testing Guidelines

There is no dedicated test framework configured yet. Treat `npm run build` as the required validation step for all changes. For visual or UI changes, also run `npm run dev` and inspect the affected pages in a browser, including desktop and narrow viewport widths. If tests are added later, place them near the code they cover or under a clearly named test directory, and add an npm script for repeatable execution.

## Commit & Pull Request Guidelines

Existing commits use short, imperative, sentence-case messages, for example `Fix GitHub Pages base paths` and `Prepare GitHub Pages deployment`. Follow that style and keep each commit focused. Pull requests should include a concise summary, the validation performed, and screenshots for visible UI changes. Mention related issues when applicable and call out any deployment, configuration, or environment variable changes.

## Security & Configuration Tips

Do not commit `.env` files or secrets; they are already ignored. Keep deployment-specific paths compatible with `astro.config.mjs`, which handles GitHub Pages base paths. Store public, non-secret assets in `public/`; keep private credentials outside the repository.

## Project Skills

When asked to beautify, redesign, or otherwise make this site's marketing, editorial, portfolio, landing-page, or about-page UI more polished, read and apply `.agents/skills/taste-skill/SKILL.md` before changing code. This skill is project-local; do not use it for unrelated projects. For dashboard, dense admin, multi-step form, or data-table UI, follow the skill's out-of-scope guidance instead.
