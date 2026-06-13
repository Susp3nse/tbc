// TBC 2.4.3 Druid Talent Data
// Icon names reference: https://wow.zamimg.com/images/wow/icons/medium/{icon}.jpg

export const trees = [
  {
    name: "Balance",
    talents: [
      { name: "Starlight Wrath", icon: "spell_nature_abolishmagic", maxRank: 5, tier: 1, col: 0, desc: "Reduces the cast time of your Wrath and Starfire spells by 0.5 sec." },
      { name: "Nature's Grasp", icon: "spell_nature_naturetouchgrow", maxRank: 1, tier: 1, col: 1, desc: "While active, any time an enemy strikes the caster they have a 35% chance to become afflicted by Entangling Roots. Only useable outdoors. 1 charge. Lasts 45 sec." },
      { name: "Focused Starlight", icon: "spell_arcane_starfire", maxRank: 2, tier: 1, col: 2, desc: "Increases the critical strike chance of your Wrath and Starfire spells by 4%." },
      { name: "Improved Moonfire", icon: "spell_nature_starfall", maxRank: 2, tier: 1, col: 3, desc: "Increases the damage and critical strike chance of your Moonfire spell by 10%." },
      { name: "Improved Nature's Grasp", icon: "spell_nature_natureswrath", maxRank: 3, tier: 2, col: 1, desc: "Increases the chance for your Nature's Grasp to entangle an enemy by 45%." },
      { name: "Control of Nature", icon: "spell_nature_stranglevines", maxRank: 3, tier: 2, col: 2, desc: "Gives you a 100% chance to avoid interruption caused by damage while casting Entangling Roots and Cyclone." },
      { name: "Improved Thorns", icon: "spell_nature_thorns", maxRank: 3, tier: 2, col: 0, desc: "Increases damage caused by your Thorns spell by 75%." },
      { name: "Insect Swarm", icon: "spell_nature_insectswarm", maxRank: 1, tier: 2, col: 3, desc: "The enemy target is swarmed by insects, decreasing their chance to hit by 2% and causing Nature damage over 12 sec." },
      { name: "Nature's Reach", icon: "spell_nature_naturetouchgrow", maxRank: 2, tier: 3, col: 0, desc: "Increases the range of your Balance spells and Faerie Fire (Feral) by 20%." },
      { name: "Vengeance", icon: "spell_nature_purge", maxRank: 5, tier: 3, col: 1, desc: "Increases the critical strike damage bonus of your Starfire, Moonfire, and Wrath spells by 100%." },
      { name: "Celestial Focus", icon: "spell_arcane_starfire", maxRank: 3, tier: 3, col: 2, desc: "Gives your Starfire spell a 15% chance to stun the target for 3 sec and reduces the pushback suffered from damaging attacks while casting Wrath by 70%." },
      { name: "Lunar Guidance", icon: "spell_holy_healingaura", maxRank: 3, tier: 4, col: 0, desc: "Increases your spell damage and healing by 25% of your total Intellect." },
      { name: "Nature's Grace", icon: "spell_nature_naturesblessing", maxRank: 1, tier: 4, col: 1, desc: "All spell criticals grace you with a blessing of nature, reducing the casting time of your next spell by 0.5 sec." },
      { name: "Moonglow", icon: "spell_nature_sentinal", maxRank: 3, tier: 4, col: 2, desc: "Reduces the Mana cost of your Moonfire, Starfire, Wrath, Healing Touch, Regrowth, and Rejuvenation spells by 9%." },
      { name: "Moonfury", icon: "spell_nature_moonglow", maxRank: 5, tier: 5, col: 0, desc: "Increases the damage done by your Starfire, Moonfire, and Wrath spells by 10%." },
      { name: "Balance of Power", icon: "spell_nature_healingway", maxRank: 2, tier: 5, col: 1, desc: "Increases your chance to hit with all spells by 4% and reduces the chance you are hit by spells by 4%." },
      { name: "Dreamstate", icon: "spell_nature_lightning", maxRank: 3, tier: 5, col: 2, desc: "Regenerate mana equal to 10% of your Intellect every 5 sec, even while casting." },
      { name: "Moonkin Form", icon: "spell_nature_forceofnature", maxRank: 1, tier: 6, col: 1, desc: "Shapeshift into Moonkin Form. While in this form the armor contribution from items is increased by 400%, and all party members within 30 yards have their spell critical chance increased by 5%." },
      { name: "Improved Faerie Fire", icon: "spell_nature_faeriefire", maxRank: 3, tier: 6, col: 2, desc: "Your Faerie Fire spell also increases the chance the target will be hit by melee and ranged attacks by 3%." },
      { name: "Wrath of Cenarius", icon: "spell_arcane_starfire", maxRank: 5, tier: 7, col: 0, desc: "Your Starfire spell gains an additional 20% and your Wrath gains an additional 10% of your bonus damage effects." },
      { name: "Force of Nature", icon: "ability_druid_forceofnature", maxRank: 1, tier: 9, col: 1, desc: "Summons 3 treants to attack the enemy target for 30 sec. 3 min cooldown." },
    ],
  },
  {
    name: "Feral Combat",
    talents: [
      { name: "Ferocity", icon: "ability_druid_ravage", maxRank: 5, tier: 1, col: 0, desc: "Reduces the cost of your Maul, Swipe, Claw, Rake, and Mangle abilities by 5 Rage or Energy." },
      { name: "Feral Aggression", icon: "ability_druid_demoralizingroar", maxRank: 5, tier: 1, col: 1, desc: "Increases the attack power reduction of your Demoralizing Roar by 40% and the damage caused by your Ferocious Bite by 15%." },
      { name: "Feral Instinct", icon: "ability_ambush", maxRank: 3, tier: 1, col: 2, desc: "Increases threat caused in Bear and Dire Bear Form by 15% and reduces the chance enemies have to detect you while Prowling." },
      { name: "Brutal Impact", icon: "ability_druid_bash", maxRank: 2, tier: 2, col: 0, desc: "Increases the stun duration of your Bash and Pounce abilities by 1 sec." },
      { name: "Thick Hide", icon: "inv_misc_pelt_bear_03", maxRank: 3, tier: 2, col: 1, desc: "Increases your Armor contribution from items by 10%." },
      { name: "Feline Swiftness", icon: "spell_holy_blessingofagility", maxRank: 2, tier: 2, col: 2, desc: "Increases your movement speed by 30% while in Cat Form and increases your chance to dodge while in Cat Form by 4%." },
      { name: "Feral Charge", icon: "ability_hunter_pet_bear", maxRank: 1, tier: 3, col: 0, desc: "Causes you to charge an enemy, immobilizing and interrupting any spell being cast for 4 sec." },
      { name: "Sharpened Claws", icon: "inv_misc_monsterclaw_04", maxRank: 3, tier: 3, col: 1, desc: "Increases your critical strike chance while in Bear, Dire Bear, or Cat Form by 6%." },
      { name: "Shredding Attacks", icon: "spell_shadow_vampiricaura", maxRank: 2, tier: 3, col: 2, desc: "Reduces the energy cost of your Shred ability by 18 and the rage cost of your Lacerate ability by 2." },
      { name: "Predatory Strikes", icon: "ability_hunter_pet_cat", maxRank: 3, tier: 4, col: 0, desc: "Increases your melee attack power in Cat, Bear, and Dire Bear Forms by 150% of your level." },
      { name: "Primal Fury", icon: "ability_racial_cannibalize", maxRank: 2, tier: 4, col: 1, desc: "Gives you a 100% chance to gain an additional 5 Rage anytime you get a critical strike while in Bear or Dire Bear Form and your critical strikes from Cat Form abilities that add combo points have a 100% chance to add an additional combo point." },
      { name: "Savage Fury", icon: "ability_druid_ravage", maxRank: 2, tier: 4, col: 2, desc: "Increases the damage caused by your Claw, Rake, Mangle (Cat), and Mangle (Bear) abilities by 20%." },
      { name: "Faerie Fire (Feral)", icon: "spell_nature_faeriefire", maxRank: 1, tier: 5, col: 0, desc: "Decrease the armor of the target by 610 for 40 sec. While affected, the target cannot stealth or turn invisible." },
      { name: "Nurturing Instinct", icon: "ability_druid_healinginstincts", maxRank: 2, tier: 5, col: 1, desc: "Increases your healing spells by up to 100% of your Agility and increases healing done to you by 20% while in Cat Form." },
      { name: "Heart of the Wild", icon: "spell_holy_blessingofagility", maxRank: 5, tier: 5, col: 2, desc: "Increases your Intellect by 20%. In addition, while in Bear or Dire Bear Form your Stamina is increased by 20% and while in Cat Form your attack power is increased by 10%." },
      { name: "Survival of the Fittest", icon: "ability_druid_enrage", maxRank: 3, tier: 6, col: 1, desc: "Increases all attributes by 3% and reduces the chance you'll be critically hit by melee attacks by 3%." },
      { name: "Primal Tenacity", icon: "ability_bullrush", maxRank: 3, tier: 6, col: 2, desc: "Increases your chance to resist Stun and Fear effects by 15%." },
      { name: "Leader of the Pack", icon: "spell_nature_unyieldingstamina", maxRank: 1, tier: 7, col: 0, desc: "While in Cat, Bear, or Dire Bear Form, Leader of the Pack increases ranged and melee critical chance of all party members within 45 yards by 5%." },
      { name: "Improved Leader of the Pack", icon: "spell_nature_unyieldingstamina", maxRank: 2, tier: 7, col: 1, desc: "Your Leader of the Pack aura also causes affected targets to heal themselves for 4% of their total health when they critically hit with a melee or ranged attack. The healing effect cannot occur more than once every 6 sec." },
      { name: "Predatory Instincts", icon: "ability_druid_kingofthejungle", maxRank: 5, tier: 7, col: 2, desc: "Increases your melee critical strike damage by 10% and reduces the damage taken from Area of Effect attacks by 15%." },
      { name: "Mangle", icon: "ability_druid_mangle2", maxRank: 1, tier: 9, col: 1, desc: "Mangle the target, inflicting damage and causing the target to take additional damage from bleed effects for 12 sec. This ability can be used in Cat and Bear Form." },
    ],
  },
  {
    name: "Restoration",
    talents: [
      { name: "Improved Mark of the Wild", icon: "spell_nature_regeneration", maxRank: 5, tier: 1, col: 0, desc: "Increases the effects of your Mark of the Wild and Gift of the Wild spells by 35%." },
      { name: "Furor", icon: "spell_holy_blessingofstamina", maxRank: 5, tier: 1, col: 1, desc: "Gives you 100% chance to gain 10 Rage when you shapeshift into Bear or Dire Bear Form, and you keep up to 40 of your Energy when you shapeshift into Cat Form." },
      { name: "Naturalist", icon: "spell_nature_healingtouch", maxRank: 5, tier: 2, col: 0, desc: "Reduces the cast time of your Healing Touch spell by 0.5 sec and increases the damage you deal with physical attacks in all forms by 10%." },
      { name: "Nature's Focus", icon: "spell_nature_healingwavelesser", maxRank: 5, tier: 2, col: 1, desc: "Gives you a 70% chance to avoid interruption caused by damage while casting Healing Touch, Regrowth, and Tranquility." },
      { name: "Natural Shapeshifter", icon: "spell_nature_wispsplode", maxRank: 3, tier: 2, col: 2, desc: "Reduces the mana cost of all shapeshifting by 30%." },
      { name: "Intensity", icon: "spell_nature_tranquility", maxRank: 3, tier: 3, col: 0, desc: "Allows 30% of your Mana regeneration to continue while casting and causes your Enrage ability to instantly generate 10 Rage." },
      { name: "Subtlety", icon: "ability_eyeoftheowl", maxRank: 5, tier: 3, col: 1, desc: "Reduces the threat generated by your healing spells by 20% and reduces the chance your spells will be dispelled by 30%." },
      { name: "Omen of Clarity", icon: "spell_nature_crystalball", maxRank: 1, tier: 3, col: 2, desc: "Each of the Druid's melee attacks has a chance of causing the caster to enter a Clearcasting state, making the next spell cost no mana." },
      { name: "Tranquil Spirit", icon: "spell_holy_elunesgrace", maxRank: 5, tier: 4, col: 0, desc: "Reduces the mana cost of your Healing Touch and Tranquility spells by 10%." },
      { name: "Improved Rejuvenation", icon: "spell_nature_rejuvenation", maxRank: 3, tier: 4, col: 1, desc: "Increases the effect of your Rejuvenation spell by 15%." },
      { name: "Nature's Swiftness", icon: "spell_nature_ravenform", maxRank: 1, tier: 5, col: 0, desc: "When activated, your next Nature spell with a casting time less than 10 sec becomes an instant cast spell. 3 min cooldown." },
      { name: "Gift of Nature", icon: "spell_nature_protectionformnature", maxRank: 5, tier: 5, col: 1, desc: "Increases the effect of all healing spells by 10%." },
      { name: "Improved Tranquility", icon: "spell_nature_tranquility", maxRank: 2, tier: 5, col: 2, desc: "Reduces threat caused by Tranquility by 100%." },
      { name: "Empowered Touch", icon: "spell_nature_healingtouch", maxRank: 2, tier: 6, col: 0, desc: "Your Healing Touch spell gains an additional 20% of your bonus healing effects." },
      { name: "Improved Regrowth", icon: "spell_nature_resistnature", maxRank: 5, tier: 6, col: 1, desc: "Increases the critical effect chance of your Regrowth spell by 50%." },
      { name: "Living Spirit", icon: "spell_nature_giftofthewaterspirit", maxRank: 3, tier: 6, col: 2, desc: "Increases your total Spirit by 15%." },
      { name: "Swiftmend", icon: "inv_relics_idolofrejuvenation", maxRank: 1, tier: 7, col: 0, desc: "Consumes a Rejuvenation or Regrowth effect on a friendly target to instantly heal them." },
      { name: "Natural Perfection", icon: "spell_nature_stoneclawtotem", maxRank: 3, tier: 7, col: 1, desc: "Your spell critical strikes increase your spell critical strike chance by 3% for 8 sec. Also reduces all damage taken by 3% while active." },
      { name: "Empowered Rejuvenation", icon: "spell_nature_rejuvenation", maxRank: 5, tier: 7, col: 2, desc: "Increases the bonus healing effects of your heal over time spells by 20%." },
      { name: "Tree of Life", icon: "ability_druid_treeoflife", maxRank: 1, tier: 9, col: 1, desc: "Shapeshift into the Tree of Life. While in this form you increase healing received by 25% of your total Spirit for all party members within 45 yards. You may only cast Restoration, Innervate, and Barkskin spells while in this form." },
    ],
  },
];

// Preset talent builds — points arrays map 1:1 to the talents arrays above
export const presets = [
  {
    name: "Standard Feral PvE",
    slug: "feral",
    spec: "0/47/14",
    points: [
      // Balance (21 talents — all 0)
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Feral (21 talents)
      [5, 2, 3, 1, 3, 2, 1, 3, 2, 3, 2, 2, 1, 0, 5, 3, 0, 1, 2, 5, 1],
      // Resto (20 talents)
      [5, 5, 0, 0, 0, 3, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard Moonkin PvE",
    slug: "balance",
    spec: "41/0/20",
    points: [
      // Balance
      [5, 0, 2, 2, 0, 0, 0, 1, 2, 5, 3, 0, 1, 3, 5, 2, 3, 1, 0, 5, 1],
      // Feral (all 0)
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Resto
      [5, 5, 5, 0, 3, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ],
  },
  {
    name: "Standard Resto PvE",
    slug: "resto",
    spec: "8/0/53",
    points: [
      // Balance
      [5, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Feral (all 0)
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Resto
      [5, 5, 5, 5, 3, 3, 0, 1, 5, 3, 1, 5, 0, 2, 0, 3, 1, 0, 5, 1],
    ],
  },
];
