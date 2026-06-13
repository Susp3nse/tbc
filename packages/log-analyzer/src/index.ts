export { graphql, fetchAllEvents } from './api.js';
export { compareFights, compareFromFiles } from './compare.js';
export { discover } from './discover.js';
export { fetchFightEvents, listTrashFights } from './fetch-events.js';
export { fetchRankings } from './fetch-rankings.js';
export {
  buildBuffTimeline,
  computeRefreshPatterns,
  computeTransitions,
  computeUptimes,
  processFight,
  sampleBuffsAtTime,
} from './process-fight.js';
export { bearDruid } from './specs/bear-druid.js';
export { catDruid } from './specs/cat-druid.js';
export { hunter, hunterSpellName } from './specs/hunter.js';

import { fetchFightEvents } from './fetch-events.js';
import { processFight } from './process-fight.js';
import { bearDruid } from './specs/bear-druid.js';
import { catDruid } from './specs/cat-druid.js';
import { hunter } from './specs/hunter.js';

const SPECS = {
  'druid-bear': bearDruid,
  'druid-feral': bearDruid,
  'druid-feral-tank': bearDruid,
  'druid-cat': catDruid,
  'druid-feral-dps': catDruid,
  hunter,
  'hunter-hunter': hunter,
  'hunter-beast-mastery': hunter,
  'hunter-marksmanship': hunter,
  'hunter-survival': hunter,
};

export function resolveSpec(className, specName = '') {
  const normalizedClass = String(className || '').toLowerCase();
  const normalizedSpec = String(specName || '').toLowerCase().replace(/\s+/g, '-');
  const key = normalizedSpec ? `${normalizedClass}-${normalizedSpec}` : normalizedClass;
  const spec = SPECS[key];

  if (!spec) {
    throw new Error(`Unknown analyzer spec: ${className}${specName ? ` ${specName}` : ''}`);
  }

  return spec;
}

export async function analyzeReportFight(options) {
  const {
    reportCode,
    fightId,
    playerName = null,
    className = 'Druid',
    specName = 'Feral',
    rankingInfo = {},
  } = options;

  if (!reportCode) throw new Error('reportCode is required');
  if (!Number.isInteger(fightId)) throw new Error('fightId must be an integer');

  const spec = resolveSpec(className, specName);
  const raw = await fetchFightEvents(reportCode, fightId, { playerName });
  const result = await processFight(raw, spec, {
    player: playerName || 'You',
    ...rankingInfo,
  });

  return {
    reportCode,
    fightId,
    playerName,
    spec: {
      name: spec.name,
      class: spec.class,
      spec: spec.spec,
    },
    result,
  };
}
