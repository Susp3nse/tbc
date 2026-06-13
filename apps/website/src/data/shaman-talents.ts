// TBC 2.4.3 Shaman Talent Data
// Icon names reference: https://wow.zamimg.com/images/wow/icons/medium/{icon}.jpg

export const trees = [
  {
    name: "Elemental",
    talents: [
      { name: "Convection", icon: "spell_nature_wispsplode", maxRank: 5, tier: 1, col: 1, desc: "Reduces the mana cost of your Shock, Lightning Bolt and Chain Lightning spells by 10%." },
      { name: "Concussion", icon: "spell_fire_fireball", maxRank: 5, tier: 1, col: 2, desc: "Increases the damage done by your Lightning Bolt, Chain Lightning and Shock spells by 5%." },
      { name: "Call of Flame", icon: "spell_fire_immolation", maxRank: 3, tier: 2, col: 0, desc: "Increases the damage done by your Fire Totems by 15%." },
      { name: "Elemental Warding", icon: "spell_nature_spiritarmor", maxRank: 3, tier: 2, col: 1, desc: "Reduces damage taken from Fire, Frost, and Nature effects by 6%." },
      { name: "Call of Thunder", icon: "spell_nature_callstorm", maxRank: 5, tier: 2, col: 2, desc: "Increases the critical strike chance of your Lightning Bolt and Chain Lightning spells by an additional 5%." },
      { name: "Elemental Focus", icon: "spell_shadow_manaburn", maxRank: 1, tier: 3, col: 0, desc: "After landing a critical strike with a Fire, Frost, or Nature damage spell, you enter a Clearcasting state. The Clearcasting state reduces the mana cost of your next 2 damage spells by 40%." },
      { name: "Reverberation", icon: "spell_frost_frostward", maxRank: 5, tier: 3, col: 1, desc: "Reduces the cooldown of your Shock spells by 1 sec." },
      { name: "Eye of the Storm", icon: "spell_nature_eyeofthestorm", maxRank: 3, tier: 3, col: 3, desc: "Gives you a 100% chance to avoid interruption caused by damage while casting Lightning Bolt, Chain Lightning, or Lava Burst spells." },
      { name: "Elemental Devastation", icon: "spell_fire_elementaldevastation", maxRank: 3, tier: 4, col: 0, desc: "Your offensive spell crits will increase your chance to get a critical strike with melee attacks by 9% for 10 sec." },
      { name: "Storm Reach", icon: "spell_nature_stormreach", maxRank: 2, tier: 4, col: 2, desc: "Increases the range of your Lightning Bolt and Chain Lightning spells by 6 yards." },
      { name: "Elemental Fury", icon: "spell_fire_volcano", maxRank: 1, tier: 4, col: 3, desc: "Increases the critical strike damage bonus of your Searing, Magma, and Fire Nova Totems and your Fire, Frost, and Nature spells by 100%." },
      { name: "Unrelenting Storm", icon: "spell_nature_unrelentingstorm", maxRank: 5, tier: 5, col: 0, desc: "Regenerate mana equal to 12% of your Intellect every 5 sec, even while casting." },
      { name: "Elemental Precision", icon: "spell_nature_elementalprecision_1", maxRank: 3, tier: 5, col: 2, desc: "Increases your chance to hit with Fire, Frost, and Nature spells by 3% and reduces the threat caused by Fire, Frost, and Nature spells by 10%." },
      { name: "Lightning Mastery", icon: "spell_lightning_lightningbolt01", maxRank: 5, tier: 6, col: 0, desc: "Reduces the cast time of your Lightning Bolt and Chain Lightning spells by 1 sec." },
      { name: "Elemental Mastery", icon: "spell_nature_wispheal", maxRank: 1, tier: 6, col: 1, desc: "When activated, your next Lightning Bolt, Chain Lightning, or Lava Burst spell becomes an instant cast spell. In addition, you gain 15% spell critical strike chance for 15 sec. Elemental Mastery shares a cooldown with Nature's Swiftness." },
      { name: "Elemental Shields", icon: "spell_nature_skinofearth", maxRank: 3, tier: 6, col: 2, desc: "Reduces the chance you will be critically hit by melee and ranged attacks by 2% and reduces all damage taken by Lightning Shield by 15%." },
      { name: "Lightning Overload", icon: "spell_nature_lightningoverload", maxRank: 5, tier: 7, col: 1, desc: "Gives your Lightning Bolt and Chain Lightning spells a 20% chance to cast a second, similar spell on the same target at no additional cost that causes half damage and no threat." },
      { name: "Totem of Wrath", icon: "spell_fire_totemofwrath", maxRank: 1, tier: 8, col: 1, desc: "Summons a Totem of Wrath with 5 health at the feet of the caster. The totem increases spell critical strike chance by 3% and spell damage done by 10% for all party and raid members, and increases the chance that enemies within range will be hit by spells by 3%. Lasts 2 min." },
    ],
  },
  {
    name: "Enhancement",
    talents: [
      { name: "Ancestral Knowledge", icon: "spell_shadow_grimward", maxRank: 5, tier: 1, col: 0, desc: "Increases your maximum Mana by 5%." },
      { name: "Shield Specialization", icon: "inv_shield_06", maxRank: 5, tier: 1, col: 2, desc: "Increases your chance to block attacks with a shield by 5% and increases the amount blocked by 5%." },
      { name: "Guardian Totems", icon: "spell_nature_stoneskintotem", maxRank: 2, tier: 2, col: 0, desc: "Increases the amount of damage reduced by your Stoneskin Totem and Windwall Totem by 20% and reduces the cooldown of your Grounding Totem by 2 sec." },
      { name: "Thundering Strikes", icon: "ability_thunderbolt", maxRank: 5, tier: 2, col: 1, desc: "Improves your chance to get a critical strike with your weapon attacks by 5%." },
      { name: "Improved Ghost Wolf", icon: "spell_nature_spiritwolf", maxRank: 2, tier: 2, col: 2, desc: "Reduces the cast time of your Ghost Wolf spell by 2 sec." },
      { name: "Improved Lightning Shield", icon: "spell_nature_lightningshield", maxRank: 3, tier: 2, col: 3, desc: "Increases the damage dealt by your Lightning Shield orbs by 15%." },
      { name: "Enhancing Totems", icon: "spell_nature_earthbindtotem", maxRank: 2, tier: 3, col: 0, desc: "Increases the effect of your Strength of Earth and Grace of Air Totems by 15%." },
      { name: "Shamanistic Focus", icon: "spell_nature_elementalabsorption", maxRank: 1, tier: 3, col: 2, desc: "After landing a melee critical strike, you enter a Focused state. The Focused state reduces the mana cost of your next Shock spell by 60%." },
      { name: "Anticipation", icon: "spell_nature_mirrorimage", maxRank: 5, tier: 3, col: 3, desc: "Increases your chance to dodge by an additional 5%." },
      { name: "Flurry", icon: "ability_ghoulfrenzy", maxRank: 5, tier: 4, col: 1, desc: "Increases your attack speed by 30% for your next 3 swings after dealing a critical strike." },
      { name: "Toughness", icon: "spell_holy_devotion", maxRank: 5, tier: 4, col: 2, desc: "Increases your armor value from items by 10%." },
      { name: "Improved Weapon Totems", icon: "spell_fire_enchantweapon", maxRank: 2, tier: 5, col: 0, desc: "Increases the melee attack power bonus of your Windfury Totem by 30% and increases the spell damage effect of your Flametongue Totem by 12%." },
      { name: "Spirit Weapons", icon: "ability_parry", maxRank: 1, tier: 5, col: 1, desc: "Gives a chance to parry enemy melee attacks and reduces all threat generated by 30%." },
      { name: "Elemental Weapons", icon: "spell_fire_flametounge", maxRank: 3, tier: 5, col: 2, desc: "Increases the melee attack power bonus of your Rockbiter Weapon by 20%, your Windfury Weapon effect by 40%, and increases the damage caused by your Flametongue Weapon and Frostbrand Weapon by 15%." },
      { name: "Mental Quickness", icon: "spell_nature_mentalquickness", maxRank: 3, tier: 6, col: 0, desc: "Reduces the mana cost of your instant cast spells by 6% and increases your spell damage and healing equal to 30% of your attack power." },
      { name: "Stormstrike", icon: "spell_holy_sealofmight", maxRank: 1, tier: 6, col: 1, desc: "Instantly attack with both weapons. In addition, the next 2 sources of Nature damage dealt to the target are increased by 20%. Lasts 12 sec." },
      { name: "Weapon Mastery", icon: "ability_hunter_swiftstrike", maxRank: 5, tier: 6, col: 2, desc: "Increases the damage you deal with all weapons by 10%." },
      { name: "Dual Wield Specialization", icon: "ability_dualwield", maxRank: 3, tier: 7, col: 0, desc: "Increases your chance to hit while dual wielding by an additional 6%." },
      { name: "Dual Wield", icon: "ability_dualwieldspecialization", maxRank: 1, tier: 7, col: 1, desc: "Allows one-hand and off-hand weapons to be equipped in the off-hand." },
      { name: "Unleashed Rage", icon: "spell_nature_unleashedrage", maxRank: 5, tier: 7, col: 2, desc: "Causes your critical hits with melee attacks to increase all party members' melee attack power by 10% if within 20 yards of the Shaman. Lasts 10 sec." },
      { name: "Shamanistic Rage", icon: "spell_nature_shamanrage", maxRank: 1, tier: 8, col: 1, desc: "Reduces all damage taken by 30% and gives your successful melee attacks a chance to regenerate mana equal to 30% of your attack power. Lasts 15 sec." },
    ],
  },
  {
    name: "Restoration",
    talents: [
      { name: "Improved Healing Wave", icon: "spell_nature_magicimmunity", maxRank: 5, tier: 1, col: 1, desc: "Reduces the casting time of your Healing Wave spell by 0.5 sec." },
      { name: "Tidal Focus", icon: "spell_frost_manarecharge", maxRank: 5, tier: 1, col: 2, desc: "Reduces the Mana cost of your healing spells by 5%." },
      { name: "Improved Reincarnation", icon: "spell_nature_reincarnation", maxRank: 2, tier: 2, col: 0, desc: "Reduces the cooldown of your Reincarnation spell by 20 min and increases the amount of health and mana you reincarnate with by an additional 20%." },
      { name: "Healing Grace", icon: "spell_nature_healingtouch", maxRank: 3, tier: 2, col: 1, desc: "Reduces the threat generated by your healing spells by 15% and reduces the chance your spells will be dispelled by 30%." },
      { name: "Totemic Focus", icon: "spell_nature_moonglow", maxRank: 5, tier: 2, col: 2, desc: "Reduces the Mana cost of your totems by 25%." },
      { name: "Healing Focus", icon: "spell_nature_healingwavelesser", maxRank: 5, tier: 3, col: 0, desc: "Gives you a 70% chance to avoid interruption caused by damage while casting any healing spell." },
      { name: "Totemic Mastery", icon: "spell_nature_nullward", maxRank: 1, tier: 3, col: 1, desc: "The radius of your totems that affect friendly targets is increased to 30 yards." },
      { name: "Healing Way", icon: "spell_nature_healingway", maxRank: 3, tier: 3, col: 2, desc: "Your Healing Wave spells have a 100% chance to increase the effect of subsequent Healing Wave spells on that target by 6% for 15 sec. This effect stacks up to 3 times." },
      { name: "Nature's Guidance", icon: "spell_frost_stun", maxRank: 3, tier: 4, col: 0, desc: "Increases your chance to hit with melee attacks and spells by 3%." },
      { name: "Nature's Swiftness", icon: "spell_nature_ravenform", maxRank: 1, tier: 4, col: 2, desc: "When activated, your next Nature spell with a casting time less than 10 sec becomes an instant cast spell." },
      { name: "Focused Mind", icon: "spell_nature_focusedmind", maxRank: 3, tier: 5, col: 0, desc: "Reduces the duration of any Silence or Interrupt effects used against you by 30%. Does not work against the Warrior's Pummel ability." },
      { name: "Purification", icon: "spell_frost_wizardmark", maxRank: 5, tier: 5, col: 2, desc: "Increases the effectiveness of your healing spells by 10%." },
      { name: "Mana Tide Totem", icon: "spell_frost_summonwaterelemental", maxRank: 1, tier: 6, col: 1, desc: "Summons a Mana Tide Totem with 5 health at the feet of the caster for 12 sec that restores 6% of total mana every 3 sec to group members within 20 yards." },
      { name: "Nature's Guardian", icon: "spell_nature_natureguardian", maxRank: 5, tier: 6, col: 2, desc: "Whenever a damaging attack is dealt to you equal to or greater than 10% of your total health, there is a 50% chance that you will be healed for 10% of your total health and your maximum health is increased by 5% for 10 sec." },
      { name: "Improved Chain Heal", icon: "spell_nature_healingwavegreater", maxRank: 2, tier: 7, col: 0, desc: "Increases the amount healed by your Chain Heal spell by 20%." },
      { name: "Nature's Blessing", icon: "spell_nature_natureblessing", maxRank: 3, tier: 7, col: 2, desc: "Increases your spell damage and healing by an amount equal to 30% of your Intellect." },
      { name: "Tidal Mastery", icon: "spell_nature_tranquility", maxRank: 5, tier: 7, col: 1, desc: "Increases the critical effect chance of your healing and lightning spells by 5%." },
      { name: "Earth Shield", icon: "spell_nature_skinofearth", maxRank: 1, tier: 8, col: 1, desc: "Protects the target with an earthen shield, reducing casting or channeling time lost when damaged by 30% and causing attacks to heal the shielded target for 270. This effect can only occur once every few seconds. 6 charges. Lasts 10 min. Earth Shield can only be placed on one target at a time and only one Elemental Shield can be active on a target at a time." },
    ],
  },
];

// Preset talent builds
export const presets = [
  {
    name: "Standard Elemental PvE",
    slug: "elemental",
    spec: "40/0/21",
    points: [
      // Elemental (18 talents) — 40 pts: deep Elemental with Totem of Wrath
      [5, 5, 3, 0, 5, 1, 0, 3, 0, 2, 1, 3, 3, 5, 1, 0, 2, 1],
      // Enhancement (21 talents) — 0 pts
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Restoration (18 talents) — 21 pts: Improved Healing Wave 5, Tidal Focus 5, Healing Grace 3, Totemic Focus 5, Nature's Guidance 3
      [5, 5, 0, 3, 5, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard Enhancement PvE",
    slug: "enhancement",
    spec: "0/45/16",
    points: [
      // Elemental (18 talents) — 0 pts
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Enhancement (21 talents) — 45 pts: deep Enhancement with Shamanistic Rage
      [5, 0, 0, 5, 2, 0, 2, 1, 5, 5, 5, 0, 1, 3, 3, 1, 5, 3, 1, 0, 0],
      // Restoration (18 talents) — 16 pts: Improved Healing Wave 5, Tidal Focus 5, Healing Grace 3, Nature's Guidance 3
      [5, 5, 0, 3, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard Restoration PvE",
    slug: "restoration",
    spec: "0/5/56",
    points: [
      // Elemental (18 talents) — 0 pts
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Enhancement (21 talents) — 5 pts: Ancestral Knowledge 5
      [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Restoration (18 talents) — 56 pts: deep Restoration with Earth Shield
      [5, 5, 2, 3, 5, 5, 1, 3, 3, 1, 3, 5, 1, 5, 2, 3, 5, 1],
    ],
  },
];
