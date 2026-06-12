import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Build a timeline of buff/debuff windows from apply/remove events.
 * @param {Array} events - Buff or debuff events
 * @param {object} tracked - Map of abilityGameID → { name }
 * @returns {Array} Windows: [{ abilityGameID, name, start, end }]
 */
export function buildBuffTimeline(events, tracked) {
  const active = {};  // abilityGameID → start timestamp
  const windows = [];

  for (const e of events) {
    const id = e.abilityGameID;
    if (!tracked[id]) continue;

    if (e.type === 'applybuff' || e.type === 'applydebuff' || e.type === 'refreshbuff' || e.type === 'refreshdebuff') {
      if (active[id] != null) {
        // Close previous window on refresh
        windows.push({ abilityGameID: id, name: tracked[id].name, start: active[id], end: e.timestamp });
      }
      active[id] = e.timestamp;
    } else if (e.type === 'removebuff' || e.type === 'removedebuff') {
      if (active[id] != null) {
        windows.push({ abilityGameID: id, name: tracked[id].name, start: active[id], end: e.timestamp });
        active[id] = null;
      }
    }
  }

  return windows;
}

/**
 * Given a timestamp, return which tracked buffs are active.
 */
export function sampleBuffsAtTime(buffWindows, timestamp) {
  return buffWindows
    .filter((w) => w.start <= timestamp && w.end > timestamp)
    .map((w) => w.name);
}

/**
 * Compute uptime percentages for each tracked buff/debuff.
 */
export function computeUptimes(windows, tracked, fightStart, fightEnd) {
  const duration = fightEnd - fightStart;
  if (duration <= 0) return {};

  const byName = {};
  for (const w of windows) {
    if (!byName[w.name]) byName[w.name] = 0;
    const overlap = Math.min(w.end, fightEnd) - Math.max(w.start, fightStart);
    if (overlap > 0) byName[w.name] += overlap;
  }

  const result = {};
  for (const [name, totalMs] of Object.entries(byName)) {
    result[name] = Math.round((totalMs / duration) * 1000) / 10;
  }
  return result;
}

/**
 * Compute spell A → spell B transition frequency matrix.
 */
export function computeTransitions(castSequence) {
  const transitions = {};
  for (let i = 0; i < castSequence.length - 1; i++) {
    const from = castSequence[i].spell;
    const to = castSequence[i + 1].spell;
    const key = `${from} -> ${to}`;
    transitions[key] = (transitions[key] || 0) + 1;
  }
  return transitions;
}

/**
 * Analyze DoT/debuff refresh patterns: how much time was remaining when re-applied.
 */
export function computeRefreshPatterns(debuffWindows, tracked) {
  const byAbility = {};
  for (const w of debuffWindows) {
    if (!byAbility[w.abilityGameID]) byAbility[w.abilityGameID] = [];
    byAbility[w.abilityGameID].push(w);
  }

  const patterns = {};
  for (const [id, wins] of Object.entries(byAbility)) {
    const info = tracked[id];
    if (!info) continue;

    const remainingOnRefresh = [];
    const dropDurations = [];

    for (let i = 0; i < wins.length - 1; i++) {
      const current = wins[i];
      const next = wins[i + 1];
      const gap = next.start - current.end;

      if (gap < 0) {
        // Refreshed before expiry — clip
        remainingOnRefresh.push(Math.abs(gap) / 1000);
      } else if (gap > 0.5 * 1000) {
        // Dropped (gap > 0.5s threshold)
        dropDurations.push(gap / 1000);
      } else {
        // Refreshed right at expiry
        remainingOnRefresh.push(0);
      }
    }

    const avg = remainingOnRefresh.length > 0
      ? remainingOnRefresh.reduce((a, b) => a + b, 0) / remainingOnRefresh.length
      : 0;

    patterns[info.name] = {
      avg_remaining_on_refresh: Math.round(avg * 100) / 100,
      min_remaining: remainingOnRefresh.length > 0 ? Math.round(Math.min(...remainingOnRefresh) * 100) / 100 : 0,
      max_remaining: remainingOnRefresh.length > 0 ? Math.round(Math.max(...remainingOnRefresh) * 100) / 100 : 0,
      clips: remainingOnRefresh.filter((r) => r > 0).length,
      drops: dropDurations.length,
      drop_durations: dropDurations.map((d) => Math.round(d * 100) / 100),
    };
  }

  return patterns;
}

/**
 * Main processor: transform raw WCL events into enriched fight JSON.
 * @param {object} rawData - Output from fetchFightEvents
 * @param {object} specConfig - Spec definition (e.g., bearDruid)
 * @param {object} rankingInfo - Optional: { player, server, dps, ilvl } from rankings
 * @returns {object} Enriched fight JSON matching design doc schema
 */
export async function processFight(rawData, specConfig, rankingInfo = {}) {
  const { meta, casts, buffs, debuffs, resources } = rawData;
  const fightStart = meta.startTime;
  const fightEnd = meta.endTime;
  const durationSec = meta.duration;

  // 1. Build buff/debuff timelines
  const buffWindows = buildBuffTimeline(buffs, specConfig.trackedBuffs);
  const debuffWindows = buildBuffTimeline(debuffs, specConfig.trackedDebuffs);

  // 2. Build cast sequence with enrichment
  const castSequence = [];
  const castCounts = {};

  for (const event of casts) {
    const spellId = event.abilityGameID;
    const spellInfo = specConfig.trackedSpells[spellId];
    if (!spellInfo) continue;

    const time = (event.timestamp - fightStart) / 1000;
    const spellName = spellInfo.name;

    castCounts[spellName] = (castCounts[spellName] || 0) + 1;

    const activeBuffs = sampleBuffsAtTime(buffWindows, event.timestamp);
    const activeDebuffs = sampleBuffsAtTime(debuffWindows, event.timestamp);

    castSequence.push({
      time: Math.round(time * 100) / 100,
      spell: spellName,
      spell_id: spellId,
      buffs_active: activeBuffs,
      target_debuffs: activeDebuffs,
      target_hp_pct: event.targetResources?.hitPoints ?? null,
    });
  }

  // 3. Cast summary (CPM)
  const castSummary = {};
  for (const [spell, count] of Object.entries(castCounts)) {
    castSummary[spell] = {
      count,
      cpm: Math.round((count / durationSec) * 60 * 10) / 10,
    };
  }

  // 4. Uptimes
  const buffUptimes = computeUptimes(buffWindows, specConfig.trackedBuffs, fightStart, fightEnd);
  const debuffUptimes = computeUptimes(debuffWindows, specConfig.trackedDebuffs, fightStart, fightEnd);
  const uptimes = { ...debuffUptimes, ...buffUptimes };

  // 5. Transitions
  const transitions = computeTransitions(castSequence);

  // 6. Refresh patterns
  const refreshPatterns = computeRefreshPatterns(debuffWindows, specConfig.trackedDebuffs);

  // 7. Idle analysis
  const idleWindows = [];
  let totalIdle = 0;
  for (let i = 0; i < castSequence.length - 1; i++) {
    const gap = castSequence[i + 1].time - castSequence[i].time;
    if (gap > specConfig.gcd * 1.5) {
      const idle = { start: castSequence[i].time, duration: Math.round(gap * 100) / 100 };
      idleWindows.push(idle);
      totalIdle += gap;
    }
  }

  const idleAnalysis = {
    total_idle_sec: Math.round(totalIdle * 100) / 100,
    idle_pct: Math.round((totalIdle / durationSec) * 1000) / 10,
    idle_windows: idleWindows,
  };

  // 8. Cooldown alignment
  const cooldownAlignment = {};
  for (const cdName of specConfig.cooldowns || []) {
    const cdCasts = castSequence.filter((c) => c.spell === cdName);
    const timestamps = cdCasts.map((c) => c.time);
    const duringBL = cdCasts.filter((c) =>
      c.buffs_active.some((b) => b === 'Bloodlust' || b === 'Heroism')
    ).length;
    const duringExecute = cdCasts.filter((c) =>
      c.target_hp_pct != null && c.target_hp_pct <= (specConfig.executeThreshold || 25)
    ).length;

    cooldownAlignment[cdName] = {
      timestamps,
      during_bloodlust: duringBL,
      during_execute_phase: duringExecute,
      on_pull: timestamps.length > 0 && timestamps[0] < 3,
    };
  }

  // 9. Assemble output
  const output = {
    meta: {
      player: rankingInfo.player || 'Unknown',
      server: rankingInfo.server || 'Unknown',
      class: specConfig.class,
      spec: specConfig.spec,
      boss: meta.fightName,
      encounter_id: meta.encounterID,
      duration_sec: Math.round(durationSec * 10) / 10,
      dps: rankingInfo.dps || 0,
      ilvl: rankingInfo.ilvl || null,
      report_code: meta.reportCode,
      fight_id: meta.fightID,
      fetched_at: new Date().toISOString(),
    },
    cast_summary: castSummary,
    uptimes,
    cast_sequence: castSequence,
    transitions,
    refresh_patterns: refreshPatterns,
    idle_analysis: idleAnalysis,
    cooldown_alignment: cooldownAlignment,
    resource_stats: {},
  };

  // Save to fights directory
  const dataDir = path.resolve(__dirname, '..', 'data');
  const fightsDir = path.join(dataDir, 'fights');
  await fs.mkdir(fightsDir, { recursive: true });
  const slug = `${meta.fightName || 'unknown'}-${output.meta.player}-${specConfig.spec}`.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const filename = `${slug}.json`;
  await fs.writeFile(path.join(fightsDir, filename), JSON.stringify(output, null, 2));
  console.log(`  Saved: data/fights/${filename}`);

  return output;
}
