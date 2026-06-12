import fs from 'fs/promises';
import path from 'path';
import { config } from '../config.js';

// --- Layer 1: Pre-Claude input validation ---

const rateLimitMap = new Map();

export function validatePrompt(prompt) {
  if (!prompt || prompt.length === 0) {
    return { valid: false, error: 'Prompt cannot be empty.' };
  }
  if (prompt.length > config.maxRequestLength) {
    return { valid: false, error: `Prompt too long (${prompt.length}/${config.maxRequestLength} chars).` };
  }
  return { valid: true };
}

export function checkRateLimit(userId) {
  const now = Date.now();
  const last = rateLimitMap.get(userId);
  if (last && now - last < config.rateLimitMs) {
    const waitSec = Math.ceil((config.rateLimitMs - (now - last)) / 1000);
    return { allowed: false, error: `Rate limited. Try again in ${waitSec}s.` };
  }
  rateLimitMap.set(userId, now);
  return { allowed: true };
}

// --- Layer 4+5: Post-Claude change validation ---

const ALLOWED_PATH_RE = /^source[/\\]aio[/\\].+\.lua$/;

const DANGEROUS_PATTERNS = [
  /os\.execute/,
  /os\.remove/,
  /os\.rename/,
  /os\.tmpname/,
  /io\.open/,
  /io\.popen/,
  /io\.write/,
  /io\.output/,
  /loadstring/,
  /dofile/,
  /loadfile/,
  /require\s*\(/,
  /rawset\s*\(\s*_G/,
  /debug\.setfenv/,
  /debug\.sethook/,
  /RunScript/,
  /SendChatMessage/,
  /SendAddonMessage/,
  /SetBindingClick/,
];

export async function validateChanges(workDir, filesChanged) {
  const errors = [];

  for (const filePath of filesChanged) {
    const relative = path.relative(workDir, filePath).replace(/\\/g, '/');

    if (!ALLOWED_PATH_RE.test(relative)) {
      errors.push(`Unauthorized file modified: ${relative}`);
      continue;
    }

    const content = await fs.readFile(filePath, 'utf8');
    for (const pattern of DANGEROUS_PATTERNS) {
      if (pattern.test(content)) {
        errors.push(`Dangerous pattern "${pattern.source}" in ${path.basename(filePath)}`);
      }
    }
  }

  return { valid: errors.length === 0, errors };
}
