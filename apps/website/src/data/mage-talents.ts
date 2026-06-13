// TBC 2.4.3 Mage Talent Data
// Icon names reference: https://wow.zamimg.com/images/wow/icons/medium/{icon}.jpg

export const trees = [
  {
    name: "Arcane",
    talents: [
      { name: "Arcane Subtlety", icon: "spell_holy_dispelmagic", maxRank: 2, tier: 1, col: 0, desc: "Reduces your target's resistance to all your spells by 10 and reduces the threat caused by your Arcane spells by 40%." },
      { name: "Arcane Focus", icon: "spell_holy_devotion", maxRank: 5, tier: 1, col: 1, desc: "Reduces the chance that the opponent can resist your Arcane spells by 10%." },
      { name: "Improved Arcane Missiles", icon: "spell_nature_starfall", maxRank: 5, tier: 1, col: 2, desc: "Gives you a 100% chance to avoid interruption caused by damage while channeling Arcane Missiles." },
      { name: "Wand Specialization", icon: "inv_wand_01", maxRank: 2, tier: 2, col: 0, desc: "Increases your damage with Wands by 25%." },
      { name: "Magic Absorption", icon: "spell_nature_astralrecalgroup", maxRank: 5, tier: 2, col: 1, desc: "Increases all resistances by 10 and causes all spells you fully resist to restore 5% of your total mana. 1 sec cooldown." },
      { name: "Arcane Concentration", icon: "spell_shadow_manaburn", maxRank: 5, tier: 2, col: 2, desc: "Gives you a 10% chance of entering a Clearcasting state after any damage spell hits a target. The Clearcasting state reduces the mana cost of your next damage spell by 100%." },
      { name: "Magic Attunement", icon: "spell_nature_abolishmagic", maxRank: 2, tier: 3, col: 0, desc: "Increases the effect of your Amplify Magic and Dampen Magic spells by 50%." },
      { name: "Arcane Impact", icon: "spell_nature_wispsplode", maxRank: 3, tier: 3, col: 1, desc: "Increases the critical strike chance of your Arcane Explosion and Arcane Blast spells by an additional 6%." },
      { name: "Arcane Fortitude", icon: "spell_arcane_arcaneresilience", maxRank: 1, tier: 3, col: 3, desc: "Increases your armor by an amount equal to 100% of your Intellect." },
      { name: "Improved Mana Shield", icon: "spell_shadow_detectlesserinvisibility", maxRank: 2, tier: 4, col: 0, desc: "Decreases the mana lost per point of damage taken when Mana Shield is active by 20%." },
      { name: "Improved Counterspell", icon: "spell_frost_iceshock", maxRank: 2, tier: 4, col: 1, desc: "Gives your Counterspell a 100% chance to silence the target for 4 sec." },
      { name: "Arcane Meditation", icon: "spell_shadow_siphonmana", maxRank: 3, tier: 4, col: 3, desc: "Allows 30% of your mana regeneration to continue while casting." },
      { name: "Improved Blink", icon: "spell_arcane_blink", maxRank: 2, tier: 5, col: 0, desc: "For 4 sec after casting Blink, your chance to be hit by all attacks and spells is reduced by 25%." },
      { name: "Presence of Mind", icon: "spell_nature_enchantarmor", maxRank: 1, tier: 5, col: 1, desc: "When activated, your next Mage spell with a casting time less than 10 sec becomes an instant cast spell. 3 min cooldown." },
      { name: "Arcane Mind", icon: "spell_shadow_charm", maxRank: 5, tier: 5, col: 3, desc: "Increases your total Intellect by 15%." },
      { name: "Prismatic Cloak", icon: "spell_arcane_prismaticcloak", maxRank: 2, tier: 6, col: 0, desc: "Reduces all damage taken by 4%." },
      { name: "Arcane Instability", icon: "spell_shadow_teleport", maxRank: 3, tier: 6, col: 1, desc: "Increases your spell damage and critical strike chance by 3%." },
      { name: "Arcane Potency", icon: "spell_arcane_arcanepotency", maxRank: 3, tier: 6, col: 2, desc: "Increases the critical strike chance of any spell cast while Clearcasting by 30%." },
      { name: "Empowered Arcane Missiles", icon: "spell_nature_starfall", maxRank: 3, tier: 7, col: 0, desc: "Your Arcane Missiles spell gains an additional 45% of your bonus spell damage effects, but the mana cost is increased by 6%." },
      { name: "Arcane Power", icon: "spell_nature_lightning", maxRank: 1, tier: 7, col: 1, desc: "When activated, your spells deal 30% more damage while costing 30% more mana to cast. This effect lasts 15 sec. 3 min cooldown." },
      { name: "Spell Power", icon: "spell_arcane_arcanetorrent", maxRank: 2, tier: 7, col: 2, desc: "Increases critical strike damage bonus of all spells by 50%." },
      { name: "Mind Mastery", icon: "spell_arcane_mindmastery", maxRank: 5, tier: 8, col: 1, desc: "Increases spell damage by up to 25% of your total Intellect." },
      { name: "Slow", icon: "spell_nature_slow", maxRank: 1, tier: 9, col: 1, desc: "Reduces target's movement speed by 50%, increases the time between ranged attacks by 50% and increases casting time by 50%. Lasts 15 sec." },
    ],
  },
  {
    name: "Fire",
    talents: [
      { name: "Improved Fireball", icon: "spell_fire_flamebolt", maxRank: 5, tier: 1, col: 1, desc: "Reduces the casting time of your Fireball spell by 0.5 sec." },
      { name: "Impact", icon: "spell_fire_meteorstorm", maxRank: 5, tier: 1, col: 2, desc: "Gives your Fire spells a 10% chance to stun the target for 2 sec." },
      { name: "Ignite", icon: "spell_fire_incinerate", maxRank: 5, tier: 2, col: 0, desc: "Your critical strikes from Fire damage spells cause the target to burn for an additional 40% of your spell's damage over 4 sec." },
      { name: "Flame Throwing", icon: "spell_fire_flare", maxRank: 2, tier: 2, col: 1, desc: "Increases the range of your Fire spells by 6 yards." },
      { name: "Improved Fire Blast", icon: "spell_fire_fireball", maxRank: 3, tier: 2, col: 2, desc: "Reduces the cooldown of your Fire Blast spell by 1.5 sec." },
      { name: "Incineration", icon: "spell_fire_flameshock", maxRank: 2, tier: 3, col: 0, desc: "Increases the critical strike chance of your Fire Blast and Scorch spells by 4%." },
      { name: "Improved Flamestrike", icon: "spell_fire_selfdestruct", maxRank: 3, tier: 3, col: 1, desc: "Increases the critical strike chance of your Flamestrike spell by 15%." },
      { name: "Pyroblast", icon: "spell_fire_fireball02", maxRank: 1, tier: 3, col: 2, desc: "Hurls an immense fiery boulder that causes Fire damage and an additional Fire damage over 12 sec." },
      { name: "Burning Soul", icon: "spell_fire_fire", maxRank: 2, tier: 3, col: 3, desc: "Gives your Fire spells a 70% chance to not lose casting time when you take damage and reduces the threat caused by your Fire spells by 10%." },
      { name: "Improved Scorch", icon: "spell_fire_soulburn", maxRank: 3, tier: 4, col: 0, desc: "Your Scorch spells have a 100% chance to cause your target to be vulnerable to Fire damage. This vulnerability increases the Fire damage dealt to your target by 3% and lasts 30 sec. Stacks up to 5 times." },
      { name: "Molten Shields", icon: "spell_fire_firearmor", maxRank: 2, tier: 4, col: 1, desc: "Causes your Fire Ward to have a 20% chance to reflect Fire spells while active. In addition, your Molten Armor has a 100% chance to affect ranged and spell attacks." },
      { name: "Master of Elements", icon: "spell_fire_masterofelements", maxRank: 3, tier: 4, col: 3, desc: "Your Fire and Frost spell criticals will refund 30% of their base mana cost." },
      { name: "Playing with Fire", icon: "spell_fire_playingwithfire", maxRank: 3, tier: 5, col: 0, desc: "Increases all spell damage caused by 3% and all spell damage taken by 3%." },
      { name: "Critical Mass", icon: "spell_nature_wispheal", maxRank: 3, tier: 5, col: 1, desc: "Increases the critical strike chance of your Fire spells by 6%." },
      { name: "Blast Wave", icon: "spell_holy_excorcism_02", maxRank: 1, tier: 5, col: 2, desc: "A wave of flame radiates outward from the caster, damaging all enemies caught within the blast for Fire damage, and dazing them for 6 sec." },
      { name: "Blazing Speed", icon: "spell_fire_burningspeed", maxRank: 2, tier: 6, col: 0, desc: "Gives you a 10% chance when hit by a melee or ranged attack to increase your movement speed by 50% and dispel all movement impairing effects. This effect lasts 8 sec." },
      { name: "Fire Power", icon: "spell_fire_immolation", maxRank: 5, tier: 6, col: 2, desc: "Increases the damage done by your Fire spells by 10%." },
      { name: "Pyromaniac", icon: "spell_fire_burnout", maxRank: 3, tier: 7, col: 0, desc: "Increases chance to critically hit and reduces the mana cost of all Fire spells by 3%." },
      { name: "Combustion", icon: "spell_fire_sealoffire", maxRank: 1, tier: 7, col: 1, desc: "When activated, this spell causes each of your Fire damage spell hits to increase your critical strike chance with Fire damage spells by 10%. This effect lasts until you have caused 3 critical strikes with Fire spells." },
      { name: "Molten Fury", icon: "spell_fire_moltenblood", maxRank: 2, tier: 7, col: 2, desc: "Increases damage of all spells against targets with less than 20% health by 20%." },
      { name: "Empowered Fireball", icon: "spell_fire_flamebolt", maxRank: 5, tier: 8, col: 2, desc: "Your Fireball spell gains an additional 15% of your bonus spell damage effects." },
      { name: "Dragon's Breath", icon: "inv_misc_head_dragon_01", maxRank: 1, tier: 9, col: 1, desc: "Targets in a cone in front of the caster take Fire damage and are Disoriented for 3 sec. Any direct damaging attack will revive targets." },
    ],
  },
  {
    name: "Frost",
    talents: [
      { name: "Frost Warding", icon: "spell_frost_frostward", maxRank: 2, tier: 1, col: 0, desc: "Increases the armor and resistances given by your Frost Armor and Ice Armor spells by 30%. In addition, gives your Frost Ward a 20% chance to reflect Frost spells and effects while active." },
      { name: "Improved Frostbolt", icon: "spell_frost_frostbolt02", maxRank: 5, tier: 1, col: 1, desc: "Reduces the casting time of your Frostbolt spell by 0.5 sec." },
      { name: "Elemental Precision", icon: "spell_ice_magicdamage", maxRank: 3, tier: 1, col: 2, desc: "Reduces the mana cost and chance targets resist your Frost and Fire spells by 3%." },
      { name: "Ice Shards", icon: "spell_frost_iceshard", maxRank: 5, tier: 2, col: 0, desc: "Increases the critical strike damage bonus of your Frost spells by 100%." },
      { name: "Frostbite", icon: "spell_frost_frostarmor", maxRank: 3, tier: 2, col: 1, desc: "Gives your Chill effects a 15% chance to freeze the target for 5 sec." },
      { name: "Improved Frost Nova", icon: "spell_frost_freezingbreath", maxRank: 2, tier: 2, col: 2, desc: "Reduces the cooldown of your Frost Nova spell by 4 sec." },
      { name: "Permafrost", icon: "spell_frost_wisp", maxRank: 3, tier: 2, col: 3, desc: "Increases the duration of your Chill effects by 3 sec and reduces the target's speed by an additional 10%." },
      { name: "Piercing Ice", icon: "spell_frost_frostbolt", maxRank: 3, tier: 3, col: 0, desc: "Increases damage done by your Frost spells by 6%." },
      { name: "Icy Veins", icon: "spell_frost_coldhearted", maxRank: 1, tier: 3, col: 1, desc: "Hastens your spellcasting, increasing spell casting speed by 20% and gives you 100% chance to avoid interruption caused by damage while casting. Lasts 20 sec." },
      { name: "Improved Blizzard", icon: "spell_frost_icestorm", maxRank: 3, tier: 3, col: 3, desc: "Adds a chill effect to your Blizzard spell. This effect lowers the target's movement speed by 65%. Lasts 1.5 sec." },
      { name: "Arctic Reach", icon: "spell_shadow_darkritual", maxRank: 2, tier: 4, col: 0, desc: "Increases the range of your Frostbolt, Ice Lance, and Blizzard spells and the radius of your Frost Nova and Cone of Cold spells by 20%." },
      { name: "Frost Channeling", icon: "spell_frost_stun", maxRank: 3, tier: 4, col: 1, desc: "Reduces the mana cost of your Frost spells by 15% and reduces the threat caused by your Frost spells by 10%." },
      { name: "Shatter", icon: "spell_frost_frostshock", maxRank: 5, tier: 4, col: 2, desc: "Increases the critical strike chance of all your spells against frozen targets by 50%." },
      { name: "Frozen Core", icon: "spell_frost_frozencore", maxRank: 3, tier: 5, col: 0, desc: "Reduces the damage taken by Frost and Fire effects by 6%." },
      { name: "Cold Snap", icon: "spell_frost_wizardmark", maxRank: 1, tier: 5, col: 1, desc: "When activated, this spell finishes the cooldown on all Frost spells you recently cast." },
      { name: "Improved Cone of Cold", icon: "spell_frost_glacier", maxRank: 3, tier: 5, col: 2, desc: "Increases the damage dealt by your Cone of Cold spell by 35%." },
      { name: "Ice Floes", icon: "spell_frost_icefloes", maxRank: 2, tier: 6, col: 0, desc: "Reduces the cooldown of your Cone of Cold, Cold Snap, Ice Barrier, and Ice Block spells by 20%." },
      { name: "Winter's Chill", icon: "spell_frost_chillingblast", maxRank: 5, tier: 6, col: 2, desc: "Gives your Frost damage spells a 100% chance to apply the Winter's Chill effect, which increases the chance a Frost spell will critically hit the target by 2% for 15 sec. Stacks up to 5 times." },
      { name: "Ice Barrier", icon: "spell_ice_lament", maxRank: 1, tier: 7, col: 1, desc: "Instantly shields you, absorbing 1075 damage. Lasts 1 min. While the shield holds, spells will not be interrupted." },
      { name: "Arctic Winds", icon: "spell_frost_arcticwinds", maxRank: 5, tier: 7, col: 2, desc: "Increases all Frost damage you cause by 5% and reduces the chance melee and ranged attacks will hit you by 5%." },
      { name: "Empowered Frostbolt", icon: "spell_frost_frostbolt02", maxRank: 5, tier: 8, col: 1, desc: "Your Frostbolt spell gains an additional 10% of your bonus spell damage effects and an additional 5% chance to critically strike." },
      { name: "Summon Water Elemental", icon: "spell_frost_summonwaterelemental_2", maxRank: 1, tier: 9, col: 1, desc: "Summon a Water Elemental to fight for the caster for 45 sec." },
    ],
  },
];

// Preset talent builds
export const presets = [
  {
    name: "Standard Fire PvE",
    slug: "fire",
    spec: "2/48/11",
    points: [
      // Arcane (23 talents) — 2 pts: Arcane Subtlety 2
      [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Fire (22 talents) — 48 pts: deep fire with Dragon's Breath
      [5, 1, 5, 2, 0, 2, 0, 1, 2, 3, 0, 3, 3, 3, 1, 0, 5, 3, 1, 2, 5, 1],
      // Frost (22 talents) — 11 pts: Improved Frostbolt 5, Elemental Precision 3, Ice Shards 2, Icy Veins 1
      [0, 5, 3, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard Frost PvE",
    slug: "frost",
    spec: "10/0/51",
    points: [
      // Arcane (23 talents) — 10 pts: Arcane Subtlety 2, Arcane Focus 3, Arcane Concentration 5
      [2, 3, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Fire (22 talents — all 0)
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Frost (22 talents) — 51 pts: deep frost with Water Elemental
      [0, 5, 3, 5, 0, 0, 1, 3, 1, 0, 2, 3, 5, 0, 1, 3, 2, 5, 1, 5, 5, 1],
    ],
  },
  {
    name: "Standard Arcane PvE",
    slug: "arcane",
    spec: "40/0/21",
    points: [
      // Arcane (23 talents) — 40 pts: deep arcane with Slow
      [2, 3, 0, 0, 0, 5, 0, 3, 1, 0, 2, 3, 0, 1, 5, 0, 3, 3, 0, 1, 2, 5, 1],
      // Fire (22 talents — all 0)
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Frost (22 talents) — 21 pts: Improved Frostbolt 5, Elemental Precision 3, Ice Shards 5, Permafrost 3, Piercing Ice 3, Icy Veins 1, Cold Snap 1
      [0, 5, 3, 5, 0, 0, 3, 3, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
];
