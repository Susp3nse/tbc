#!/usr/bin/env node
// @ts-nocheck

/*
 * Offline harness for the Hunter adaptive rotation.
 *
 * This intentionally mirrors apps/tbc-rotation/src/aio/hunter/adaptive.lua's
 * ChooseAction timing model:
 *   - Player:GetSwingShoot() is time until the next Auto Shot lands.
 *   - shootAt is derived as land time minus current ranged windup.
 *   - SpellQueueWindow/full latency is not added to PvE cast times.
 *
 * The sim is not a full WoW server. It is a deterministic pressure test for
 * the bugs we keep tuning: no Steady in very high haste windows, and ugly
 * Steady clips in base/RF windows.
 */

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const ADAPTIVE_LUA = path.join(ROOT, 'src', 'aio', 'hunter', 'adaptive.lua');

const GCD_DEFAULT = 1.5;
const NEG = -1e9;
const TIMER_EPSILON = 0.05;

const DEFAULT_PROFILE = {
  avgShoot: 966.4,
  avgSteady: 1084.7,
  avgMulti: 1165.1,
  avgArcane: 697.8,
  weaponBaseSpeed: 2.9,
  latency: 0.235,
  adaptiveExecPad: 0.1,
  pollInterval: 0.02,
  reactionTime: 0.05,
  duration: 30,
  manaPct: 100,
  manaSaveFloor: 15,
  arcaneManaFloor: 15,
  multiCooldown: 10,
  arcaneCooldown: 6,
  killCommandCooldown: 5,
  multiStartCooldown: 0,
  arcaneStartCooldown: 0,
  killCommandStartCooldown: 0,
  useMulti: true,
  useArcane: true,
  useKillCommand: true,
  timerMode: 'perfect',
  actionPublishDelay: 0,
  dropAutos: 0,
};

const BUCKET_THRESHOLDS = [
  { name: 'BASE', minSpeed: 2.35 },
  { name: 'LIGHT', minSpeed: 2.0 },
  { name: 'MAJOR', minSpeed: 1.7 },
  { name: 'DOUBLE', minSpeed: 1.4 },
  { name: 'PEAK', minSpeed: 1.15 },
  { name: 'ULTRA', minSpeed: 0 },
];

const SCENARIOS = [
  {
    name: 'base-90',
    label: 'BASE steady state',
    duration: 90,
    speed: 2.102,
    asserts: { maxAvgClipPerAuto: 0.04, maxWorstClip: 0.18, minSteady: 20 },
  },
  {
    name: 'rf-30',
    label: 'Rapid Fire',
    duration: 30,
    speed: 1.827,
    asserts: { maxAvgClipPerAuto: 0.06, maxWorstClip: 0.22, minSteady: 7 },
  },
  {
    name: 'rf-pot-25',
    label: 'RF + pot/trinket class',
    duration: 25,
    speed: 1.501,
    asserts: { maxAvgClipPerAuto: 0.1, maxWorstClip: 0.35, minSteady: 6 },
  },
  {
    name: 'peak-20',
    label: 'PEAK high haste',
    duration: 20,
    speed: 1.289,
    asserts: { maxAvgClipPerAuto: 0.16, maxWorstClip: 0.42, minSteady: 5 },
  },
  {
    name: 'ultra-15',
    label: 'ULTRA lust+RF+pot+trinket',
    duration: 15,
    speed: 1.058,
    asserts: { maxAvgClipPerAuto: 0.24, maxWorstClip: 0.55, minSteady: 4, maxSteadyDrought: 5.0 },
  },
  {
    name: 'ultra-qs-15',
    label: 'ULTRA with Quick Shots',
    duration: 15,
    speed: 0.92,
    asserts: { maxAvgClipPerAuto: 0.3, maxWorstClip: 0.65, minSteady: 4, maxSteadyDrought: 5.0 },
  },
  {
    name: 'base-no-arcane-90',
    label: 'BASE with Arcane disabled',
    duration: 90,
    speed: 2.102,
    profile: { useArcane: false },
    asserts: { maxAvgClipPerAuto: 0.04, maxWorstClip: 0.18, minSteady: 24 },
  },
  {
    name: 'ultra-no-instants-15',
    label: 'ULTRA with Multi/Arcane disabled',
    duration: 15,
    speed: 1.058,
    profile: { useMulti: false, useArcane: false },
    asserts: { maxAvgClipPerAuto: 0.3, maxWorstClip: 0.65, minSteady: 4, maxSteadyDrought: 5.0 },
  },
];

function die(message) {
  console.error(message);
  process.exit(1);
}

function parseArgs(argv) {
  const opts = {
    trace: null,
    json: false,
    list: false,
    speed: null,
    duration: null,
    latency: null,
    manaPct: null,
    manaSaveFloor: null,
    arcaneManaFloor: null,
    useMulti: null,
    useArcane: null,
    useKillCommand: null,
    multiCooldown: null,
    arcaneCooldown: null,
    killCommandCooldown: null,
    multiStartCooldown: null,
    arcaneStartCooldown: null,
    killCommandStartCooldown: null,
    timerMode: null,
    timerMatrix: null,
    actionPublishDelay: null,
    dropAutos: null,
    adaptiveExecPad: null,
    noAsserts: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--trace') opts.trace = argv[++i];
    else if (arg === '--json') opts.json = true;
    else if (arg === '--list') opts.list = true;
    else if (arg === '--speed') opts.speed = Number(argv[++i]);
    else if (arg === '--duration') opts.duration = Number(argv[++i]);
    else if (arg === '--latency') opts.latency = Number(argv[++i]);
    else if (arg === '--mana') opts.manaPct = Number(argv[++i]);
    else if (arg === '--mana-save') opts.manaSaveFloor = Number(argv[++i]);
    else if (arg === '--arcane-mana') opts.arcaneManaFloor = Number(argv[++i]);
    else if (arg === '--no-multi') opts.useMulti = false;
    else if (arg === '--with-multi') opts.useMulti = true;
    else if (arg === '--no-arcane') opts.useArcane = false;
    else if (arg === '--with-arcane') opts.useArcane = true;
    else if (arg === '--no-kc') opts.useKillCommand = false;
    else if (arg === '--with-kc') opts.useKillCommand = true;
    else if (arg === '--multi-cd') opts.multiCooldown = Number(argv[++i]);
    else if (arg === '--arcane-cd') opts.arcaneCooldown = Number(argv[++i]);
    else if (arg === '--kc-cd') opts.killCommandCooldown = Number(argv[++i]);
    else if (arg === '--multi-start-cd') opts.multiStartCooldown = Number(argv[++i]);
    else if (arg === '--arcane-start-cd') opts.arcaneStartCooldown = Number(argv[++i]);
    else if (arg === '--kc-start-cd') opts.killCommandStartCooldown = Number(argv[++i]);
    else if (arg === '--timer-mode') opts.timerMode = argv[++i];
    else if (arg === '--timer-matrix') opts.timerMatrix = argv[++i];
    else if (arg === '--action-delay') opts.actionPublishDelay = Number(argv[++i]);
    else if (arg === '--drop-autos') opts.dropAutos = Number(argv[++i]);
    else if (arg === '--exec-pad') opts.adaptiveExecPad = Number(argv[++i]);
    else if (arg === '--no-asserts') opts.noAsserts = true;
    else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      die(`Unknown argument: ${arg}`);
    }
  }

  return opts;
}

function printHelp() {
  console.log(`Usage: corepack pnpm --filter @flux/tbc-rotation sim:hunter -- [options]

Options:
  --list                 List built-in scenarios
  --trace <scenario>     Print the cast/auto timeline for one scenario
  --json                 Emit JSON instead of the summary table
  --speed <seconds>      Run one ad-hoc scenario at this ranged speed
  --duration <seconds>   Duration for the ad-hoc scenario
  --latency <seconds>    Override logged latency value (not cast-time math)
  --mana <percent>       Override mana percent used by gates
  --mana-save <percent>  Override expensive-shot mana floor
  --arcane-mana <pct>    Override Arcane-specific mana floor
  --no-multi             Disable Multi-Shot
  --no-arcane            Disable Arcane Shot
  --no-kc                Disable Kill Command
  --with-multi           Force-enable Multi-Shot for a scenario
  --with-arcane          Force-enable Arcane Shot for a scenario
  --with-kc              Force-enable Kill Command for a scenario
  --multi-cd <seconds>   Override Multi-Shot cooldown length
  --arcane-cd <seconds>  Override Arcane Shot cooldown length
  --kc-cd <seconds>      Override Kill Command cooldown length
  --multi-start-cd <sec> Start with this much Multi-Shot cooldown remaining
  --arcane-start-cd <s>  Start with this much Arcane cooldown remaining
  --kc-start-cd <sec>    Start with this much Kill Command cooldown remaining
  --timer-mode <mode>    perfect, action, inhouse, or inhouse-fallback
  --timer-matrix <name>  Compare timer modes for one built-in scenario
  --action-delay <sec>   Simulate Action returning 0 after Auto until this delay
  --drop-autos <count>   Simulate missed in-house Auto Shot events after pull sync
  --exec-pad <seconds>   Add cast-start safety time to Adaptive clip checks
  --no-asserts           Do not fail the process on assertion misses
  -h, --help             Show this help

Examples:
  corepack pnpm --filter @flux/tbc-rotation sim:hunter
  corepack pnpm --filter @flux/tbc-rotation sim:hunter -- --trace ultra-15
  corepack pnpm --filter @flux/tbc-rotation sim:hunter -- --speed 1.05 --duration 20
  corepack pnpm --filter @flux/tbc-rotation sim:hunter -- --trace ultra-15 --no-arcane --multi-start-cd 4
  corepack pnpm --filter @flux/tbc-rotation sim:hunter -- --timer-matrix ultra-15 --drop-autos 3 --action-delay 0.20 --no-asserts
`);
}

function applyOptionOverrides(profile, opts) {
  const numericKeys = [
    'latency',
    'manaPct',
    'manaSaveFloor',
    'arcaneManaFloor',
    'multiCooldown',
    'arcaneCooldown',
    'killCommandCooldown',
    'multiStartCooldown',
    'arcaneStartCooldown',
    'killCommandStartCooldown',
    'actionPublishDelay',
    'dropAutos',
    'adaptiveExecPad',
  ];

  for (const key of numericKeys) {
    if (opts[key] != null) profile[key] = opts[key];
  }
  if (opts.duration != null) profile.duration = opts.duration;
  if (opts.useMulti != null) profile.useMulti = opts.useMulti;
  if (opts.useArcane != null) profile.useArcane = opts.useArcane;
  if (opts.useKillCommand != null) profile.useKillCommand = opts.useKillCommand;
  if (opts.timerMode != null) profile.timerMode = opts.timerMode;

  validateProfile(profile);
}

function validateProfile(profile) {
  const nonNegativeKeys = [
    'latency',
    'pollInterval',
    'reactionTime',
    'duration',
    'manaPct',
    'manaSaveFloor',
    'arcaneManaFloor',
    'multiCooldown',
    'arcaneCooldown',
    'killCommandCooldown',
    'multiStartCooldown',
    'arcaneStartCooldown',
    'killCommandStartCooldown',
    'actionPublishDelay',
    'dropAutos',
  ];
  for (const key of nonNegativeKeys) {
    if (!Number.isFinite(profile[key]) || profile[key] < 0) {
      die(`${key} must be a non-negative number`);
    }
  }
}

function loadClipBudgets() {
  const text = fs.readFileSync(ADAPTIVE_LUA, 'utf8');
  const budgets = {};
  const re =
    /^\s*(BASE|LIGHT|MAJOR|DOUBLE|PEAK|ULTRA)\s*=\s*\{\s*steady\s*=\s*([0-9.]+),\s*multi\s*=\s*([0-9.]+),\s*arcane\s*=\s*([0-9.]+)\s*\}/gm;
  let match;
  while ((match = re.exec(text)) !== null) {
    budgets[match[1]] = {
      steady: Number(match[2]),
      multi: Number(match[3]),
      arcane: Number(match[4]),
    };
  }

  for (const name of BUCKET_THRESHOLDS.map((b) => b.name)) {
    if (!budgets[name]) {
      die(`Could not read ${name} clip budget from ${ADAPTIVE_LUA}`);
    }
  }
  return budgets;
}

function bucketForSpeed(speed) {
  for (const bucket of BUCKET_THRESHOLDS) {
    if (speed >= bucket.minSpeed) return bucket.name;
  }
  return 'ULTRA';
}

function recomputeState(profile, speed, budgets) {
  const hasteMult = profile.weaponBaseSpeed / Math.max(0.1, speed);
  const rangedWindup = 0.5 / hasteMult;
  const steadyCastTime = 1.5 / hasteMult;
  const multiCastTime = 0.5 / hasteMult;
  const arcaneCastTime = 0;
  const shootDPS = profile.avgShoot / Math.max(0.1, speed);
  const steadyDPS = profile.avgSteady / GCD_DEFAULT;

  const rangedGap = speed - rangedWindup;
  let autoCycleDuration = rangedGap;
  let guard = 0;
  while (autoCycleDuration < GCD_DEFAULT && guard < 10) {
    autoCycleDuration += rangedGap + rangedWindup;
    guard += 1;
  }
  const denom = rangedGap + rangedWindup;
  const leftoverGCDRatio = denom > 0 ? (autoCycleDuration - GCD_DEFAULT) / denom : 1.0;
  const useMultiForCatchup = leftoverGCDRatio < 0.95;
  const clipBucket = bucketForSpeed(speed);

  return {
    speed,
    hasteMult,
    rangedWindup,
    steadyCastTime,
    multiCastTime,
    arcaneCastTime,
    shootDPS,
    steadyDPS,
    useMultiForCatchup,
    leftoverGCDRatio,
    clipBucket,
    clipBudget: budgets[clipBucket],
  };
}

function normalizeTimerMode(mode) {
  const normalized = mode || 'perfect';
  if (['perfect', 'action', 'inhouse', 'inhouse-fallback'].includes(normalized)) return normalized;
  die(`Unknown --timer-mode: ${mode}. Use perfect, action, inhouse, or inhouse-fallback.`);
}

function createTimer(profile) {
  return {
    mode: normalizeTimerMode(profile.timerMode),
    actionPublishDelay: profile.actionPublishDelay || 0,
    actionPublishAt: 0,
    inhouseKnown: false,
    inhouseNextDoneAt: 0,
    inhouseSource: '',
    autoEventsSeen: 0,
    dropRemaining: profile.dropAutos || 0,
  };
}

function readActionTimer(timer, now, trueNextAutoDoneAt) {
  if (now < timer.actionPublishAt - 1e-9) return 0;
  return Math.max(0, trueNextAutoDoneAt - now);
}

function recordTimerAuto(timer, autoDoneAt, state) {
  timer.autoEventsSeen += 1;
  timer.actionPublishAt = autoDoneAt + timer.actionPublishDelay;

  if (timer.mode !== 'inhouse' && timer.mode !== 'inhouse-fallback') return;

  if (timer.autoEventsSeen > 1 && timer.dropRemaining > 0) {
    timer.dropRemaining -= 1;
    return;
  }

  timer.inhouseKnown = true;
  timer.inhouseNextDoneAt = autoDoneAt + state.speed;
  timer.inhouseSource = 'auto';
}

function readInhouseTimer(timer, now) {
  if (!timer.inhouseKnown) {
    return { shootRemaining: 0, state: 'unknown' };
  }

  const remaining = timer.inhouseNextDoneAt - now;
  if (remaining > TIMER_EPSILON) {
    return { shootRemaining: remaining, state: `known:${timer.inhouseSource || 'auto'}` };
  }

  timer.inhouseKnown = false;
  return { shootRemaining: 0, state: 'elapsed' };
}

function readTimer(timer, now, trueNextAutoDoneAt) {
  const rawActionRemaining = readActionTimer(timer, now, trueNextAutoDoneAt);

  if (timer.mode === 'perfect') {
    return {
      shootRemaining: Math.max(0, trueNextAutoDoneAt - now),
      rawActionRemaining,
      mode: timer.mode,
      state: 'perfect',
    };
  }

  if (timer.mode === 'action') {
    return {
      shootRemaining: rawActionRemaining,
      rawActionRemaining,
      mode: timer.mode,
      state: rawActionRemaining > TIMER_EPSILON ? 'action' : 'action_zero',
    };
  }

  const inhouse = readInhouseTimer(timer, now);
  if (
    timer.mode === 'inhouse-fallback' &&
    inhouse.shootRemaining <= TIMER_EPSILON &&
    rawActionRemaining > TIMER_EPSILON
  ) {
    return {
      shootRemaining: rawActionRemaining,
      rawActionRemaining,
      mode: timer.mode,
      state: `${inhouse.state}+action_fallback`,
    };
  }

  return {
    shootRemaining: inhouse.shootRemaining,
    rawActionRemaining,
    mode: timer.mode,
    state: inhouse.state,
  };
}

function chooseAction(ctx) {
  const { now, profile, state, gcdUntil, nextAutoDoneAt, cooldowns, timer } = ctx;

  const gcdRemaining = Math.max(0, gcdUntil - now);
  const gcdAt = Math.max(now, now + gcdRemaining);
  const timerSnapshot = readTimer(timer, now, nextAutoDoneAt);
  const shootRemaining = timerSnapshot.shootRemaining;

  const shootDoneAt = Math.max(now, now + shootRemaining);
  const shootAt = Math.max(now, shootDoneAt - state.rangedWindup);

  const shootGCDDelay = Math.max(0, shootDoneAt - gcdAt);
  const scores = {
    shoot: profile.avgShoot - state.steadyDPS * shootGCDDelay,
    steady: NEG,
    multi: NEG,
    arcane: NEG,
  };

  const executionPad = Math.max(0, Math.min(0.25, profile.adaptiveExecPad ?? 0.1));
  const castStartAt = gcdAt + executionPad;
  const steadyShootDelay = Math.max(0, castStartAt + state.steadyCastTime - shootAt);
  const multiShootDelay = Math.max(0, castStartAt + state.multiCastTime - shootAt);
  const arcaneShootDelay = Math.max(0, castStartAt + state.arcaneCastTime - shootAt);

  const steadyClipGated = steadyShootDelay > state.clipBudget.steady;
  const multiClipGated = multiShootDelay > state.clipBudget.multi;
  const arcaneClipGated = arcaneShootDelay > state.clipBudget.arcane;
  const expensiveManaOk = profile.manaPct > profile.manaSaveFloor;

  if (!steadyClipGated) {
    scores.steady = profile.avgSteady - state.shootDPS * steadyShootDelay;
  }

  const multiReady = profile.useMulti && expensiveManaOk && now >= cooldowns.multiReadyAt;
  if (
    multiReady &&
    !multiClipGated &&
    (!state.useMultiForCatchup || multiShootDelay < steadyShootDelay)
  ) {
    scores.multi = profile.avgMulti - state.shootDPS * multiShootDelay;
  }

  const arcaneReady =
    profile.useArcane &&
    profile.manaPct > profile.arcaneManaFloor &&
    now >= cooldowns.arcaneReadyAt;
  if (arcaneReady && !arcaneClipGated) {
    scores.arcane = profile.avgArcane - state.shootDPS * arcaneShootDelay;
  }

  let best = 'shoot';
  let bestDmg = scores.shoot;
  for (const opt of ['steady', 'multi', 'arcane']) {
    if (scores[opt] > bestDmg) {
      best = opt;
      bestDmg = scores[opt];
    }
  }

  if (best !== 'shoot' && gcdRemaining > 0.05 && scores.shoot >= bestDmg - 0.01) {
    best = 'shoot';
  }

  return {
    choice: best,
    scores,
    gcdRemaining,
    shootRemaining,
    rawShootRemaining: timerSnapshot.rawActionRemaining,
    timerMode: timerSnapshot.mode,
    timerState: timerSnapshot.state,
    shootAt,
    shootDoneAt,
    shootGCDDelay,
    steadyShootDelay,
    multiShootDelay,
    arcaneShootDelay,
    executionPad,
    steadyClipGated,
    multiClipGated,
    arcaneClipGated,
  };
}

function castDuration(spell, state) {
  if (spell === 'steady') return state.steadyCastTime;
  if (spell === 'multi') return state.multiCastTime;
  if (spell === 'arcane') return state.arcaneCastTime;
  return 0;
}

function spellName(spell) {
  if (spell === 'steady') return 'Steady Shot';
  if (spell === 'multi') return 'Multi-Shot';
  if (spell === 'arcane') return 'Arcane Shot';
  if (spell === 'kc') return 'Kill Command';
  return spell;
}

function simulateScenario(inputScenario, budgets, opts = {}) {
  const scenario = { ...inputScenario };
  const profile = {
    ...DEFAULT_PROFILE,
    ...scenario.profile,
    duration: scenario.duration ?? DEFAULT_PROFILE.duration,
    latency: scenario.latency ?? DEFAULT_PROFILE.latency,
  };

  applyOptionOverrides(profile, opts);
  const speed = opts.speed ?? scenario.speed;
  const state = recomputeState(profile, speed, budgets);
  const timer = createTimer(profile);
  const endTime = profile.duration;

  const cooldowns = {
    multiReadyAt: profile.multiStartCooldown,
    arcaneReadyAt: profile.arcaneStartCooldown,
    kcReadyAt: profile.killCommandStartCooldown,
  };

  let now = 0;
  let gcdUntil = 0;
  let castingUntil = 0;
  let nextAllowedPressAt = 0;
  let lastAutoDoneAt = 0;
  let nextAutoDoneAt = 0;
  let pendingClip = 0;
  let pendingCause = 'Clean';
  let pendingBucket = state.clipBucket;

  const counts = { auto: 0, steady: 0, multi: 0, arcane: 0, kc: 0, shootWaits: 0 };
  const clips = [];
  const events = [];
  const steadyTimes = [];
  const decisions = [];

  function pushEvent(type, fields) {
    events.push({ t: Number(now.toFixed(3)), type, ...fields });
  }

  function processAuto() {
    while (now + 1e-9 >= nextAutoDoneAt && nextAutoDoneAt <= endTime + 1e-9) {
      now = Math.max(now, nextAutoDoneAt);
      const actualInterval = counts.auto === 0 ? 0 : nextAutoDoneAt - lastAutoDoneAt;
      counts.auto += 1;
      if (counts.auto > 1 && pendingClip > 1e-6) {
        clips.push({
          t: nextAutoDoneAt,
          clip: pendingClip,
          actualInterval,
          expectedSpeed: state.speed,
          cause: pendingCause,
          bucket: pendingBucket,
        });
      }
      pushEvent('auto', {
        clip: Number(pendingClip.toFixed(3)),
        interval: counts.auto === 1 ? 0 : Number(actualInterval.toFixed(3)),
        cause: pendingCause,
      });

      pendingClip = 0;
      pendingCause = 'Clean';
      pendingBucket = state.clipBucket;
      lastAutoDoneAt = nextAutoDoneAt;
      recordTimerAuto(timer, nextAutoDoneAt, state);
      nextAutoDoneAt += state.speed;
    }
  }

  function applyClipForCast(spell, castStart, castEnd) {
    const shootAt = Math.max(castStart, nextAutoDoneAt - state.rangedWindup);
    if (castStart < nextAutoDoneAt && castEnd > shootAt) {
      const added = castEnd - shootAt;
      nextAutoDoneAt += added;
      pendingClip += added;
      pendingCause = spellName(spell);
      pendingBucket = state.clipBucket;
    }
  }

  processAuto();
  while (now < endTime - 1e-9) {
    processAuto();

    const canPress = now >= nextAllowedPressAt - 1e-9 && now >= castingUntil - 1e-9;

    if (canPress) {
      const decision = chooseAction({
        now,
        profile,
        state,
        gcdUntil,
        nextAutoDoneAt,
        cooldowns,
        timer,
      });
      decisions.push({ t: now, ...decision });

      if (decision.choice !== 'shoot' && now >= gcdUntil - 1e-9) {
        const spell = decision.choice;
        const duration = castDuration(spell, state);
        const castEnd = now + duration;
        counts[spell] += 1;
        if (spell === 'steady') steadyTimes.push(now);
        if (spell === 'multi') cooldowns.multiReadyAt = now + profile.multiCooldown;
        if (spell === 'arcane') cooldowns.arcaneReadyAt = now + profile.arcaneCooldown;
        gcdUntil = now + GCD_DEFAULT;
        castingUntil = castEnd;
        nextAllowedPressAt = now + profile.reactionTime;
        applyClipForCast(spell, now, castEnd);
        pushEvent('cast', {
          spell,
          end: Number(castEnd.toFixed(3)),
          bucket: state.clipBucket,
          timer: decision.timerState,
          steadyDelay: Number(decision.steadyShootDelay.toFixed(3)),
          multiDelay: Number(decision.multiShootDelay.toFixed(3)),
          arcaneDelay: Number(decision.arcaneShootDelay.toFixed(3)),
        });
      } else {
        counts.shootWaits += 1;
        nextAllowedPressAt = now + profile.reactionTime;
        if (decision.timerState !== 'perfect' && decision.timerState !== 'action') {
          pushEvent('wait', {
            choice: decision.choice,
            timer: decision.timerState,
            shootRemaining: Number(decision.shootRemaining.toFixed(3)),
            rawShootRemaining: Number(decision.rawShootRemaining.toFixed(3)),
            steadyDelay: Number(decision.steadyShootDelay.toFixed(3)),
            steadyGated: decision.steadyClipGated,
          });
        }
      }
    }

    if (
      profile.useKillCommand &&
      now >= cooldowns.kcReadyAt - 1e-9 &&
      (now < gcdUntil - 0.05 || now < castingUntil - 1e-9)
    ) {
      counts.kc += 1;
      cooldowns.kcReadyAt = now + profile.killCommandCooldown;
      pushEvent('cast', { spell: 'kc', end: Number(now.toFixed(3)), bucket: state.clipBucket });
    }

    const candidates = [
      endTime,
      nextAutoDoneAt,
      castingUntil > now ? castingUntil : Infinity,
      nextAllowedPressAt > now ? nextAllowedPressAt : Infinity,
      now + profile.pollInterval,
    ];
    const next = Math.min(...candidates.filter((v) => Number.isFinite(v) && v > now + 1e-9));
    now = next;
  }

  processAuto();

  const totalClip = clips.reduce((sum, clip) => sum + clip.clip, 0);
  const worstClip = clips.reduce((max, clip) => Math.max(max, clip.clip), 0);
  const avgClipPerAuto = counts.auto > 0 ? totalClip / counts.auto : 0;
  const maxSteadyDrought = computeMaxDrought(steadyTimes, endTime);
  const verdicts = evaluateAssertions(scenario.asserts, {
    counts,
    totalClip,
    worstClip,
    avgClipPerAuto,
    maxSteadyDrought,
  });

  return {
    name: scenario.name,
    label: scenario.label,
    duration: endTime,
    speed,
    bucket: state.clipBucket,
    hasteMult: state.hasteMult,
    windup: state.rangedWindup,
    steadyCastTime: state.steadyCastTime,
    multiCastTime: state.multiCastTime,
    latency: profile.latency,
    clipBudget: state.clipBudget,
    useMultiForCatchup: state.useMultiForCatchup,
    profile: {
      useMulti: profile.useMulti,
      useArcane: profile.useArcane,
      useKillCommand: profile.useKillCommand,
      multiCooldown: profile.multiCooldown,
      arcaneCooldown: profile.arcaneCooldown,
      killCommandCooldown: profile.killCommandCooldown,
      multiStartCooldown: profile.multiStartCooldown,
      arcaneStartCooldown: profile.arcaneStartCooldown,
      killCommandStartCooldown: profile.killCommandStartCooldown,
      manaPct: profile.manaPct,
      manaSaveFloor: profile.manaSaveFloor,
      arcaneManaFloor: profile.arcaneManaFloor,
      timerMode: profile.timerMode,
      actionPublishDelay: profile.actionPublishDelay,
      dropAutos: profile.dropAutos,
      adaptiveExecPad: profile.adaptiveExecPad,
    },
    counts,
    clips: {
      count: clips.length,
      total: totalClip,
      avgPerAuto: avgClipPerAuto,
      avgClipped: clips.length ? totalClip / clips.length : 0,
      worst: worstClip,
      bySpell: groupClipsBySpell(clips),
    },
    maxSteadyDrought,
    verdicts,
    passed: verdicts.every((v) => v.pass),
    events,
    decisions,
  };
}

function computeMaxDrought(times, duration) {
  let prev = 0;
  let max = 0;
  for (const t of times) {
    max = Math.max(max, t - prev);
    prev = t;
  }
  max = Math.max(max, duration - prev);
  return max;
}

function groupClipsBySpell(clips) {
  const grouped = {};
  for (const clip of clips) {
    if (!grouped[clip.cause]) grouped[clip.cause] = { count: 0, total: 0, worst: 0 };
    grouped[clip.cause].count += 1;
    grouped[clip.cause].total += clip.clip;
    grouped[clip.cause].worst = Math.max(grouped[clip.cause].worst, clip.clip);
  }
  return grouped;
}

function evaluateAssertions(asserts, result) {
  if (!asserts) return [];
  const checks = [];
  function add(name, pass, actual, limit) {
    checks.push({ name, pass, actual, limit });
  }
  if (asserts.minSteady != null) {
    add(
      'minSteady',
      result.counts.steady >= asserts.minSteady,
      result.counts.steady,
      asserts.minSteady,
    );
  }
  if (asserts.maxAvgClipPerAuto != null) {
    add(
      'maxAvgClipPerAuto',
      result.avgClipPerAuto <= asserts.maxAvgClipPerAuto,
      result.avgClipPerAuto,
      asserts.maxAvgClipPerAuto,
    );
  }
  if (asserts.maxWorstClip != null) {
    add(
      'maxWorstClip',
      result.worstClip <= asserts.maxWorstClip,
      result.worstClip,
      asserts.maxWorstClip,
    );
  }
  if (asserts.maxSteadyDrought != null) {
    add(
      'maxSteadyDrought',
      result.maxSteadyDrought <= asserts.maxSteadyDrought,
      result.maxSteadyDrought,
      asserts.maxSteadyDrought,
    );
  }
  return checks;
}

function pad(value, width) {
  const text = String(value);
  return text.length >= width ? text : `${' '.repeat(width - text.length)}${text}`;
}

function fixed(value, digits = 3) {
  return Number(value).toFixed(digits);
}

function printSummary(results) {
  console.log('Hunter adaptive offline sim');
  console.log('Budgets are read from apps/tbc-rotation/src/aio/hunter/adaptive.lua');
  console.log('');
  console.log(
    [
      'scenario'.padEnd(20),
      'timer'.padEnd(16),
      'bucket'.padEnd(7),
      'speed',
      'autos',
      'steady',
      'multi',
      'arc',
      'kc',
      'clip/auto',
      'worst',
      'drought',
      'result',
    ].join('  '),
  );
  console.log('-'.repeat(129));
  for (const r of results) {
    console.log(
      [
        r.name.padEnd(20),
        r.profile.timerMode.padEnd(16),
        r.bucket.padEnd(7),
        pad(fixed(r.speed, 3), 5),
        pad(r.counts.auto, 5),
        pad(r.counts.steady, 6),
        pad(r.counts.multi, 5),
        pad(r.counts.arcane, 3),
        pad(r.counts.kc, 2),
        pad(fixed(r.clips.avgPerAuto, 3), 9),
        pad(fixed(r.clips.worst, 3), 5),
        pad(fixed(r.maxSteadyDrought, 2), 7),
        r.passed ? 'PASS' : 'FAIL',
      ].join('  '),
    );
  }

  const failures = results.flatMap((r) =>
    r.verdicts.filter((v) => !v.pass).map((v) => ({ scenario: r.name, ...v })),
  );
  if (failures.length) {
    console.log('');
    console.log('Failures:');
    for (const f of failures) {
      console.log(
        `  ${f.scenario}: ${f.name} actual=${formatActual(f.actual)} limit=${formatActual(f.limit)}`,
      );
    }
  }
}

function formatActual(value) {
  return typeof value === 'number' ? fixed(value, 3) : String(value);
}

function printTrace(result) {
  printSummary([result]);
  console.log('');
  console.log(`Trace: ${result.name} (${result.label})`);
  console.log(
    `speed=${fixed(result.speed)} bucket=${result.bucket} haste=${fixed(result.hasteMult)} ` +
      `windup=${fixed(result.windup)} steadyCT=${fixed(result.steadyCastTime)} ` +
      `multiCT=${fixed(result.multiCastTime)}`,
  );
  console.log(
    `enabled: multi=${result.profile.useMulti} arcane=${result.profile.useArcane} kc=${result.profile.useKillCommand} | ` +
      `cds: multi=${fixed(result.profile.multiCooldown, 1)} arcane=${fixed(result.profile.arcaneCooldown, 1)} ` +
      `kc=${fixed(result.profile.killCommandCooldown, 1)} | ` +
      `startCD: multi=${fixed(result.profile.multiStartCooldown, 1)} arcane=${fixed(result.profile.arcaneStartCooldown, 1)} ` +
      `kc=${fixed(result.profile.killCommandStartCooldown, 1)}`,
  );
  console.log(
    `timer: mode=${result.profile.timerMode} actionDelay=${fixed(result.profile.actionPublishDelay)} ` +
      `dropAutos=${result.profile.dropAutos}`,
  );
  console.log('');
  for (const event of result.events) {
    if (event.type === 'auto') {
      console.log(
        `${fixed(event.t, 3)}  AUTO   interval=${fixed(event.interval)} clip=${fixed(event.clip)} cause=${event.cause}`,
      );
    } else if (event.type === 'cast') {
      const end = event.end != null ? ` end=${fixed(event.end)}` : '';
      const timer = event.timer ? ` timer=${event.timer}` : '';
      const delays =
        event.steadyDelay != null
          ? ` delays steady=${fixed(event.steadyDelay)} multi=${fixed(event.multiDelay)} arcane=${fixed(event.arcaneDelay)}`
          : '';
      console.log(
        `${fixed(event.t, 3)}  CAST   ${event.spell}${end} bucket=${event.bucket}${timer}${delays}`,
      );
    } else if (event.type === 'wait') {
      console.log(
        `${fixed(event.t, 3)}  WAIT   timer=${event.timer} shoot=${fixed(event.shootRemaining)} ` +
          `raw=${fixed(event.rawShootRemaining)} steadyDelay=${fixed(event.steadyDelay)} gated=${event.steadyGated}`,
      );
    }
  }
}

function buildTimerMatrix(baseScenario, opts) {
  const dropAutos = opts.dropAutos ?? 3;
  const actionDelay = opts.actionPublishDelay ?? 0.2;
  const baseProfile = baseScenario.profile || {};

  function variant(suffix, label, profilePatch) {
    return {
      ...baseScenario,
      name: `${baseScenario.name}-${suffix}`,
      label: `${baseScenario.label} (${label})`,
      profile: {
        ...baseProfile,
        ...profilePatch,
      },
    };
  }

  return [
    variant('perfect', 'perfect timer', {
      timerMode: 'perfect',
      actionPublishDelay: 0,
      dropAutos: 0,
    }),
    variant('action-delay', `Action delay ${fixed(actionDelay)}s`, {
      timerMode: 'action',
      actionPublishDelay: actionDelay,
      dropAutos: 0,
    }),
    variant('inhouse-drop', `${dropAutos} missed in-house events`, {
      timerMode: 'inhouse',
      actionPublishDelay: actionDelay,
      dropAutos,
    }),
    variant('fallback', `${dropAutos} missed events + Action fallback`, {
      timerMode: 'inhouse-fallback',
      actionPublishDelay: actionDelay,
      dropAutos,
    }),
  ];
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.list) {
    for (const s of SCENARIOS) {
      console.log(`${s.name.padEnd(14)} ${s.speed.toFixed(3)}s ${s.duration}s  ${s.label}`);
    }
    return;
  }

  const budgets = loadClipBudgets();
  let scenarios = SCENARIOS;

  if (opts.timerMatrix) {
    const scenario = SCENARIOS.find((s) => s.name === opts.timerMatrix);
    if (!scenario) die(`Unknown scenario for --timer-matrix: ${opts.timerMatrix}. Use --list.`);
    const matrixOpts = {
      ...opts,
      timerMode: null,
      actionPublishDelay: null,
      dropAutos: null,
    };
    const results = buildTimerMatrix(scenario, opts).map((s) =>
      simulateScenario(s, budgets, matrixOpts),
    );
    if (opts.json) console.log(JSON.stringify(results, null, 2));
    else printSummary(results);
    if (!opts.noAsserts && results.some((r) => !r.passed)) process.exit(1);
    return;
  }

  if (opts.speed != null) {
    if (!Number.isFinite(opts.speed) || opts.speed <= 0) die('--speed must be a positive number');
    scenarios = [
      {
        name: 'adhoc',
        label: 'Ad-hoc speed test',
        speed: opts.speed,
        duration: opts.duration ?? DEFAULT_PROFILE.duration,
      },
    ];
  }

  if (opts.trace) {
    const scenario = scenarios.find((s) => s.name === opts.trace);
    if (!scenario) die(`Unknown scenario for --trace: ${opts.trace}. Use --list.`);
    const result = simulateScenario(scenario, budgets, opts);
    if (opts.json) console.log(JSON.stringify(result, null, 2));
    else printTrace(result);
    if (!opts.noAsserts && !result.passed) process.exit(1);
    return;
  }

  const results = scenarios.map((scenario) => simulateScenario(scenario, budgets, opts));
  if (opts.json) console.log(JSON.stringify(results, null, 2));
  else printSummary(results);

  if (!opts.noAsserts && results.some((r) => !r.passed)) {
    process.exit(1);
  }
}

main();
