import { defineConfig } from 'astro/config';

export default defineConfig({
  output: 'static',
  site: 'https://flux-rotations.github.io',
  base: '/tbc',
  build: {
    inlineStylesheets: 'always',
  },
});
