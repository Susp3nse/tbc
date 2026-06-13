// Top-hunter clip calibration.
//
// Pulls the server's top Hunter parses for a set of bosses, measures each
// hunter's Auto Shot clipping bucketed by ranged-speed (the same buckets
// adaptive.lua's clipBudgetForSpeed uses), and aggregates. Used to calibrate
// the CLIP_BUDGETS caps against how elite hunters actually play at high haste.
//
// Clip is derived from begincast->cast windup (windup = 0.5/hasteMult, immune
// to latency since timestamps are server-side): per-hunter base weapon speed is
// estimated from the 10th-percentile of interval*hasteMult, then expected swing
// = base/hasteMult and clip = max(0, actualInterval - expected).
//
// Usage:
//   node src/top-hunter-clips.js [--spec BeastMastery] [--max 14] [--report <code>]
//   --report supplies a reference report whose kill fights' encounterIDs are
//   used for the rankings queries (defaults to the known SSC clear).

import { graphql } from './api.js';

const argv = process.argv.slice(2);
const getArg = (flag, def) => {
  const i = argv.indexOf(flag);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : def;
};
const SPEC = getArg('--spec', 'BeastMastery');
const MAX_HUNTERS = parseInt(getArg('--max', '14'), 10);
const REF_REPORT = getArg('--report', 'zYJPGyHZbhV6WTMK');
const PER_BOSS = 6; // top parses to consider per boss before dedupe
const AUTO = 75;

function bucketFor(s) {
  if (!s || s <= 0) return 'BASE';
  if (s >= 2.35) return 'BASE';
  if (s >= 2.0) return 'LIGHT';
  if (s >= 1.7) return 'MAJOR';
  if (s >= 1.4) return 'DOUBLE';
  if (s >= 1.15) return 'PEAK';
  return 'ULTRA';
}
const ORDER = ['BASE', 'LIGHT', 'MAJOR', 'DOUBLE', 'PEAK', 'ULTRA'];
const pctl = (a, p) => {
  if (!a.length) return 0;
  const s = [...a].sort((x, y) => x - y);
  return s[Math.min(s.length - 1, Math.floor(s.length * p))];
};
const mean = (a) => (a.length ? a.reduce((x, y) => x + y, 0) / a.length : 0);

async function discoverEncounters(reportCode) {
  const meta = await graphql(`query { reportData { report(code: "${reportCode}") {
    fights { name encounterID kill }
  } } }`);
  const seen = new Map();
  for (const f of meta.reportData.report.fights) {
    if (f.kill && f.encounterID > 0 && !seen.has(f.encounterID)) seen.set(f.encounterID, f.name);
  }
  return [...seen.entries()];
}

async function collectTopHunters(encounters) {
  const picks = new Map();
  for (const [encId, boss] of encounters) {
    if (picks.size >= MAX_HUNTERS) break;
    const data = await graphql(`query { worldData { encounter(id: ${encId}) {
      characterRankings(className: "Hunter" specName: "${SPEC}" metric: dps page: 1)
    } } }`);
    const cr = data.worldData?.encounter?.characterRankings;
    if (!cr) continue;
    const parsed = typeof cr === 'string' ? JSON.parse(cr) : cr;
    for (const x of (parsed.rankings || []).slice(0, PER_BOSS)) {
      if (picks.size >= MAX_HUNTERS) break;
      if (!picks.has(x.name) && x.report?.code) {
        picks.set(x.name, {
          report: x.report.code,
          fightID: x.report.fightID,
          name: x.name,
          boss,
          dps: Math.round(x.amount),
        });
      }
    }
  }
  return [...picks.values()];
}

async function clipSamplesFor(p) {
  const meta = await graphql(`query { reportData { report(code: "${p.report}") {
    fights(fightIDs: [${p.fightID}]) { startTime endTime }
    masterData { actors(type: "Player") { id name subType } }
  } } }`);
  const f = meta.reportData.report.fights[0];
  const actor = meta.reportData.report.masterData.actors.find(
    (a) => a.name === p.name && a.subType === 'Hunter',
  );
  if (!f || !actor) return null;
  const evs =
    (
      await graphql(`query { reportData { report(code: "${p.report}") {
    events(fightIDs: [${p.fightID}], dataType: Casts, sourceID: ${actor.id}, startTime: ${f.startTime}, endTime: ${f.endTime}, limit: 20000) { data }
  } } }`)
    ).reportData.report.events.data || [];
  const auto = evs
    .filter((e) => e.abilityGameID === AUTO)
    .sort((a, b) => a.timestamp - b.timestamp);
  const samples: Array<{ windup: number; itv: number }> = [];
  let lastCast = null;
  for (let i = 0; i < auto.length - 1; i++) {
    if (auto[i].type === 'begincast' && auto[i + 1].type === 'cast') {
      const windup = (auto[i + 1].timestamp - auto[i].timestamp) / 1000;
      if (windup > 0.1 && windup < 1.5) {
        const t = auto[i + 1].timestamp;
        if (lastCast != null) {
          const itv = (t - lastCast) / 1000;
          if (itv > 0.3 && itv < 8) samples.push({ windup, itv });
        }
        lastCast = t;
      }
    }
  }
  return samples;
}

async function main() {
  const encounters = await discoverEncounters(REF_REPORT);
  console.log(`Bosses: ${encounters.map((e) => e[1]).join(', ')}`);
  const hunters = await collectTopHunters(encounters);
  console.log(`Collected ${hunters.length} distinct top ${SPEC} hunters\n`);

  const global: Record<string, number[]> = {};
  for (const b of ORDER) global[b] = [];
  for (const p of hunters) {
    try {
      const samples = await clipSamplesFor(p);
      if (!samples || samples.length < 10) {
        console.log(`  skip ${p.name} (${samples ? samples.length : 0} samples)`);
        continue;
      }
      const base = pctl(
        samples.map((s) => s.itv * (0.5 / s.windup)),
        0.1,
      );
      const counts: Record<string, number> = {};
      for (const b of ORDER) counts[b] = 0;
      for (const s of samples) {
        const expected = base / (0.5 / s.windup);
        const clip = Math.max(0, s.itv - expected);
        const bk = bucketFor(expected);
        global[bk].push(clip);
        counts[bk]++;
      }
      console.log(
        `  ${p.name.padEnd(22)} base~${base.toFixed(2)}  ${samples.length} autos  [${ORDER.map(
          (b) => (counts[b] ? `${b}:${counts[b]}` : ''),
        )
          .filter(Boolean)
          .join(' ')}]`,
      );
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      console.log(`  err ${p.name}: ${message.slice(0, 60)}`);
    }
  }

  console.log(`\n================= TOP ${SPEC} HUNTERS — clip per haste bucket =================`);
  console.log('bucket   nAutos  %clipped>0.10  meanClip  p50    p90    p99');
  for (const b of ORDER) {
    const a = global[b];
    if (!a.length) continue;
    const clipped = a.filter((c) => c > 0.1).length;
    console.log(
      `${b.padEnd(8)} ${String(a.length).padStart(5)}   ${((100 * clipped) / a.length).toFixed(0).padStart(3)}%          ${mean(a).toFixed(3)}    ${pctl(a, 0.5).toFixed(3)}  ${pctl(a, 0.9).toFixed(3)}  ${pctl(a, 0.99).toFixed(3)}`,
    );
  }
}
main().catch((e) => {
  console.error(e);
  process.exit(1);
});
