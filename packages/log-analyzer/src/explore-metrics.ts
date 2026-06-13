import { graphql } from './api.js';

// Try all possible metric values for tank rankings
const encounterID = parseInt(process.argv[2]) || 50656;
const metrics = ['dps', 'hps', 'tankhps', 'wdps', 'ndps', 'rdps', 'krsi', 'default'];

for (const metric of metrics) {
  const query = `query {
    worldData {
      encounter(id: ${encounterID}) {
        name
        characterRankings(
          className: "Druid"
          specName: "Feral"
          metric: ${metric}
          page: 1
        )
      }
    }
  }`;

  try {
    const data = await graphql(query);
    const rankings = data.worldData.encounter.characterRankings;
    const parsed = typeof rankings === 'string' ? JSON.parse(rankings) : rankings;
    const entries = parsed.rankings || parsed;

    if (parsed.error) {
      console.log(`metric=${metric}: ERROR - ${parsed.error}`);
    } else if (Array.isArray(entries)) {
      console.log(`metric=${metric}: ${entries.length} results`);
      if (entries.length > 0) {
        const e = entries[0];
        console.log(`  #1: ${e.name} - ${Math.round(e.amount || 0)} (${metric})`);
      }
    }
  } catch (err) {
    console.log(`metric=${metric}: API ERROR - ${err.message.substring(0, 100)}`);
  }
}
