// TBC 2.4.3 Rogue Talent Data
// Icon names reference: https://wow.zamimg.com/images/wow/icons/medium/{icon}.jpg

export const trees = [
  {
    name: "Assassination",
    talents: [
      { name: "Improved Eviscerate", icon: "ability_rogue_eviscerate", maxRank: 3, tier: 1, col: 0, desc: "Increases the damage done by your Eviscerate ability by 15%." },
      { name: "Remorseless Attacks", icon: "ability_fiegndead", maxRank: 2, tier: 1, col: 1, desc: "After killing an opponent that yields experience or honor, gives you a 40% increased critical strike chance on your next Sinister Strike, Backstab, Ambush, or Ghostly Strike. Lasts 20 sec." },
      { name: "Malice", icon: "ability_racial_bloodrage", maxRank: 5, tier: 1, col: 2, desc: "Increases your critical strike chance by 5%." },
      { name: "Ruthlessness", icon: "ability_druid_disembowel", maxRank: 3, tier: 2, col: 0, desc: "Gives your finishing moves a 60% chance to add a combo point to your target." },
      { name: "Murder", icon: "spell_shadow_deathpact", maxRank: 2, tier: 2, col: 1, desc: "Increases all damage caused by 2%." },
      { name: "Puncturing Wounds", icon: "ability_backstab", maxRank: 3, tier: 2, col: 3, desc: "Increases the critical strike chance of your Backstab ability by 30% and the critical strike chance of your Mutilate ability by 15%." },
      { name: "Relentless Strikes", icon: "ability_warrior_decisivestrike", maxRank: 1, tier: 3, col: 0, desc: "Your finishing moves have a 20% chance per combo point to restore 25 energy." },
      { name: "Improved Expose Armor", icon: "ability_warrior_riposte", maxRank: 2, tier: 3, col: 1, desc: "Reduces the energy cost of your Expose Armor ability by 10." },
      { name: "Lethality", icon: "ability_criticalstrike", maxRank: 5, tier: 3, col: 2, desc: "Increases the critical strike damage bonus of your Sinister Strike, Gouge, Backstab, Ghostly Strike, Mutilate, and Hemorrhage abilities by 30%." },
      { name: "Vile Poisons", icon: "ability_rogue_feigndeath", maxRank: 5, tier: 4, col: 1, desc: "Increases the damage dealt by your poisons by 20% and gives your Envenom ability a 100% chance of applying Instant Poison to the target." },
      { name: "Improved Poisons", icon: "ability_poisons", maxRank: 5, tier: 4, col: 2, desc: "Increases the chance to apply poisons to your target by 10%." },
      { name: "Fleet Footed", icon: "ability_rogue_fleetfooted", maxRank: 2, tier: 5, col: 0, desc: "Increases your movement speed by 8% and increases your chance to resist movement impairing effects by 25%." },
      { name: "Cold Blood", icon: "spell_ice_lament", maxRank: 1, tier: 5, col: 1, desc: "When activated, increases the critical strike chance of your next offensive ability by 100%." },
      { name: "Improved Kidney Shot", icon: "ability_rogue_kidneyshot", maxRank: 3, tier: 5, col: 2, desc: "While affected by your Kidney Shot ability, the target receives an additional 9% damage from all sources." },
      { name: "Quick Recovery", icon: "ability_rogue_quickrecovery", maxRank: 2, tier: 5, col: 3, desc: "All healing effects on you are increased by 20%. In addition, your finishing moves cost 80% less Energy when they fail to hit." },
      { name: "Seal Fate", icon: "spell_shadow_chilltouch", maxRank: 5, tier: 6, col: 1, desc: "Your critical strikes from abilities that add combo points have a 100% chance to add an additional combo point." },
      { name: "Master Poisoner", icon: "ability_poisonsting", maxRank: 2, tier: 6, col: 2, desc: "Reduces the chance your poisons will be resisted by 10% and reduces the duration of all Poison effects applied to you by 50%." },
      { name: "Vigor", icon: "spell_nature_earthbindtotem", maxRank: 1, tier: 7, col: 1, desc: "Increases your maximum Energy by 10." },
      { name: "Deadened Nerves", icon: "ability_rogue_deadenednerves", maxRank: 5, tier: 7, col: 2, desc: "Reduces all damage taken by 5%." },
      { name: "Find Weakness", icon: "ability_rogue_findweakness", maxRank: 5, tier: 8, col: 1, desc: "Your finishing moves increase the damage of all offensive abilities by 10% for 10 sec." },
      { name: "Mutilate", icon: "ability_rogue_shadowstrikes", maxRank: 1, tier: 9, col: 1, desc: "Instantly attacks with both weapons for an additional 101 with each weapon. Damage is increased by 50% against Poisoned targets. Awards 2 combo points." },
    ],
  },
  {
    name: "Combat",
    talents: [
      { name: "Improved Gouge", icon: "ability_gouge", maxRank: 3, tier: 1, col: 0, desc: "Increases the effect duration of your Gouge ability by 1.5 sec." },
      { name: "Improved Sinister Strike", icon: "spell_shadow_ritualofsacrifice", maxRank: 2, tier: 1, col: 1, desc: "Reduces the Energy cost of your Sinister Strike ability by 5." },
      { name: "Lightning Reflexes", icon: "spell_nature_invisibilty", maxRank: 3, tier: 1, col: 2, desc: "Increases your Dodge chance by 3%." },
      { name: "Improved Backstab", icon: "ability_backstab", maxRank: 3, tier: 2, col: 0, desc: "Increases the critical strike chance of your Backstab ability by 30%." },
      { name: "Deflection", icon: "ability_parry", maxRank: 5, tier: 2, col: 1, desc: "Increases your Parry chance by 5%." },
      { name: "Precision", icon: "ability_marksmanship", maxRank: 5, tier: 2, col: 2, desc: "Increases your chance to hit with melee weapons by 5%." },
      { name: "Endurance", icon: "spell_shadow_shadowward", maxRank: 2, tier: 3, col: 0, desc: "Reduces the cooldown of your Sprint and Evasion abilities by 1 min and increases your total Stamina by 4%." },
      { name: "Riposte", icon: "ability_warrior_challengingroar", maxRank: 1, tier: 3, col: 1, desc: "A strike that becomes active after parrying an opponent's attack. This deals 150% weapon damage and disarms the target for 6 sec." },
      { name: "Close Quarters Combat", icon: "inv_weapon_07", maxRank: 5, tier: 3, col: 2, desc: "Increases your chance to get a critical strike with Daggers and Fist Weapons by 5%." },
      { name: "Improved Kick", icon: "ability_kick", maxRank: 2, tier: 4, col: 0, desc: "Gives your Kick ability a 100% chance to silence the target for 2 sec." },
      { name: "Dual Wield Specialization", icon: "ability_dualwield", maxRank: 5, tier: 4, col: 1, desc: "Increases the damage done by your offhand weapon by 50%." },
      { name: "Improved Sprint", icon: "ability_rogue_sprint", maxRank: 2, tier: 4, col: 2, desc: "Gives a 50% chance to remove all movement impairing effects when you activate your Sprint ability." },
      { name: "Blade Flurry", icon: "ability_warrior_punishingblow", maxRank: 1, tier: 5, col: 0, desc: "Increases your attack speed by 20%. In addition, attacks strike an additional nearby opponent. Lasts 15 sec." },
      { name: "Hack and Slash", icon: "inv_sword_30", maxRank: 5, tier: 5, col: 1, desc: "Gives you a 5% chance to get an extra attack on the same target after dealing damage with your Swords or Axes." },
      { name: "Mace Specialization", icon: "inv_mace_01", maxRank: 5, tier: 5, col: 2, desc: "Your attacks with Maces ignore up to 15 of your opponent's armor." },
      { name: "Weapon Expertise", icon: "spell_holy_blessingofstrength", maxRank: 2, tier: 6, col: 0, desc: "Increases your expertise by 10." },
      { name: "Aggression", icon: "ability_racial_avatar", maxRank: 5, tier: 6, col: 2, desc: "Increases the damage of your Sinister Strike, Backstab, and Eviscerate abilities by 6%." },
      { name: "Adrenaline Rush", icon: "spell_shadow_shadowworddominate", maxRank: 1, tier: 7, col: 1, desc: "Increases your Energy regeneration rate by 100% for 15 sec." },
      { name: "Vitality", icon: "inv_relics_totemofrage", maxRank: 2, tier: 7, col: 2, desc: "Increases your total Stamina by 4% and your total Agility by 4%." },
      { name: "Combat Potency", icon: "inv_weapon_shortblade_38", maxRank: 5, tier: 8, col: 1, desc: "Gives your successful off-hand melee attacks a 20% chance to generate 15 Energy." },
      { name: "Surprise Attacks", icon: "ability_rogue_surpriseattack", maxRank: 1, tier: 9, col: 1, desc: "Your finishing moves can no longer be dodged, and the damage dealt by your Sinister Strike, Backstab, Shiv and Gouge abilities is increased by 10%." },
    ],
  },
  {
    name: "Subtlety",
    talents: [
      { name: "Master of Deception", icon: "spell_shadow_charm", maxRank: 5, tier: 1, col: 0, desc: "Reduces the chance enemies have to detect you while in Stealth mode." },
      { name: "Opportunity", icon: "ability_warrior_warcry", maxRank: 5, tier: 1, col: 1, desc: "Increases the damage dealt when striking from behind with your Backstab, Mutilate, Garrote and Ambush abilities by 20%." },
      { name: "Sleight of Hand", icon: "ability_rogue_feint", maxRank: 2, tier: 2, col: 0, desc: "Reduces the chance you are critically hit by melee and ranged attacks by 2% and increases the threat reduction of your Feint ability by 20%." },
      { name: "Dirty Tricks", icon: "spell_shadow_curse", maxRank: 2, tier: 2, col: 1, desc: "Increases the range of your Blind and Sap abilities by 5 yards and reduces the energy cost of your Blind and Sap abilities by 50%." },
      { name: "Camouflage", icon: "ability_stealth", maxRank: 5, tier: 2, col: 2, desc: "Increases your speed while stealthed by 15% and reduces the cooldown of your Stealth ability by 5 sec." },
      { name: "Elusiveness", icon: "spell_magic_lesserinvisibilty", maxRank: 2, tier: 3, col: 0, desc: "Reduces the cooldown of your Vanish and Blind abilities by 90 sec and your Cloak of Shadows ability by 30 sec." },
      { name: "Ghostly Strike", icon: "spell_shadow_curse", maxRank: 1, tier: 3, col: 1, desc: "A strike that deals 125% weapon damage and increases your chance to dodge by 15% for 7 sec. Awards 1 combo point." },
      { name: "Serrated Blades", icon: "inv_sword_17", maxRank: 3, tier: 3, col: 2, desc: "Causes your attacks to ignore 560 of your target's Armor and increases the damage dealt by your Rupture ability by 30%." },
      { name: "Setup", icon: "spell_nature_mirrorimage", maxRank: 3, tier: 4, col: 0, desc: "Gives you a 45% chance to add a combo point to your target after dodging their attack or fully resisting one of their spells." },
      { name: "Initiative", icon: "spell_shadow_fumble", maxRank: 3, tier: 4, col: 1, desc: "Gives you a 75% chance to add an additional combo point to your target when using your Ambush, Garrote, or Cheap Shot ability." },
      { name: "Improved Ambush", icon: "ability_rogue_ambush", maxRank: 3, tier: 4, col: 2, desc: "Increases the critical strike chance of your Ambush ability by 45%." },
      { name: "Heightened Senses", icon: "ability_ambush", maxRank: 2, tier: 5, col: 0, desc: "Increases your Stealth detection and reduces the chance you are hit by spells and ranged attacks by 4%." },
      { name: "Preparation", icon: "spell_shadow_antishadow", maxRank: 1, tier: 5, col: 1, desc: "When activated, this ability immediately finishes the cooldown on your Evasion, Sprint, Vanish, Cold Blood, Shadowstep and Premeditation abilities." },
      { name: "Dirty Deeds", icon: "spell_shadow_auraofdarkness", maxRank: 2, tier: 5, col: 2, desc: "Reduces the Energy cost of your Cheap Shot and Garrote abilities by 20. Additionally, your special abilities cause 20% more damage against targets below 35% health." },
      { name: "Hemorrhage", icon: "spell_shadow_lifedrain", maxRank: 1, tier: 5, col: 3, desc: "An instant strike that deals 110% weapon damage and causes the target to hemorrhage, increasing any Physical damage dealt to the target by up to 42. Lasts 10 charges. Awards 1 combo point." },
      { name: "Master of Subtlety", icon: "ability_rogue_masterofsubtlety", maxRank: 3, tier: 6, col: 0, desc: "Attacks made while stealthed and for 6 sec after breaking stealth cause an additional 10% damage." },
      { name: "Deadliness", icon: "inv_weapon_crossbow_11", maxRank: 5, tier: 6, col: 2, desc: "Increases your attack power by 10%." },
      { name: "Premeditation", icon: "spell_shadow_possession", maxRank: 1, tier: 7, col: 0, desc: "When used, adds 2 combo points to your target. You must add to or use those combo points within 10 sec or the combo points are lost. Must be stealthed." },
      { name: "Enveloping Shadows", icon: "ability_rogue_envelopingshadows", maxRank: 3, tier: 7, col: 1, desc: "Reduces the damage taken by Ambush, Backstab, and Hemorrhage abilities by 30%." },
      { name: "Sinister Calling", icon: "ability_rogue_sinistercalling", maxRank: 5, tier: 8, col: 1, desc: "Increases your total Agility by 15% and increases the percentage damage bonus of your Backstab and Hemorrhage abilities by 10%." },
      { name: "Shadowstep", icon: "ability_rogue_shadowstep", maxRank: 1, tier: 9, col: 1, desc: "Attempts to step through the shadows and reappear behind your enemy target. Your next ability within 10 sec will deal 20% increased damage." },
    ],
  },
];

// Preset talent builds
export const presets = [
  {
    name: "Standard Combat PvE",
    slug: "combat",
    spec: "15/41/5",
    points: [
      // Assassination (21 talents) — 15 pts: Malice 5, Ruthlessness 3, Murder 2, Relentless Strikes 1, Lethality 4
      [0, 0, 5, 3, 2, 0, 1, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Combat (21 talents) — 41 pts: deep Combat with Surprise Attacks
      [0, 2, 3, 0, 5, 5, 2, 0, 5, 2, 5, 0, 1, 5, 0, 2, 0, 1, 0, 2, 1],
      // Subtlety (21 talents) — 5 pts: Camouflage 5
      [0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard Assassination PvE",
    slug: "assassination",
    spec: "41/20/0",
    points: [
      // Assassination (21 talents) — 41 pts: deep Assassination with Mutilate
      [0, 2, 5, 3, 2, 3, 1, 0, 5, 5, 5, 0, 1, 0, 0, 5, 0, 1, 0, 2, 1],
      // Combat (21 talents) — 20 pts: Improved Sinister Strike 2, Lightning Reflexes 3, Deflection 5, Precision 5, Dual Wield Specialization 5
      [0, 2, 3, 0, 5, 5, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Subtlety (21 talents) — 0 pts
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard Subtlety PvE",
    slug: "subtlety",
    spec: "16/5/40",
    points: [
      // Assassination (21 talents) — 16 pts: Malice 5, Murder 2, Relentless Strikes 1, Lethality 5, Remorseless Attacks 2, Improved Eviscerate 1
      [1, 2, 5, 0, 2, 0, 1, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Combat (21 talents) — 5 pts: Precision 5
      [0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Subtlety (21 talents) — 40 pts: deep Subtlety with Shadowstep
      [5, 5, 2, 0, 5, 0, 1, 3, 0, 3, 0, 0, 1, 2, 1, 3, 5, 1, 0, 3, 0],
    ],
  },
];
