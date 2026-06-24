# Disney+ Design System

A reference for building a streaming interface in the spirit of Disney+. This document captures the visual language, component patterns, motion principles, and tokens you can use to build a faithful Disney+–style UI without reproducing Disney's proprietary assets (logos, character art, trademarked typefaces).

---

## 1. Design Principles

1. **Cinematic by default.** The interface is a window into stories, not a stage for chrome. UI fades back; artwork leads.
2. **Dark, deep, premium.** A near-black navy canvas gives posters and key art maximum contrast and saturation.
3. **Magical, not playful.** The brand sits between luxury and family-friendly — restrained motion, generous spacing, soft glows. Avoid cartoon-y or overly bouncy interactions.
4. **Franchise-first navigation.** The home screen privileges *brands* (Disney, Pixar, Marvel, Star Wars, National Geographic, Star) before genres. Brand tiles are the anchor of discovery.
5. **One thing at a time.** Hero carousels, large tiles, and big type prioritize one piece of content per viewport zone.
6. **Trustworthy density.** Long horizontal rails of equal-sized tiles. Predictable, scannable, never cluttered.

---

## 2. Color

The palette is dominated by deep navy with a single saturated blue accent. Everything else is grayscale.

### Tokens

```css
:root {
  /* Surface */
  --surface-0:        #06080c;  /* page background, top of gradient */
  --surface-1:        #0c111c;  /* card background, content area */
  --surface-2:        #141a26;  /* elevated card, modal */
  --surface-3:        #1f2733;  /* hover surface, input background */

  /* Text */
  --text-primary:     #f9f9f9;  /* headings, primary copy */
  --text-secondary:   #c5cad3;  /* metadata, descriptions */
  --text-tertiary:    #8a8f98;  /* timestamps, captions */
  --text-disabled:    #555a64;

  /* Brand / Accent */
  --accent-blue:      #0063e5;  /* primary CTA, focus ring */
  --accent-blue-hov:  #0483ee;  /* hover state */
  --accent-blue-glow: rgba(0, 99, 229, 0.45);

  /* Semantic */
  --success:          #1f9d55;
  --warning:          #f5a623;
  --danger:           #e3342f;

  /* Borders & Dividers */
  --border-subtle:    rgba(255, 255, 255, 0.08);
  --border-strong:    rgba(255, 255, 255, 0.18);
  --border-focus:     #f9f9f9;   /* white focus ring on tiles */
}
```

### Signature Gradient

The home page uses a radial blue glow bleeding from the hero into the dark canvas:

```css
background:
  radial-gradient(ellipse 80% 60% at 50% 0%,
    rgba(0, 99, 229, 0.35) 0%,
    rgba(0, 99, 229, 0.10) 40%,
    var(--surface-0) 75%);
```

### Usage rules

- **Never** use pure black (`#000`) or pure white (`#fff`) for large surfaces — they kill the cinematic depth. Use `--surface-0` and `--text-primary`.
- The accent blue is reserved for: primary CTA, focus rings, active nav state, progress bars. Don't use it for decorative chrome.
- Posters and key art carry the color. The shell stays monochrome so artwork can sing.

---

## 3. Typography

Disney+ uses a proprietary geometric sans (Inspire/AvenirNext-derived). For an open-source equivalent, pair a humanist geometric sans for display with a clean neutral sans for body.

### Recommended stack

```css
--font-display: "Inspire", "Avenir Next", "Sofia Pro", "Inter", sans-serif;
--font-body:    "Inspire", "Avenir Next", -apple-system, BlinkMacSystemFont, sans-serif;
--font-mono:    "JetBrains Mono", ui-monospace, monospace;
```

### Scale

| Token             | Size     | Line height | Weight | Usage                              |
|-------------------|----------|-------------|--------|------------------------------------|
| `--text-hero`     | 72px     | 1.05        | 700    | Logo-art replacements, hero titles |
| `--text-display`  | 48px     | 1.1         | 700    | Page titles, marketing hooks       |
| `--text-h1`       | 32px     | 1.2         | 700    | Section dividers                   |
| `--text-h2`       | 24px     | 1.25        | 600    | Row headers ("Trending Now")       |
| `--text-h3`       | 20px     | 1.3         | 600    | Tile titles in expanded view       |
| `--text-body`     | 16px     | 1.5         | 400    | Descriptions, body copy            |
| `--text-meta`     | 14px     | 1.45        | 500    | Metadata, year/duration/rating     |
| `--text-caption`  | 12px     | 1.4         | 500    | Badges, fine print                 |
| `--text-micro`    | 11px     | 1.3         | 600    | All-caps labels (UHD, 5.1, IMAX)   |

### Rules

- Headings: tight tracking (`letter-spacing: -0.01em` to `-0.02em`).
- Micro labels (UHD, HDR, 4K, IMAX Enhanced): `text-transform: uppercase`, `letter-spacing: 0.08em`, `font-weight: 600`.
- Body copy never exceeds 65 characters per line in detail views.
- Tile titles are rendered as logo art (image), not text, whenever possible — this is a Disney+ signature.

---

## 4. Spacing & Layout

An 8px base grid. Everything snaps to multiples of 4.

```css
--space-1:  4px;
--space-2:  8px;
--space-3:  12px;
--space-4:  16px;
--space-5:  24px;
--space-6:  32px;
--space-8:  48px;
--space-10: 64px;
--space-12: 80px;
--space-16: 128px;
```

### Page rhythm

- Left/right page padding: `var(--space-8)` on desktop (48px), `var(--space-4)` on mobile.
- Vertical gap between content rows: `var(--space-8)` (48px).
- Gap between tiles within a row: `var(--space-2)` (8px), expanding to `var(--space-3)` on hover.
- Top nav height: 70px, transparent over hero, solid `--surface-0` after 80px scroll.

### Breakpoints

```css
--bp-mobile:   480px;
--bp-tablet:   768px;
--bp-laptop:  1024px;
--bp-desktop: 1440px;
--bp-tv:      1920px;   /* 10-foot UI */
```

---

## 5. Component Patterns

### 5.1 Top Navigation

- Transparent at scroll = 0, fades to `var(--surface-0)` with `backdrop-filter: blur(12px)` after 80px.
- Logo mark left-aligned. Primary links: Home, Search, Watchlist, Originals, Movies, Series.
- Profile avatar right-aligned, 32px, circular, with a 2px border on focus.
- Height: 70px desktop, 56px mobile (bottom-anchored on mobile with icon-only nav).

### 5.2 Hero Carousel (Billboard)

- Full-bleed, edge-to-edge, 16:9 on desktop, taller crop on mobile (~4:5).
- Background image scales from 100% → 105% over 8s while idle (subtle Ken Burns).
- Bottom 40% has a vertical gradient overlay: `linear-gradient(to top, var(--surface-0) 0%, transparent 60%)` to land copy on dark.
- Title rendered as logo art positioned bottom-left, ~25% page width.
- Metadata row below logo: year · duration · rating · genre tags, separated by `·`.
- Auto-advance every 8s. Pagination dots bottom-right. Pause on hover.

### 5.3 Brand Tile Strip

The franchise rail is unique to Disney+. Five to six oversized branded tiles in a single row directly under the hero.

- Aspect ratio: 16:9.
- Each tile has a looping background video clip (muted, ~3s loop) and a centered brand logo.
- Hover: scale 1.05, blue glow `box-shadow: 0 0 24px var(--accent-blue-glow)`, video plays at full speed.
- Border on hover: 2px solid `var(--text-primary)`.
- Transition: 300ms `cubic-bezier(0.4, 0, 0.2, 1)`.

### 5.4 Content Row (Shelf)

```
┌─────────────────────────────────────────────┐
│ Trending Now                         See All │
├─────────────────────────────────────────────┤
│ [tile] [tile] [tile] [tile] [tile] [tile] → │
└─────────────────────────────────────────────┘
```

- Header: `--text-h2`, left-aligned, with optional "See All" link right-aligned.
- 6 tiles visible at desktop, 4 at tablet, 2.5 at mobile (peek pattern).
- Horizontal scroll with snap: `scroll-snap-type: x mandatory`.
- Arrow controls fade in on row hover (desktop only), positioned outside the row.

### 5.5 Content Tile (Poster Card)

- Default aspect: 16:9 landscape (Disney+ favors landscape over portrait posters).
- Inner padding: 0. Artwork is edge-to-edge.
- Border radius: `4px`.
- Default state: 100% scale, no border.
- Hover state:
  - Scale 1.08
  - Border: 2px solid `var(--text-primary)`
  - Z-index lifted above siblings
  - Adjacent tiles do NOT shift (overlay, not push)
  - Background video preview begins after 800ms hover delay
  - Drop shadow: `0 12px 32px rgba(0, 0, 0, 0.6)`
- Title logo + metadata + CTA appear in an expanded info panel below the tile after 1.2s.

### 5.6 Detail Page

- Full-bleed hero with key art, same gradient overlay as billboard.
- Below the fold, content sits on `var(--surface-1)`.
- Primary CTA: large pill button, `var(--accent-blue)`, white text, play icon left.
- Secondary CTAs (Add to Watchlist, Trailer, Download): outlined pill buttons with `var(--border-strong)`.
- Episode list: vertical stack of 16:9 thumbnails left, title + synopsis right.

### 5.7 Buttons

```css
.btn-primary {
  background: var(--accent-blue);
  color: var(--text-primary);
  padding: 14px 32px;
  border-radius: 4px;
  font: 600 16px/1 var(--font-display);
  letter-spacing: 0.02em;
  transition: background 200ms ease, transform 200ms ease;
}
.btn-primary:hover {
  background: var(--accent-blue-hov);
  transform: scale(1.02);
}
```

Pill buttons (radius `999px`) are used for CTA stacks on detail pages. Rectangular buttons (radius `4px`) are used in modals and forms.

### 5.8 Form Inputs

- Background: `var(--surface-3)`.
- Border: 1px solid `var(--border-subtle)`, becomes `var(--accent-blue)` on focus with a 4px outer glow.
- Height: 48px, padding: 0 16px.
- Label sits above the input, `--text-meta`, all-caps tracked.

### 5.9 Profile Picker

- Centered on `var(--surface-0)`.
- Avatars are 160px circles arranged in a row of up to 5, wrap on smaller screens.
- Each avatar pulses subtly on hover: scale 1.08, white ring appears, 200ms.
- Title above: "Who's watching?" in `--text-display`.

---

## 6. Iconography

- Line icons, 1.5px stroke, rounded caps, on a 24px grid.
- Filled icons reserved for: active nav state, primary CTA play icon.
- Source: a consistent set like Phosphor, Lucide (rounded variant), or a custom set. Mixing icon sets breaks the premium feel.

---

## 7. Motion

Motion in Disney+ is **slow, confident, and silky**. Never bouncy. Never abrupt.

### Easing tokens

```css
--ease-out:     cubic-bezier(0.22, 1, 0.36, 1);     /* most UI transitions */
--ease-in-out:  cubic-bezier(0.65, 0, 0.35, 1);     /* page transitions */
--ease-spring:  cubic-bezier(0.34, 1.56, 0.64, 1);  /* used sparingly */
```

### Duration tokens

```css
--dur-fast:   150ms;   /* hover state changes */
--dur-base:   300ms;   /* tile hover, button hover */
--dur-slow:   600ms;   /* page transitions, modal */
--dur-cinema: 1200ms;  /* hero crossfades */
```

### Key motion patterns

- **Tile hover**: scale and border appear together over 300ms. Background video fades in after 800ms.
- **Hero crossfade**: 1200ms, with a 200ms still-frame hold between transitions.
- **Modal entry**: backdrop fades in 300ms, modal scales from 0.96 → 1 over 400ms.
- **Page change**: outgoing page fades to black (300ms), incoming page hero fades in (600ms).
- **Loader**: a thin progress bar in `--accent-blue` slides left-to-right; no spinners.

Respect `prefers-reduced-motion: reduce` — disable Ken Burns, background video previews, and scale transforms; keep only opacity transitions.

---

## 8. Imagery Guidelines

- **Hero / key art**: 16:9 minimum 1920×1080, ideally 3840×2160. Subject framed in the left third (logo lands left); right third stays cinematic.
- **Tile art**: 16:9 landscape. Title logo baked into the image, bottom-left or center.
- **Brand tile**: 16:9 with a short looping clip (3s, no audio, ~2MB max).
- **Avatars**: square, 320×320, transparent background, character framed top-down.
- All artwork sits on dark backgrounds — avoid bright white art that breaks the cinematic canvas.

---

## 9. Accessibility

- Contrast: all text meets WCAG AA. `--text-secondary` on `--surface-1` clears 4.5:1.
- Focus rings: 2px solid `var(--border-focus)` with 2px offset on every interactive element. Never remove without replacing.
- All carousels have keyboard navigation (← → arrows), and arrow controls are reachable via tab.
- Background video previews are muted, never autoplay with audio, and respect `prefers-reduced-motion`.
- All title-as-image elements ship with descriptive `alt` text.
- Captions/subtitles in the player default to white-on-black-bar, 18px, with user override.

---

## 10. Don'ts

- Don't introduce a second accent color. The blue stands alone.
- Don't use shadows on flat UI chrome (buttons, nav). Shadows belong on lifted tiles only.
- Don't fill empty space with decorative chrome. Let the canvas breathe.
- Don't use portrait posters on the home rails. Disney+ is landscape-first.
- Don't animate everything. Reserve motion for hero, tile hover, and page transitions.
- Don't mix icon sets, button radii, or font weights inconsistently across screens.

---

## 11. File / Token Export

When implementing, expose tokens via:

- `tokens.css` — CSS custom properties (the `:root` block above)
- `tokens.js` — same values as a JS object for runtime use
- `tailwind.config.js` — extend theme with the same scale

Keep a single source of truth (suggested: `tokens.json`) and generate the rest with Style Dictionary or a similar pipeline.

---

*This document describes a design language inspired by Disney+ for use in personal or educational projects. Disney, the Disney+ wordmark, and associated franchise marks are trademarks of The Walt Disney Company and should not be reproduced in shipped work without permission.*
