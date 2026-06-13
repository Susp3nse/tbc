import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Compare a top parser's fight against yours.
 * @param {object} baseline - Top parser's processed fight JSON
 * @param {object} yours - Your processed fight JSON
 * @returns {object} Comparison report
 */
export function compareFights(baseline, yours) {
  const insights = [];

  // DPS gap
  const dpsGap = {
    yours: yours.meta.dps,
    top: baseline.meta.dps,
    delta: yours.meta.dps - baseline.meta.dps,
    pct_of_top: baseline.meta.dps > 0
      ? Math.round((yours.meta.dps / baseline.meta.dps) * 1000) / 10
      : 0,
  };

  // Cast CPM diffs
  const allSpells = new Set([
    ...Object.keys(baseline.cast_summary || {}),
    ...Object.keys(yours.cast_summary || {}),
  ]);
  const castDiffs = {};
  for (const spell of allSpells) {
    const topCpm = baseline.cast_summary?.[spell]?.cpm || 0;
    const yourCpm = yours.cast_summary?.[spell]?.cpm || 0;
    const delta = Math.round((yourCpm - topCpm) * 10) / 10;
    castDiffs[spell] = { yours_cpm: yourCpm, top_cpm: topCpm, delta };

    if (topCpm > 0 && Math.abs(delta) / topCpm > 0.2) {
      const pctDiff = Math.round((delta / topCpm) * 100);
      if (delta < 0) {
        insights.push(`${spell} CPM ${Math.abs(pctDiff)}% lower (${yourCpm} vs ${topCpm}) — under-using this ability`);
      } else {
        insights.push(`${spell} CPM ${pctDiff}% higher (${yourCpm} vs ${topCpm}) — possibly over-using this ability`);
      }
    }
  }

  // Uptime diffs
  const allUptimes = new Set([
    ...Object.keys(baseline.uptimes || {}),
    ...Object.keys(yours.uptimes || {}),
  ]);
  const uptimeDiffs = {};
  for (const name of allUptimes) {
    const topUp = baseline.uptimes?.[name] || 0;
    const yourUp = yours.uptimes?.[name] || 0;
    const delta = Math.round((yourUp - topUp) * 10) / 10;
    uptimeDiffs[name] = { yours: yourUp, top: topUp, delta };

    if (Math.abs(delta) > 5) {
      insights.push(`${name} uptime ${delta > 0 ? '+' : ''}${delta}% (${yourUp}% vs ${topUp}%)`);
    }
  }

  // Transition diffs
  const transitionNotes = [];
  const allTransitions = new Set([
    ...Object.keys(baseline.transitions || {}),
    ...Object.keys(yours.transitions || {}),
  ]);
  for (const key of allTransitions) {
    const topCount = baseline.transitions?.[key] || 0;
    const yourCount = yours.transitions?.[key] || 0;
    if (Math.abs(yourCount - topCount) >= 3) {
      transitionNotes.push(`${key}: you ${yourCount}x vs top ${topCount}x`);
    }
  }

  // Refresh pattern diffs
  const refreshDiffs = {};
  const allRefreshKeys = new Set([
    ...Object.keys(baseline.refresh_patterns || {}),
    ...Object.keys(yours.refresh_patterns || {}),
  ]);
  for (const name of allRefreshKeys) {
    const topRefresh = baseline.refresh_patterns?.[name];
    const yourRefresh = yours.refresh_patterns?.[name];
    if (topRefresh && yourRefresh) {
      const topAvg = topRefresh.avg_remaining_on_refresh;
      const yourAvg = yourRefresh.avg_remaining_on_refresh;
      const diff = Math.round((yourAvg - topAvg) * 100) / 100;
      refreshDiffs[name] = {
        yours_avg_remaining: yourAvg,
        top_avg_remaining: topAvg,
      };
      if (Math.abs(diff) > 0.5) {
        if (diff > 0) {
          refreshDiffs[name].insight = `Refreshing ${name} ${diff.toFixed(1)}s too early — wasting resources on overlapping ticks`;
        } else {
          refreshDiffs[name].insight = `Refreshing ${name} ${Math.abs(diff).toFixed(1)}s later than top — risk of dropping`;
        }
        insights.push(refreshDiffs[name].insight);
      }
    }
  }

  return {
    meta: {
      boss: baseline.meta.boss,
      baseline: { player: baseline.meta.player, dps: baseline.meta.dps, duration: baseline.meta.duration_sec },
      yours: { player: yours.meta.player, dps: yours.meta.dps, duration: yours.meta.duration_sec },
    },
    dps_gap: dpsGap,
    cast_diffs: castDiffs,
    uptime_diffs: uptimeDiffs,
    transition_diffs: { notable: transitionNotes },
    refresh_diffs: refreshDiffs,
    actionable_insights: insights,
  };
}

/**
 * Load two fight JSONs and compare them. Save output.
 */
export async function compareFromFiles(baselinePath, yoursPath) {
  const baseline = JSON.parse(await fs.readFile(baselinePath, 'utf-8'));
  const yours = JSON.parse(await fs.readFile(yoursPath, 'utf-8'));

  const result = compareFights(baseline, yours);

  // Save comparison
  const dataDir = path.resolve(__dirname, '..', 'data');
  const compDir = path.join(dataDir, 'comparisons');
  await fs.mkdir(compDir, { recursive: true });
  const slug = `${result.meta.boss || 'unknown'}-comparison`.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const filename = `${slug}.json`;
  await fs.writeFile(path.join(compDir, filename), JSON.stringify(result, null, 2));

  // Print summary
  console.log(`\n${'='.repeat(60)}`);
  console.log(`COMPARISON: ${result.meta.yours.player} vs ${result.meta.baseline.player}`);
  console.log(`Boss: ${result.meta.boss}`);
  console.log(`DPS: ${result.dps_gap.yours} vs ${result.dps_gap.top} (${result.dps_gap.pct_of_top}% of top)`);
  console.log(`${'='.repeat(60)}\n`);

  if (result.actionable_insights.length > 0) {
    console.log('Actionable Insights:');
    for (const insight of result.actionable_insights) {
      console.log(`  - ${insight}`);
    }
  }

  console.log(`\nSaved: data/comparisons/${filename}`);
  return result;
}
