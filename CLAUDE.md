# emilyaudio.github.io

Static personal site for Emily Bryner (voice-over artist + audio engineer).
Hand-written HTML, no build step, GitHub Pages.

## Mental model
A neutral hub (`index.html`) routing to two standalone portfolios: voice-over
(`vo/`, live) and audio post-production (`audio/`, live). Each stands on
its own -- they cross-link but don't share nav or contact.

## Design: shared chrome + per-surface accent
Shared chrome -- design tokens, reset, header (brand + theme toggle), and the
portrait component -- lives in `base.css`, linked by every page; the theme
toggle is `base.js`. Edit a shared thing once there and the hub, `/vo`, and
`/audio` all pick it up. Don't re-copy shared rules into a page's inline
`<style>`; page `<style>` blocks hold only page-specific styles (and
page-specific tokens: hub `--vo`/`--post`, vo `--accent` etc.).

`vo/index.html` stays the reference for page-specific conventions (type,
spacing, section patterns) -- read its `<style>` block for those. New surfaces
take their own accent color over the shared neutral system (voice-over = blue,
audio = red); the hub itself stays neutral (carries both). Pages remain
standalone *for the visitor* (no shared nav/contact) -- sharing a stylesheet is
a code concern, not a UX one.

## Content in HTML, behaviour in JS
Hand-write portfolio content (e.g. "Selected work" cards) as static HTML so it
renders without JS -- crawlable, link-preview-friendly, and matching the
no-build-step ethos. `/vo` and `/audio` both do this. Reserve JS for behaviour
(playback, hover, reveal) and for genuinely *generated* markup: the `/vo` hero
demo waveforms are 64 procedural bars per reel, so static would mean
hand-writing 320 `<span>`s -- they stay JS. Rule: static for content; JS only
when static means transcribing generated output. Simplest correct solution wins.

## Design standards (non-negotiable)
Every visual change must satisfy these. When they conflict with a quick fix,
the standard wins.

- **Accessibility is a requirement, not a nicety.** Meet WCAG 2.2 AA: text
  contrast >=4.5:1 (>=3:1 for large text and UI borders), visible focus states,
  keyboard-reachable everything, real semantic HTML (headings in order, `alt`
  text, labelled controls), respect `prefers-reduced-motion`.
- **Consistency over novelty.** Wording, structure, colour, and font sizes stay
  consistent across a surface. "Modern" means clean and standards-compliant, not
  chasing trends -- don't add an effect or layout just because it's fashionable.
- **Use the design system, don't freelance values.** Font sizes follow one
  typographic scale (a hierarchy, not ad-hoc px); spacing/sizing come from one
  mathematically-related scale; colours are picked to sit together. `vo/`'s
  `<style>` block is that system -- read it and reuse its tokens.
- **Self-hosted fonts only.** Never link external web fonts (Google Fonts, CDNs).
  If a face like Inter is wanted, download it and serve it from the repo.

### saferules (anthonyhobday.com/sideprojects/saferules) -- distilled
Fallback defaults: apply whenever nothing above or the owner's explicit
direction overrides them. If the owner asks for something that contradicts a
saferule, open a discussion -- name the conflict and the trade-off, and make the
case if you think the saferule is right. The owner has the final say; once
they've heard the argument and still want it, do as asked without further
pushback -- don't refuse.
- **Colour:** near-black/near-white, never pure #000/#fff. Saturate neutrals
  with a hint of the accent (warm *or* cool, not both). Palette colours need
  distinct brightness. High contrast for buttons/key content; keep structure
  subtle. Lower icon contrast when paired with text.
- **Type:** body >=16px. Line length ~70 chars (60-80). Larger/heavier text gets
  tighter letter-spacing and line-height; smaller/lighter text gets looser. Two
  typefaces at most.
- **Spacing & layout:** measurements mathematically related (one scale).
  Everything aligns to something; optical alignment beats mathematical when they
  disagree. Outer padding >= inner padding. Button horizontal padding ~2x
  vertical. Measure spacing between high-contrast edges. 12-column grid if you
  grid.
- **Containers & depth:** borders contrast with *both* container and background.
  Keep container brightness steps small (~7% light UI, ~12% dark). Nest corner
  radii (inner = outer - gap). Closer elements are lighter. One depth technique
  throughout; no shadows in dark UI; drop-shadow blur = 2x distance. Don't stack
  two hard divides (border + colour change); don't mix simple-on-simple.
- **Intent:** every spacing/size/colour/shadow choice is deliberate. If you
  can't say why, it's wrong.

## Copy decisions (not inferable from code)
- "voice-over" and "audio post-production" are each correctly hyphenated --
  leave them; don't normalize one to match the other.
- Audio post uses a short URL (`/audio/`); its display label is
  "Audio Post-Production".
- Contact is email-only; no forms.

## Local dev
Assumes a bare machine with only `make` + `brew`; first run installs the rest.
- `make`      -- installs deps, then a tmux split: browser-sync (server + live
  reload + opens browser) on the left, `claude` on the right.
- `make shot` -- screenshots the running site to `/tmp/emilyaudio-shot.png` so
  Claude can Read it. Override the page: `make shot URL=http://localhost:3000/vo/`.
- `make stop` -- kill the dev session.
- Deps (`make deps`): tmux, node, google-chrome via brew; claude via Anthropic's
  recommended native installer; browser-sync via npm. Alt: `python3 -m http.server`.

## Gotchas
- `vo/index.html` and `audio/index.html` are very large HTML files that exceed
  Read limits -- use grep/sed for lookups, never a full Read.
- To see the running site, use `make shot` (above) and Read the PNG.
