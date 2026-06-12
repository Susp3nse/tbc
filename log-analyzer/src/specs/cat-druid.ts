/**
 * Cat Druid (Feral DPS) spec configuration for fight processing.
 * Defines which spells to track, resource types, debuff durations, cooldowns.
 *
 * WCL uses max-rank spell IDs (abilityGameID).
 * Max-rank IDs sourced from docs/DRUID_RESEARCH.md
 */
export const catDruid = {
  name: 'Cat Druid',
  class: 'Druid',
  spec: 'Feral',
  resource: 'energy',

  // Spells to track in cast_summary and cast_sequence
  trackedSpells: {
    // Core cat abilities — max rank IDs
    33983: { name: 'Mangle (Cat)', category: 'ability', cooldown: 0 },  // R3
    33982: { name: 'Mangle (Cat)', category: 'ability', cooldown: 0 },  // R2
    33876: { name: 'Mangle (Cat)', category: 'ability', cooldown: 0 },  // R1
    27002: { name: 'Shred', category: 'ability' },              // R7
    5221:  { name: 'Shred', category: 'ability' },               // base fallback
    27008: { name: 'Rip', category: 'dot' },                     // R7
    1079:  { name: 'Rip', category: 'dot' },                     // base fallback
    31018: { name: 'Ferocious Bite', category: 'ability' },      // R6
    22568: { name: 'Ferocious Bite', category: 'ability' },      // base fallback
    27003: { name: 'Rake', category: 'dot' },                    // R5
    1822:  { name: 'Rake', category: 'dot' },                    // base fallback
    27000: { name: 'Claw', category: 'ability' },                // R6
    1082:  { name: 'Claw', category: 'ability' },                // base fallback
    9846:  { name: "Tiger's Fury", category: 'offensive_cd', cooldown: 0 }, // R4 (no CD, requires 0 energy)
    5217:  { name: "Tiger's Fury", category: 'offensive_cd', cooldown: 0 }, // base fallback
    // Stealth openers
    27005: { name: 'Ravage', category: 'ability' },              // R5
    6785:  { name: 'Ravage', category: 'ability' },              // base fallback
    27006: { name: 'Pounce', category: 'ability' },              // R4
    9913:  { name: 'Prowl', category: 'form' },                  // R3
    5215:  { name: 'Prowl', category: 'form' },                  // base fallback
    // Forms
    768:   { name: 'Cat Form', category: 'form' },
    9634:  { name: 'Dire Bear Form', category: 'form' },
    // Faerie Fire (Feral) — all ranks
    27011: { name: 'Faerie Fire (Feral)', category: 'debuff' },  // R5
    17392: { name: 'Faerie Fire (Feral)', category: 'debuff' },  // R4
    16857: { name: 'Faerie Fire (Feral)', category: 'debuff' },  // R1
    // Utility
    16979: { name: 'Feral Charge', category: 'utility', cooldown: 15 },
    8983:  { name: 'Bash', category: 'interrupt', cooldown: 60 },
    26994: { name: 'Rebirth', category: 'utility' },
    // Powershift (going cat → cat effectively)
    // No separate ID — tracked as Cat Form casts mid-combat
  },

  // Debuffs to track for uptime analysis (on target)
  trackedDebuffs: {
    // Mangle debuff — +30% bleed damage (all ranks, 12s)
    33983: { name: 'Mangle', duration: 12 },
    33982: { name: 'Mangle', duration: 12 },
    33876: { name: 'Mangle', duration: 12 },
    // Bear mangle also applies same debuff
    33987: { name: 'Mangle', duration: 12 },
    33986: { name: 'Mangle', duration: 12 },
    33878: { name: 'Mangle', duration: 12 },
    // Rake (9s bleed)
    27003: { name: 'Rake', duration: 9 },
    1822:  { name: 'Rake', duration: 9 },
    // Rip (12s bleed finisher)
    27008: { name: 'Rip', duration: 12 },
    1079:  { name: 'Rip', duration: 12 },
    // Faerie Fire (all ranks, 40s)
    27011: { name: 'Faerie Fire', duration: 40 },
    17392: { name: 'Faerie Fire', duration: 40 },
    17391: { name: 'Faerie Fire', duration: 40 },
    17390: { name: 'Faerie Fire', duration: 40 },
    16857: { name: 'Faerie Fire', duration: 40 },
  },

  // Buffs to track (on player)
  trackedBuffs: {
    16870: { name: 'Clearcasting', duration: 15 },
    9846:  { name: "Tiger's Fury", duration: 6 },
    5217:  { name: "Tiger's Fury", duration: 6 },
    // External buffs of interest
    2825:  { name: 'Bloodlust', duration: 40 },
    32182: { name: 'Heroism', duration: 40 },
  },

  // Cooldowns to analyze alignment for
  cooldowns: ["Tiger's Fury"],

  // Bloodlust buff IDs (for burst alignment)
  bloodlustBuffs: [2825, 32182],

  // Execute phase threshold (% HP)
  executeThreshold: 25,

  // GCD for this spec (seconds) — cat GCD is 1.0s
  gcd: 1.0,
};
