# website — Flux AIO Distribution Site

> Scope: the static marketing/docs site. Read the root `AGENTS.md` first for global behavior + the
> workspace map.

An **Astro** static site (`output: 'static'`) that distributes the addon and documents the classes.
Deployed to GitHub Pages at `https://flux-rotations.github.io/tbc` (`base: '/tbc'` — use the `url()`
helper from `src/config.ts` for internal links, never bare absolute paths).

## Commands

```bash
pnpm --filter @flux/website dev        # local dev server
pnpm --filter @flux/website build      # static build → apps/website/dist
pnpm --filter @flux/website preview     # preview the built site
pnpm --filter @flux/website typecheck  # astro check
```

## Layout

```
src/
  pages/          Routed pages — index, faq, changelog, classes/<class>.astro, guides/<class>-talents.astro
  layouts/        Base.astro — shared page shell (title/description props)
  components/      TalentTree.astro and other reusable bits
  data/           Per-class talent data (<class>-talents.ts) consumed by guides + TalentTree
  styles/         global.css
  config.ts       url() base-path helper + site config
public/           Static assets served as-is
```

## Changelog page

`src/pages/changelog.astro` is the user-facing release history. Each release is a
`<section class="section changelog-entry">` with `<h2>vX.Y.Z</h2>`, a
`<span class="changelog-tag tag-feature">Feature</span>` and/or `tag-fix` tag, one `<h3>Class &mdash;
Spec</h3>` per area touched, and a `<ul class="features">` of `<li><strong>Title</strong> &mdash;
description</li>`. **Insert new entries at the top**, above the current topmost entry, mirroring its
markup. This is the website substep of the root release workflow — see root `AGENTS.md`.

## Deploy

`.github/workflows/deploy-website.yml` builds and publishes to GitHub Pages on push to `main` that
touches `apps/website/**` (or via `workflow_dispatch`). **Website-only changes don't need a rotation
version bump or tag** — they ship through this workflow on their own.
