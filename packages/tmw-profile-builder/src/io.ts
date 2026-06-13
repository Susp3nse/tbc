import fs from 'node:fs';

export function writeWithRetry(filePath: string, content: string, attempts = 3, delay = 500): void {
  for (let i = 0; i < attempts; i++) {
    try {
      fs.writeFileSync(filePath, content, 'utf8');
      return;
    } catch (err) {
      const e = err as NodeJS.ErrnoException;
      if (i < attempts - 1 && (e.code === 'EBUSY' || e.code === 'EPERM')) {
        console.log(`  File locked, retrying in ${delay}ms...`);
        const waitUntil = Date.now() + delay;
        while (Date.now() < waitUntil) {
          // busy wait to preserve existing sync behavior
        }
      } else {
        console.error(`  ERROR writing ${filePath}: ${e.message}`);
        return;
      }
    }
  }
}

export function timestamp(): string {
  return new Date().toLocaleTimeString('en-US', { hour12: false });
}
