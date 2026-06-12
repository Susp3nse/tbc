#!/usr/bin/env node

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { graphql, fetchAllEvents } from './api.js';
import { reportFightsQuery } from './queries.js';
import { config } from './config.js';
import { hunter, hunterSpellName } from './specs/hunter.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const args = { top: 3, maxFights: 0, player: null, report: null, noTop: false, spec: null };
  const positional = [];

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) {
      positional.push(arg);
      continue;
    }

    const key = arg.slice(2);
    if (key === 'no-top') {
      args.noTop = true;
      continue;
    }
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = next;
      i++;
    }
  }

  if (!args.report && positional[0]) args.report = positional[0];
  args.top = Number(args.top ?? 3);
  args.maxFights = Number(args.maxFights ?? 0);
  return args;
}

function extractReportCode(value) {
  if (!value) return null;
  const match = String(value).match(/reports\/([A-Za-z0-9]+)/);
  return match ? match[1] : String(value).trim();
}

function usage() {
  console.log(`Hunter WCL Review

Usage:
  corepack pnpm --filter @flux/log-analyzer hunter-review -- <reportUrlOrCode> --player <name> [--top 3]
  corepack pnpm --filter @flux/log-analyzer hunter-review -- <reportUrlOrCode> --player <name> --spec Survival
  corepack pnpm --filter @flux/log-analyzer hunter-review -- --report <reportUrlOrCode> --player <name> --max-fights 4
  corepack pnpm --filter @flux/log-analyzer hunter-review -- <reportUrlOrCode> --player <name> --no-top

Requires WCL_CLIENT_ID and WCL_CLIENT_SECRET in the repo root .env file.`);
}

function slugify(value) {
  return String(value || 'unknown').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function round(value, digits = 1) {
  if (!Number.isFinite(value)) return 0;
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function percentile(values, p) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.floor((sorted.length - 1) * p)));
  return sorted[idx];
}

function average(values) {
  const valid = values.filter((v) => Number.isFinite(v));
  return valid.length ? valid.reduce((sum, v) => sum + v, 0) / valid.length : 0;
}

function cpm(count, durationSec) {
  return durationSec > 0 ? round((count / durationSec) * 60, 2) : 0;
}

function eventTime(event, fightStart) {
  return round((event.timestamp - fightStart) / 1000, 2);
}

function amountFromDamage(event) {
  return Number(event.amount ?? event.unmitigatedAmount ?? 0) + Number(event.absorbed ?? 0);
}

function buildWindows(events, tracked, fightStart, fightEnd, opts = {}) {
  const active = new Map();
  const windows = [];
  const isApply = new Set(['applybuff', 'refreshbuff', 'applydebuff', 'refreshdebuff']);
  const isRemove = new Set(['removebuff', 'removedebuff']);

  for (const event of events) {
    const spellId = event.abilityGameID;
    const info = tracked[spellId];
    if (!info) continue;
    if (opts.targetID != null && event.targetID !== opts.targetID) continue;
    if (opts.sourceID != null && event.sourceID !== opts.sourceID) continue;

    const key = `${spellId}:${event.targetID ?? 'target'}`;
    if (isApply.has(event.type)) {
      if (active.has(key)) {
        windows.push({ spellId, name: info.name, start: active.get(key), end: event.timestamp });
      }
      active.set(key, event.timestamp);
    } else if (isRemove.has(event.type) && active.has(key)) {
      windows.push({ spellId, name: info.name, start: active.get(key), end: event.timestamp });
      active.delete(key);
    }
  }

  for (const [key, start] of active.entries()) {
    const spellId = Number(key.split(':')[0]);
    windows.push({ spellId, name: tracked[spellId].name, start, end: fightEnd });
  }

  return windows.filter((w) => w.end > fightStart && w.start < fightEnd);
}

function computeUptimes(windows, fightStart, fightEnd) {
  const duration = fightEnd - fightStart;
  const totals = {};
  for (const window of windows) {
    const overlap = Math.min(window.end, fightEnd) - Math.max(window.start, fightStart);
    if (overlap <= 0) continue;
    totals[window.name] = (totals[window.name] || 0) + overlap;
  }

  const result = {};
  for (const [name, totalMs] of Object.entries(totals)) {
    result[name] = round((totalMs / duration) * 100, 1);
  }
  return result;
}

function summarizeByName(events, durationSec, spellMap, amountFn = null) {
  const summary = {};
  for (const event of events) {
    const info = spellMap[event.abilityGameID];
    if (!info) continue;
    const name = info.name;
    if (!summary[name]) summary[name] = { count: 0, cpm: 0, amount: 0 };
    summary[name].count++;
    if (amountFn) summary[name].amount += amountFn(event);
  }

  for (const entry of Object.values(summary)) {
    entry.cpm = cpm(entry.count, durationSec);
    if (amountFn) entry.amount = Math.round(entry.amount);
  }
  return summary;
}

function summarizeAutoShot(damage, fightStart, durationSec) {
  const times = damage
    .filter((event) => event.abilityGameID === 75)
    .map((event) => eventTime(event, fightStart))
    .sort((a, b) => a - b);

  const intervals = [];
  for (let i = 1; i < times.length; i++) {
    intervals.push(round(times[i] - times[i - 1], 3));
  }

  const median = percentile(intervals, 0.5);
  const longGapThreshold = median > 0 ? Math.max(median + 0.45, median * 1.25) : 0;
  const longGaps = intervals.filter((gap) => longGapThreshold > 0 && gap > longGapThreshold);

  return {
    count: times.length,
    cpm: cpm(times.length, durationSec),
    median_interval: round(median, 3),
    p90_interval: round(percentile(intervals, 0.9), 3),
    max_interval: round(intervals.length ? Math.max(...intervals) : 0, 3),
    long_gap_threshold: round(longGapThreshold, 3),
    long_gap_count: longGaps.length,
    long_gap_pct: intervals.length ? round((longGaps.length / intervals.length) * 100, 1) : 0,
  };
}

function summarizeCooldowns(casts, buffWindows, fightStart) {
  const byName = {};

  for (const event of casts) {
    const name = hunter.trackedSpells[event.abilityGameID]?.name;
    if (!name || !hunter.cooldownNames.includes(name)) continue;
    if (!byName[name]) byName[name] = [];
    byName[name].push(eventTime(event, fightStart));
  }

  for (const window of buffWindows) {
    if (!hunter.cooldownNames.includes(window.name)) continue;
    if (!byName[window.name]) byName[window.name] = [];
    const t = round((window.start - fightStart) / 1000, 2);
    if (!byName[window.name].some((existing) => Math.abs(existing - t) < 0.25)) {
      byName[window.name].push(t);
    }
  }

  const result = {};
  for (const [name, times] of Object.entries(byName)) {
    const ordered = times.sort((a, b) => a - b);
    result[name] = { count: ordered.length, first: ordered[0] ?? null, times: ordered };
  }
  return result;
}

function buildOpener(casts, damage, fightStart, maxEvents = 16) {
  const castEvents = casts
    .filter((event) => hunter.trackedSpells[event.abilityGameID])
    .map((event) => ({
      time: eventTime(event, fightStart),
      kind: 'cast',
      spell: hunterSpellName(event.abilityGameID),
    }));

  const autoEvents = damage
    .filter((event) => event.abilityGameID === 75)
    .map((event) => ({
      time: eventTime(event, fightStart),
      kind: 'hit',
      spell: 'Auto Shot',
    }));

  return [...castEvents, ...autoEvents]
    .filter((event) => event.time >= -5)
    .sort((a, b) => a.time - b.time || (a.kind === 'cast' ? -1 : 1))
    .slice(0, maxEvents);
}

function deathForActor(deaths, sourceID) {
  return (deaths || [])
    .filter((event) => event.targetID === sourceID || event.sourceID === sourceID)
    .sort((a, b) => a.timestamp - b.timestamp)[0] || null;
}

function eventsUntil(events, endTime) {
  return (events || []).filter((event) => event.timestamp <= endTime);
}

function processHunterFight(raw, rankingInfo = {}) {
  const { meta, deaths } = raw;
  const death = deathForActor(deaths, meta.sourceID);
  const fightStart = meta.startTime;
  const fightEnd = meta.endTime;
  const activeEnd = death ? death.timestamp : fightEnd;
  const durationSec = (activeEnd - fightStart) / 1000;
  const casts = eventsUntil(raw.casts, activeEnd);
  const buffs = eventsUntil(raw.buffs, activeEnd);
  const debuffs = eventsUntil(raw.debuffs, activeEnd);
  const damage = eventsUntil(raw.damage, activeEnd);

  const buffWindows = buildWindows(buffs, hunter.trackedBuffs, fightStart, activeEnd, {
    targetID: meta.sourceID,
  });
  const ownDebuffWindows = buildWindows(debuffs, hunter.trackedDebuffs, fightStart, activeEnd, {
    sourceID: meta.sourceID,
  });

  const castSummary = summarizeByName(casts, durationSec, hunter.trackedSpells);
  const damageSummary = summarizeByName(damage, durationSec, hunter.trackedSpells, amountFromDamage);
  const autoShot = summarizeAutoShot(damage, fightStart, durationSec);

  const actionSummary = { ...castSummary };
  actionSummary['Auto Shot'] = {
    count: autoShot.count,
    cpm: autoShot.cpm,
    amount: damageSummary['Auto Shot']?.amount || 0,
  };

  return {
    meta: {
      player: rankingInfo.player || meta.playerName,
      server: rankingInfo.server || meta.server || 'Unknown',
      class: 'Hunter',
      boss: meta.fightName,
      encounter_id: meta.encounterID,
      duration_sec: round(durationSec, 1),
      fight_duration_sec: round(meta.duration, 1),
      died_at_sec: death ? round((death.timestamp - fightStart) / 1000, 1) : null,
      death_pct: death ? round(((death.timestamp - fightStart) / (fightEnd - fightStart)) * 100, 1) : null,
      dps: rankingInfo.dps || null,
      report_code: meta.reportCode,
      fight_id: meta.fightID,
      kill: meta.kill,
    },
    action_summary: actionSummary,
    cast_summary: castSummary,
    damage_summary: damageSummary,
    uptimes: {
      ...computeUptimes(ownDebuffWindows, fightStart, activeEnd),
      ...computeUptimes(buffWindows, fightStart, activeEnd),
    },
    cooldowns: summarizeCooldowns(casts, buffWindows, fightStart),
    auto_shot: autoShot,
    opener: buildOpener(casts, damage, fightStart),
  };
}

function hunterRankingsQuery(encounterID, page = 1, specName = null) {
  const specFilter = specName ? `specName: "${specName}"` : '';
  return `
    query {
      worldData {
        encounter(id: ${encounterID}) {
          name
          characterRankings(
            className: "Hunter"
            ${specFilter}
            metric: dps
            page: ${page}
          )
        }
      }
    }
  `;
}

function parseRankingsResponse(encounter, count) {
  const rankings = typeof encounter.characterRankings === 'string'
    ? JSON.parse(encounter.characterRankings)
    : encounter.characterRankings;
  const entries = rankings.rankings || rankings;
  if (!Array.isArray(entries)) return [];

  return entries.slice(0, count).map((entry) => ({
    rank: entry.rank,
    player: entry.name,
    server: entry.server?.name || entry.serverName || 'Unknown',
    dps: Math.round(entry.amount || entry.total || 0),
    duration: entry.duration ? entry.duration / 1000 : 0,
    reportCode: entry.report?.code || entry.reportCode,
    fightID: entry.report?.fightID ?? entry.fightID,
  }));
}

async function fetchHunterRankings(encounterID, count, specName = null) {
  const data = await graphql(hunterRankingsQuery(encounterID, 1, specName));
  const encounter = data.worldData.encounter;
  if (!encounter) throw new Error(`No WCL encounter found for ID ${encounterID}`);
  return {
    encounterName: encounter.name,
    specName,
    rankings: parseRankingsResponse(encounter, Math.max(count, 1) * 4),
  };
}

function findPlayerActor(report, playerName) {
  const actors = report.masterData?.actors || [];
  if (playerName) {
    return actors.find((actor) => actor.name.toLowerCase() === playerName.toLowerCase());
  }

  const hunters = actors.filter((actor) => actor.subType === 'Hunter');
  if (hunters.length === 1) return hunters[0];
  const names = hunters.map((actor) => actor.name).join(', ') || 'none';
  throw new Error(`Report has ${hunters.length} Hunter players (${names}). Re-run with --player <name>.`);
}

async function fetchReport(reportCode) {
  const data = await graphql(reportFightsQuery(reportCode));
  const report = data.reportData.report;
  if (!report) throw new Error(`Report ${reportCode} not found`);
  return report;
}

async function fetchHunterFight(reportCode, fight, actor, reportTitle) {
  const start = fight.startTime;
  const end = fight.endTime;
  const duration = (end - start) / 1000;

  console.log(`  Fetching ${fight.name} fight ${fight.id} for ${actor.name} (${round(duration, 1)}s)`);

  const casts = await fetchAllEvents(reportCode, fight.id, 'Casts', start, end, { sourceID: actor.id });
  const damage = await fetchAllEvents(reportCode, fight.id, 'DamageDone', start, end, { sourceID: actor.id });
  const buffs = await fetchAllEvents(reportCode, fight.id, 'Buffs', start, end);
  const debuffs = await fetchAllEvents(reportCode, fight.id, 'Debuffs', start, end);
  const deaths = await fetchAllEvents(reportCode, fight.id, 'Deaths', start, end);

  return {
    meta: {
      reportCode,
      reportTitle,
      fightID: fight.id,
      fightName: fight.name,
      encounterID: fight.encounterID,
      startTime: start,
      endTime: end,
      duration,
      kill: fight.kill,
      sourceID: actor.id,
      playerName: actor.name,
      server: actor.server || 'Unknown',
    },
    casts,
    damage,
    buffs,
    debuffs,
    deaths,
  };
}

function aggregateTop(fights) {
  const agg = {
    sample_count: fights.length,
    action_summary: {},
    uptimes: {},
    auto_shot: {},
    cooldowns: {},
  };
  if (!fights.length) return agg;

  for (const spell of hunter.comparisonSpells) {
    const values = fights.map((fight) => fight.action_summary[spell]?.cpm || 0);
    const countValues = fights.map((fight) => fight.action_summary[spell]?.count || 0);
    agg.action_summary[spell] = {
      avg_cpm: round(average(values), 2),
      avg_count: round(average(countValues), 1),
    };
  }

  const uptimeNames = new Set(fights.flatMap((fight) => Object.keys(fight.uptimes || {})));
  for (const name of uptimeNames) {
    agg.uptimes[name] = round(average(fights.map((fight) => fight.uptimes[name] || 0)), 1);
  }

  for (const key of ['cpm', 'median_interval', 'p90_interval', 'max_interval', 'long_gap_pct']) {
    agg.auto_shot[key] = round(average(fights.map((fight) => fight.auto_shot[key] || 0)), 2);
  }

  for (const cd of hunter.cooldownNames) {
    const counts = fights.map((fight) => fight.cooldowns[cd]?.count || 0);
    const firsts = fights.map((fight) => fight.cooldowns[cd]?.first).filter((v) => v != null);
    agg.cooldowns[cd] = {
      avg_count: round(average(counts), 1),
      avg_first: firsts.length ? round(average(firsts), 1) : null,
    };
  }

  return agg;
}

function compareFight(yours, topAgg) {
  const notes = [];
  const spellRows = [];

  for (const spell of hunter.comparisonSpells) {
    const yoursCpm = yours.action_summary[spell]?.cpm || 0;
    const topCpm = topAgg.action_summary[spell]?.avg_cpm || 0;
    if (yoursCpm === 0 && topCpm === 0) continue;
    const delta = round(yoursCpm - topCpm, 2);
    spellRows.push({ spell, yoursCpm, topCpm, delta });

    if (topCpm > 0 && yoursCpm < topCpm * 0.9 && ['Auto Shot', 'Steady Shot', 'Aimed Shot', 'Multi-Shot', 'Kill Command'].includes(spell)) {
      const pct = Math.round((1 - yoursCpm / topCpm) * 100);
      notes.push(`${spell} usage is ${pct}% below the top sample (${yoursCpm}/min vs ${topCpm}/min).`);
    }
  }

  if (topAgg.auto_shot.cpm > 0 && yours.auto_shot.cpm < topAgg.auto_shot.cpm * 0.92) {
    notes.push(`Auto Shot throughput is low (${yours.auto_shot.cpm}/min vs ${topAgg.auto_shot.cpm}/min top avg). This is the clearest clipping/movement/not-shooting signal.`);
  }
  if (topAgg.auto_shot.long_gap_pct > 0 && yours.auto_shot.long_gap_pct > topAgg.auto_shot.long_gap_pct + 8) {
    notes.push(`Auto Shot long-gap rate is higher than top sample (${yours.auto_shot.long_gap_pct}% vs ${topAgg.auto_shot.long_gap_pct}%). Review movement and shot timing around those gaps.`);
  }

  for (const debuff of ["Hunter's Mark", 'Serpent Sting']) {
    const yoursUp = yours.uptimes[debuff] || 0;
    const topUp = topAgg.uptimes[debuff] || 0;
    if (topUp >= 40 && yoursUp < topUp - 15) {
      notes.push(`${debuff} uptime trails top sample (${yoursUp}% vs ${topUp}%). Treat Hunter's Mark as assignment-sensitive.`);
    }
  }

  for (const cd of ['Rapid Fire', 'Bestial Wrath', 'Readiness', 'Haste Potion']) {
    const yoursCount = yours.cooldowns[cd]?.count || 0;
    const topCount = topAgg.cooldowns[cd]?.avg_count || 0;
    if (topCount >= 0.8 && yoursCount + 0.5 < topCount) {
      notes.push(`${cd} use count is behind top sample (${yoursCount} vs ${topCount} avg).`);
    }
  }

  return { notes, spellRows };
}

function openerText(opener) {
  return opener.map((event) => `${event.time}s ${event.spell}`).join(' -> ');
}

function renderMarkdown({ reportCode, reportTitle, playerName, fights, specName }) {
  const lines = [];
  const generatedAt = new Date().toISOString();
  lines.push(`# Hunter WCL Review - ${playerName}${specName ? ` vs ${specName}` : ''}`);
  lines.push('');
  lines.push(`Report: ${reportCode}`);
  lines.push(`Title: ${reportTitle || 'Unknown'}`);
  lines.push(`Top sample: ${specName ? `${specName} Hunters` : 'All Hunters'}`);
  lines.push(`Generated: ${generatedAt}`);
  lines.push('');
  lines.push('## Executive Findings');
  const allNotes = fights.flatMap((fight) => fight.comparison?.notes || []);
  if (allNotes.length) {
    for (const note of [...new Set(allNotes)].slice(0, 12)) {
      lines.push(`- ${note}`);
    }
  } else {
    lines.push('- No top-sample comparison findings were generated. This can mean the run used --no-top or the fetched sample was unavailable.');
  }
  lines.push('');
  lines.push('## Boss Summary');
  lines.push('| Boss | Duration | Auto/min | Top Auto/min | Auto long gaps | Main notes |');
  lines.push('|---|---:|---:|---:|---:|---|');
  for (const fight of fights) {
    const topAuto = fight.topAggregate?.auto_shot?.cpm || 0;
    const notes = fight.comparison?.notes?.slice(0, 2).join(' ') || '';
    const durationText = fight.yours.meta.died_at_sec == null
      ? `${fight.yours.meta.duration_sec}s`
      : `${fight.yours.meta.duration_sec}s alive, died ${fight.yours.meta.died_at_sec}s`;
    lines.push(`| ${fight.yours.meta.boss} | ${durationText} | ${fight.yours.auto_shot.cpm} | ${topAuto || 'n/a'} | ${fight.yours.auto_shot.long_gap_pct}% | ${notes.replace(/\|/g, '/')} |`);
  }
  lines.push('');

  for (const fight of fights) {
    lines.push(`## ${fight.yours.meta.boss}`);
    lines.push('');
    lines.push(`Player: ${fight.yours.meta.player}`);
    lines.push(`Fight: ${fight.yours.meta.fight_duration_sec}s, ${fight.yours.meta.kill ? 'kill' : 'wipe'}`);
    if (fight.yours.meta.died_at_sec != null) {
      lines.push(`Death: ${fight.yours.meta.died_at_sec}s (${fight.yours.meta.death_pct}% of fight). Metrics below are normalized to time alive.`);
    }
    lines.push('');
    lines.push('### Shot CPM');
    lines.push('| Spell | Yours/min | Top avg/min | Delta |');
    lines.push('|---|---:|---:|---:|');
    for (const row of fight.comparison?.spellRows || []) {
      lines.push(`| ${row.spell} | ${row.yoursCpm} | ${row.topCpm || 'n/a'} | ${row.delta} |`);
    }
    lines.push('');
    lines.push('### Auto Shot Timing');
    lines.push(`- Yours: median ${fight.yours.auto_shot.median_interval}s, p90 ${fight.yours.auto_shot.p90_interval}s, max ${fight.yours.auto_shot.max_interval}s, long gaps ${fight.yours.auto_shot.long_gap_pct}%`);
    if (fight.topAggregate?.sample_count) {
      lines.push(`- Top sample (${fight.topAggregate.sample_count}): median ${fight.topAggregate.auto_shot.median_interval}s, p90 ${fight.topAggregate.auto_shot.p90_interval}s, long gaps ${fight.topAggregate.auto_shot.long_gap_pct}%`);
    }
    lines.push('');
    lines.push('### Uptimes');
    lines.push('| Aura/debuff | Yours | Top avg |');
    lines.push('|---|---:|---:|');
    const uptimeNames = new Set([
      ...Object.keys(fight.yours.uptimes || {}),
      ...Object.keys(fight.topAggregate?.uptimes || {}),
    ]);
    for (const name of [...uptimeNames].sort()) {
      lines.push(`| ${name} | ${fight.yours.uptimes[name] ?? 0}% | ${fight.topAggregate?.uptimes?.[name] ?? 'n/a'}% |`);
    }
    lines.push('');
    lines.push('### Cooldowns');
    lines.push('| Cooldown | Yours uses | First use | Top avg uses | Top avg first |');
    lines.push('|---|---:|---:|---:|---:|');
    for (const cd of hunter.cooldownNames) {
      const yoursCd = fight.yours.cooldowns[cd] || { count: 0, first: null };
      const topCd = fight.topAggregate?.cooldowns?.[cd] || { avg_count: 0, avg_first: null };
      if (!yoursCd.count && !topCd.avg_count) continue;
      lines.push(`| ${cd} | ${yoursCd.count} | ${yoursCd.first ?? 'n/a'} | ${topCd.avg_count || 'n/a'} | ${topCd.avg_first ?? 'n/a'} |`);
    }
    lines.push('');
    lines.push('### Opener');
    lines.push(openerText(fight.yours.opener) || 'No tracked opener events.');
    lines.push('');
    if (fight.comparison?.notes?.length) {
      lines.push('### Notes');
      for (const note of fight.comparison.notes) lines.push(`- ${note}`);
      lines.push('');
    }
  }

  lines.push('## Caveats');
  lines.push('- Auto Shot timing here is comparative from WCL damage timestamps. It flags long gaps and low throughput, but exact clip attribution still needs in-game clip tracker CSV.');
  lines.push('- Pet damage is not owner-attributed in this first pass; this review focuses on hunter casts, Auto Shot, debuffs, and cooldown timing.');
  lines.push('- Hunter\'s Mark is assignment-sensitive. Low uptime is only a bug if you were responsible for it.');
  lines.push('');

  return `${lines.join('\n')}\n`;
}

async function saveJson(relativePath, data) {
  const fullPath = path.join(config.dataDir, relativePath);
  await fs.mkdir(path.dirname(fullPath), { recursive: true });
  await fs.writeFile(fullPath, JSON.stringify(data, null, 2));
  return fullPath;
}

async function saveText(relativePath, text) {
  const fullPath = path.join(config.dataDir, relativePath);
  await fs.mkdir(path.dirname(fullPath), { recursive: true });
  await fs.writeFile(fullPath, text);
  return fullPath;
}

async function analyzeTopHunters(fight, ownReportCode, ownPlayer, topCount, specName = null) {
  const rankings = await fetchHunterRankings(fight.encounterID, topCount, specName);
  const processed = [];

  for (const entry of rankings.rankings) {
    if (processed.length >= topCount) break;
    if (!entry.reportCode || entry.fightID == null) continue;
    if (entry.reportCode === ownReportCode && entry.player.toLowerCase() === ownPlayer.toLowerCase()) continue;

    try {
      console.log(`  Top sample${specName ? ` (${specName})` : ''}: ${entry.player}-${entry.server} on ${rankings.encounterName}`);
      const report = await fetchReport(entry.reportCode);
      const topFight = report.fights.find((candidate) => candidate.id === entry.fightID);
      if (!topFight) continue;
      const actor = findPlayerActor(report, entry.player);
      const raw = await fetchHunterFight(entry.reportCode, topFight, actor, report.title);
      processed.push(processHunterFight(raw, entry));
    } catch (err) {
      console.warn(`    Skipping top sample ${entry.player}: ${err.message}`);
    }
  }

  return processed;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || args.h || !args.report) {
    usage();
    return;
  }

  const reportCode = extractReportCode(args.report);
  console.log(`Fetching report ${reportCode}...`);
  const report = await fetchReport(reportCode);
  const actor = findPlayerActor(report, args.player);
  const playerName = actor.name;

  const bossFights = report.fights
    .filter((fight) => fight.kill && fight.encounterID > 0)
    .slice(0, args.maxFights > 0 ? args.maxFights : undefined);

  if (!bossFights.length) throw new Error('No killed boss fights found in report.');

  const reviewFights = [];
  for (const fight of bossFights) {
    console.log(`\n=== ${fight.name} ===`);
    const raw = await fetchHunterFight(reportCode, fight, actor, report.title);
    const yours = processHunterFight(raw, { player: playerName, server: actor.server });
    const topAnalyses = args.noTop ? [] : await analyzeTopHunters(fight, reportCode, playerName, args.top, args.spec);
    const topAggregate = aggregateTop(topAnalyses);
    const comparison = compareFight(yours, topAggregate);

    reviewFights.push({ yours, topAnalyses, topAggregate, comparison });
    const specPart = args.spec ? `-${slugify(args.spec)}` : '';
    await saveJson(`hunter-review/${reportCode}-${slugify(playerName)}${specPart}-${slugify(fight.name)}.json`, {
      yours,
      topAnalyses,
      topAggregate,
      comparison,
    });
  }

  const markdown = renderMarkdown({
    reportCode,
    reportTitle: report.title,
    playerName,
    specName: args.spec,
    fights: reviewFights,
  });

  const specPart = args.spec ? `-${slugify(args.spec)}` : '';
  const mdPath = await saveText(`hunter-review/${reportCode}-${slugify(playerName)}${specPart}-review.md`, markdown);
  console.log(`\nSaved hunter review: ${path.relative(path.resolve(__dirname, '..'), mdPath)}`);
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
