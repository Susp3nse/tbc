# WCL Log Analyzer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a CLI tool that fetches top parser combat logs from Warcraft Logs and produces structured JSON for rotation analysis and comparison.

**Architecture:** Node.js CLI in a new `log-analyzer/` workspace. OAuth client credentials for WCL API v2 (GraphQL). Raw events processed into enriched fight JSONs. Spec-specific config objects define which spells/resources to track. Comparison mode diffs two fights.

**Tech Stack:** Node.js 18+ (native fetch), ESM modules, dotenv, no test framework (manual validation via real API calls for network layer, Node assert for pure functions)

**Design doc:** `docs/plans/2026-02-25-log-analyzer-design.md`

---

## Task Summary

| # | Task | What it does |
|---|------|-------------|
| 1 | Scaffold workspace | package.json, directory structure, npm workspace registration |
| 2 | Auth module | OAuth client credentials flow with token caching |
| 3 | API module | GraphQL POST client with pagination and rate limiting |
| 4 | Queries module | All GraphQL query strings |
| 5 | Discover command | List TBC zones/encounters from API |
| 6 | Fetch rankings | Pull top N parses for a boss+class+spec |
| 7 | Fetch events | Pull cast/buff/debuff events for a fight |
| 8 | Spec config | Cat Druid spell definitions, resource tracking rules |
| 9 | Process fight | Transform raw events → enriched fight JSON (TDD) |
| 10 | Compare | Diff two fight JSONs → comparison report (TDD) |
| 11 | CLI entry point | Arg parsing, command dispatch, wire everything together |

---

## Task 1: Scaffold workspace

**Files:**
- Create: `log-analyzer/package.json`
- Create: `log-analyzer/src/` (empty directory marker)
- Create: `log-analyzer/data/.gitkeep`
- Modify: `package.json` (root — add workspace)
- Modify: `.gitignore` (add data directory)

**Step 1: Create package.json**

```json
{
  "name": "@menagerie/log-analyzer",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=18.0.0"
  },
  "dependencies": {
    "dotenv": "^16.4.0"
  }
}
```

**Step 2: Create directory structure**

```bash
mkdir -p log-analyzer/src log-analyzer/data/raw log-analyzer/data/fights log-analyzer/data/comparisons
touch log-analyzer/data/.gitkeep
```

**Step 3: Register workspace in root package.json**

Add `"log-analyzer"` to the `workspaces` array:

```json
{
  "name": "gg-rotations",
  "private": true,
  "workspaces": ["rotation", "website", "discord-bot", "log-analyzer"]
}
```

**Step 4: Add data directory to .gitignore**

Append to `.gitignore`:

```
# Log analyzer output data
log-analyzer/data/raw/
log-analyzer/data/fights/
log-analyzer/data/comparisons/
```

**Step 5: Install dependencies**

```bash
npm install -w log-analyzer
```

**Step 6: Commit**

```bash
git add log-analyzer/package.json log-analyzer/data/.gitkeep package.json .gitignore
git commit -m "chore: scaffold log-analyzer workspace"
```

---

## Task 2: Auth module

**Files:**
- Create: `log-analyzer/src/config.js`
- Create: `log-analyzer/src/auth.js`

**Step 1: Create config module**

`log-analyzer/src/config.js` — loads env vars from root `.env`:

```js
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

dotenv.config({ path: path.resolve(__dirname, '..', '..', '.env') });

const required = ['WCL_CLIENT_ID', 'WCL_CLIENT_SECRET'];
for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}. Check root .env file.`);
  }
}

export const config = {
  wcl: {
    clientId: process.env.WCL_CLIENT_ID,
    clientSecret: process.env.WCL_CLIENT_SECRET,
    tokenUrl: 'https://www.warcraftlogs.com/oauth/token',
    apiUrl: 'https://www.warcraftlogs.com/api/v2/client',
  },
  dataDir: path.resolve(__dirname, '..', 'data'),
  requestDelayMs: 500,
};
```

**Step 2: Create auth module**

`log-analyzer/src/auth.js` — OAuth client credentials with in-memory caching:

```js
import { config } from './config.js';

let cachedToken = null;
let tokenExpiry = 0;

export async function getToken() {
  const now = Date.now();
  if (cachedToken && now < tokenExpiry) {
    return cachedToken;
  }

  const params = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: config.wcl.clientId,
    client_secret: config.wcl.clientSecret,
  });

  const res = await fetch(config.wcl.tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`WCL auth failed (${res.status}): ${text}`);
  }

  const data = await res.json();
  cachedToken = data.access_token;
  // Expire 60s early to avoid edge cases
  tokenExpiry = now + (data.expires_in - 60) * 1000;

  return cachedToken;
}
```

**Step 3: Verify auth works**

Create a quick smoke test (delete after):

```bash
cd log-analyzer && node -e "
import { getToken } from './src/auth.js';
const token = await getToken();
console.log('Token received:', token.substring(0, 20) + '...');
console.log('Length:', token.length);
"
```

Expected: prints a truncated token string. If it fails, check `.env` credentials.

**Step 4: Commit**

```bash
git add log-analyzer/src/config.js log-analyzer/src/auth.js
git commit -m "feat(log-analyzer): add OAuth auth with token caching"
```

---

## Task 3: API module

**Files:**
- Create: `log-analyzer/src/api.js`

**Step 1: Create GraphQL client with pagination**

`log-analyzer/src/api.js`:

```js
import { config } from './config.js';
import { getToken } from './auth.js';

const delay = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Execute a GraphQL query against WCL API v2.
 * @param {string} query - GraphQL query string
 * @param {object} variables - Query variables (optional)
 * @returns {object} The `data` field from the response
 */
export async function graphql(query, variables = {}) {
  const token = await getToken();

  const res = await fetch(config.wcl.apiUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query, variables }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`WCL API error (${res.status}): ${text}`);
  }

  const json = await res.json();
  if (json.errors) {
    throw new Error(`WCL GraphQL errors: ${JSON.stringify(json.errors)}`);
  }

  return json.data;
}

/**
 * Fetch paginated events from a report fight.
 * Follows nextPageTimestamp until all events are collected.
 * @param {string} reportCode
 * @param {number} fightID
 * @param {string} dataType - "Casts", "Buffs", "Debuffs", etc.
 * @param {number} startTime - Fight start time (ms)
 * @param {number} endTime - Fight end time (ms)
 * @param {object} opts - Optional: { sourceID, limit }
 * @returns {Array} All events
 */
export async function fetchAllEvents(reportCode, fightID, dataType, startTime, endTime, opts = {}) {
  const allEvents = [];
  let cursor = startTime;
  const limit = opts.limit || 10000;
  const sourceID = opts.sourceID;

  while (cursor !== null && cursor < endTime) {
    const sourceFilter = sourceID != null ? `sourceID: ${sourceID},` : '';
    const query = `
      query {
        reportData {
          report(code: "${reportCode}") {
            events(
              fightIDs: [${fightID}],
              dataType: ${dataType},
              startTime: ${cursor},
              endTime: ${endTime},
              limit: ${limit},
              ${sourceFilter}
            ) {
              data
              nextPageTimestamp
            }
          }
        }
      }
    `;

    const data = await graphql(query);
    const events = data.reportData.report.events;

    if (events.data && events.data.length > 0) {
      allEvents.push(...events.data);
    }

    cursor = events.nextPageTimestamp;

    if (cursor !== null) {
      await delay(config.requestDelayMs);
    }
  }

  return allEvents;
}
```

**Step 2: Commit**

```bash
git add log-analyzer/src/api.js
git commit -m "feat(log-analyzer): add GraphQL client with pagination"
```

---

## Task 4: Queries module

**Files:**
- Create: `log-analyzer/src/queries.js`

**Step 1: Create all GraphQL query strings**

`log-analyzer/src/queries.js`:

```js
/**
 * Discover zones and encounters for an expansion.
 * WCL expansion IDs: 1=Classic, 2=TBC, 3=WotLK
 */
export function discoverZonesQuery(expansionId) {
  return `
    query {
      worldData {
        expansion(id: ${expansionId}) {
          name
          zones {
            id
            name
            encounters {
              id
              name
            }
          }
        }
      }
    }
  `;
}

/**
 * Fetch top character rankings for an encounter.
 * className: "Druid", "Warrior", etc.
 * specName: "Feral", "Arms", etc.
 * metric: "dps" or "hps"
 */
export function rankingsQuery(encounterID, className, specName, metric = 'dps', page = 1) {
  return `
    query {
      worldData {
        encounter(id: ${encounterID}) {
          name
          characterRankings(
            className: "${className}"
            specName: "${specName}"
            metric: ${metric}
            page: ${page}
          )
        }
      }
    }
  `;
}

/**
 * Fetch report metadata including fights list.
 */
export function reportFightsQuery(reportCode) {
  return `
    query {
      reportData {
        report(code: "${reportCode}") {
          code
          title
          startTime
          endTime
          fights {
            id
            name
            encounterID
            startTime
            endTime
            kill
            difficulty
            fightPercentage
            bossPercentage
            friendlyPlayers
          }
          masterData {
            actors(type: "Player") {
              id
              name
              type
              subType
              server
            }
          }
        }
      }
    }
  `;
}
```

**Step 2: Commit**

```bash
git add log-analyzer/src/queries.js
git commit -m "feat(log-analyzer): add GraphQL query strings"
```

---

## Task 5: Discover command

**Files:**
- Create: `log-analyzer/src/discover.js`

**Step 1: Implement discover**

`log-analyzer/src/discover.js`:

```js
import { graphql } from './api.js';
import { discoverZonesQuery } from './queries.js';

// WCL expansion IDs
const EXPANSION_IDS = {
  classic: 1,
  tbc: 2,
  wotlk: 3,
};

export async function discover(expansionName) {
  const expId = EXPANSION_IDS[expansionName.toLowerCase()];
  if (!expId) {
    throw new Error(`Unknown expansion: "${expansionName}". Valid: ${Object.keys(EXPANSION_IDS).join(', ')}`);
  }

  const data = await graphql(discoverZonesQuery(expId));
  const expansion = data.worldData.expansion;

  if (!expansion) {
    throw new Error(`No data returned for expansion ID ${expId}`);
  }

  console.log(`\n${expansion.name}\n${'='.repeat(expansion.name.length)}\n`);

  for (const zone of expansion.zones || []) {
    console.log(`  ${zone.name} (zone ${zone.id})`);
    for (const enc of zone.encounters || []) {
      console.log(`    - ${enc.name} (encounter ${enc.id})`);
    }
  }

  return expansion;
}
```

**Step 2: Verify with real API call**

```bash
cd log-analyzer && node -e "
import { discover } from './src/discover.js';
await discover('tbc');
"
```

Expected: prints TBC zones (Karazhan, Gruul, SSC/TK, BT/Hyjal, Sunwell) with encounter IDs. **Save this output** — we'll use the encounter IDs in later tasks.

**Step 3: Commit**

```bash
git add log-analyzer/src/discover.js
git commit -m "feat(log-analyzer): add discover command for zones/encounters"
```

---

## Task 6: Fetch rankings

**Files:**
- Create: `log-analyzer/src/fetch-rankings.js`

**Step 1: Implement rankings fetcher**

`log-analyzer/src/fetch-rankings.js`:

```js
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
```

**Note:** The exact shape of `characterRankings` may differ from what's assumed here. WCL returns it as a JSON scalar type. The code handles both string and object forms. On first real run, log the raw response to `data/raw/` to see the actual structure and adjust if needed.

**Step 2: Verify with real API call**

Pick an encounter ID from the discover output (Task 5) and run:

```bash
cd log-analyzer && node -e "
import { fetchRankings } from './src/fetch-rankings.js';
const result = await fetchRankings(649, 'Druid', 'Feral', 3);
console.log(JSON.stringify(result, null, 2));
"
```

Note: encounter ID 649 is a guess for Gruul — use the real ID from discover output. If the response shape doesn't match, adjust the parsing in `fetchRankings`.

**Step 3: Commit**

```bash
git add log-analyzer/src/fetch-rankings.js
git commit -m "feat(log-analyzer): add rankings fetcher for top parses"
```

---

## Task 7: Fetch events

**Files:**
- Create: `log-analyzer/src/fetch-events.js`

**Step 1: Implement event fetcher**

`log-analyzer/src/fetch-events.js`:

```js
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
 * @returns {object} { meta, fights, actors, casts, buffs, debuffs }
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
```

**Step 2: Verify with real API call**

Use a reportCode and fightID from the rankings output (Task 6):

```bash
cd log-analyzer && node -e "
import { fetchFightEvents } from './src/fetch-events.js';
const result = await fetchFightEvents('REPORT_CODE', FIGHT_ID, { playerName: 'PLAYER_NAME' });
console.log('Cast event sample:', JSON.stringify(result.casts[0], null, 2));
console.log('Buff event sample:', JSON.stringify(result.buffs[0], null, 2));
console.log('Resource event sample:', JSON.stringify(result.resources[0], null, 2));
"
```

**CRITICAL:** Examine the raw event shapes. Each event will have fields like `timestamp`, `type`, `sourceID`, `targetID`, `abilityGameID`, `resourceChange`, etc. The exact field names determine how `process-fight.js` works. Save the sample output and reference it when building Task 9.

**Step 3: Commit**

```bash
git add log-analyzer/src/fetch-events.js
git commit -m "feat(log-analyzer): add fight event fetcher with raw data saving"
```

---

## Task 8: Spec config (Cat Druid)

**Files:**
- Create: `log-analyzer/src/specs/cat-druid.js`

**Step 1: Define cat druid spell and resource config**

`log-analyzer/src/specs/cat-druid.js`:

This file defines what the processor needs to know about cat druid. Spell IDs referenced from `docs/DRUID_RESEARCH.md` and `rotation/source/aio/druid/cat.lua`.

```js
/**
 * Cat Druid spec configuration for fight processing.
 * Defines which spells to track, resource types, DoT durations, cooldowns.
 */
export const catDruid = {
  name: 'Cat Druid',
  class: 'Druid',
  spec: 'Feral',
  resource: 'energy',

  // Spells to track in cast_summary and cast_sequence
  trackedSpells: {
    // Builders
    33876: { name: 'Mangle (Cat)', category: 'builder', generates_cp: true },
    27002: { name: 'Shred', category: 'builder', generates_cp: true },
    27003: { name: 'Rake', category: 'dot', generates_cp: true, base_duration: 9 },
    // Finishers
    27008: { name: 'Rip', category: 'finisher_dot', base_duration: 12 },
    27005: { name: 'Ferocious Bite', category: 'finisher' },
    // Cooldowns
    9846:  { name: "Tiger's Fury", category: 'cooldown', cooldown: 30 },
    // Utility
    9634:  { name: 'Prowl', category: 'utility' },
    // Powershifting
    768:   { name: 'Cat Form', category: 'form' },
  },

  // Debuffs to track for uptime analysis (on target)
  trackedDebuffs: {
    33876: { name: 'Mangle (Cat)', duration: 12 },
    27008: { name: 'Rip', duration: 12 },
    27003: { name: 'Rake', duration: 9 },
  },

  // Buffs to track (on player)
  trackedBuffs: {
    9846:  { name: "Tiger's Fury", duration: 6 },
    16870: { name: 'Clearcasting', duration: 15 },
    // External buffs of interest
    2825:  { name: 'Bloodlust', duration: 40 },
    32182: { name: 'Heroism', duration: 40 },
  },

  // Cooldowns to analyze alignment for
  cooldowns: ['Tiger\'s Fury'],

  // Bloodlust buff IDs (for burst alignment)
  bloodlustBuffs: [2825, 32182],

  // Execute phase threshold (% HP)
  executeThreshold: 25,

  // GCD for this spec (seconds)
  gcd: 1.0,
};
```

**Note:** Spell IDs may need adjustment based on actual WCL event data. WCL uses `abilityGameID` which corresponds to WoW spell IDs. Cross-reference with the raw event data from Task 7. Some spells have multiple rank IDs — WCL typically reports the highest rank used.

**Step 2: Commit**

```bash
git add log-analyzer/src/specs/cat-druid.js
git commit -m "feat(log-analyzer): add cat druid spec config"
```

---

## Task 9: Process fight (enriched JSON)

**Files:**
- Create: `log-analyzer/src/process-fight.js`
- Create: `log-analyzer/test/process-fight.test.js`

This is the most complex task. It transforms raw WCL events into the enriched fight JSON from the design doc. Pure function — testable.

**Step 1: Write tests for key processing functions**

`log-analyzer/test/process-fight.test.js`:

```js
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
    { abilityGameID: 100, start: 0, end: 5000 },
    { abilityGameID: 100, start: 8000, end: 10000 },
  ];
  const uptime = computeUptimes(windows, { 100: { name: 'TestBuff' } }, 0, 10000);
  assert.equal(uptime['TestBuff'], 70, 'Uptime should be 70%');
  console.log('PASS: computeUptimes');
}

// Test transition matrix
{
  const casts = [
    { spell: 'Mangle' },
    { spell: 'Shred' },
    { spell: 'Shred' },
    { spell: 'Rip' },
  ];
  const transitions = computeTransitions(casts);
  assert.equal(transitions['Mangle -> Shred'], 1);
  assert.equal(transitions['Shred -> Shred'], 1);
  assert.equal(transitions['Shred -> Rip'], 1);
  console.log('PASS: computeTransitions');
}

// Test refresh pattern detection
{
  const debuffWindows = [
    { abilityGameID: 200, start: 0, end: 12000 },
    { abilityGameID: 200, start: 10800, end: 22800 },  // refreshed at 1.2s remaining
  ];
  const patterns = computeRefreshPatterns(debuffWindows, { 200: { name: 'Rip', duration: 12 } });
  assert.equal(patterns['Rip'].clips, 1, 'Should detect 1 clip');
  assert.ok(Math.abs(patterns['Rip'].avg_remaining_on_refresh - 1.2) < 0.01, 'Avg remaining should be ~1.2s');
  console.log('PASS: computeRefreshPatterns');
}

console.log('\nAll process-fight tests passed.');
```

**Step 2: Run tests, verify they fail**

```bash
cd log-analyzer && node test/process-fight.test.js
```

Expected: FAIL — module not found.

**Step 3: Implement process-fight.js**

`log-analyzer/src/process-fight.js`:

```js
import fs from 'fs/promises';
import path from 'path';
import { config } from './config.js';

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

  // Close any still-active buffs at fight end (handled by caller)
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
  // Group windows by ability
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
 * @param {object} specConfig - Spec definition (e.g., catDruid)
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

  // Close any active buffs/debuffs at fight end
  // (buildBuffTimeline leaves active ones open — close them here)

  // 2. Build cast sequence with enrichment
  const castSequence = [];
  const castCounts = {};

  for (const event of casts) {
    const spellId = event.abilityGameID;
    const spellInfo = specConfig.trackedSpells[spellId];
    if (!spellInfo) continue;

    const time = (event.timestamp - fightStart) / 1000;
    const spellName = spellInfo.name;

    // Count casts
    castCounts[spellName] = (castCounts[spellName] || 0) + 1;

    // Sample buffs/debuffs active at this moment
    const activeBuffs = sampleBuffsAtTime(buffWindows, event.timestamp);
    const activeDebuffs = sampleBuffsAtTime(debuffWindows, event.timestamp);

    castSequence.push({
      time: Math.round(time * 100) / 100,
      spell: spellName,
      spell_id: spellId,
      buffs_active: activeBuffs,
      target_debuffs: activeDebuffs,
      // Resource state — populated below if available
      energy: null,
      combo_points: null,
      target_hp_pct: event.hitPoints != null ? Math.round(event.targetResources?.hitPoints ?? 0) : null,
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
    resource_stats: {},  // Populated if resource events available
  };

  // Save to fights directory
  const fightsDir = path.join(config.dataDir, 'fights');
  await fs.mkdir(fightsDir, { recursive: true });
  const slug = `${meta.fightName || 'unknown'}-${output.meta.player}-${specConfig.spec}`.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  const filename = `${slug}.json`;
  await fs.writeFile(path.join(fightsDir, filename), JSON.stringify(output, null, 2));
  console.log(`  Saved: data/fights/${filename}`);

  return output;
}
```

**Step 4: Run tests, verify they pass**

```bash
cd log-analyzer && mkdir -p test && node test/process-fight.test.js
```

Expected: All 4 tests pass.

**Step 5: Commit**

```bash
git add log-analyzer/src/process-fight.js log-analyzer/test/process-fight.test.js
git commit -m "feat(log-analyzer): add fight processor with enriched JSON output"
```

---

## Task 10: Compare

**Files:**
- Create: `log-analyzer/src/compare.js`
- Create: `log-analyzer/test/compare.test.js`

**Step 1: Write tests**

`log-analyzer/test/compare.test.js`:

```js
import assert from 'node:assert/strict';
import { compareFights } from '../src/compare.js';

const top = {
  meta: { player: 'Top', boss: 'Gruul', dps: 1800, duration_sec: 140 },
  cast_summary: { Shred: { count: 42, cpm: 18 }, Rip: { count: 8, cpm: 3.4 } },
  uptimes: { Rip: 94 },
  transitions: { 'Shred -> Rip': 6 },
  refresh_patterns: { Rip: { avg_remaining_on_refresh: 1.2, clips: 0, drops: 1 } },
};

const yours = {
  meta: { player: 'You', boss: 'Gruul', dps: 1200, duration_sec: 150 },
  cast_summary: { Shred: { count: 28, cpm: 11.2 }, Rip: { count: 6, cpm: 2.4 } },
  uptimes: { Rip: 78 },
  transitions: { 'Shred -> Rip': 3 },
  refresh_patterns: { Rip: { avg_remaining_on_refresh: 3.8, clips: 2, drops: 3 } },
};

const result = compareFights(top, yours);

assert.equal(result.dps_gap.delta, -600);
assert.equal(result.uptime_diffs.Rip.delta, -16);
assert.ok(result.actionable_insights.length > 0, 'Should generate insights');
console.log('PASS: compareFights');
console.log('Insights:', result.actionable_insights);
```

**Step 2: Run tests, verify they fail**

```bash
cd log-analyzer && node test/compare.test.js
```

**Step 3: Implement compare.js**

`log-analyzer/src/compare.js`:

```js
import fs from 'fs/promises';
import path from 'path';
import { config } from './config.js';

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

    // Generate insights for significant differences
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
  const compDir = path.join(config.dataDir, 'comparisons');
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
```

**Step 4: Run tests, verify they pass**

```bash
cd log-analyzer && node test/compare.test.js
```

Expected: PASS

**Step 5: Commit**

```bash
git add log-analyzer/src/compare.js log-analyzer/test/compare.test.js
git commit -m "feat(log-analyzer): add fight comparison with actionable insights"
```

---

## Task 11: CLI entry point

**Files:**
- Create: `log-analyzer/src/cli.js`

**Step 1: Implement CLI with command dispatch**

`log-analyzer/src/cli.js`:

```js
#!/usr/bin/env node

import { discover } from './discover.js';
import { fetchRankings } from './fetch-rankings.js';
import { fetchFightEvents } from './fetch-events.js';
import { processFight } from './process-fight.js';
import { compareFromFiles } from './compare.js';
import { catDruid } from './specs/cat-druid.js';

// Spec lookup
const SPECS = {
  'druid-feral': catDruid,
  // Add more as needed
};

function parseArgs(argv) {
  const args = {};
  const positional = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const key = argv[i].slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith('--')) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    } else {
      positional.push(argv[i]);
    }
  }
  return { command: positional[0], args };
}

function resolveSpec(className, specName) {
  const key = `${className}-${specName}`.toLowerCase();
  const spec = SPECS[key];
  if (!spec) {
    console.error(`Unknown spec: ${className} ${specName}. Available: ${Object.keys(SPECS).join(', ')}`);
    process.exit(1);
  }
  return spec;
}

async function main() {
  const { command, args } = parseArgs(process.argv.slice(2));

  switch (command) {
    case 'discover': {
      const expansion = args.expansion || 'tbc';
      await discover(expansion);
      break;
    }

    case 'fetch': {
      if (args.report) {
        // Fetch specific report fight or trash
        const reportCode = args.report;
        const fightID = args.fight ? parseInt(args.fight, 10) : null;
        const playerName = args.player || null;

        if (args.trash) {
          const { listTrashFights } = await import('./fetch-events.js');
          await listTrashFights(reportCode);
        } else if (fightID) {
          const spec = args.class && args.spec ? resolveSpec(args.class, args.spec) : catDruid;
          const raw = await fetchFightEvents(reportCode, fightID, { playerName });
          const result = await processFight(raw, spec, { player: playerName || 'You' });
          console.log(`\nProcessed ${result.cast_sequence.length} casts, ${Object.keys(result.uptimes).length} uptimes tracked`);
        } else {
          console.error('--report requires --fight <id> or --trash');
          process.exit(1);
        }
      } else if (args.boss) {
        // Fetch top parses by boss name/ID
        const encounterID = parseInt(args.boss, 10) || null;
        if (!encounterID) {
          console.error('--boss must be a numeric encounter ID. Use "discover" to find IDs.');
          process.exit(1);
        }
        const className = args.class || 'Druid';
        const specName = args.spec || 'Feral';
        const count = parseInt(args.count, 10) || 10;
        const spec = resolveSpec(className, specName);

        const rankings = await fetchRankings(encounterID, className, specName, count);

        // Fetch and process each top parse
        for (const entry of rankings.rankings) {
          if (!entry.reportCode || entry.fightID == null) {
            console.warn(`  Skipping ${entry.player}: missing report/fight info`);
            continue;
          }
          try {
            console.log(`\nFetching ${entry.player}'s fight...`);
            const raw = await fetchFightEvents(entry.reportCode, entry.fightID, { playerName: entry.player });
            await processFight(raw, spec, entry);
          } catch (err) {
            console.error(`  Error processing ${entry.player}: ${err.message}`);
          }
        }
      } else {
        console.error('fetch requires --boss <encounterID> or --report <code>');
        process.exit(1);
      }
      break;
    }

    case 'compare': {
      if (!args.baseline || !args.yours) {
        console.error('compare requires --baseline <path> --yours <path>');
        process.exit(1);
      }
      await compareFromFiles(args.baseline, args.yours);
      break;
    }

    default:
      console.log(`
WCL Log Analyzer — Fetch and analyze top parser combat logs

Usage:
  node src/cli.js discover --expansion tbc
  node src/cli.js fetch --boss <encounterID> --class Druid --spec Feral --count 10
  node src/cli.js fetch --report <code> --fight <id> [--player <name>] [--class Druid --spec Feral]
  node src/cli.js fetch --report <code> --trash
  node src/cli.js compare --baseline <file> --yours <file>

Options:
  --expansion    Expansion name: classic, tbc, wotlk (default: tbc)
  --boss         Encounter ID (use discover to find IDs)
  --class        Class name (e.g., Druid, Warrior)
  --spec         Spec name (e.g., Feral, Arms)
  --count        Number of top parses to fetch (default: 10)
  --report       WCL report code
  --fight        Fight ID within a report
  --player       Player name to filter events
  --trash        List trash fights in a report
  --baseline     Path to top parser's fight JSON
  --yours        Path to your fight JSON
      `);
  }
}

main().catch((err) => {
  console.error('Fatal:', err.message);
  process.exit(1);
});
```

**Step 2: Add npm scripts to package.json**

Update `log-analyzer/package.json`:

```json
{
  "name": "@menagerie/log-analyzer",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=18.0.0"
  },
  "scripts": {
    "cli": "node src/cli.js",
    "discover": "node src/cli.js discover --expansion tbc",
    "test": "node test/process-fight.test.js && node test/compare.test.js"
  },
  "dependencies": {
    "dotenv": "^16.4.0"
  }
}
```

**Step 3: End-to-end verification**

Run the full pipeline:

```bash
# 1. Discover encounters
cd log-analyzer && node src/cli.js discover --expansion tbc

# 2. Fetch top 1 parse (use encounter ID from discover output)
node src/cli.js fetch --boss <ENCOUNTER_ID> --class Druid --spec Feral --count 1

# 3. Check output
ls data/fights/
cat data/fights/*.json | head -50

# 4. Run tests
npm test -w log-analyzer
```

**Step 4: Commit**

```bash
git add log-analyzer/src/cli.js log-analyzer/package.json
git commit -m "feat(log-analyzer): add CLI entry point with discover/fetch/compare commands"
```

---

## Summary

| Task | Files Created | Files Modified |
|------|--------------|----------------|
| 1 | `log-analyzer/package.json`, `data/.gitkeep` | `package.json`, `.gitignore` |
| 2 | `src/config.js`, `src/auth.js` | — |
| 3 | `src/api.js` | — |
| 4 | `src/queries.js` | — |
| 5 | `src/discover.js` | — |
| 6 | `src/fetch-rankings.js` | — |
| 7 | `src/fetch-events.js` | — |
| 8 | `src/specs/cat-druid.js` | — |
| 9 | `src/process-fight.js`, `test/process-fight.test.js` | — |
| 10 | `src/compare.js`, `test/compare.test.js` | — |
| 11 | `src/cli.js` | `package.json` |

### Known Unknowns (Discovered During Implementation)

- **WCL `characterRankings` response shape**: Returns a JSON scalar. Exact field names (`report.code`, `report.fightID`, `amount`, `duration`, etc.) must be verified against real API response in Task 6. Adjust parsing accordingly.
- **WCL event field names**: Cast events contain `abilityGameID`, `timestamp`, `sourceID`, `targetID` but resource fields (`classResources`, `hitPoints`) vary by event type. Verify in Task 7 raw output.
- **Cat Druid spell IDs**: IDs in spec config come from research docs. WCL may report different rank IDs. Cross-reference with raw data.
- **Resource reconstruction**: WCL may not include energy/CP in cast events. May need to reconstruct from `Resources` dataType or `classResources` arrays on events. Investigate in Task 7.
- **TBC Classic vs Retail API**: All queries go to `warcraftlogs.com` (not `classic.warcraftlogs.com`). The API may require a `partition` or `zoneID` parameter to scope to TBC. Discover command (Task 5) will reveal this.
