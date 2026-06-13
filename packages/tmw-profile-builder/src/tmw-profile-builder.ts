import fs from 'node:fs';
import path from 'node:path';
import type { BuildContext, LocalConfig } from './types.js';
import { discoverClasses, discoverModules, getProfileName } from './discovery.js';
import { getAIODir, getSavedVariablesPaths } from './localconfig.js';
import { bumpBuildMetadata, readBuildMetadata } from './metadata.js';
import { buildValidProfileNames, purgeStaleProfiles } from './profile-sync.js';
import {
  ensureProfileKey,
  findBracedSection,
  removeProfile,
  removeProfileKey,
  syncProfile,
} from './tmw-profile.js';
import { timestamp, writeWithRetry } from './io.js';

export class ProfileBuilder {
  constructor(private readonly context: BuildContext) {}

  get projectRoot(): string {
    return this.context.projectRoot;
  }

  getAIODir(config?: LocalConfig | null): string {
    return getAIODir(this.context, config);
  }

  getSavedVariablesPaths(config?: LocalConfig | null) {
    return getSavedVariablesPaths(config);
  }

  discoverClasses(aioDir: string): string[] {
    return discoverClasses(aioDir);
  }

  discoverModules(className: string, aioDir: string) {
    return discoverModules(className, aioDir, this.context.conventions);
  }

  getProfileName(className: string, config?: LocalConfig | null): string {
    return getProfileName(className, this.context.conventions, config);
  }

  readBuildMetadata() {
    return readBuildMetadata(this.context);
  }

  bumpBuildMetadata() {
    return bumpBuildMetadata(this.context);
  }

  timestamp(): string {
    return timestamp();
  }

  buildOutput(classes: string[], config?: LocalConfig | null): boolean {
    if (!fs.existsSync(this.context.templatePath)) {
      console.error(`Error: Template not found: ${this.context.templatePath}`);
      return false;
    }

    const aioDir = this.getAIODir(config);
    const metadata = this.bumpBuildMetadata();
    console.log(`  Build: #${metadata.build}`);
    const template = fs.readFileSync(this.context.templatePath, 'utf8');
    const hasWindows = template.includes('\r\n');
    let lines = template.split(/\r?\n/);

    lines = removeProfile(lines, this.context.conventions.templateProfileKey);
    lines = removeProfileKey(lines, this.context.conventions.templateProfileKey);

    for (const className of classes) {
      const profileName = this.getProfileName(className, config);
      const modules = this.discoverModules(className, aioDir);
      if (modules.length === 0) {
        console.log(`  Skipping ${className}: no modules found`);
        continue;
      }
      lines = syncProfile(
        this.context,
        lines,
        profileName,
        modules,
        this.context.templatePath,
        metadata,
      );
      console.log(`  Built: ${profileName} (${modules.length} modules)`);
    }

    const output = lines.join(hasWindows ? '\r\n' : '\n');
    const outputDir = path.dirname(this.context.outputPath);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    fs.writeFileSync(this.context.outputPath, output, 'utf8');
    console.log(`\nWrote ${this.context.outputPath}`);
    return true;
  }

  syncToSavedVariables(config: LocalConfig, classNames: string[], svPathOverride?: string): boolean {
    const svPath = svPathOverride || config.paths?.savedvariables;
    if (!svPath) {
      console.error(`[${timestamp()}] ERROR: SavedVariables path is required`);
      return false;
    }

    const aioDir = this.getAIODir(config);
    const metadata = this.readBuildMetadata();
    const templatePath = config.paths?.template
      ? path.resolve(this.context.projectRoot, config.paths.template)
      : null;

    if (!fs.existsSync(svPath)) {
      console.log(`[${timestamp()}] SavedVariables not found - creating from template: ${svPath}`);
      const svDir = path.dirname(svPath);
      if (!fs.existsSync(svDir)) {
        fs.mkdirSync(svDir, { recursive: true });
      }

      const seedPath = templatePath || this.context.templatePath;
      if (!fs.existsSync(seedPath)) {
        console.error(`[${timestamp()}] ERROR: Template not found: ${seedPath}`);
        return false;
      }
      fs.copyFileSync(seedPath, svPath);
    }

    const start = Date.now();
    const content = fs.readFileSync(svPath, 'utf8');
    const hasWindows = content.includes('\r\n');
    let lines = content.split(/\r?\n/);

    lines = removeProfile(lines, this.context.conventions.templateProfileKey);
    lines = removeProfileKey(lines, this.context.conventions.templateProfileKey);

    const validNames = buildValidProfileNames(classNames, this.context.conventions, config);
    for (const className of classNames) {
      const profileName = this.getProfileName(className, config);
      const modules = this.discoverModules(className, aioDir);

      if (modules.length === 0) {
        console.log(`[${timestamp()}] Skipping ${className}: no modules found`);
        continue;
      }

      lines = syncProfile(this.context, lines, profileName, modules, templatePath, metadata);
      console.log(
        `[${timestamp()}] Synced: ${profileName} (${modules.length} modules, ${Date.now() - start}ms)`,
      );
    }

    lines = purgeStaleProfiles(lines, validNames, this.context.conventions, config);

    const output = lines.join(hasWindows ? '\r\n' : '\n');
    writeWithRetry(svPath, output);

    const written = fs.existsSync(svPath) ? fs.readFileSync(svPath, 'utf8') : '';
    if (!written.includes('NS.BUILD_LABEL')) {
      console.error(`[${timestamp()}] ERROR: Build metadata was not written to ${svPath}`);
      return false;
    }

    return true;
  }

  createMinimalProfile(lines: string[], profileName: string): string[] {
    const newProfile = [
      `["${profileName}"] = {`,
      '["Version"] = 12000703,',
      '["CodeSnippets"] = {',
      '["n"] = 0,',
      '},',
      '},',
    ];
    const profilesSection = findBracedSection(lines, /^\["profiles"\]\s*=\s*\{/);
    if (!profilesSection) return lines;
    return ensureProfileKey(
      [...lines.slice(0, profilesSection.end), ...newProfile, ...lines.slice(profilesSection.end)],
      profileName,
    );
  }
}
