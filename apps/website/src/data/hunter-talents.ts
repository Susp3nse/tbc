// TBC 2.4.3 Hunter Talent Data
// Icon names reference: https://wow.zamimg.com/images/wow/icons/medium/{icon}.jpg

export const trees = [
  {
    name: "Beast Mastery",
    talents: [
      { name: "Improved Aspect of the Hawk", icon: "spell_nature_ravenform", maxRank: 5, tier: 1, col: 0, desc: "While Aspect of the Hawk is active, all normal ranged attacks have a 10% chance of increasing ranged attack speed by 15% for 12 sec." },
      { name: "Endurance Training", icon: "spell_nature_reincarnation", maxRank: 5, tier: 1, col: 1, desc: "Increases the Health of your pet by 10% and your total health by 5%." },
      { name: "Focused Fire", icon: "ability_firehawk", maxRank: 2, tier: 1, col: 2, desc: "All damage caused by you is increased by 2% while your pet is active and the critical strike chance of your pet's special abilities is increased by 20% while Kill Command is active." },
      { name: "Improved Aspect of the Monkey", icon: "ability_hunter_aspectofthemonkey", maxRank: 3, tier: 1, col: 3, desc: "Increases the Dodge bonus of your Aspect of the Monkey by 6%." },
      { name: "Thick Hide", icon: "inv_misc_pelt_bear_03", maxRank: 3, tier: 2, col: 0, desc: "Increases the armor rating of your pets by 20% and your armor contribution from items by 10%." },
      { name: "Improved Revive Pet", icon: "ability_hunter_beastsoothe", maxRank: 2, tier: 2, col: 1, desc: "Revive Pet casting time reduced by 6 sec, mana cost reduced by 40%, and increases the health your pet returns with by an additional 30%." },
      { name: "Pathfinding", icon: "ability_mount_jungletiger", maxRank: 2, tier: 2, col: 2, desc: "Increases the speed bonus of your Aspect of the Cheetah and Aspect of the Pack by 8%." },
      { name: "Bestial Swiftness", icon: "ability_druid_dash", maxRank: 1, tier: 2, col: 3, desc: "Increases the outdoor movement speed of your pets by 30%." },
      { name: "Unleashed Fury", icon: "ability_bullrush", maxRank: 5, tier: 3, col: 1, desc: "Increases the damage done by your pets by 20%." },
      { name: "Improved Mend Pet", icon: "ability_hunter_mendpet", maxRank: 2, tier: 3, col: 2, desc: "Reduces the mana cost of your Mend Pet spell by 20% and gives the Mend Pet spell a 50% chance of cleansing 1 Curse, Disease, Magic, or Poison effect from the pet each tick." },
      { name: "Ferocity", icon: "inv_misc_monsterclaw_03", maxRank: 5, tier: 4, col: 1, desc: "Increases the critical strike chance of your pet by 10%." },
      { name: "Spirit Bond", icon: "spell_nature_spiritwolf", maxRank: 2, tier: 4, col: 2, desc: "While your pet is active, you and your pet will regenerate 2% of total health every 10 sec." },
      { name: "Intimidation", icon: "ability_devour", maxRank: 1, tier: 5, col: 0, desc: "Command your pet to intimidate the target on the next successful melee attack, causing a high amount of threat and stunning the target for 3 sec." },
      { name: "Bestial Discipline", icon: "spell_nature_abolishmagic", maxRank: 2, tier: 5, col: 1, desc: "Increases the Focus regeneration of your pets by 100%." },
      { name: "Animal Handler", icon: "ability_hunter_animalhandler", maxRank: 2, tier: 5, col: 2, desc: "Increases your speed while mounted by 8% and your pet's chance to hit by 4%." },
      { name: "Frenzy", icon: "inv_misc_monsterclaw_03", maxRank: 5, tier: 6, col: 1, desc: "Gives your pet a 100% chance to gain a 30% attack speed increase for 8 sec after dealing a critical strike." },
      { name: "Ferocious Inspiration", icon: "ability_hunter_ferociousinspiration", maxRank: 3, tier: 6, col: 2, desc: "When your pet scores a critical hit, all party members have all damage increased by 3% for 10 sec." },
      { name: "Bestial Wrath", icon: "ability_druid_ferociousbite", maxRank: 1, tier: 7, col: 1, desc: "Send your pet into a rage causing 50% additional damage for 18 sec. While enraged, the beast does not feel pity or remorse or fear and it cannot be stopped unless killed." },
      { name: "Catlike Reflexes", icon: "ability_hunter_catlikereflexes", maxRank: 3, tier: 7, col: 2, desc: "Increases your chance to dodge by 3% and your pet's chance to dodge by 9%." },
      { name: "Serpent's Swiftness", icon: "ability_hunter_serpentswiftness", maxRank: 5, tier: 8, col: 1, desc: "Increases ranged combat attack speed by 20% and your pet's melee attack speed by 20%." },
      { name: "The Beast Within", icon: "ability_hunter_thebeastwith", maxRank: 1, tier: 9, col: 1, desc: "When your pet is under the effects of Bestial Wrath, you also go into a rage causing 10% additional damage and reducing mana costs of all spells by 20% for 18 sec." },
    ],
  },
  {
    name: "Marksmanship",
    talents: [
      { name: "Improved Concussive Shot", icon: "spell_frost_stun", maxRank: 5, tier: 1, col: 0, desc: "Gives your Concussive Shot a 20% chance to stun the target for 3 sec." },
      { name: "Lethal Shots", icon: "ability_searingarrow", maxRank: 5, tier: 1, col: 1, desc: "Increases your critical strike chance with ranged weapons by 5%." },
      { name: "Improved Hunter's Mark", icon: "ability_hunter_snipershot", maxRank: 5, tier: 1, col: 2, desc: "Increases the melee attack power bonus of your Hunter's Mark by 100% of its ranged attack power bonus." },
      { name: "Efficiency", icon: "spell_frost_wizardmark", maxRank: 5, tier: 1, col: 3, desc: "Reduces the Mana cost of your Shots and Stings by 10%." },
      { name: "Go for the Throat", icon: "ability_hunter_goforthethroat", maxRank: 2, tier: 2, col: 1, desc: "Your ranged critical hits cause your pet to generate 50 Focus." },
      { name: "Improved Arcane Shot", icon: "ability_impalingbolt", maxRank: 5, tier: 2, col: 2, desc: "Reduces the cooldown of your Arcane Shot by 1 sec." },
      { name: "Aimed Shot", icon: "inv_spear_07", maxRank: 1, tier: 3, col: 1, desc: "An aimed shot that increases ranged damage by 70 and reduces healing done to that target by 50%. 6 sec cast." },
      { name: "Rapid Killing", icon: "ability_hunter_rapidkilling", maxRank: 2, tier: 3, col: 2, desc: "Reduces the cooldown of your Rapid Fire spell by 2 min. In addition, after killing an opponent that yields experience or honor, your next Aimed Shot, Arcane Shot, or Multi-Shot causes 20% additional damage." },
      { name: "Improved Stings", icon: "ability_hunter_quickshot", maxRank: 5, tier: 4, col: 1, desc: "Increases the damage done by your Serpent Sting and Wyvern Sting by 30% and the mana drained by your Viper Sting by 30%." },
      { name: "Mortal Shots", icon: "ability_piercedamage", maxRank: 5, tier: 4, col: 2, desc: "Increases your ranged weapon critical strike damage bonus by 30%." },
      { name: "Concussive Barrage", icon: "ability_golemstormbolt", maxRank: 3, tier: 5, col: 1, desc: "Your successful Auto Shot attacks have a 6% chance of dazing the target for 4 sec." },
      { name: "Scatter Shot", icon: "ability_golemstormbolt", maxRank: 1, tier: 5, col: 2, desc: "A short-range shot that deals 50% weapon damage and disorients the target for 4 sec. Any damage caused will remove the effect." },
      { name: "Barrage", icon: "ability_upgrademoonglaive", maxRank: 3, tier: 6, col: 1, desc: "Increases the damage done by your Multi-Shot and Volley spells by 15%." },
      { name: "Combat Experience", icon: "ability_hunter_combatexperience", maxRank: 2, tier: 6, col: 2, desc: "Increases your total Agility by 2% and your total Intellect by 6%." },
      { name: "Ranged Weapon Specialization", icon: "inv_weapon_rifle_06", maxRank: 5, tier: 7, col: 1, desc: "Increases the damage you deal with ranged weapons by 5%." },
      { name: "Careful Aim", icon: "ability_hunter_zenarchery", maxRank: 3, tier: 7, col: 2, desc: "Increases your ranged attack power by an amount equal to 45% of your total Intellect." },
      { name: "Trueshot Aura", icon: "ability_trueshot", maxRank: 1, tier: 8, col: 0, desc: "Increases the attack power of party members within 45 yards by 125. Lasts until cancelled." },
      { name: "Improved Barrage", icon: "ability_upgrademoonglaive", maxRank: 3, tier: 8, col: 1, desc: "Increases the critical strike chance of your Multi-Shot ability by 12% and reduces the pushback suffered from damaging attacks while channeling Volley by 100%." },
      { name: "Master Marksman", icon: "ability_hunter_mastermarksman", maxRank: 5, tier: 8, col: 2, desc: "Increases your ranged attack power by 10%." },
      { name: "Silencing Shot", icon: "ability_theblackarrow", maxRank: 1, tier: 9, col: 1, desc: "A shot that deals 50% weapon damage and silences the target for 3 sec." },
    ],
  },
  {
    name: "Survival",
    talents: [
      { name: "Monster Slaying", icon: "inv_misc_head_dragon_01", maxRank: 3, tier: 1, col: 0, desc: "Increases all damage caused against Beasts, Giants, and Dragonkin targets by 3% and increases critical strike chance against them by 3%." },
      { name: "Humanoid Slaying", icon: "spell_holy_prayerofhealing", maxRank: 3, tier: 1, col: 1, desc: "Increases all damage caused against Humanoid targets by 3% and increases critical strike chance against them by 3%." },
      { name: "Hawk Eye", icon: "ability_hunter_eagleeye", maxRank: 3, tier: 1, col: 2, desc: "Increases the range of your ranged weapons by 6 yards." },
      { name: "Savage Strikes", icon: "ability_racial_bloodrage", maxRank: 2, tier: 1, col: 3, desc: "Increases the critical strike chance of Raptor Strike and Mongoose Bite by 20%." },
      { name: "Entrapment", icon: "spell_nature_stranglevines", maxRank: 3, tier: 2, col: 1, desc: "Gives your Immolation Trap, Frost Trap, Explosive Trap, and Snake Trap a 25% chance to entrap the target, preventing them from moving for 4 sec." },
      { name: "Deflection", icon: "ability_parry", maxRank: 5, tier: 2, col: 2, desc: "Increases your Parry chance by 5%." },
      { name: "Improved Wing Clip", icon: "ability_rogue_trip", maxRank: 3, tier: 2, col: 3, desc: "Gives your Wing Clip ability a 20% chance to immobilize the target for 5 sec." },
      { name: "Clever Traps", icon: "spell_nature_timestop", maxRank: 2, tier: 3, col: 1, desc: "Increases the duration of your Frost Trap and Freezing Trap by 30% and the damage of your Immolation Trap and Explosive Trap by 30%." },
      { name: "Survivalist", icon: "spell_shadow_antishadow", maxRank: 5, tier: 3, col: 2, desc: "Increases total health by 10%." },
      { name: "Deterrence", icon: "ability_whirlwind", maxRank: 1, tier: 3, col: 3, desc: "When activated, increases your Dodge and Parry chance by 25% for 10 sec." },
      { name: "Trap Mastery", icon: "ability_ensnare", maxRank: 2, tier: 4, col: 1, desc: "Decreases the chance enemies will resist trap effects by 10%." },
      { name: "Surefooted", icon: "ability_kick", maxRank: 3, tier: 4, col: 2, desc: "Increases hit chance by 3% and increases the chance movement impairing effects will be resisted by 15%." },
      { name: "Improved Feign Death", icon: "ability_rogue_feigndeath", maxRank: 2, tier: 4, col: 3, desc: "Reduces the chance your Feign Death ability will be resisted by 4%." },
      { name: "Survival Instincts", icon: "ability_hunter_survivalinstincts", maxRank: 2, tier: 5, col: 2, desc: "Reduces all damage taken by 4% and increases attack power by 4%." },
      { name: "Killer Instinct", icon: "ability_hunter_killerinstinct", maxRank: 3, tier: 5, col: 3, desc: "Increases your critical strike chance with all attacks by 3%." },
      { name: "Counterattack", icon: "ability_warrior_challange", maxRank: 1, tier: 6, col: 2, desc: "A strike that becomes active after parrying an opponent's attack. This attack deals 40 damage and immobilizes the target for 5 sec." },
      { name: "Resourcefulness", icon: "ability_hunter_resourcefulness", maxRank: 3, tier: 6, col: 3, desc: "Reduces the mana cost of all traps and melee abilities by 60% and reduces the cooldown of all traps by 6 sec." },
      { name: "Lightning Reflexes", icon: "spell_nature_invisibilty", maxRank: 5, tier: 7, col: 2, desc: "Increases your Agility by 15%." },
      { name: "Wyvern Sting", icon: "inv_spear_02", maxRank: 1, tier: 8, col: 0, desc: "A stinging shot that puts the target to sleep for 12 sec. Any damage will cancel the effect. When the target wakes up, the Sting causes Nature damage over 12 sec. Only usable out of combat." },
      { name: "Thrill of the Hunt", icon: "ability_hunter_thrillofthehunt", maxRank: 3, tier: 8, col: 1, desc: "Gives you a 100% chance to regain 40% of the mana cost of any shot when it critically hits." },
      { name: "Expose Weakness", icon: "ability_hunter_yourexposeweakness", maxRank: 3, tier: 8, col: 2, desc: "Your ranged criticals have a 100% chance to grant you Expose Weakness. Expose Weakness increases the attack power of all attackers against that target by 25% of your Agility for 7 sec." },
      { name: "Master Tactician", icon: "ability_hunter_mastertactitian", maxRank: 5, tier: 8, col: 3, desc: "Your successful ranged attacks have a 10% chance to increase your critical strike chance by 10% for 8 sec." },
      { name: "Readiness", icon: "ability_hunter_readiness", maxRank: 1, tier: 9, col: 1, desc: "When activated, this ability immediately finishes the cooldown on all Hunter abilities." },
    ],
  },
];

// Preset talent builds
export const presets = [
  {
    name: "Standard BM PvE",
    slug: "bm",
    spec: "41/20/0",
    points: [
      // Beast Mastery (21 talents)
      [5, 2, 2, 0, 0, 0, 0, 1, 5, 2, 5, 0, 1, 2, 2, 4, 3, 1, 0, 5, 1],
      // Marksmanship (20 talents)
      [0, 5, 0, 2, 2, 3, 1, 2, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Survival (23 talents — all 0)
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard MM PvE",
    slug: "mm",
    spec: "0/41/20",
    points: [
      // Beast Mastery (all 0)
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Marksmanship (41 points)
      [0, 5, 0, 5, 2, 5, 1, 2, 0, 5, 0, 1, 3, 2, 5, 3, 1, 0, 0, 1],
      // Survival (20 points)
      [3, 3, 3, 1, 0, 0, 0, 2, 5, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard SV PvE",
    slug: "sv",
    spec: "0/20/41",
    points: [
      // Beast Mastery (all 0)
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Marksmanship (20 points)
      [0, 5, 0, 2, 2, 3, 1, 2, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Survival (41 points)
      [3, 3, 3, 2, 0, 0, 0, 2, 5, 1, 2, 3, 0, 2, 3, 0, 0, 5, 0, 3, 3, 0, 1],
    ],
  },
];
