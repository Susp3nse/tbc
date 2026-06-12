import assert from 'node:assert/strict';
import { buildBuffTimeline, sampleBuffsAtTime, computeUptimes, computeTransitions, computeRefreshPatterns } from '../src/process-fight.js';

// Test buff timeline building
{
  const events = [
    { timestamp: 1000, type: 'applybuff', abilityGameID: 100 },
    { timestamp: 5000, type: 'removebuff', abilityGameID: 100 },
    { timestamp: 8000, type: 'applybuff', abilityGameID: 100 },
    { timestamp: 12000, type: 'removebuff', abilityGameID: 100 },
  ];
  const timeline = buildBuffTimeline(events, { 100: { name: 'TestBuff' } });
  assert.equal(timeline.length, 2, 'Should have 2 buff windows');
  assert.equal(timeline[0].start, 1000);
  assert.equal(timeline[0].end, 5000);
  assert.equal(timeline[1].start, 8000);
  console.log('PASS: buildBuffTimeline');
}

// Test uptime computation
{
  const windows = [
    { abilityGameID: 100, name: 'TestBuff', start: 0, end: 5000 },
    { abilityGameID: 100, name: 'TestBuff', start: 8000, end: 10000 },
  ];
  const uptime = computeUptimes(windows, { 100: { name: 'TestBuff' } }, 0, 10000);
  assert.equal(uptime['TestBuff'], 70, 'Uptime should be 70%');
  console.log('PASS: computeUptimes');
}

// Test transition matrix
{
  const casts = [
    { spell: 'Mangle' },
    { spell: 'Swipe' },
    { spell: 'Swipe' },
    { spell: 'Lacerate' },
  ];
  const transitions = computeTransitions(casts);
  assert.equal(transitions['Mangle -> Swipe'], 1);
  assert.equal(transitions['Swipe -> Swipe'], 1);
  assert.equal(transitions['Swipe -> Lacerate'], 1);
  console.log('PASS: computeTransitions');
}

// Test refresh pattern detection
{
  const debuffWindows = [
    { abilityGameID: 200, start: 0, end: 12000 },
    { abilityGameID: 200, start: 10800, end: 22800 },  // refreshed at 1.2s remaining
  ];
  const patterns = computeRefreshPatterns(debuffWindows, { 200: { name: 'Lacerate', duration: 12 } });
  assert.equal(patterns['Lacerate'].clips, 1, 'Should detect 1 clip');
  assert.ok(Math.abs(patterns['Lacerate'].avg_remaining_on_refresh - 1.2) < 0.01, 'Avg remaining should be ~1.2s');
  console.log('PASS: computeRefreshPatterns');
}

console.log('\nAll process-fight tests passed.');
