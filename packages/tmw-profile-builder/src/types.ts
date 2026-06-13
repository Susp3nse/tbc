export type IniConfig = {
  paths?: Record<string, string>;
  accounts?: Record<string, string>;
  profiles?: Record<string, string>;
};

export type BuildContext = {
  projectRoot: string;
  defaultExpansion: string;
  defaultAioDir: string;
  templatePath: string;
  outputPath: string;
  iniPath: string;
  buildVersionPath: string;
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
