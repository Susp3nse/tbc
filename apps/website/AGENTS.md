# website — Menagerie Distribution Site

> Scope: the static marketing/docs site. Read the root `AGENTS.md` first for global behavior + the
> workspace map.

An **Astro** static site (`output: 'static'`) that distributes the addon and documents the classes.
Deployed to GitHub Pages at `https://menagerie.dev` (`base: '/tbc'` — use the `url()`
helper from `src/config.ts` for internal links, never bare absolute paths).

## Commands

```bash
pnpm --filter @menagerie/website dev        # local dev server
pnpm --filter @menagerie/website build      # static build → apps/website/dist
pnpm --filter @menagerie/website preview     # preview the built site
pnpm --filter @menagerie/website typecheck  # astro check
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

## Changelog (content collection)

The changelog is an **Astro content collection**, not hand-written HTML. It is the single source of
truth for release notes — the website renders it, and (going forward) the release pipeline reads the
matching entry for the GitHub Release body + Discord announcement.

- **Source:** one markdown file per release at `src/content/changelog/v<X.Y.Z>.md`.
- **Schema** (`src/content/config.ts`): frontmatter `version` (string), `year` (string), `tags`
  (array of `feature` / `fix` / `major` / `minor` / `patch`). Body is markdown.
- **Body format:** `### Class — Spec` heading per area touched, then a `-` bulleted list of
  `**Title** — description` (markdown `**bold**`, `*italic*`, `` `code` `` all render).
- **Rendering:** `src/pages/changelog.astro` loads the collection, sorts by semver descending, and
  renders each entry; the page is generic and needs no edits per release.

**To add a release:** drop a new `v<X.Y.Z>.md` file in `src/content/changelog/`. No markup to mirror,
no ordering to manage. This is the website substep of the root release workflow — see root `AGENTS.md`.

> Historical note: entries `v1.0.0`–`v1.8.x` predate the `feature`/`fix` convention and carry
> `major`/`minor`/`patch` tags; both taxonomies are accepted. New entries should use `feature`/`fix`.

## Deploy

`.github/workflows/deploy-website.yml` builds and publishes to GitHub Pages on push to `main` that
touches `apps/website/**` (or via `workflow_dispatch`). **Website-only changes don't need a rotation
version bump or tag** — they ship through this workflow on their own.
