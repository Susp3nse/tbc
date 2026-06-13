/** GitHub owner/repo — update this when the repo is created */
const GITHUB_REPO = 'flux-rotations/tbc';

export const config = {
  /** Base GitHub repo URL */
  github: `https://github.com/${GITHUB_REPO}`,

  /** GitHub Issues URL */
  githubIssues: `https://github.com/${GITHUB_REPO}/issues`,

  /** Direct download URL for the latest release asset */
  downloadUrl: `https://github.com/${GITHUB_REPO}/releases/latest/download/TellMeWhen.lua`,

  /** GitHub Releases page (for browsing all releases) */
  releasesUrl: `https://github.com/${GITHUB_REPO}/releases/latest`,

  /** Git clone URL */
  cloneUrl: `https://github.com/${GITHUB_REPO}.git`,

  /** Discord invite link */
  discord: 'https://discord.gg/M2HJeYCxgg',
};

/** Prefix a path with the Astro base URL (for GitHub Pages sub-path deployment). */
export function url(path: string): string {
  const base = import.meta.env.BASE_URL.replace(/\/$/, '');
  return base + path;
}
