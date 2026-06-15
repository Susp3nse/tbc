/// <reference path="../.astro/types.d.ts" />

// fontsource packages ship CSS without type declarations; these side-effect
// imports are resolved by Vite at build time.
declare module '@fontsource-variable/inter';
declare module '@fontsource/cinzel/*';
