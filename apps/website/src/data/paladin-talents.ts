// TBC 2.4.3 Paladin Talent Data
// Icon names reference: https://wow.zamimg.com/images/wow/icons/medium/{icon}.jpg

export const trees = [
  {
    name: "Holy",
    talents: [
      { name: "Divine Strength", icon: "spell_holy_devotion", maxRank: 5, tier: 1, col: 0, desc: "Increases your total Strength by 10%." },
      { name: "Divine Intellect", icon: "spell_holy_magicalsentry", maxRank: 5, tier: 1, col: 1, desc: "Increases your total Intellect by 10%." },
      { name: "Spiritual Focus", icon: "spell_arcane_blink", maxRank: 5, tier: 1, col: 2, desc: "Gives your Flash of Light and Holy Light spells a 70% chance to not lose casting time when you take damage." },
      { name: "Improved Seal of Righteousness", icon: "ability_thunderbolt", maxRank: 5, tier: 2, col: 0, desc: "Increases the damage done by your Seal of Righteousness and Judgement of Righteousness by 15%." },
      { name: "Healing Light", icon: "spell_holy_holybolt", maxRank: 3, tier: 2, col: 1, desc: "Increases the amount healed by your Holy Light and Flash of Light spells by 12%." },
      { name: "Aura Mastery", icon: "spell_holy_auramastery", maxRank: 1, tier: 2, col: 2, desc: "Increases the radius of your Auras to 40 yards." },
      { name: "Improved Lay on Hands", icon: "spell_holy_layonhands", maxRank: 2, tier: 2, col: 3, desc: "Gives the target of your Lay on Hands spell a 30% bonus to their armor value from items for 2 min. In addition, the cooldown for your Lay on Hands spell is reduced by 10 min." },
      { name: "Unyielding Faith", icon: "spell_holy_unyieldingfaith", maxRank: 2, tier: 3, col: 0, desc: "Increases your chance to resist Fear and Disorient effects by an additional 10%." },
      { name: "Illumination", icon: "spell_holy_greaterheal", maxRank: 5, tier: 3, col: 1, desc: "After getting a critical effect from your Flash of Light, Holy Light, or Holy Shock heal spell, gives you a 100% chance to gain mana equal to 60% of the base cost of the spell." },
      { name: "Improved Blessing of Wisdom", icon: "spell_holy_sealofwisdom", maxRank: 2, tier: 3, col: 2, desc: "Increases the effect of your Blessing of Wisdom spell by 20%." },
      { name: "Pure of Heart", icon: "spell_holy_pureofheart", maxRank: 3, tier: 4, col: 0, desc: "Increases your resistance to Curse and Disease effects by 15%." },
      { name: "Divine Favor", icon: "spell_holy_heal", maxRank: 1, tier: 4, col: 1, desc: "When activated, gives your next Flash of Light, Holy Light, or Holy Shock spell a 100% critical effect chance." },
      { name: "Sanctified Light", icon: "spell_holy_healingaura", maxRank: 3, tier: 4, col: 2, desc: "Increases the critical effect chance of your Holy Light spell by 6%." },
      { name: "Purifying Power", icon: "spell_holy_purifyingpower", maxRank: 2, tier: 5, col: 0, desc: "Reduces the mana cost of your Cleanse, Purify, and Consecration spells by 10% and increases the critical strike chance of your Exorcism and Holy Wrath spells by 10%." },
      { name: "Holy Power", icon: "spell_holy_power", maxRank: 5, tier: 5, col: 2, desc: "Increases the critical effect chance of your Holy spells by 5%." },
      { name: "Light's Grace", icon: "spell_holy_lightsgrace", maxRank: 3, tier: 6, col: 0, desc: "Your Holy Light spell has a 100% chance to reduce the cast time of your next Holy Light spell by 0.5 sec. This effect lasts 15 sec." },
      { name: "Holy Shock", icon: "spell_holy_searinglight", maxRank: 1, tier: 6, col: 1, desc: "Blasts the target with Holy energy, causing 721 to 779 Holy damage to an enemy, or 913 to 987 healing to an ally." },
      { name: "Blessed Life", icon: "spell_holy_blessedlife", maxRank: 3, tier: 6, col: 2, desc: "All attacks against you have a 10% chance to cause half damage." },
      { name: "Holy Guidance", icon: "spell_holy_holyguidance", maxRank: 5, tier: 7, col: 1, desc: "Increases your spell damage and healing by 35% of your total Intellect." },
      { name: "Divine Illumination", icon: "spell_holy_divineillumination", maxRank: 1, tier: 8, col: 1, desc: "Reduces the mana cost of all spells by 50% for 15 sec." },
    ],
  },
  {
    name: "Protection",
    talents: [
      { name: "Improved Devotion Aura", icon: "spell_holy_devotionaura", maxRank: 5, tier: 1, col: 0, desc: "Increases the armor bonus of your Devotion Aura by 40%." },
      { name: "Redoubt", icon: "ability_defend", maxRank: 5, tier: 1, col: 2, desc: "Increases your block value by 30% for 10 sec after being the victim of a critical strike." },
      { name: "Precision", icon: "ability_marksmanship", maxRank: 3, tier: 2, col: 0, desc: "Increases your chance to hit with melee weapons and spells by 3%." },
      { name: "Guardian's Favor", icon: "spell_holy_sealofprotection", maxRank: 2, tier: 2, col: 1, desc: "Reduces the cooldown of your Blessing of Protection by 120 sec and increases the duration of your Blessing of Freedom by 4 sec." },
      { name: "Toughness", icon: "spell_holy_devotion", maxRank: 5, tier: 2, col: 2, desc: "Increases your armor value from items by 10%." },
      { name: "Blessing of Kings", icon: "spell_magic_greaterblessingofkings", maxRank: 1, tier: 3, col: 0, desc: "Places a Blessing on the friendly target, increasing total stats by 10% for 10 min." },
      { name: "Improved Righteous Fury", icon: "spell_holy_sealoffury", maxRank: 3, tier: 3, col: 1, desc: "While Righteous Fury is active, all damage taken is reduced by 6%." },
      { name: "Shield Specialization", icon: "inv_shield_06", maxRank: 3, tier: 3, col: 2, desc: "Increases the amount of damage absorbed by your shield by 30%." },
      { name: "Anticipation", icon: "spell_nature_mirrorimage", maxRank: 5, tier: 3, col: 3, desc: "Increases your Defense skill by 20." },
      { name: "Stoicism", icon: "spell_holy_stoicism", maxRank: 2, tier: 4, col: 0, desc: "Increases your chance to resist Stun effects by an additional 6% and reduces the chance your spells will be dispelled by an additional 30%." },
      { name: "Improved Hammer of Justice", icon: "spell_holy_sealofmight", maxRank: 3, tier: 4, col: 1, desc: "Decreases the cooldown of your Hammer of Justice spell by 15 sec." },
      { name: "Improved Concentration Aura", icon: "spell_holy_mindsooth", maxRank: 3, tier: 4, col: 2, desc: "Increases the effect of your Concentration Aura by an additional 15% and gives all party members affected by the aura an additional 15% chance to resist Silence and Interrupt effects." },
      { name: "Spell Warding", icon: "spell_holy_spellwarding", maxRank: 2, tier: 5, col: 0, desc: "All spell damage taken is reduced by 4%." },
      { name: "Blessing of Sanctuary", icon: "spell_nature_lightningshield", maxRank: 1, tier: 5, col: 1, desc: "Places a Blessing on the friendly target, reducing damage dealt to the target by up to 24 and increasing strength of the target's shield block by 35. When the target blocks, parries, or dodges a melee attack the target will gain 10 additional rage, mana, or energy." },
      { name: "Reckoning", icon: "spell_holy_blessingofstrength", maxRank: 5, tier: 5, col: 2, desc: "Gives you a 10% chance after being hit by any damaging attack that the next 4 weapon swings within 8 sec will generate an additional attack." },
      { name: "Sacred Duty", icon: "spell_holy_divineintervention", maxRank: 2, tier: 6, col: 0, desc: "Increases your total Stamina by 6%, and reduces the cooldown of your Divine Shield spell by 60 sec and reduces the attack speed penalty by 100%." },
      { name: "One-Handed Weapon Specialization", icon: "inv_sword_20", maxRank: 5, tier: 6, col: 2, desc: "Increases all damage you deal when a one-handed melee weapon is equipped by 5%." },
      { name: "Improved Holy Shield", icon: "spell_holy_devotionaura", maxRank: 2, tier: 7, col: 0, desc: "Increases damage caused by Holy Shield by 20% and adds 2 additional charges." },
      { name: "Holy Shield", icon: "spell_holy_blessingofprotection", maxRank: 1, tier: 7, col: 1, desc: "Increases chance to block by 30% for 10 sec, and deals 155 Holy damage for each attack blocked while active. Damage caused by Holy Shield causes 35% additional threat. Each block expends a charge. 8 charges." },
      { name: "Ardent Defender", icon: "spell_holy_ardentdefender", maxRank: 5, tier: 7, col: 2, desc: "When you have less than 35% health, all damage taken is reduced by 30%." },
      { name: "Combat Expertise", icon: "spell_holy_weaponmastery", maxRank: 5, tier: 8, col: 1, desc: "Increases your expertise by 5, total Stamina by 10% and your spell critical strike chance by 5%." },
      { name: "Avenger's Shield", icon: "spell_holy_avengersshield", maxRank: 1, tier: 9, col: 1, desc: "Hurls a holy shield at the enemy, dealing 494 to 602 Holy damage, Dazing them and then jumping to additional nearby enemies. Affects 3 total targets." },
    ],
  },
  {
    name: "Retribution",
    talents: [
      { name: "Improved Blessing of Might", icon: "spell_holy_fistofjustice", maxRank: 5, tier: 1, col: 0, desc: "Increases the melee attack power bonus of your Blessing of Might by 25%." },
      { name: "Benediction", icon: "spell_frost_windwalkon", maxRank: 5, tier: 1, col: 1, desc: "Reduces the mana cost of your Judgement and Seal spells by 15%." },
      { name: "Improved Judgement", icon: "spell_holy_righteousfury", maxRank: 2, tier: 1, col: 2, desc: "Decreases the cooldown of your Judgement spell by 2 sec." },
      { name: "Deflection", icon: "ability_parry", maxRank: 5, tier: 2, col: 0, desc: "Increases your Parry chance by 5%." },
      { name: "Vindication", icon: "spell_holy_vindication", maxRank: 3, tier: 2, col: 2, desc: "Gives the Paladin's damaging melee attacks a chance to reduce the target's attributes by 15% for 15 sec." },
      { name: "Conviction", icon: "spell_holy_retributionaura", maxRank: 5, tier: 3, col: 0, desc: "Increases your chance to get a critical strike with all spells and attacks by 5%." },
      { name: "Seal of Command", icon: "ability_warrior_innerrage", maxRank: 1, tier: 3, col: 1, desc: "Gives the Paladin a chance to deal additional Holy damage equal to 70% of normal weapon damage. Only one Seal can be active on the Paladin at any one time. Lasts 30 sec." },
      { name: "Pursuit of Justice", icon: "spell_holy_persuitofjustice", maxRank: 3, tier: 3, col: 2, desc: "Increases movement and mounted movement speed by 8%. This does not stack with other movement speed increasing effects." },
      { name: "Eye for an Eye", icon: "spell_holy_eyeforaneye", maxRank: 2, tier: 4, col: 0, desc: "All spell criticals against you cause 30% of the damage taken to the caster as well." },
      { name: "Crusade", icon: "spell_holy_crusade", maxRank: 3, tier: 4, col: 2, desc: "Increases all damage caused by 3% and all damage caused against Humanoids, Demons, Undead, and Elementals by an additional 3%." },
      { name: "Two-Handed Weapon Specialization", icon: "inv_hammer_04", maxRank: 3, tier: 5, col: 0, desc: "Increases the damage you deal with two-handed melee weapons by 6%." },
      { name: "Sanctity Aura", icon: "spell_holy_mindvision", maxRank: 1, tier: 5, col: 1, desc: "Increases Holy damage done by party members within 30 yards by 10%. Players may only have one Aura on them per Paladin at any one time." },
      { name: "Improved Sanctity Aura", icon: "spell_holy_mindvision", maxRank: 2, tier: 5, col: 2, desc: "The amount healed by all party members within your Sanctity Aura is increased by 6%." },
      { name: "Vengeance", icon: "ability_racial_avatar", maxRank: 5, tier: 6, col: 1, desc: "Gives you a 3% bonus to Physical and Holy damage you deal for 30 sec after dealing a critical strike from a weapon swing, spell, or ability. This effect stacks up to 3 times." },
      { name: "Sanctified Judgement", icon: "spell_holy_holysmite", maxRank: 3, tier: 6, col: 2, desc: "Your Judgement spell now returns 80% of its mana cost when used." },
      { name: "Sanctified Seals", icon: "ability_paladin_sanctifiedseals", maxRank: 3, tier: 7, col: 0, desc: "Increases your chance to critically hit with all spells and melee attacks by 3% and your Seal and Judgement spells can no longer be dispelled." },
      { name: "Repentance", icon: "spell_holy_prayerofhealing", maxRank: 1, tier: 7, col: 1, desc: "Puts the enemy target in a state of meditation, incapacitating them for up to 1 min. Any damage caused will awaken the target. Only works against Humanoids." },
      { name: "Fanaticism", icon: "spell_holy_fanaticism", maxRank: 5, tier: 7, col: 2, desc: "Increases the critical strike chance of all Judgements capable of a critical hit by 25% and reduces threat caused by all actions by 30% except when under the effects of Righteous Fury." },
      { name: "Crusader Strike", icon: "spell_holy_crusaderstrike", maxRank: 1, tier: 9, col: 1, desc: "An instant strike that causes weapon damage plus 40% of your Holy spell damage and refreshes all Judgements on the target." },
    ],
  },
];

// Preset talent builds
export const presets = [
  {
    name: "Standard Retribution PvE",
    slug: "retribution",
    spec: "5/8/48",
    points: [
      // Holy (20 talents) — 5 pts: Divine Strength 5
      [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Protection (22 talents) — 8 pts: Precision 3, Anticipation 5
      [0, 0, 3, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Retribution (19 talents) — 48 pts: deep Ret with Crusader Strike
      [5, 5, 2, 5, 0, 5, 1, 2, 0, 3, 3, 1, 2, 5, 3, 3, 1, 1, 1],
    ],
  },
  {
    name: "Standard Protection PvE",
    slug: "protection",
    spec: "0/49/12",
    points: [
      // Holy (20 talents) — 0 pts
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Protection (22 talents) — 49 pts: deep Prot with Avenger's Shield
      [5, 3, 3, 2, 5, 1, 3, 0, 5, 0, 0, 0, 2, 1, 0, 2, 5, 0, 1, 5, 5, 1],
      // Retribution (19 talents) — 12 pts: Benediction 5, Improved Judgement 2, Deflection 5
      [0, 5, 2, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard Holy PvE",
    slug: "holy",
    spec: "41/20/0",
    points: [
      // Holy (20 talents) — 41 pts: deep Holy with Divine Illumination
      [5, 5, 5, 0, 3, 1, 2, 0, 5, 2, 0, 1, 3, 0, 0, 3, 1, 0, 5, 0],
      // Protection (22 talents) — 20 pts: Improved Devotion Aura 5, Precision 3, Guardian's Favor 2, Toughness 5, Anticipation 5
      [5, 0, 3, 2, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Retribution (19 talents) — 0 pts
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
];
