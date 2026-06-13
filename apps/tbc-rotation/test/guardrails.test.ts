import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');

function read(relativePath: string): string {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

function assertDoesNotMatch(source: string, pattern: RegExp, message: string): void {
  assert.equal(pattern.test(source), false, message);
}

{
  const caster = read('src/aio/druid/caster.lua');

  assertDoesNotMatch(
    caster,
    /safe_heal_cast\s*\(\s*A\.Thorns\b/,
    'Druid Thorns must not use HealingEngine/safe_heal_cast targeting; it can retarget pets/current units.',
  );

  assertDoesNotMatch(
    caster,
    /suggestion_spell\s*=\s*A\.Thorns\b/,
    'Targeted Thorns must not be placed on the generic suggestion icon without explicit unit targeting.',
  );

  console.log('PASS: Druid Thorns targeting guardrails');
}

{
  const main = read('src/aio/main.lua');

  assertDoesNotMatch(
    main,
    /if\s+context\.player_stunned\s+then\s+return\s+end/,
    'Do not hard-stop the entire rotation on context.player_stunned; false positives disable all casting.',
  );

  assertDoesNotMatch(
    main,
    /local\s+player_is_stunned\s*=\s*NS\.player_is_stunned/,
    'Stun suppression should not be wired as a global main.lua gate without runtime validation.',
  );

  console.log('PASS: Global stun hard-stop guardrails');
}

{
  const core = read('src/aio/core.lua');

  assert.match(
    core,
    /local\s+heal_target_click\s*=\s*\{\s*unit\s*=\s*"player"\s*\}/,
    'safe_heal_cast must use a pre-allocated Click table for explicit healing targets.',
  );

  assert.match(
    core,
    /heal_target_click\.unit\s*=\s*target_unit[\s\S]*ability\.Click\s*=\s*heal_target_click[\s\S]*ability:Show\(icon\)/,
    'safe_heal_cast must set ability.Click.unit before Show() so party/raid heals cannot fall back to player.',
  );

  console.log('PASS: Healing click-target guardrails');
}

{
  const healing = read('src/aio/druid/healing.lua');

  assert.match(
    healing,
    /entry\.has_aggro\s+and\s+not\s+player_has_aggro/,
    'Resto tank detection must not treat the player as tank only because they have threat; this causes P0 Regrowth spam.',
  );

  console.log('PASS: Druid resto tank-target guardrails');
}

console.log('\nAll rotation guardrail tests passed.');
