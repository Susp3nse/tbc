import { fetchFightEvents } from './fetch-events.js';
import { processFight } from './process-fight.js';
import { bearDruid } from './specs/bear-druid.js';

const reportCode = process.argv[2];
const playerName = process.argv[3];
const fightIDs = process.argv.slice(4).map(Number);

if (!reportCode || !playerName || fightIDs.length === 0) {
  console.error('Usage: node src/batch-process.js <reportCode> <playerName> <fightID1> [fightID2] ...');
  process.exit(1);
}

for (const fightID of fightIDs) {
  try {
    console.log(`\n${'='.repeat(60)}`);
    const raw = await fetchFightEvents(reportCode, fightID, { playerName });
    const result = await processFight(raw, bearDruid, { player: playerName });
    console.log(`Processed ${result.cast_sequence.length} casts, ${Object.keys(result.uptimes).length} uptimes tracked`);
    console.log(`Cast summary:`, JSON.stringify(result.cast_summary, null, 2));
  } catch (err) {
    console.error(`Error on fight ${fightID}: ${err.message}`);
  }
}
