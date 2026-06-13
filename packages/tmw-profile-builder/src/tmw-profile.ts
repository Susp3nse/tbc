import fs from 'node:fs';
import type {
  BracedSection,
  BuildContext,
  BuildMetadata,
  MetadataInjection,
  RotationModule,
} from './types.js';
import { escapeLuaString } from './lua.js';
import { injectBuildMetadata } from './metadata.js';

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function findBracedSection(lines: string[], startPattern: RegExp): BracedSection | null {
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim().match(startPattern)) {
      let braceDepth = 0;
      let foundOpen = false;
      for (let j = i; j < lines.length; j++) {
        for (const ch of lines[j]) {
          if (ch === '{') {
            braceDepth++;
            foundOpen = true;
          }
          if (ch === '}') braceDepth--;
        }
        if (foundOpen && braceDepth <= 0) return { start: i, end: j };
      }
      break;
    }
  }
  return null;
}

function findCodeSnippets(
  lines: string[],
  profileStart: number,
  profileEnd: number,
): BracedSection | null {
  for (let i = profileStart; i <= profileEnd; i++) {
    if (lines[i].trim() === '["CodeSnippets"] = {') {
      let braceDepth = 1;
      for (let j = i + 1; j <= profileEnd; j++) {
        for (const ch of lines[j]) {
          if (ch === '{') braceDepth++;
          if (ch === '}') braceDepth--;
        }
        if (braceDepth <= 0) return { start: i, end: j };
      }
    }
  }
  return null;
}

function findNamedBracedSection(
  lines: string[],
  profileStart: number,
  profileEnd: number,
  sectionName: string,
): BracedSection | null {
  const pattern = new RegExp(`^\\["${escapeRegExp(sectionName)}"\\]\\s*=\\s*\\{`);
  for (let i = profileStart; i <= profileEnd; i++) {
    if (lines[i].trim().match(pattern)) {
      let braceDepth = 0;
      let foundOpen = false;
      for (let j = i; j <= profileEnd; j++) {
        for (const ch of lines[j]) {
          if (ch === '{') {
            braceDepth++;
            foundOpen = true;
          }
          if (ch === '}') braceDepth--;
        }
        if (foundOpen && braceDepth <= 0) return { start: i, end: j };
      }
      break;
    }
  }
  return null;
}

function findScalarLine(
  lines: string[],
  profileStart: number,
  profileEnd: number,
  keyName: string,
): number {
  const pattern = new RegExp(`^\\["${escapeRegExp(keyName)}"\\]\\s*=`);
  for (let i = profileStart; i <= profileEnd; i++) {
    if (lines[i].trim().match(pattern)) return i;
  }
  return -1;
}

function buildCodeSnippets(
  modules: RotationModule[],
  metadata: BuildMetadata | null | undefined,
  injection: MetadataInjection | undefined,
): string[] {
  const lines = ['["CodeSnippets"] = {'];
  for (const mod of modules) {
    const rawCode = fs.readFileSync(mod.filePath, 'utf8');
    const code = injectBuildMetadata(rawCode, metadata, injection);
    const escaped = escapeLuaString(code);
    lines.push('{');
    lines.push(`["Order"] = ${mod.order},`);
    lines.push(`["Name"] = "${mod.name}",`);
    lines.push(`["Code"] = "${escaped}",`);
    lines.push('},');
  }
  lines.push(`["n"] = ${modules.length},`);
  lines.push('},');
  return lines;
}

function replaceNamedBracedSection(
  targetLines: string[],
  templateProfileLines: string[],
  sectionName: string,
): string[] {
  const src = findNamedBracedSection(
    templateProfileLines,
    0,
    templateProfileLines.length - 1,
    sectionName,
  );
  if (!src) return targetLines;

  const srcLines = templateProfileLines.slice(src.start, src.end + 1);
  const dst = findNamedBracedSection(targetLines, 0, targetLines.length - 1, sectionName);
  if (dst) {
    return [...targetLines.slice(0, dst.start), ...srcLines, ...targetLines.slice(dst.end + 1)];
  }

  return [...targetLines.slice(0, -1), ...srcLines, targetLines[targetLines.length - 1]];
}

function replaceScalarFromTemplate(
  targetLines: string[],
  templateProfileLines: string[],
  keyName: string,
): string[] {
  const srcIndex = findScalarLine(
    templateProfileLines,
    0,
    templateProfileLines.length - 1,
    keyName,
  );
  if (srcIndex < 0) return targetLines;

  const dstIndex = findScalarLine(targetLines, 0, targetLines.length - 1, keyName);
  if (dstIndex >= 0) {
    const result = [...targetLines];
    result[dstIndex] = templateProfileLines[srcIndex];
    return result;
  }

  return [targetLines[0], templateProfileLines[srcIndex], ...targetLines.slice(1)];
}

function loadTemplateProfileLines(
  context: BuildContext,
  templatePath?: string | null,
): string[] | null {
  const effectiveTemplatePath =
    templatePath && fs.existsSync(templatePath)
      ? templatePath
      : fs.existsSync(context.templatePath)
        ? context.templatePath
        : null;
  if (!effectiveTemplatePath) return null;

  const templateLines = fs.readFileSync(effectiveTemplatePath, 'utf8').split(/\r?\n/);
  const profilesSection = findBracedSection(templateLines, /^\["profiles"\]\s*=\s*\{/);
  if (!profilesSection) {
    console.error('  ERROR: No ["profiles"] section in template');
    return null;
  }

  for (let i = profilesSection.start + 1; i <= profilesSection.end; i++) {
    if (templateLines[i].trim().match(/^\[".+"\]\s*=\s*\{/)) {
      let depth = 0;
      for (let j = i; j <= profilesSection.end; j++) {
        for (const ch of templateLines[j]) {
          if (ch === '{') depth++;
          if (ch === '}') depth--;
        }
        if (depth <= 0) return templateLines.slice(i, j + 1);
      }
      break;
    }
  }

  console.error('  ERROR: Could not find profile skeleton in template');
  return null;
}

function refreshManagedProfileScaffold(
  profileLines: string[],
  templateProfileLines: string[],
): string[] {
  let result = profileLines;
  result = replaceNamedBracedSection(result, templateProfileLines, 'Groups');
  result = replaceScalarFromTemplate(result, templateProfileLines, 'NumGroups');
  result = replaceScalarFromTemplate(result, templateProfileLines, 'TextureName');
  return result;
}

export function findProfile(lines: string[], profileName: string): BracedSection | null {
  const profilesSection = findBracedSection(lines, /^\["profiles"\]\s*=\s*\{/);
  if (!profilesSection) return null;

  const pattern = new RegExp(`^\\["${escapeRegExp(profileName)}"\\]\\s*=\\s*\\{`);
  for (let i = profilesSection.start + 1; i <= profilesSection.end; i++) {
    if (lines[i].trim().match(pattern)) {
      let braceDepth = 0;
      for (let j = i; j <= profilesSection.end; j++) {
        for (const ch of lines[j]) {
          if (ch === '{') braceDepth++;
          if (ch === '}') braceDepth--;
        }
        if (braceDepth <= 0) return { start: i, end: j };
      }
    }
  }
  return null;
}

export function ensureProfileKey(lines: string[], profileName: string): string[] {
  const keysSection = findBracedSection(lines, /^\["profileKeys"\]\s*=\s*\{/);
  if (!keysSection) return lines;

  const keyPattern = new RegExp(`\\["${escapeRegExp(profileName)}"\\]`);
  for (let i = keysSection.start; i <= keysSection.end; i++) {
    if (lines[i].match(keyPattern)) return lines;
  }

  const result = [...lines];
  result.splice(keysSection.end, 0, `["${profileName}"] = "${profileName}",`);
  return result;
}

export function removeProfileKey(lines: string[], profileName: string): string[] {
  const keysSection = findBracedSection(lines, /^\["profileKeys"\]\s*=\s*\{/);
  if (!keysSection) return lines;

  const keyPattern = new RegExp(`^\\["${escapeRegExp(profileName)}"\\]\\s*=`);
  const result = [...lines];
  for (let i = keysSection.end; i >= keysSection.start; i--) {
    if (result[i].trim().match(keyPattern)) result.splice(i, 1);
  }
  return result;
}

export function removeProfile(lines: string[], profileName: string): string[] {
  const profile = findProfile(lines, profileName);
  if (!profile) return lines;

  const result = [...lines];
  result.splice(profile.start, profile.end - profile.start + 1);
  return result;
}

export function syncProfile(
  context: BuildContext,
  lines: string[],
  profileName: string,
  modules: RotationModule[],
  templatePath?: string | null,
  metadata?: BuildMetadata | null,
): string[] {
  const snippetLines = buildCodeSnippets(modules, metadata, context.conventions.metadata);
  const profile = findProfile(lines, profileName);
  const templateProfileLines = loadTemplateProfileLines(context, templatePath);

  if (profile) {
    let existingProfileLines = lines.slice(profile.start, profile.end + 1);
    const cs = findCodeSnippets(existingProfileLines, 0, existingProfileLines.length - 1);
    if (!cs) {
      console.log(`  Profile "${profileName}" missing CodeSnippets - rebuilding from template`);
      lines = [...lines.slice(0, profile.start), ...lines.slice(profile.end + 1)];
    } else {
      existingProfileLines = [
        ...existingProfileLines.slice(0, cs.start),
        ...snippetLines,
        ...existingProfileLines.slice(cs.end + 1),
      ];
      if (templateProfileLines) {
        existingProfileLines = refreshManagedProfileScaffold(
          existingProfileLines,
          templateProfileLines,
        );
      }
      return [
        ...lines.slice(0, profile.start),
        ...existingProfileLines,
        ...lines.slice(profile.end + 1),
      ];
    }
  }

  console.log(`  Creating new profile "${profileName}" from template...`);

  if (!templateProfileLines) {
    console.log('  WARNING: No template found, creating minimal profile');
    const newProfile = [`["${profileName}"] = {`, '["Version"] = 12000703,', ...snippetLines, '},'];
    const profilesSection = findBracedSection(lines, /^\["profiles"\]\s*=\s*\{/);
    if (!profilesSection) {
      console.error('  ERROR: No ["profiles"] section found in TellMeWhen.lua');
      return lines;
    }
    let result = [
      ...lines.slice(0, profilesSection.end),
      ...newProfile,
      ...lines.slice(profilesSection.end),
    ];
    result = ensureProfileKey(result, profileName);
    return result;
  }

  let profileLines = [...templateProfileLines];
  profileLines[0] = `["${profileName}"] = {`;

  const clonedCS = findCodeSnippets(profileLines, 0, profileLines.length - 1);
  if (clonedCS) {
    profileLines = [
      ...profileLines.slice(0, clonedCS.start),
      ...snippetLines,
      ...profileLines.slice(clonedCS.end + 1),
    ];
  }

  const profilesSection = findBracedSection(lines, /^\["profiles"\]\s*=\s*\{/);
  if (!profilesSection) {
    console.error('  ERROR: No ["profiles"] section in TellMeWhen.lua');
    return lines;
  }

  let result = [
    ...lines.slice(0, profilesSection.end),
    ...profileLines,
    ...lines.slice(profilesSection.end),
  ];
  result = ensureProfileKey(result, profileName);
  return result;
}

export function listProfileNames(lines: string[]): string[] {
  const profilesSection = findBracedSection(lines, /^\["profiles"\]\s*=\s*\{/);
  if (!profilesSection) return [];

  const names: string[] = [];
  for (let i = profilesSection.start + 1; i <= profilesSection.end; i++) {
    const match = lines[i].trim().match(/^\["(.+)"\]\s*=\s*\{/);
    if (match) names.push(match[1]);
  }
  return names;
}
