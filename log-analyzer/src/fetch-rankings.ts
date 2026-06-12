import { graphql } from './api.js';
import { rankingsQuery } from './queries.js';

/**
 * Fetch top N parses for an encounter+class+spec.
 * @param {number} encounterID - WCL encounter ID
 * @param {string} className - e.g. "Druid"
 * @param {string} specName - e.g. "Feral"
 * @param {number} count - Number of top parses to return
 * @param {string} metric - "dps" or "hps"
 * @returns {Array} Top parses with reportCode, fightID, player info, dps
 */
export async function fetchRankings(encounterID, className, specName, count = 10, metric = 'dps') {
  const data = await graphql(rankingsQuery(encounterID, className, specName, metric));
  const encounter = data.worldData.encounter;

  if (!encounter) {
    throw new Error(`No data for encounter ID ${encounterID}`);
  }

  // characterRankings returns a JSON blob — the structure varies
  // but typically has a rankings array with report info
  const rankings = encounter.characterRankings;

  // WCL returns this as a JSON scalar — may need to parse
  const parsed = typeof rankings === 'string' ? JSON.parse(rankings) : rankings;

  // Extract the rankings array (structure: { rankings: [...] } or { page, hasMorePages, count, rankings: [...] })
  const entries = parsed.rankings || parsed;

  if (!Array.isArray(entries)) {
    console.error('Unexpected rankings shape:', JSON.stringify(parsed).substring(0, 500));
    throw new Error('Could not parse rankings response');
  }

  const top = entries.slice(0, count).map((entry) => ({
    rank: entry.rank,
    player: entry.name,
    server: entry.server?.name || entry.serverName || 'Unknown',
    class: className,
    spec: specName,
    dps: Math.round(entry.amount || entry.total || 0),
    duration: entry.duration ? entry.duration / 1000 : 0,
    ilvl: entry.bracketData || entry.ilvlKeyOrPatch || null,
    reportCode: entry.report?.code || entry.reportCode,
    fightID: entry.report?.fightID ?? entry.fightID,
    startTime: entry.report?.startTime ?? entry.startTime ?? 0,
  }));

  console.log(`\nTop ${top.length} ${specName} ${className} on ${encounter.name}:`);
  for (const p of top) {
    console.log(`  #${p.rank} ${p.player}-${p.server}: ${p.dps} DPS (${p.duration.toFixed(1)}s) — report ${p.reportCode} fight ${p.fightID}`);
  }

  return { encounter: encounter.name, encounterID, rankings: top };
}
