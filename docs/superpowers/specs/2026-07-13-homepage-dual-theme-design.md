# Homepage Dual-Theme Redesign

## Goal

Redesign the Astro blog homepage as a highly distinctive personal publishing surface with two coordinated visual identities:

- Light mode: a clear, organic digital garden.
- Dark mode: a deep, liquid digital nightscape.

The redesign must preserve the site's information architecture, routes, navigation labels, article content, SEO behavior, theme persistence, and accessibility. It should replace the current cyberpunk city and generic glass-card treatment on the homepage without forcing a redesign of every internal page in the same change.

## Design Read

Reading this as an editorial personal blog for Chinese readers interested in technology, reading, and everyday observation, with a digital-garden and liquid-digital language, implemented as a native Astro and CSS design system.

Global design dials:

- `DESIGN_VARIANCE: 8`
- `MOTION_INTENSITY: 6`
- `VISUAL_DENSITY: 4`

This is a redesign-overhaul for the homepage visuals with strict content and information-architecture preservation.

## Selected Direction

The selected direction is “Digital Garden and Liquid Night.” Both modes share the same grid, component hierarchy, radius system, typographic scale, and interaction model. They differ in light, material, palette, and atmosphere.

### Light Mode

Light mode should feel like a digital garden in cool morning light:

- Mist-blue canvas rather than warm cream.
- Deep blue-green text and structure.
- Mint green as the single primary accent.
- Acid yellow used only as a small supporting highlight, never as a competing CTA color.
- Soft organic fields or photographic imagery behind selected content.
- Clear-water glass with restrained blur and low-opacity highlights.
- Generous negative space and crisp editorial typography.

### Dark Mode

Dark mode should feel like a liquid digital nightscape:

- Near-black violet canvas.
- Soft off-white text.
- Magenta as the single primary accent.
- Acid yellow retained only as a small supporting highlight.
- Violet and magenta ambient reflections around key surfaces.
- Dark liquid-glass depth with localized bloom, not page-wide glow.
- Strong contrast and calmer empty space around article content.

Each mode locks its own palette across the entire page. The page does not invert individual sections.

## Liquid Glass Treatment

The design uses a web liquid-glass approximation. It is not presented as Apple's official Liquid Glass. The effect is built with native CSS:

- `backdrop-filter` and `-webkit-backdrop-filter`
- layered translucent fills
- inner highlight borders
- localized radial reflections
- tinted shadows matching each theme
- subtle pseudo-element refraction layers

Liquid glass is limited to surfaces where translucency communicates hierarchy:

1. Floating site header and navigation.
2. Search surface and focused search state.
3. Theme toggle control.
4. One featured-story surface in the homepage composition.

Standard article entries rely on typography, imagery, spacing, and sparse dividers. They do not become a grid of identical glass cards.

Fallback behavior:

- `prefers-reduced-transparency: reduce` receives opaque, high-contrast surfaces.
- Browsers without backdrop-filter support receive a solid themed background.
- Narrow screens use lower blur and smaller shadow radii.
- Motion does not continuously animate blur or large shadow regions.

## Homepage Structure

### Floating Header

The existing brand, navigation labels, authentication state, and theme control remain. The header becomes a one-line floating glass bar on desktop, no taller than 72px. At narrow widths it wraps into the existing mobile navigation behavior without horizontal overflow.

### Asymmetric Hero

The hero uses an asymmetric editorial composition rather than a centered stack:

- Left side: one restrained eyebrow, a two-line headline, a short description, and the existing two CTA intents.
- Right side: a real visual field drawn from an existing post image or site artwork, composed with an organic mask.
- Article count moves out of the generic metric card and becomes a small editorial annotation attached to the visual field.

The hero fits inside the initial desktop viewport. CTA labels remain on one line. On mobile, the visual follows the copy and uses a stable aspect ratio.

### Search Portal

Search becomes a distinct glass portal immediately after the hero. It remains functionally identical, including Pagefind behavior, empty states, results, keyboard focus, and error handling. Its visual state changes clearly between idle, focus, loading, populated, and unavailable states.

### Featured Stories

Featured stories use a 1+1 editorial split with intentional asymmetry:

- The first item is image-led and larger.
- The second item is more typographic and compact.
- Each story uses a different internal composition while sharing metadata and accessibility behavior from `PostCard`.

If no posts are featured, the entire section remains absent, matching current behavior.

### Latest Writing

Latest posts use a magazine-style grid that avoids repeated equal cards. The first latest item may span more space when enough posts exist, while the remaining items use compact rows. The grid collapses to a single readable column below 768px.

The “all articles” link remains and retains its destination and intent.

### Footer Transition

The homepage concludes with a quiet visual transition into the existing footer. No duplicate CTA is added. Footer content and legal text remain unchanged.

## Typography and Shape System

The redesign uses the existing system font stack initially to avoid a network font dependency. Display text uses weight, scale, and letter spacing to create personality. Chinese body text remains optimized for legibility with `Microsoft YaHei` and system fallbacks.

Typography rules:

- Hero title: two lines maximum on desktop.
- Hero description: twenty words or fewer when translated to English-equivalent density, and four rendered lines maximum.
- Body copy: readable line height and approximately 60 to 68 Chinese characters at the widest reading measure.
- One eyebrow in the hero. Section headings avoid repeated uppercase micro-labels.

Shape rules:

- Primary surface radius: 18px.
- Compact controls: 12px.
- Buttons may use full-pill geometry as an explicit control-only exception.
- Organic media masks are decorative image geometry, not component radii.

## Imagery

The homepage must use real visual assets. Priority:

1. Existing post cover images when available.
2. Existing site artwork when it supports the selected theme.
3. A generated homepage-specific visual if the content collection lacks suitable imagery.

Decorative fake dashboards and hand-built fake screenshots are not used. Images include useful alt text, explicit dimensions or aspect ratios, lazy loading below the fold, and object positioning that works in both themes.

## Motion

Motion is used to explain hierarchy and state:

- Hero copy and visual enter with a short stagger on first load.
- Featured stories reveal once as they approach the viewport.
- Article imagery receives a restrained scale or mask shift on hover.
- Theme switching crossfades tokens and reflections without animating the entire layout.
- Buttons provide tactile active feedback.

Implementation uses CSS animation and `IntersectionObserver`, avoiding a new runtime dependency. No window-level scroll listener is added. All motion has a `prefers-reduced-motion` fallback that removes transforms and stagger delays.

## Component and Code Boundaries

The implementation should keep responsibilities focused:

- `src/pages/index.astro`: homepage data selection and section composition.
- `src/components/PostCard.astro`: shared article semantics, with optional visual variants if required.
- `src/components/Search.astro`: existing search behavior plus homepage visual states.
- `src/components/Header.astro` and `ThemeToggle.astro`: glass header and theme-control states without changing their public behavior.
- `src/styles/global.css`: shared design tokens, baseline components, both theme palettes, fallbacks, and responsive rules.
- A homepage-specific component or stylesheet may be introduced if global CSS would otherwise accumulate unrelated homepage-only rules.

No new third-party package is required for the design.

## Data and State Behavior

The homepage keeps its current data sources:

- `getPublishedPosts()` supplies published content.
- Featured posts remain the first two posts marked `featured`.
- Latest posts remain the first four published posts unless the final layout requires the same four in a different visual order.
- Search remains driven by the current Pagefind integration.
- Theme selection remains stored and restored through the current theme mechanism.

Empty and degraded states:

- No featured posts: omit the featured section.
- No latest posts: show a concise empty-state message and a route-appropriate action if one already exists.
- Missing cover image: use an intentional theme-aware media field, not a broken image or fake screenshot.
- Search unavailable: preserve the current clear unavailable or error message.

## Accessibility

The redesign must preserve or improve:

- Semantic heading order.
- Keyboard navigation and visible focus styles.
- WCAG AA contrast for text, controls, placeholders, metadata, and focus rings.
- Minimum 44px touch targets for primary interactive controls.
- Descriptive image alt text and decorative-image hiding.
- Reduced motion and reduced transparency preferences.
- No content encoded by color alone.
- Stable layout without cumulative layout shift from imagery.

## SEO and Preservation Constraints

The redesign does not change:

- Route paths or slugs.
- Primary navigation labels.
- Existing page titles, canonical behavior, Open Graph metadata, RSS, or sitemap behavior.
- Article copy, post metadata, or tag semantics.
- Authentication, view count, comments, or Supabase integration.
- Existing analytics-relevant IDs or form field names, if present.

## Validation

Required validation before completion:

1. `npm run build` passes.
2. `npm run typecheck` passes or any pre-existing failures are reported separately.
3. Homepage is visually inspected in both themes at desktop width.
4. Homepage is visually inspected in both themes below 768px.
5. Keyboard navigation reaches all header, hero, search, article, and theme controls in a logical order.
6. Reduced-motion behavior is verified.
7. Liquid-glass fallback remains readable when backdrop filtering is unavailable or transparency is reduced.
8. Visible homepage copy contains no em dash or en dash separators.
9. Accent colors, surface radii, and CTA intent are audited for consistency.
10. Header remains one line on desktop and no horizontal overflow appears on mobile.

## Success Criteria

The redesign is successful when:

- Light and dark modes feel deliberately authored rather than simple palette swaps.
- Both modes are recognizably part of the same blog.
- The homepage has a strong personal identity without obscuring article discovery.
- Liquid glass creates hierarchy in a small number of surfaces and does not become a repeated card gimmick.
- Existing content, routes, SEO, search, and theme functionality continue to work.
- Desktop and mobile layouts are polished, legible, responsive, and performant.
