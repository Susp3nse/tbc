import fs from 'node:fs';
import path from 'node:path';
import type { BuildConventions, LocalConfig, RotationModule } from './types.js';

function toPascalCase(filename: string, nameOverrides: Record<string, string>): string {
  const name = filename.replace('.lua', '');
  return nameOverrides[name] || name.charAt(0).toUpperCase() + name.slice(1);
}

function assertValidLuaFileNames(files: string[]): void {
  for (const file of files) {
    const stem = file.replace('.lua', '');
    if (/[_\s-]/.test(stem)) {
      throw new Error(
        `Bad filename "${file}" - use single lowercase words (no underscores/hyphens/spaces)`,
      );
    }
  }
}

export function discoverModules(
  className: string,
  aioDir: string,
  conventions: BuildConventions,
): RotationModule[] {
  const { loadOrder, nameOverrides, modulePrefix, defaultModuleOrder } = conventions;
  const classDir = path.join(aioDir, className);
  const sharedFiles = fs.readdirSync(aioDir).filter((file) => file.endsWith('.lua'));
  const classFiles = fs.existsSync(classDir)
    ? fs.readdirSync(classDir).filter((file) => file.endsWith('.lua'))
    : [];

  assertValidLuaFileNames([...sharedFiles, ...classFiles]);

  const orderMap = new Map(loadOrder.map((slot) => [slot.source, slot.order]));
  const knownClassFiles = new Set(
    loadOrder.filter((slot) => slot.slot === 'class').map((slot) => slot.source),
  );
  const remainingClass = classFiles.filter((file) => !knownClassFiles.has(file)).sort();
  const terminalSource = loadOrder.length > 0 ? loadOrder[loadOrder.length - 1].source : null;

  const pascal = (file: string) => toPascalCase(file, nameOverrides);
  const classPascal = pascal(className);
  const modules: RotationModule[] = [];

  for (const slot of loadOrder) {
    // Extra (un-listed) class files load just before the terminal module (main.lua by default).
    if (slot.source === terminalSource) {
      for (const file of remainingClass) {
        modules.push({
          name: `${modulePrefix}${classPascal}_${pascal(file)}`,
          order: orderMap.get(file) ?? defaultModuleOrder,
          filePath: path.join(classDir, file),
        });
      }
    }

    if (slot.slot === 'shared') {
      if (sharedFiles.includes(slot.source)) {
        modules.push({
          name: `${modulePrefix}${pascal(slot.source)}`,
          order: slot.order,
          filePath: path.join(aioDir, slot.source),
        });
      }
    } else if (classFiles.includes(slot.source)) {
      modules.push({
        name: `${modulePrefix}${classPascal}_${pascal(slot.source)}`,
        order: slot.order,
        filePath: path.join(classDir, slot.source),
      });
    }
  }

  return modules;
}

export function discoverClasses(aioDir: string): string[] {
  if (!fs.existsSync(aioDir)) return [];
  return fs
    .readdirSync(aioDir)
    .filter((entry) => fs.statSync(path.join(aioDir, entry)).isDirectory());
}

export function getProfileName(
  className: string,
  conventions: BuildConventions,
  config?: LocalConfig | null,
): string {
  if (config?.profiles?.[className]) return config.profiles[className];
  return `${conventions.profileNamePrefix}${className.charAt(0).toUpperCase() + className.slice(1)}`;
}
