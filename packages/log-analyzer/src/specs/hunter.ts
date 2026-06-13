/**
 * Hunter spell metadata for WCL log analysis.
 *
 * Includes Classic Fresh level-60 ranks and TBC level-70 ranks because report
 * domains and partitions can vary while the rotation project is TBC-focused.
 */
export const hunter = {
  name: 'Hunter',
  class: 'Hunter',
  spec: 'Hunter',

  trackedSpells: {
    75: { name: 'Auto Shot', category: 'auto' },

    // TBC core
    34120: { name: 'Steady Shot', category: 'shot' },
    34026: { name: 'Kill Command', category: 'off_gcd' },
    27021: { name: 'Multi-Shot', category: 'shot' },
    27019: { name: 'Arcane Shot', category: 'shot' },
    27065: { name: 'Aimed Shot', category: 'shot' },
    27016: { name: 'Serpent Sting', category: 'sting' },
    27018: { name: 'Viper Sting', category: 'sting' },
    27014: { name: 'Raptor Strike', category: 'melee' },

    // Classic level-60 ranks and common base fallbacks.
    14295: { name: 'Multi-Shot', category: 'shot' },
    2643: { name: 'Multi-Shot', category: 'shot' },
    14287: { name: 'Arcane Shot', category: 'shot' },
    3044: { name: 'Arcane Shot', category: 'shot' },
    20904: { name: 'Aimed Shot', category: 'shot' },
    19434: { name: 'Aimed Shot', category: 'shot' },
    13555: { name: 'Serpent Sting', category: 'sting' },
    1978: { name: 'Serpent Sting', category: 'sting' },
    14266: { name: 'Raptor Strike', category: 'melee' },
    2973: { name: 'Raptor Strike', category: 'melee' },

    // Utility/cooldowns.
    3045: { name: 'Rapid Fire', category: 'cooldown' },
    19574: { name: 'Bestial Wrath', category: 'cooldown' },
    19577: { name: 'Intimidation', category: 'utility' },
    23989: { name: 'Readiness', category: 'cooldown' },
    34490: { name: 'Silencing Shot', category: 'shot' },
    34477: { name: 'Misdirection', category: 'utility' },
    19801: { name: 'Tranquilizing Shot', category: 'utility' },
    14325: { name: "Hunter's Mark", category: 'debuff' },
    14324: { name: "Hunter's Mark", category: 'debuff' },
    1130: { name: "Hunter's Mark", category: 'debuff' },
    19506: { name: 'Trueshot Aura', category: 'buff' },
    27066: { name: 'Trueshot Aura', category: 'buff' },

    // Racial and common on-use casts seen in logs.
    20572: { name: 'Blood Fury', category: 'cooldown' },
    20554: { name: 'Berserking', category: 'cooldown' },
  },

  trackedBuffs: {
    3045: { name: 'Rapid Fire', duration: 15 },
    19574: { name: 'Bestial Wrath', duration: 18 },
    34471: { name: 'The Beast Within', duration: 18 },
    6150: { name: 'Quick Shots', duration: 12 },
    19506: { name: 'Trueshot Aura', duration: 1800 },
    27066: { name: 'Trueshot Aura', duration: 1800 },
    2825: { name: 'Bloodlust', duration: 40 },
    32182: { name: 'Heroism', duration: 40 },
    35476: { name: 'Drums of Battle', duration: 30 },
    28507: { name: 'Haste Potion', duration: 15 },
    20572: { name: 'Blood Fury', duration: 15 },
    20554: { name: 'Berserking', duration: 10 },
  },

  trackedDebuffs: {
    14325: { name: "Hunter's Mark", duration: 120 },
    14324: { name: "Hunter's Mark", duration: 120 },
    1130: { name: "Hunter's Mark", duration: 120 },
    27016: { name: 'Serpent Sting', duration: 15 },
    13555: { name: 'Serpent Sting', duration: 15 },
    1978: { name: 'Serpent Sting', duration: 15 },
    3043: { name: 'Scorpid Sting', duration: 20 },
    27018: { name: 'Viper Sting', duration: 8 },
  },

  cooldownNames: [
    'Rapid Fire',
    'Bestial Wrath',
    'Readiness',
    'Blood Fury',
    'Berserking',
    'Haste Potion',
    'Drums of Battle',
  ],

  comparisonSpells: [
    'Auto Shot',
    'Steady Shot',
    'Aimed Shot',
    'Multi-Shot',
    'Arcane Shot',
    'Kill Command',
    'Serpent Sting',
    'Raptor Strike',
  ],
};

export function hunterSpellName(spellId) {
  return hunter.trackedSpells[spellId]?.name
    || hunter.trackedBuffs[spellId]?.name
    || hunter.trackedDebuffs[spellId]?.name
    || `Spell ${spellId}`;
}
