export type IniConfig = {
  paths?: Record<string, string>;
  accounts?: Record<string, string>;
  profiles?: Record<string, string>;
};

/** One entry in the module load order: a known source file and the TMW snippet Order it maps to. */
export type ModuleSlot = {
  slot: 'shared' | 'class';
  source: string;
  order: number;
};

/** How module metadata (e.g. a build stamp) is injected into a module's source before compilation. */
export type MetadataInjection = {
  /** Only inject when the module source begins with this marker comment. */
  marker: string;
  /** The injected text is placed immediately after this anchor line. */
  anchor: string;
  /** Renders the text to inject for a given build number. */
  render: (build: number) => string;
};

/**
 * Project-specific naming/layout conventions. The package itself is content-agnostic;
 * everything Flux-specific lives here and is supplied (with defaults) by createBuildContext().
 */
export type BuildConventions = {
  /** Prefix for generated TMW snippet names, e.g. "Flux_". */
  modulePrefix: string;
  /** Profile display-name prefix, e.g. "Flux ". Also used to detect managed profiles for stale purge. */
  profileNamePrefix: string;
  /** Per-source-file name casing overrides, e.g. { ui: "UI" }. */
  nameOverrides: Record<string, string>;
  /** Ordered load slots (shared files + known class files with their TMW Order). */
  loadOrder: ModuleSlot[];
  /** Order assigned to class files not named in loadOrder. */
  defaultModuleOrder: number;
  /** Sentinel profile key stripped from template and output, e.g. "__template__". */
  templateProfileKey: string;
  /** Optional build-stamp injection; omit to disable. */
  metadata?: MetadataInjection;
};

export type BuildContext = {
  projectRoot: string;
  /** Directory holding the compiled rotation source (class dirs + shared files), e.g. <root>/src/aio. */
  aioDir: string;
  templatePath: string;
  outputPath: string;
  iniPath: string;
  buildVersionPath: string;
  conventions: BuildConventions;
};

export type RotationModule = {
  name: string;
  order: number;
  filePath: string;
};

export type BuildMetadata = {
  build: number;
};

export type SavedVariablesTarget = {
  name: string;
  svPath: string;
};

export type BracedSection = {
  start: number;
  end: number;
};

export type WatchOptions = {
  sourceDebounceMs?: number;
  savedVariablesDebounceMs?: number;
  ourWriteCooldownMs?: number;
};
