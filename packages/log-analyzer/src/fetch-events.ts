import fs from 'fs/promises';
import path from 'path';
import { graphql, fetchAllEvents } from './api.js';
import { reportFightsQuery } from './queries.js';
import { config } from './config.js';

const delay = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Fetch all events for a specific fight in a report.
 * Pulls Casts, Buffs, and Debuffs in sequence.
 * @param {string} reportCode
 * @param {number} fightID
 * @param {object} opts - { playerName, className }
 * @returns {object} { meta, casts, buffs, debuffs, resources }
 */
export async function fetchFightEvents(reportCode, fightID, opts = {}) {
  // 1. Get report metadata
  console.log(`Fetching report ${reportCode}...`);
  const reportData = await graphql(reportFightsQuery(reportCode));
  const report = reportData.reportData.report;

  if (!report) {
    throw new Error(`Report ${reportCode} not found`);
  }

  // 2. Find the fight
  const fight = report.fights.find((f) => f.id === fightID);
  if (!fight) {
    const available = report.fights.map((f) => `${f.id}: ${f.name}`).join(', ');
    throw new Error(`Fight ${fightID} not found in report. Available: ${available}`);
  }

  // 3. Find the player's actor ID (for filtering events)
  let sourceID = null;
  if (opts.playerName) {
    const actor = (report.masterData?.actors || []).find(
      (a) => a.name.toLowerCase() === opts.playerName.toLowerCase()
    );
    if (actor) {
      sourceID = actor.id;
      console.log(`  Player "${actor.name}" = actor ID ${sourceID} (${actor.subType})`);
    } else {
      console.warn(`  Player "${opts.playerName}" not found in report actors. Fetching all events.`);
    }
  }

  const start = fight.startTime;
  const end = fight.endTime;
  const duration = (end - start) / 1000;

  console.log(`  Fight: ${fight.name} (${duration.toFixed(1)}s, ${fight.kill ? 'KILL' : 'WIPE'})`);

  // 4. Fetch events by type
  console.log('  Fetching casts...');
  const casts = await fetchAllEvents(reportCode, fightID, 'Casts', start, end, { sourceID });

  await delay(config.requestDelayMs);

  console.log('  Fetching buffs...');
  const buffs = await fetchAllEvents(reportCode, fightID, 'Buffs', start, end, { sourceID });

  await delay(config.requestDelayMs);

  console.log('  Fetching debuffs...');
  const debuffs = await fetchAllEvents(reportCode, fightID, 'Debuffs', start, end);

  await delay(config.requestDelayMs);

  console.log('  Fetching resources (energize/drain)...');
  const resources = await fetchAllEvents(reportCode, fightID, 'Resources', start, end, { sourceID });

  const result = {
    meta: {
      reportCode,
      fightID,
      fightName: fight.name,
      encounterID: fight.encounterID,
      startTime: start,
      endTime: end,
      duration,
      kill: fight.kill,
      actors: report.masterData?.actors || [],
      sourceID,
    },
    casts,
    buffs,
    debuffs,
    resources,
  };

  // 5. Save raw data
  const rawDir = path.join(config.dataDir, 'raw');
  await fs.mkdir(rawDir, { recursive: true });
  const filename = `${reportCode}-fight${fightID}-raw.json`;
  await fs.writeFile(path.join(rawDir, filename), JSON.stringify(result, null, 2));
  console.log(`  Saved raw data: data/raw/${filename}`);
  console.log(`  Events: ${casts.length} casts, ${buffs.length} buffs, ${debuffs.length} debuffs, ${resources.length} resources`);

  return result;
}

/**
 * List trash fights (encounterID == 0) in a report.
 */
export async function listTrashFights(reportCode) {
  const reportData = await graphql(reportFightsQuery(reportCode));
  const report = reportData.reportData.report;

  const trash = report.fights.filter((f) => f.encounterID === 0);

  console.log(`\nTrash fights in ${reportCode}:`);
  for (const f of trash) {
    const dur = ((f.endTime - f.startTime) / 1000).toFixed(1);
    console.log(`  Fight ${f.id}: ${f.name} (${dur}s)`);
  }

  return { report, trashFights: trash };
}
