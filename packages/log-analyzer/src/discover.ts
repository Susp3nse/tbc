import { graphql } from './api.js';
import { discoverZonesQuery } from './queries.js';

// WCL expansion IDs (Classic uses 1000+ range)
const EXPANSION_IDS = {
  classic: 1000,
  tbc: 1001,
  wotlk: 1002,
  cata: 1003,
  mop: 1004,
};

export async function discover(expansionName) {
  const expId = EXPANSION_IDS[expansionName.toLowerCase()];
  if (!expId) {
    throw new Error(`Unknown expansion: "${expansionName}". Valid: ${Object.keys(EXPANSION_IDS).join(', ')}`);
  }

  const data = await graphql(discoverZonesQuery(expId));
  const expansion = data.worldData.expansion;

  if (!expansion) {
    throw new Error(`No data returned for expansion ID ${expId}`);
  }

  console.log(`\n${expansion.name}\n${'='.repeat(expansion.name.length)}\n`);

  for (const zone of expansion.zones || []) {
    console.log(`  ${zone.name} (zone ${zone.id})`);
    for (const enc of zone.encounters || []) {
      console.log(`    - ${enc.name} (encounter ${enc.id})`);
    }
  }

  return expansion;
}
