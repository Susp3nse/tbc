#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';

type AnalyzeReportFight = (options: {
  reportCode: string;
  fightId: number;
  playerName?: string | null;
  className?: string;
  specName?: string;
}) => Promise<{
  result: {
    cast_sequence: unknown[];
    uptimes: Record<string, unknown>;
  };
}>;

function parseArgs(argv: string[]) {
  const args: Record<string, string | boolean> = {};

  for (let i = 0; i < argv.length; i++) {
    const current = argv[i];
    if (!current.startsWith('--')) continue;

    const key = current.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith('--')) {
      args[key] = next;
      i++;
    } else {
      args[key] = true;
    }
  }

  return args;
}

function stringArg(args: Record<string, string | boolean>, key: string, fallback = '') {
  const value = args[key];
  return typeof value === 'string' ? value : fallback;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const reportCode = stringArg(args, 'report');
  const fightId = Number.parseInt(stringArg(args, 'fight'), 10);
  const playerName = stringArg(args, 'player') || null;
  const className = stringArg(args, 'class', 'Druid');
  const specName = stringArg(args, 'spec', 'Feral');

  if (!reportCode || !Number.isInteger(fightId)) {
    console.error(`
Usage:
  corepack pnpm --filter @flux/tbc-rotation analyze:report -- --report <code> --fight <id> [--player <name>] [--class Druid] [--spec Feral]

Examples:
  corepack pnpm --filter @flux/tbc-rotation analyze:report -- --report Mz94KqCY8X7LkP23 --fight 31 --player Chancity --class Druid --spec Cat
  corepack pnpm --filter @flux/tbc-rotation analyze:report -- --report Mz94KqCY8X7LkP23 --fight 31 --player Chancity --class Hunter
`);
    process.exit(1);
  }

  const { analyzeReportFight } = (await import('@flux/log-analyzer')) as {
    analyzeReportFight: AnalyzeReportFight;
  };

  const report = await analyzeReportFight({
    reportCode,
    fightId,
    playerName,
    className,
    specName,
  });

  const outputDir = path.resolve(process.cwd(), 'reports');
  await fs.mkdir(outputDir, { recursive: true });

  const playerPart = playerName ? `-${playerName.replace(/[^a-z0-9_-]/gi, '_')}` : '';
  const outputPath = path.join(outputDir, `${reportCode}-fight-${fightId}${playerPart}.json`);
  await fs.writeFile(outputPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');

  console.log(`Wrote ${outputPath}`);
  console.log(`Casts tracked: ${report.result.cast_sequence.length}`);
  console.log(`Uptimes tracked: ${Object.keys(report.result.uptimes).length}`);
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
