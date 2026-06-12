import assert from 'node:assert/strict';
import { compareFights } from '../src/compare.js';

const top = {
  meta: { player: 'Top', boss: 'Gruul', dps: 1800, duration_sec: 140 },
  cast_summary: { Swipe: { count: 42, cpm: 18 }, Lacerate: { count: 8, cpm: 3.4 } },
  uptimes: { Lacerate: 94 },
  transitions: { 'Swipe -> Lacerate': 6 },
  refresh_patterns: { Lacerate: { avg_remaining_on_refresh: 1.2, clips: 0, drops: 1 } },
};

const yours = {
  meta: { player: 'You', boss: 'Gruul', dps: 1200, duration_sec: 150 },
  cast_summary: { Swipe: { count: 28, cpm: 11.2 }, Lacerate: { count: 6, cpm: 2.4 } },
  uptimes: { Lacerate: 78 },
  transitions: { 'Swipe -> Lacerate': 3 },
  refresh_patterns: { Lacerate: { avg_remaining_on_refresh: 3.8, clips: 2, drops: 3 } },
};

const result = compareFights(top, yours);

assert.equal(result.dps_gap.delta, -600);
assert.equal(result.uptime_diffs.Lacerate.delta, -16);
assert.ok(result.actionable_insights.length > 0, 'Should generate insights');
console.log('PASS: compareFights');
console.log('Insights:', result.actionable_insights);
