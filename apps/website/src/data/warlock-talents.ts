// TBC 2.4.3 Warlock Talent Data
// Icon names reference: https://wow.zamimg.com/images/wow/icons/medium/{icon}.jpg

export const trees = [
  {
    name: "Affliction",
    talents: [
      { name: "Suppression", icon: "spell_shadow_unsummonbuilding", maxRank: 3, tier: 1, col: 0, desc: "Reduces the chance for enemies to resist your Affliction spells by 6%." },
      { name: "Improved Corruption", icon: "spell_shadow_abominationexplosion", maxRank: 5, tier: 1, col: 1, desc: "Reduces the casting time of your Corruption spell by 2 sec." },
      { name: "Improved Curse of Weakness", icon: "spell_shadow_curseofmannoroth", maxRank: 2, tier: 1, col: 2, desc: "Increases the effect of your Curse of Weakness by 20%." },
      { name: "Improved Drain Soul", icon: "spell_shadow_haunting", maxRank: 2, tier: 2, col: 0, desc: "Returns 15% of your maximum mana if the target is killed by you while you drain its soul. In addition, your Affliction spells generate 10% less threat." },
      { name: "Improved Life Tap", icon: "spell_shadow_burningspirit", maxRank: 2, tier: 2, col: 1, desc: "Increases the amount of Mana awarded by your Life Tap spell by 20%." },
      { name: "Soul Siphon", icon: "spell_shadow_lifedrain02", maxRank: 2, tier: 2, col: 2, desc: "Increases the amount drained by your Drain Life and Drain Soul spells by an additional 4% for each Affliction effect on the target, up to a maximum of 60% additional effect." },
      { name: "Improved Curse of Agony", icon: "spell_shadow_curseofsargeras", maxRank: 2, tier: 3, col: 0, desc: "Increases the damage done by your Curse of Agony by 10%." },
      { name: "Fel Concentration", icon: "spell_shadow_fingerofdeath", maxRank: 5, tier: 3, col: 1, desc: "Gives you a 70% chance to avoid interruption caused by damage while channeling the Drain Life, Drain Mana, or Drain Soul spell." },
      { name: "Amplify Curse", icon: "spell_shadow_contagion", maxRank: 1, tier: 3, col: 2, desc: "Increases the effect of your next Curse of Doom or Curse of Agony by 50%, or your next Curse of Exhaustion by an additional 20%. Lasts 30 sec." },
      { name: "Grim Reach", icon: "spell_shadow_callofbone", maxRank: 2, tier: 4, col: 0, desc: "Increases the range of your Affliction spells by 20%." },
      { name: "Nightfall", icon: "spell_shadow_twilight", maxRank: 2, tier: 4, col: 1, desc: "Gives your Corruption and Drain Life spells a 4% chance to cause you to enter a Shadow Trance state after damaging the opponent. The Shadow Trance state reduces the casting time of your next Shadow Bolt spell by 100%." },
      { name: "Empowered Corruption", icon: "spell_shadow_abominationexplosion", maxRank: 3, tier: 4, col: 3, desc: "Your Corruption spell gains an additional 36% of your bonus spell damage effects." },
      { name: "Shadow Embrace", icon: "spell_shadow_shadowembrace", maxRank: 5, tier: 5, col: 0, desc: "Your Shadow Bolt spell applies the Shadow Embrace effect, reducing Physical damage caused by 5% for 12 sec. Stacks up to 2 times." },
      { name: "Siphon Life", icon: "spell_shadow_requiem", maxRank: 1, tier: 5, col: 1, desc: "Transfers 63 health from the target to the caster every 3 sec. Lasts 30 sec." },
      { name: "Curse of Exhaustion", icon: "spell_shadow_grimward", maxRank: 1, tier: 5, col: 3, desc: "Reduces the target's movement speed by 30% for 12 sec. Only one Curse per Warlock can be active on any one target." },
      { name: "Shadow Mastery", icon: "spell_shadow_shadetruesight", maxRank: 5, tier: 6, col: 1, desc: "Increases the damage dealt or life drained by your Shadow spells by 10%." },
      { name: "Contagion", icon: "spell_shadow_painandsuffering", maxRank: 5, tier: 7, col: 0, desc: "Increases the damage of your Curse of Agony, Corruption, and Seed of Corruption spells by 5% and reduces the chance your Affliction spells will be dispelled by an additional 30%." },
      { name: "Dark Pact", icon: "spell_shadow_darkritual", maxRank: 1, tier: 7, col: 1, desc: "Drains 700 of your pet's Mana, returning 100% to you." },
      { name: "Malediction", icon: "spell_shadow_curseofachimonde", maxRank: 3, tier: 8, col: 1, desc: "Increases the damage bonus effect of your Curse of the Elements spell by an additional 3%." },
      { name: "Improved Howl of Terror", icon: "spell_shadow_deathscream", maxRank: 2, tier: 8, col: 2, desc: "Reduces the casting time of your Howl of Terror spell by 1.5 sec." },
      { name: "Unstable Affliction", icon: "spell_shadow_unstableaffliction_3", maxRank: 1, tier: 9, col: 1, desc: "Shadow energy slowly destroys the target, dealing 1050 damage over 18 sec. In addition, if the Unstable Affliction is dispelled it will cause 1575 damage to the dispeller and silence them for 5 sec." },
    ],
  },
  {
    name: "Demonology",
    talents: [
      { name: "Improved Healthstone", icon: "inv_stone_04", maxRank: 2, tier: 1, col: 0, desc: "Increases the amount of Health restored by your Healthstone by 20%." },
      { name: "Improved Imp", icon: "spell_shadow_summonimp", maxRank: 3, tier: 1, col: 1, desc: "Increases the effect of your Imp's Firebolt, Fire Shield, and Blood Pact spells by 30%." },
      { name: "Demonic Embrace", icon: "spell_shadow_metamorphosis", maxRank: 5, tier: 1, col: 2, desc: "Increases your total Stamina by 15%." },
      { name: "Improved Health Funnel", icon: "spell_shadow_lifedrain", maxRank: 2, tier: 2, col: 0, desc: "Increases the amount of Health transferred by your Health Funnel spell by 20% and reduces the initial health cost by 20%." },
      { name: "Improved Voidwalker", icon: "spell_shadow_summonvoidwalker", maxRank: 3, tier: 2, col: 1, desc: "Increases the effectiveness of your Voidwalker's Torment, Consume Shadows, Sacrifice, and Suffering spells by 30%." },
      { name: "Fel Intellect", icon: "spell_holy_magicalsentry", maxRank: 3, tier: 2, col: 2, desc: "Increases the Intellect of your Imp, Succubus, Voidwalker, and Felhunter by 15% and increases your maximum mana by 3%." },
      { name: "Improved Succubus", icon: "spell_shadow_summonsuccubus", maxRank: 3, tier: 3, col: 0, desc: "Increases the effect of your Succubus' Lash of Pain and Soothing Kiss spells by 30%, and increases the duration of your Succubus' Seduction by 30%." },
      { name: "Fel Domination", icon: "spell_nature_removecurse", maxRank: 1, tier: 3, col: 1, desc: "Your next Imp, Voidwalker, Succubus, Felhunter or Felguard Summon spell has its casting time reduced by 5.5 sec and its Mana cost reduced by 50%." },
      { name: "Fel Stamina", icon: "spell_shadow_antishadow", maxRank: 3, tier: 3, col: 2, desc: "Increases the Stamina of your Imp, Voidwalker, Succubus, Felhunter and Felguard by 15% and increases your maximum health by 3%." },
      { name: "Demonic Aegis", icon: "spell_shadow_ragingscream", maxRank: 3, tier: 4, col: 0, desc: "Increases the effectiveness of your Demon Armor and Fel Armor spells by 30%." },
      { name: "Master Summoner", icon: "spell_shadow_impphaseshift", maxRank: 2, tier: 4, col: 1, desc: "Reduces the casting time of your Imp, Voidwalker, Succubus, Felhunter and Felguard Summoning spells by 4 sec and the Mana cost by 40%." },
      { name: "Unholy Power", icon: "spell_shadow_shadowworddominate", maxRank: 5, tier: 4, col: 2, desc: "Increases the damage done by your Voidwalker, Succubus, Felhunter and Felguard's melee attacks by 20%." },
      { name: "Demonic Sacrifice", icon: "spell_shadow_psychicscream", maxRank: 1, tier: 5, col: 0, desc: "When activated, sacrifices your summoned demon to grant you an effect that lasts 30 min. The effect is canceled if any Demon is summoned. Imp: Increases your Fire damage by 15%. Voidwalker: Restores 2% of total Health every 4 sec. Succubus: Increases your Shadow damage by 15%. Felhunter: Restores 3% of total Mana every 4 sec." },
      { name: "Mana Feed", icon: "spell_shadow_creepingplague", maxRank: 3, tier: 5, col: 1, desc: "When your Imp, Succubus, Felhunter or Felguard critically hits, you have a 100% chance to gain mana equal to 100% of the damage done by the critical hit." },
      { name: "Master Demonologist", icon: "spell_shadow_shadowpact", maxRank: 5, tier: 5, col: 2, desc: "Grants both the master and the pet a bonus depending on the active demon. Imp: Fire damage +5%. Voidwalker: Physical damage taken -10%. Succubus: Shadow damage +5%. Felhunter: All resistances +.5/lvl. Felguard: All damage +5%, all resistances +.5/lvl." },
      { name: "Demonic Resilience", icon: "spell_shadow_demonicfortitude", maxRank: 3, tier: 6, col: 0, desc: "Reduces the chance you'll be critically hit by melee and spells by 3% and reduces all damage your summoned demon takes by 15%." },
      { name: "Demonic Knowledge", icon: "spell_shadow_improvedvampiricembrace", maxRank: 3, tier: 6, col: 2, desc: "Increases your spell damage by an amount equal to 12% of the total of your active demon's Stamina plus Intellect." },
      { name: "Demonic Tactics", icon: "spell_shadow_demonictactics", maxRank: 5, tier: 7, col: 1, desc: "Increases melee and spell critical strike chance for you and your summoned demon by 5%." },
      { name: "Soul Link", icon: "spell_shadow_gathershadows", maxRank: 1, tier: 7, col: 2, desc: "When active, 20% of all damage taken by the caster is taken by your Imp, Voidwalker, Succubus, Felhunter or Felguard demon instead. In addition, both the demon and master will inflict 5% more damage. Lasts as long as the demon is active." },
      { name: "Summon Felguard", icon: "spell_shadow_summonfelguard", maxRank: 1, tier: 8, col: 1, desc: "Summons a Felguard under the command of the Warlock." },
    ],
  },
  {
    name: "Destruction",
    talents: [
      { name: "Improved Shadow Bolt", icon: "spell_shadow_shadowbolt", maxRank: 5, tier: 1, col: 1, desc: "Your Shadow Bolt critical strikes increase Shadow damage dealt to the target by 20% for 12 sec." },
      { name: "Cataclysm", icon: "spell_fire_windsofwoe", maxRank: 3, tier: 1, col: 2, desc: "Reduces the Mana cost of your Destruction spells by 5%." },
      { name: "Bane", icon: "spell_shadow_deathpact", maxRank: 5, tier: 2, col: 1, desc: "Reduces the casting time of your Shadow Bolt and Immolate spells by 0.5 sec and your Soul Fire spell by 2 sec." },
      { name: "Aftermath", icon: "spell_fire_fire", maxRank: 5, tier: 2, col: 2, desc: "Increases the periodic damage done by your Immolate spell by 10%." },
      { name: "Improved Firebolt", icon: "spell_fire_firebolt", maxRank: 2, tier: 3, col: 0, desc: "Reduces the casting time of your Imp's Firebolt spell by 0.5 sec." },
      { name: "Improved Lash of Pain", icon: "spell_shadow_curse", maxRank: 2, tier: 3, col: 1, desc: "Reduces the cooldown of your Succubus' Lash of Pain spell by 6 sec." },
      { name: "Devastation", icon: "spell_fire_flameshock", maxRank: 5, tier: 3, col: 2, desc: "Increases the critical strike chance of your Destruction spells by 5%." },
      { name: "Shadowburn", icon: "spell_shadow_scourgebuild", maxRank: 1, tier: 4, col: 0, desc: "Instantly blasts the target for 597 to 665 Shadow damage. If the target dies within 5 sec of Shadowburn, and yields experience or honor, the caster gains a Soul Shard." },
      { name: "Intensity", icon: "spell_fire_lavaspawn", maxRank: 2, tier: 4, col: 1, desc: "Gives you a 70% chance to resist interruption caused by damage while casting or channeling any Destruction spell." },
      { name: "Destructive Reach", icon: "spell_shadow_corpseexplode", maxRank: 2, tier: 4, col: 2, desc: "Increases the range of your Destruction spells by 20% and reduces the threat caused by Destruction spells by 10%." },
      { name: "Improved Searing Pain", icon: "spell_fire_soulburn", maxRank: 3, tier: 5, col: 0, desc: "Increases the critical strike chance of your Searing Pain spell by 10%." },
      { name: "Pyroclasm", icon: "spell_fire_volcano", maxRank: 2, tier: 5, col: 1, desc: "Gives your Rain of Fire, Hellfire, and Soul Fire spells a 26% chance to stun the target for 3 sec." },
      { name: "Improved Immolate", icon: "spell_fire_immolation", maxRank: 5, tier: 5, col: 2, desc: "Increases the initial damage of your Immolate spell by 25%." },
      { name: "Ruin", icon: "spell_shadow_shadowworddominate", maxRank: 1, tier: 6, col: 1, desc: "Increases the critical strike damage bonus of your Destruction spells by 100%." },
      { name: "Nether Protection", icon: "spell_shadow_netherprotection", maxRank: 3, tier: 6, col: 2, desc: "After being hit with a Shadow or Fire spell, you have a 30% chance to become immune to Shadow and Fire spells for 4 sec." },
      { name: "Emberstorm", icon: "spell_fire_selfdestruct", maxRank: 5, tier: 7, col: 0, desc: "Increases the damage done by your Fire spells by 10% and reduces the cast time of your Incinerate spell by 0.25 sec." },
      { name: "Backlash", icon: "spell_fire_playingwithfire", maxRank: 3, tier: 7, col: 2, desc: "Increases your critical strike chance with spells by 3% and gives you a 100% chance when hit by a physical attack to reduce the cast time of your next Shadow Bolt or Incinerate spell by 100%. This effect lasts 8 sec and will not occur more than once every 8 sec." },
      { name: "Conflagrate", icon: "spell_fire_fireball", maxRank: 1, tier: 8, col: 0, desc: "Ignites a target that is already afflicted by your Immolate, dealing 579 to 721 Fire damage and consuming the Immolate spell." },
      { name: "Soul Leech", icon: "spell_shadow_soulleech_3", maxRank: 3, tier: 8, col: 1, desc: "Gives your Shadow Bolt, Shadowburn, Soul Fire, Incinerate, Searing Pain and Conflagrate spells a 30% chance to return health equal to 20% of the damage caused." },
      { name: "Shadow and Flame", icon: "spell_shadow_shadowandflame", maxRank: 5, tier: 8, col: 2, desc: "Your Shadow Bolt and Incinerate spells gain an additional 20% of your bonus spell damage effects." },
      { name: "Shadowfury", icon: "spell_shadow_shadowfury", maxRank: 1, tier: 9, col: 1, desc: "Shadowfury is unleashed, causing 612 to 728 Shadow damage and stunning all enemies within 8 yds for 2 sec." },
    ],
  },
];

// Preset talent builds
export const presets = [
  {
    name: "Standard Affliction PvE",
    slug: "affliction",
    spec: "41/0/20",
    points: [
      // Affliction (21 talents) — 41 pts: deep Aff with Unstable Affliction
      [3, 5, 0, 2, 2, 0, 0, 0, 1, 2, 0, 3, 5, 1, 0, 5, 5, 1, 3, 2, 1],
      // Demonology (20 talents) — 0 pts
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Destruction (21 talents) — 20 pts: ISB 5, Bane 5, Devastation 5, Ruin 1, Shadow and Flame 4
      [5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 4, 0],
    ],
  },
  {
    name: "Standard Demonology PvE",
    slug: "demonology",
    spec: "0/41/20",
    points: [
      // Affliction (21 talents) — 0 pts
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Demonology (20 talents) — 41 pts: Felguard build
      [0, 1, 5, 0, 0, 3, 0, 1, 3, 3, 2, 5, 0, 3, 5, 0, 3, 5, 1, 1],
      // Destruction (21 talents) — 20 pts: ISB 5, Bane 5, Devastation 5, Ruin 1, Shadow and Flame 4
      [5, 0, 5, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 4, 0],
    ],
  },
  {
    name: "Standard Destruction PvE",
    slug: "destruction",
    spec: "0/21/40",
    points: [
      // Affliction (21 talents) — 0 pts
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      // Demonology (20 talents) — 21 pts: Demonic Embrace 5, Fel Intellect 3, Fel Stamina 3, Demonic Aegis 3, Master Summoner 2, Unholy Power 4, Demonic Sacrifice 1
      [0, 0, 5, 0, 0, 3, 0, 0, 3, 3, 2, 4, 1, 0, 0, 0, 0, 0, 0, 0],
      // Destruction (21 talents) — 40 pts: deep Destro with Shadowfury
      [5, 3, 5, 0, 0, 0, 5, 1, 2, 2, 0, 0, 5, 1, 0, 5, 3, 1, 0, 1, 1],
    ],
  },
];
