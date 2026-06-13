import { graphql } from './api.js';
import { reportFightsQuery } from './queries.js';

const reportCode = process.argv[2] || 'Mz94KqCY8X7LkP23';
const playerName = process.argv[3] || 'Chancity';

const data = await graphql(reportFightsQuery(reportCode));
const report = data.reportData.report;

const actor = report.masterData.actors.find(a => a.name === playerName);
if (!actor) { console.error('Player not found'); process.exit(1); }
const sourceID = actor.id;

const bossFights = report.fights.filter(f => f.kill && f.encounterID > 0);

const bearSpells = new Set([33878, 6807, 779, 33745, 99, 6795, 5209, 9634]);
const catSpells = new Set([33876, 1822, 1079, 5221, 22568, 768]);

for (const fight of bossFights) {
  const start = fight.startTime;
  const end = fight.endTime;

  const query = `query {
    reportData {
      report(code: "${reportCode}") {
        events(
          fightIDs: [${fight.id}],
          dataType: Casts,
          startTime: ${start},
          endTime: ${end},
          sourceID: ${sourceID},
          limit: 200
        ) { data }
      }
    }
  }`;

  const result = await graphql(query);
  const casts = result.reportData.report.events.data || [];

  let bearCount = 0;
  let catCount = 0;

  for (const c of casts) {
    if (bearSpells.has(c.abilityGameID)) bearCount++;
    if (catSpells.has(c.abilityGameID)) catCount++;
  }

  const role = bearCount > catCount ? 'BEAR' : catCount > bearCount ? 'CAT' : 'UNKNOWN';
  const dur = ((fight.endTime - fight.startTime) / 1000).toFixed(0);
  console.log(`Fight ${fight.id}: ${fight.name} (${dur}s) — ${role} (bear:${bearCount} cat:${catCount})`);
}
