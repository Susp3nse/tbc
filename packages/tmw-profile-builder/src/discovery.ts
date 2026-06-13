import fs from 'node:fs';
import path from 'node:path';
import type { IniConfig, RotationModule } from './types.js';

const ORDER_MAP: Record<string, number> = {
  'common.lua': 1,
  'schema.lua': 2,
  'ui.lua': 3,
  'core.lua': 4,
  'class.lua': 5,
  'healing.lua': 6,
  'settings.lua': 6,
  'middleware.lua': 7,
  'dashboard.lua': 8,
  'main.lua': 9,
};

const LOAD_ORDER = [
  { slot: 'shared', source: 'common.lua' },
  { slot: 'class', source: 'schema.lua' },
  { slot: 'shared', source: 'ui.lua' },
  { slot: 'shared', source: 'core.lua' },
  { slot: 'class', source: 'class.lua' },
  { slot: 'class', source: 'healing.lua' },
  { slot: 'shared', source: 'settings.lua' },
  { slot: 'class', source: 'middleware.lua' },
  { slot: 'shared', source: 'dashboard.lua' },
  { slot: 'shared', source: 'main.lua' },
];

const NAME_OVERRIDES: Record<string, string> = { ui: 'UI' };

function toPascalCase(filename: string): string {
  const name = filename.replace('.lua', '');
  return NAME_OVERRIDES[name] || name.charAt(0).toUpperCase() + name.slice(1);
}

function assertValidLuaFileNames(files: string[]): void {
  for (const file of files) {
    const stem = file.replace('.lua', '');
    if (/[_\s-]/.test(stem)) {
      throw new Error(`Bad filename "${file}" - use single lowercase words (no underscores/hyphens/spaces)`);
    }
  }
}

export function discoverModules(className: string, aioDir: string): RotationModule[] {
  const classDir = path.join(aioDir, className);
  const sharedFiles = fs.readdirSync(aioDir).filter((file) => file.endsWith('.lua'));
  const classFiles = fs.existsSync(classDir)
    ? fs.readdirSync(classDir).filter((file) => file.endsWith('.lua'))
    : [];

  assertValidLuaFileNames([...sharedFiles, ...classFiles]);

  const knownClassFiles = new Set(LOAD_ORDER.filter((slot) => slot.slot === 'class').map((slot) => slot.source));
  const remainingClass = classFiles.filter((file) => !knownClassFiles.has(file)).sort();
  const modules: RotationModule[] = [];

  for (const slot of LOAD_ORDER) {
    if (slot.source === 'main.lua') {
      for (const file of remainingClass) {
        modules.push({
          name: `Flux_${toPascalCase(className)}_${toPascalCase(file)}`,
          order: ORDER_MAP[file] || 7,
          filePath: path.join(classDir, file),
        });
      }
    }

    if (slot.slot === 'shared') {
      if (sharedFiles.includes(slot.source)) {
        modules.push({
          name: `Flux_${toPascalCase(slot.source)}`,
          order: ORDER_MAP[slot.source],
          filePath: path.join(aioDir, slot.source),
        });
      }
    } else if (classFiles.includes(slot.source)) {
      modules.push({
        name: `Flux_${toPascalCase(className)}_${toPascalCase(slot.source)}`,
        order: ORDER_MAP[slot.source],
        filePath: path.join(classDir, slot.source),
      });
    }
  }

  return modules;
}

export function discoverClasses(aioDir: string): string[] {
  if (!fs.existsSync(aioDir)) return [];
  return fs.readdirSync(aioDir).filter((entry) => fs.statSync(path.join(aioDir, entry)).isDirectory());
}

export function getProfileName(className: string, config?: IniConfig | null): string {
  if (config?.profiles?.[className]) return config.profiles[className];
  return `Flux ${className.charAt(0).toUpperCase() + className.slice(1)}`;
}
