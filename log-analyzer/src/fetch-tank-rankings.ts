import { graphql, fetchAllEvents } from './api.js';
import { reportFightsQuery } from './queries.js';
import { processFight } from './process-fight.js';
import { bearDruid } from './specs/bear-druid.js';

const encounterID = parseInt(process.argv[2]) || 50656;
const count = parseInt(process.argv[3]) || 20; // fetch more to filter

// Fetch regular Feral rankings (will include both cat and bear)
const query = `query {
  worldData {
    encounter(id: ${encounterID}) {
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

console.log(`Scanning ${Math.min(count, entries.length)} Feral Druids on ${encounter.name} for BEAR players...\n`);

const bearSpells = new Set([33987, 33986, 33878, 26996, 6807, 26997, 779, 33745, 26998, 9898, 99]);
const catSpells = new Set([33876, 33983, 33982, 1822, 27003, 1079, 27008, 5221, 27002, 22568, 27005, 768]);

let found = 0;

for (const entry of entries.slice(0, count)) {
  const reportCode = entry.report?.code;
  const fightID = entry.report?.fightID;
  const playerName = entry.name;

  if (!reportCode || fightID == null) continue;

  try {
    // Get report to find actor ID
    const reportData = await graphql(reportFightsQuery(reportCode));
    const report = reportData.reportData.report;
    const fight = report.fights.find(f => f.id === fightID);
    if (!fight) continue;

    const actor = (report.masterData?.actors || []).find(a => a.name === playerName);
    if (!actor) continue;

    // Fetch a small sample of casts
    const start = fight.startTime;
    const end = Math.min(fight.endTime, start + 30000);
    const sampleQuery = `query {
      reportData {
        report(code: "${reportCode}") {
          events(
            fightIDs: [${fightID}],
            dataType: Casts,
            startTime: ${start},
            endTime: ${end},
            sourceID: ${actor.id},
            limit: 100
          ) { data }
        }
      }
    }`;

    const sampleData = await graphql(sampleQuery);
    const casts = sampleData.reportData.report.events.data || [];

    let bearCount = 0;
    let catCount = 0;
    for (const c of casts) {
      if (bearSpells.has(c.abilityGameID)) bearCount++;
      if (catSpells.has(c.abilityGameID)) catCount++;
    }

    const role = bearCount > catCount ? 'BEAR' : 'CAT';
    const server = entry.server?.name || '?';
    const dps = Math.round(entry.amount || 0);
    const dur = entry.duration ? (entry.duration / 1000).toFixed(0) : '?';

    if (role === 'BEAR') {
      found++;
      console.log(`  [BEAR] ${playerName}-${server}: ${dps} DPS (${dur}s) — report ${reportCode} fight ${fightID}`);

      // Process this bear's fight
      console.log(`    Processing full fight...`);
      const raw = await fetchAllBearEvents(reportCode, fightID, playerName, actor.id, fight);
      const result = await processFight(raw, bearDruid, { player: playerName, server, dps });
      console.log(`    Saved. ${result.cast_sequence.length} casts tracked.`);
      console.log(`    Casts: ${Object.entries(result.cast_summary).map(([s,i]) => s + ':' + i.count).join(', ')}`);

      if (found >= 3) break;
    } else {
      console.log(`  [CAT]  ${playerName}-${server}: ${dps} DPS — skipping`);
    }
  } catch (err) {
    console.error(`  Error checking ${playerName}: ${err.message}`);
  }
}

if (found === 0) {
  console.log('\nNo bear tanks found in top rankings. This is expected — top DPS Ferals are always cat.');
  console.log('For bear comparison, consider comparing against your own best fight or known bear guildie logs.');
}

async function fetchAllBearEvents(reportCode, fightID, playerName, sourceID, fight) {
  const start = fight.startTime;
  const end = fight.endTime;
  const duration = (end - start) / 1000;

  const casts = await fetchAllEvents(reportCode, fightID, 'Casts', start, end, { sourceID });
  const buffs = await fetchAllEvents(reportCode, fightID, 'Buffs', start, end, { sourceID });
  const debuffs = await fetchAllEvents(reportCode, fightID, 'Debuffs', start, end);
  const resources = await fetchAllEvents(reportCode, fightID, 'Resources', start, end, { sourceID });

  return {
    meta: {
      reportCode, fightID, fightName: fight.name, encounterID: fight.encounterID,
      startTime: start, endTime: end, duration, kill: fight.kill, actors: [], sourceID,
    },
    casts, buffs, debuffs, resources,
  };
}
