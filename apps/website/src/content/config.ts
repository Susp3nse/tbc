import { defineCollection, z } from 'astro:content';

/**
 * Changelog: one markdown file per release in `src/content/changelog/`.
 * Frontmatter carries the version, the display year, and the release tags
 * (feature / fix / patch); the markdown body holds the curated per-class notes.
 * This collection is the single source of truth — the website renders it, and
 * (going forward) the release pipeline reads the matching entry for the GitHub
 * Release body + Discord announcement.
 */
const changelog = defineCollection({
  type: 'content',
  schema: z.object({
    version: z.string(),
    year: z.string(),
    tags: z.array(z.enum(['feature', 'fix', 'major', 'minor', 'patch'])),
  }),
});

export const collections = { changelog };
