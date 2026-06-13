/**
 * Bear Druid (Feral Tank) spec configuration for fight processing.
 * Defines which spells to track, resource types, debuff durations, cooldowns.
 *
 * WCL uses max-rank spell IDs (abilityGameID).
 * Max-rank IDs sourced from docs/DRUID_RESEARCH.md
 */
export const bearDruid = {
  name: 'Bear Druid',
  class: 'Druid',
  spec: 'Feral',
  resource: 'rage',

  // Spells to track in cast_summary and cast_sequence
  // WCL reports max-rank IDs, so we need both base and max-rank entries
  trackedSpells: {
    // Core bear abilities — max rank IDs (what WCL actually reports)
    33987: { name: 'Mangle (Bear)', category: 'ability', cooldown: 6 },  // R3
    33986: { name: 'Mangle (Bear)', category: 'ability', cooldown: 6 },  // R2
    33878: { name: 'Mangle (Bear)', category: 'ability', cooldown: 6 },  // R1
    26996: { name: 'Maul', category: 'ability' },            // R8 (on-next-attack, off-GCD)
    6807:  { name: 'Maul', category: 'ability' },             // base ID fallback
    26997: { name: 'Swipe', category: 'ability' },            // R6
    779:   { name: 'Swipe', category: 'ability' },            // base ID fallback
    33745: { name: 'Lacerate', category: 'dot' },             // single rank
    26998: { name: 'Demoralizing Roar', category: 'debuff', base_duration: 30 }, // R6
    9898:  { name: 'Demoralizing Roar', category: 'debuff', base_duration: 30 }, // R5
    99:    { name: 'Demoralizing Roar', category: 'debuff', base_duration: 30 }, // R1
    6795:  { name: 'Growl', category: 'taunt', cooldown: 10 },
    5209:  { name: 'Challenging Roar', category: 'taunt', cooldown: 600 },
    26999: { name: 'Frenzied Regeneration', category: 'defensive', cooldown: 180 }, // R4
    22842: { name: 'Frenzied Regeneration', category: 'defensive', cooldown: 180 }, // base
    5229:  { name: 'Enrage', category: 'utility', cooldown: 60 },
    22812: { name: 'Barkskin', category: 'defensive', cooldown: 60 },
    // Faerie Fire (Feral) — all ranks
    27011: { name: 'Faerie Fire (Feral)', category: 'debuff' },  // R5
    17392: { name: 'Faerie Fire (Feral)', category: 'debuff' },  // R4
    16857: { name: 'Faerie Fire (Feral)', category: 'debuff' },  // R1
    // Forms
    9634:  { name: 'Dire Bear Form', category: 'form' },
    768:   { name: 'Cat Form', category: 'form' },
    // Utility
    16979: { name: 'Feral Charge', category: 'utility', cooldown: 15 },
    8983:  { name: 'Bash', category: 'interrupt', cooldown: 60 },
    26994: { name: 'Rebirth', category: 'utility' },
  },

  // Debuffs to track for uptime analysis (on target)
  trackedDebuffs: {
    // Lacerate (single ID, stacking)
    33745: { name: 'Lacerate', duration: 15 },
    // Mangle debuff (all ranks)
    33987: { name: 'Mangle', duration: 12 },
    33986: { name: 'Mangle', duration: 12 },
    33878: { name: 'Mangle', duration: 12 },
    33876: { name: 'Mangle', duration: 12 },
    33983: { name: 'Mangle', duration: 12 },
    33982: { name: 'Mangle', duration: 12 },
    // Demoralizing Roar (all ranks)
    26998: { name: 'Demoralizing Roar', duration: 30 },
    9898:  { name: 'Demoralizing Roar', duration: 30 },
    9747:  { name: 'Demoralizing Roar', duration: 30 },
    9490:  { name: 'Demoralizing Roar', duration: 30 },
    1735:  { name: 'Demoralizing Roar', duration: 30 },
    99:    { name: 'Demoralizing Roar', duration: 30 },
    // Faerie Fire (all ranks)
    27011: { name: 'Faerie Fire', duration: 40 },
    17392: { name: 'Faerie Fire', duration: 40 },
    17391: { name: 'Faerie Fire', duration: 40 },
    17390: { name: 'Faerie Fire', duration: 40 },
    16857: { name: 'Faerie Fire', duration: 40 },
  },

  // Buffs to track (on player)
  trackedBuffs: {
    16870: { name: 'Clearcasting', duration: 15 },
    26999: { name: 'Frenzied Regeneration', duration: 10 },
    22842: { name: 'Frenzied Regeneration', duration: 10 },
    5229:  { name: 'Enrage', duration: 10 },
    22812: { name: 'Barkskin', duration: 12 },
    // External buffs of interest
    2825:  { name: 'Bloodlust', duration: 40 },
    32182: { name: 'Heroism', duration: 40 },
  },

  // Cooldowns to analyze alignment for
  cooldowns: ['Frenzied Regeneration', 'Barkskin', 'Enrage'],

  // Bloodlust buff IDs (for burst/defensive alignment)
  bloodlustBuffs: [2825, 32182],

  // Execute phase threshold (% HP)
  executeThreshold: 25,

  // GCD for this spec (seconds) — bear GCD is 1.5s
  gcd: 1.5,
};
