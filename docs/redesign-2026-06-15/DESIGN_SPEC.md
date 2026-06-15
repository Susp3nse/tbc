# Menagerie — Website Redesign Spec

**Direction:** Arcane Codex · **Date:** 2026-06-15 · **Status:** proposal (mockup only)

> Standalone homepage mockup: [`mockup.html`](./mockup.html) — open directly in a browser, no build
> needed. Nothing in `apps/website/src/` is touched by this proposal.

---

## 1. The idea

The product is named **Menagerie** — a curated collection of tamed creatures. Nine classes = a
literal menagerie. The redesign makes that the entire concept: the site is an **illuminated codex /
bestiary**, and each class is a *specimen* with its own color sigil. This does three things the
current site doesn't:

1. Gives the site a **distinct identity** instead of a default dark-template look.
2. Turns the **nine WoW class colors** (already in `global.css`, currently wasted on tiny card
   borders) into the entire visual system — the strongest asset you have.
3. Gives the name a reason to exist on the page.

**The single most important change: kill the brown.** `#16130f` + `#e08a3c` is what reads as
"generic WoW addon dark mode." We move to a **deep obsidian-indigo** base with a **warm gold metal**
accent — the color of an old gilded tome, not mud.

---

## 2. Design tokens

### Color
| Token | Value | Use |
|-------|-------|-----|
| `--ink` | `#0a0b12` | page base (near-black indigo) |
| `--ink-raised` | `#12131e` | cards / raised surfaces |
| `--ink-hover` | `#191a28` | hover surface |
| `--vellum` | `#ece6d6` | primary text (warm off-white "parchment ink, inverted") |
| `--vellum-dim` | `#a9a394` | secondary text |
| `--vellum-faint` | `#6f6a5d` | tertiary / captions |
| `--gold` | `#e6c478` | primary metal accent, rules, glyphs |
| `--gold-bright` | `#f6d98f` | hover / emphasis |
| `--gold-deep` | `#b8923f` | pressed / borders |
| `--rule` | `#262436` | hairline borders (cool, not brown) |

**Class colors stay WoW-accurate** (`--druid #ff7d0a` … `--warrior #c79c6e`), with `shaman`
brightened to `#2f9bff` for legibility on dark. Each class owns its color across its crest, its page
header, and its hover glow.

### Type
- **Display / wordmark / headings:** `Cinzel` (engraved Roman serif — reads "arcane tome," pairs with
  the gold). Weights 500/600. Letterspaced `+0.04em` on the wordmark.
- **Body / UI:** `Inter` (keep it — clean, already loaded mentally). 15px base (up from 14px), line
  height 1.6. We are deliberately **less dense** than today.
- **Mono (code, build labels, talent reqs):** `ui-monospace`.

Scale (desktop): hero wordmark `clamp(3rem, 9vw, 6rem)`, h1 `2.5rem`, h2 `1.6rem`, h3 `1.05rem`,
body `0.95rem`. Generous section spacing (`5–6rem` between major bands vs. today's cramped `0.75rem`).

### Texture / motifs (used sparingly — restraint is the point)
- A faint **arcane ring** (thin gold concentric circles + tick marks) behind the hero wordmark, very
  low opacity, slow rotation.
- **Hairline gold rules** with a small center diamond `◆` as section dividers (the "codex" tell).
- Cards get a **1px top edge in the class color** plus a soft color glow on hover — the specimen
  glows when you look at it.
- No drop shadows from the 2014 era; use **color glow + thin borders** instead.

---

## 3. Page structure (homepage)

1. **Nav** — `Menagerie` wordmark (Cinzel) left; `Classes ▾`, `Install`, `Changelog`, `FAQ`,
   `GitHub` right. Sticky, blurred ink background, a single hairline gold underline.
2. **Hero** — full-bleed. Arcane ring motif → wordmark `MENAGERIE` → tagline **"Nine classes. One
   intelligence."** → primary `Download` + secondary `Installation Guide`. A thin stat line under
   the CTAs: `9 classes · 25 specs · priority-driven`.
3. **The Collection** — the signature section. Nine class **crests** in a 3×3 constellation, each a
   color-lit sigil with the class name in Cinzel. Hover lifts + glows in the class color and reveals
   a one-line descriptor; click → class page. Replaces today's flat card grid.
4. **What it does** — 3–4 "codex entry" feature blocks (Smart Rotations, Form-Aware, Resource
   Management, Consumable Automation) with a gold glyph, title, prose. Roomy, not bulleted lists.
5. **Proof** — a stylized **in-game overlay mock** (CSS HUD: recovery/cooldown/priority readout in
   class color) so visitors *see* the thing working. Swap for a real screenshot when available.
6. **How it works** — one tight paragraph + a quiet 3-item architecture note (middleware → strategies
   → context). For the curious, not the front door.
7. **Footer** — wordmark, primary links, and the fork credit demoted to a small `Credits` line
   (kept for the NOTICE obligation, no longer shouting on every page).

---

## 4. Rollout (when you greenlight the build)

This is a **reskin + restructure**, not a rewrite — the Astro structure, content collections, and
talent data all stay.

- **Phase 1:** new tokens in `global.css`, restyle `Base.astro` (nav/footer/shell), rebuild
  `index.astro` to the structure above, add fonts. ← the homepage you'd review.
- **Phase 2:** roll the token system + section components across the 9 class pages, guides, FAQ, and
  changelog (these mostly inherit the new tokens for free; class pages get the new color-led header).
- **New components:** `Crest.astro` (class sigil), `Rule.astro` (diamond divider), `CodexEntry.astro`
  (feature block). The `TalentTree` component re-skins via tokens, no structural change.

**Open question for build time:** do you have (or want me to generate) real in-game screenshots? The
mockup ships a CSS-drawn HUD as a placeholder; a real screenshot would land much harder.
