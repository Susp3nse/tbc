#!/usr/bin/env node

import { discover } from './discover.js';
import { fetchRankings } from './fetch-rankings.js';
import { fetchFightEvents } from './fetch-events.js';
import { processFight } from './process-fight.js';
import { compareFromFiles } from './compare.js';
import { bearDruid } from './specs/bear-druid.js';

// Spec lookup
const SPECS = {
  'druid-feral': bearDruid,
  // Add more as needed
};

function parseArgs(argv) {
  const args = {};
  const positional = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const key = argv[i].slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith('--')) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    } else {
      positional.push(argv[i]);
    }
  }
  return { command: positional[0], args };
}

function resolveSpec(className, specName) {
  const key = `${className}-${specName}`.toLowerCase();
  const spec = SPECS[key];
  if (!spec) {
    console.error(`Unknown spec: ${className} ${specName}. Available: ${Object.keys(SPECS).join(', ')}`);
    process.exit(1);
  }
  return spec;
}

async function main() {
  const { command, args } = parseArgs(process.argv.slice(2));

  switch (command) {
    case 'discover': {
      const expansion = args.expansion || 'tbc';
      await discover(expansion);
      break;
    }

    case 'fetch': {
      if (args.report) {
        // Fetch specific report fight or trash
        const reportCode = args.report;
        const fightID = args.fight ? parseInt(args.fight, 10) : null;
        const playerName = args.player || null;

        if (args.trash) {
          const { listTrashFights } = await import('./fetch-events.js');
          await listTrashFights(reportCode);
        } else if (fightID) {
          const spec = args.class && args.spec ? resolveSpec(args.class, args.spec) : bearDruid;
          const raw = await fetchFightEvents(reportCode, fightID, { playerName });
          const result = await processFight(raw, spec, { player: playerName || 'You' });
          console.log(`\nProcessed ${result.cast_sequence.length} casts, ${Object.keys(result.uptimes).length} uptimes tracked`);
        } else {
          console.error('--report requires --fight <id> or --trash');
          process.exit(1);
        }
      } else if (args.boss) {
        // Fetch top parses by boss name/ID
        const encounterID = parseInt(args.boss, 10) || null;
        if (!encounterID) {
          console.error('--boss must be a numeric encounter ID. Use "discover" to find IDs.');
          process.exit(1);
        }
        const className = args.class || 'Druid';
        const specName = args.spec || 'Feral';
        const count = parseInt(args.count, 10) || 10;
        const spec = resolveSpec(className, specName);

        const rankings = await fetchRankings(encounterID, className, specName, count);

        // Fetch and process each top parse
        for (const entry of rankings.rankings) {
          if (!entry.reportCode || entry.fightID == null) {
            console.warn(`  Skipping ${entry.player}: missing report/fight info`);
            continue;
          }
          try {
            console.log(`\nFetching ${entry.player}'s fight...`);
            const raw = await fetchFightEvents(entry.reportCode, entry.fightID, { playerName: entry.player });
            await processFight(raw, spec, entry);
          } catch (err) {
            console.error(`  Error processing ${entry.player}: ${err.message}`);
          }
        }
      } else {
        console.error('fetch requires --boss <encounterID> or --report <code>');
        process.exit(1);
      }
      break;
    }

    case 'compare': {
      if (!args.baseline || !args.yours) {
        console.error('compare requires --baseline <path> --yours <path>');
        process.exit(1);
      }
      await compareFromFiles(args.baseline, args.yours);
      break;
    }

    default:
      console.log(`
WCL Log Analyzer — Fetch and analyze top parser combat logs

Usage:
  corepack pnpm --filter @flux/log-analyzer cli -- discover --expansion tbc
  corepack pnpm --filter @flux/log-analyzer cli -- fetch --boss <encounterID> --class Druid --spec Feral --count 10
  corepack pnpm --filter @flux/log-analyzer cli -- fetch --report <code> --fight <id> [--player <name>] [--class Druid --spec Feral]
  corepack pnpm --filter @flux/log-analyzer cli -- fetch --report <code> --trash
  corepack pnpm --filter @flux/log-analyzer cli -- compare --baseline <file> --yours <file>

Options:
  --expansion    Expansion name: classic, tbc, wotlk (default: tbc)
  --boss         Encounter ID (use discover to find IDs)
  --class        Class name (e.g., Druid, Warrior)
  --spec         Spec name (e.g., Feral, Arms)
  --count        Number of top parses to fetch (default: 10)
  --report       WCL report code
  --fight        Fight ID within a report
  --player       Player name to filter events
  --trash        List trash fights in a report
  --baseline     Path to top parser's fight JSON
  --yours        Path to your fight JSON
      `);
  }
}

main().catch((err) => {
  console.error('Fatal:', err.message);
  process.exit(1);
});
