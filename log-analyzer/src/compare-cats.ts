/**
 * Compare Chancity's cat fights against top cat parsers.
 *
 * Chancity's cat fights (Mz94KqCY8X7LkP23):
 *   Fight 31: Maiden of Virtue (69s)  — encounter 50654
 *   Fight 85: Shade of Aran (137s)    — encounter 50658
 *   Fight 102: Prince Malchezaar (195s) — encounter 50661
 */
import { fetchFightEvents } from './fetch-events.js';
import { processFight } from './process-fight.js';
import { compareFights } from './compare.js';
import { graphql, fetchAllEvents } from './api.js';
import { reportFightsQuery } from './queries.js';
import { catDruid } from './specs/cat-druid.js';

const CHANCITY_REPORT = 'Mz94KqCY8X7LkP23';
const CHANCITY_NAME = 'Chancity';
const CAT_FIGHTS = [
  { fightID: 31, encounter: 50654, boss: 'Maiden of Virtue' },
  { fightID: 85, encounter: 50658, boss: 'Shade of Aran' },
  { fightID: 102, encounter: 50661, boss: 'Prince Malchezaar' },
];

const mode = process.argv[2] || 'all'; // 'process', 'fetch-top', 'compare', or 'all'

// --- Step 1: Process Chancity's cat fights ---
async function processChancityFights() {
  console.log('=== PROCESSING CHANCITY CAT FIGHTS ===\n');
  const results = [];

  for (const fight of CAT_FIGHTS) {
    console.log(`\n--- ${fight.boss} (Fight ${fight.fightID}) ---`);
    try {
      const raw = await fetchFightEvents(CHANCITY_REPORT, fight.fightID, { playerName: CHANCITY_NAME });
      const result = await processFight(raw, catDruid, { player: CHANCITY_NAME });
      results.push(result);
      console.log(`  ${result.cast_sequence.length} casts tracked`);
      console.log(`  Casts: ${Object.entries(result.cast_summary).map(([s, i]) => s + ':' + i.count).join(', ')}`);
    } catch (err) {
      console.error(`  Error: ${err.message}`);
    }
  }

  return results;
}

// --- Step 2: Fetch top cat parsers for same encounters ---
async function fetchTopCatParsers() {
  console.log('\n=== FETCHING TOP CAT PARSERS ===\n');
  const results = [];

  for (const fight of CAT_FIGHTS) {
    console.log(`\n--- Top Feral on ${fight.boss} (encounter ${fight.encounter}) ---`);

    // Fetch rankings
    const query = `query {
      worldData {
        encounter(id: ${fight.encounter}) {
          name
          characterRankings(
            className: "Druid"
            specName: "Feral"
            metric: dps
            page: 1
          )
        }
      }
    }`;

    const data = await graphql(query);
    const encounter = data.worldData.encounter;
    const rankings = typeof encounter.characterRankings === 'string'
      ? JSON.parse(encounter.characterRankings)
      : encounter.characterRankings;
    const entries = rankings.rankings || rankings;

    console.log(`  ${entries.length} ranked players found`);

    // Take top 3 cat druids (verify they're actually cat by checking casts)
    let processed = 0;

    for (const entry of entries.slice(0, 10)) {
      if (processed >= 3) break;

      const reportCode = entry.report?.code;
      const fightID = entry.report?.fightID;
      const playerName = entry.name;
      const server = entry.server?.name || '?';
      const dps = Math.round(entry.amount || 0);

      if (!reportCode || fightID == null) continue;

      try {
        // Fetch fight events for this top parser
        console.log(`  Checking ${playerName}-${server} (${dps} DPS)...`);
        const raw = await fetchFightEvents(reportCode, fightID, { playerName });

        // Verify it's a cat (not bear) by checking first 30s of casts
        const catSpells = new Set([33983, 33982, 33876, 27002, 5221, 27008, 1079, 31018, 22568, 27003, 1822, 768]);
        const bearSpells = new Set([33987, 33986, 33878, 26996, 6807, 26997, 779, 33745, 9634]);
        let catCount = 0, bearCount = 0;

        for (const c of raw.casts.slice(0, 100)) {
          if (catSpells.has(c.abilityGameID)) catCount++;
          if (bearSpells.has(c.abilityGameID)) bearCount++;
        }

        if (bearCount > catCount) {
          console.log(`    Skipping — this is a BEAR (bear:${bearCount} cat:${catCount})`);
          continue;
        }

        const result = await processFight(raw, catDruid, { player: playerName, server, dps });
        results.push(result);
        processed++;
        console.log(`    [CAT] ${playerName}-${server}: ${dps} DPS, ${result.cast_sequence.length} casts`);
      } catch (err) {
        console.error(`    Error: ${err.message}`);
      }
    }
  }

  return results;
}

// --- Step 3: Compare ---
async function compareAll() {
  console.log('\n=== COMPARING CHANCITY vs TOP CATS ===\n');

  // Load processed fight files
  const fs = await import('fs/promises');
  const path = await import('path');
  const { fileURLToPath } = await import('url');
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const fightsDir = path.resolve(__dirname, '..', 'data', 'fights');

  const files = await fs.readdir(fightsDir);

  for (const fight of CAT_FIGHTS) {
    const bossSlug = fight.boss.toLowerCase().replace(/[^a-z0-9]+/g, '-');

    // Find Chancity's file
    const chancityFile = files.find(f => f.includes(bossSlug) && f.includes('chancity'));
    if (!chancityFile) {
      console.log(`No Chancity data for ${fight.boss}, skipping.`);
      continue;
    }

    // Find top parser files for same boss
    const topFiles = files.filter(f => f.includes(bossSlug) && !f.includes('chancity'));
    if (topFiles.length === 0) {
      console.log(`No top parser data for ${fight.boss}, skipping.`);
      continue;
    }

    const chancityData = JSON.parse(await fs.readFile(path.join(fightsDir, chancityFile), 'utf-8'));

    console.log(`\n${'='.repeat(70)}`);
    console.log(`  ${fight.boss}: Chancity (${chancityData.meta.dps || '?'} DPS, ${chancityData.meta.duration_sec}s)`);
    console.log(`${'='.repeat(70)}`);

    for (const topFile of topFiles) {
      const topData = JSON.parse(await fs.readFile(path.join(fightsDir, topFile), 'utf-8'));

      console.log(`\n  vs ${topData.meta.player}-${topData.meta.server} (${topData.meta.dps} DPS, ${topData.meta.duration_sec}s)`);
      console.log(`  ${'-'.repeat(50)}`);

      const comparison = compareFights(topData, chancityData);

      // DPS gap
      if (comparison.dps_gap) {
        console.log(`\n  DPS: You ${comparison.dps_gap.yours || '?'} vs Top ${comparison.dps_gap.top} (${comparison.dps_gap.pct_of_top}% of top)`);
      }

      // CPM differences
      console.log('\n  Cast-per-minute comparison:');
      for (const [spell, info] of Object.entries(comparison.cast_diffs || {})) {
        const dir = info.delta > 0 ? '+' : '';
        console.log(`    ${spell.padEnd(25)} Top: ${info.top_cpm.toFixed(1).padStart(5)}   You: ${info.yours_cpm.toFixed(1).padStart(5)}   (${dir}${info.delta.toFixed(1)})`);
      }

      // Uptimes
      if (Object.keys(comparison.uptime_diffs || {}).length > 0) {
        console.log('\n  Uptime comparison:');
        for (const [buff, info] of Object.entries(comparison.uptime_diffs)) {
          const dir = info.delta > 0 ? '+' : '';
          console.log(`    ${buff.padEnd(25)} Top: ${info.top.toFixed(1).padStart(5)}%  You: ${info.yours.toFixed(1).padStart(5)}%  (${dir}${info.delta.toFixed(1)}%)`);
        }
      }

      // Idle analysis (from raw fight data)
      const topIdle = topData.idle_analysis?.idle_pct || 0;
      const yoursIdle = chancityData.idle_analysis?.idle_pct || 0;
      console.log('\n  Activity:');
      console.log(`    GCD Efficiency:    Top: ${(100 - topIdle).toFixed(0)}%   You: ${(100 - yoursIdle).toFixed(0)}%`);
      console.log(`    Idle Time:         Top: ${topIdle.toFixed(1)}%   You: ${yoursIdle.toFixed(1)}%`);

      // Insights
      if (comparison.actionable_insights?.length > 0) {
        console.log('\n  Key insights:');
        for (const insight of comparison.actionable_insights) {
          console.log(`    - ${insight}`);
        }
      }
    }
  }
}

// Run
if (mode === 'process' || mode === 'all') {
  await processChancityFights();
}

if (mode === 'fetch-top' || mode === 'all') {
  await fetchTopCatParsers();
}

if (mode === 'compare' || mode === 'all') {
  await compareAll();
}
