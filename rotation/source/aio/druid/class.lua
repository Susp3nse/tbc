-- Druid Class Module
-- Defines all Druid spells, constants, data tables, and registers Druid as a class

local _G, setmetatable, pairs, ipairs, tostring = _G, setmetatable, pairs, ipairs, tostring
local tinsert = table.insert
local format = string.format
local GetTime = _G.GetTime
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "DRUID" then return end

local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Druid]|r Core module not loaded!")
   return
end

-- ============================================================================
-- ACTION DEFINITIONS
-- ============================================================================
local Create = A.Create

Action[A.PlayerClass] = {
   -- Self Buffs
   SelfMarkOfTheWild = Create({ Type = "Spell", ID = 1126, useMaxRank = true, Desc = "Self Mark of the Wild", Click = { unit = "player" }}),
   SelfThorns = Create({ Type = "Spell", ID = 467, useMaxRank = true, Desc = "Self Thorns", Click = { unit = "player" }}),
   SelfOmenOfClarity = Create({ Type = "Spell", ID = 16864, Desc = "Self Omen of Clarity", Click = { unit = "player" }}),

   -- Self-cast utility
   SelfRemoveCurse = Create({ Type = "Spell", ID = 2782, Desc = "Self Remove Curse", Click = { unit = "player" } }),
   SelfAbolishPoison = Create({ Type = "Spell", ID = 2893, Desc = "Self Abolish Poison", Click = { unit = "player" } }),
   SelfInnervate = Create({ Type = "Spell", ID = 29166, Desc = "Self Innervate", Click = { unit = "player" } }),
   SelfBarkskin = Create({ Type = "Spell", ID = 22812, Desc = "Self Barkskin", Click = { unit = "player" } }),

   -- Forms
   CatForm = Create({ Type = "Spell", ID = 768, Desc = "Fast Cat Form", Click = { macrobefore = "/cast !" .. GetSpellInfo(768) .. "\n" } }),
   BearForm = Create({ Type = "Spell", ID = 9634, Desc = "Fast Bear Form", Click = { macrobefore = "/cast !" .. GetSpellInfo(9634) .. "\n" } }),
   MoonkinForm = Create({ Type = "Spell", ID = 24858, Desc = "Fast Moonkin Form", Click = { macrobefore = "/cast !" .. GetSpellInfo(24858) .. "\n" } }),
   TravelForm = Create({ Type = "Spell", ID = 783, Desc = "Fast Travel Form", Click = { macrobefore = "/cast !" .. GetSpellInfo(783) .. "\n" } }),

   -- Cat Abilities
   Rake = Create({ Type = "Spell", ID = 1822, useMaxRank = true }),
   Rip = Create({ Type = "Spell", ID = 1079, useMaxRank = true }),
   FerociousBite = Create({ Type = "Spell", ID = 22568, useMaxRank = true }),
   Shred = Create({ Type = "Spell", ID = 5221, useMaxRank = true }),
   MangleCat = Create({ Type = "Spell", ID = 33876, useMaxRank = true }),
   TigersFury = Create({ Type = "Spell", ID = 5217, useMaxRank = true }),
   Prowl = Create({ Type = "Spell", ID = 5215, useMaxRank = true }),
   Ravage = Create({ Type = "Spell", ID = 6785, useMaxRank = true }),
   Pounce = Create({ Type = "Spell", ID = 27006, useMaxRank = true }),
   Dash = Create({ Type = "Spell", ID = 33357, useMaxRank = true }),
   FaerieFire = Create({ Type = "Spell", ID = 16857, useMaxRank = true }),
   Cower = Create({ Type = "Spell", ID = 8998, useMaxRank = true }),

   -- Bear Abilities
   MangleBear = Create({ Type = "Spell", ID = 33878, useMaxRank = true }),
   Maul = Create({ Type = "Spell", ID = 6807, useMaxRank = true }),
   Swipe = Create({ Type = "Spell", ID = 779, useMaxRank = true }),
   Lacerate = Create({ Type = "Spell", ID = 33745, useMaxRank = true }),
   FrenziedRegeneration = Create({ Type = "Spell", ID = 22842, useMaxRank = true }),
   Enrage = Create({ Type = "Spell", ID = 5229 }),
   DemoralizingRoar = Create({ Type = "Spell", ID = 99, useMaxRank = true }),
   Growl = Create({ Type = "Spell", ID = 6795 }),
   ChallengingRoar = Create({ Type = "Spell", ID = 5209 }),

   -- Balance Abilities
   FaerieFireCaster = Create({ Type = "Spell", ID = 770, useMaxRank = true }),
   Moonfire = Create({ Type = "Spell", ID = 8921, useMaxRank = true }),
   Starfire = Create({ Type = "Spell", ID = 2912, useMaxRank = true }),
   Wrath = Create({ Type = "Spell", ID = 5176, useMaxRank = true }),
   InsectSwarm = Create({ Type = "Spell", ID = 5570, useMaxRank = true }),
   Hurricane = Create({ Type = "Spell", ID = 16914, useMaxRank = true }),
   ForceOfNature = Create({ Type = "Spell", ID = 33831 }),

   -- Healing
   NaturesSwiftness = Create({ Type = "Spell", ID = 17116 }),
   Swiftmend = Create({ Type = "Spell", ID = 18562 }),
   Lifebloom = Create({ Type = "Spell", ID = 33763, useMaxRank = true }),
   TreeOfLifeForm = Create({ Type = "Spell", ID = 33891 }),
   Tranquility = Create({ Type = "Spell", ID = 740, useMaxRank = true }),

   -- NS + Healing Touch combo (cancelform macro for Tree of Life emergency)
   NSHealingTouch13 = Create({ Type = "Spell", ID = 26979, Desc = "NS + Healing Touch",
      Click = { macrobefore = "/cast Nature's Swiftness\n/cancelform\n" } }),

   -- Healing Touch ranks (13 total, high to low)
   HealingTouch13 = Create({ Type = "Spell", ID = 26979, Desc = "Healing Touch" }),
   HealingTouch12 = Create({ Type = "Spell", ID = 26978, Desc = "Healing Touch" }),
   HealingTouch11 = Create({ Type = "Spell", ID = 25297, Desc = "Healing Touch" }),
   HealingTouch10 = Create({ Type = "Spell", ID = 9889, Desc = "Healing Touch" }),
   HealingTouch9 = Create({ Type = "Spell", ID = 9888, Desc = "Healing Touch" }),
   HealingTouch8 = Create({ Type = "Spell", ID = 9758, Desc = "Healing Touch" }),
   HealingTouch7 = Create({ Type = "Spell", ID = 8903, Desc = "Healing Touch" }),
   HealingTouch6 = Create({ Type = "Spell", ID = 6778, Desc = "Healing Touch" }),
   HealingTouch5 = Create({ Type = "Spell", ID = 5189, Desc = "Healing Touch" }),
   HealingTouch4 = Create({ Type = "Spell", ID = 5188, Desc = "Healing Touch" }),
   HealingTouch3 = Create({ Type = "Spell", ID = 5187, Desc = "Healing Touch" }),
   HealingTouch2 = Create({ Type = "Spell", ID = 5186, Desc = "Healing Touch" }),
   HealingTouch1 = Create({ Type = "Spell", ID = 5185, Desc = "Healing Touch" }),

   -- Regrowth ranks (10 total)
   Regrowth10 = Create({ Type = "Spell", ID = 26980, Desc = "Regrowth" }),
   Regrowth9 = Create({ Type = "Spell", ID = 9858, Desc = "Regrowth" }),
   Regrowth8 = Create({ Type = "Spell", ID = 9857, Desc = "Regrowth" }),
   Regrowth7 = Create({ Type = "Spell", ID = 9856, Desc = "Regrowth" }),
   Regrowth6 = Create({ Type = "Spell", ID = 9750, Desc = "Regrowth" }),
   Regrowth5 = Create({ Type = "Spell", ID = 8941, Desc = "Regrowth" }),
   Regrowth4 = Create({ Type = "Spell", ID = 8940, Desc = "Regrowth" }),
   Regrowth3 = Create({ Type = "Spell", ID = 8939, Desc = "Regrowth" }),
   Regrowth2 = Create({ Type = "Spell", ID = 8938, Desc = "Regrowth" }),
   Regrowth1 = Create({ Type = "Spell", ID = 8936, Desc = "Regrowth" }),

   -- Rejuvenation ranks (13 total)
   Rejuvenation13 = Create({ Type = "Spell", ID = 26982, Desc = "Rejuvenation" }),
   Rejuvenation12 = Create({ Type = "Spell", ID = 26981, Desc = "Rejuvenation" }),
   Rejuvenation11 = Create({ Type = "Spell", ID = 25299, Desc = "Rejuvenation" }),
   Rejuvenation10 = Create({ Type = "Spell", ID = 9841, Desc = "Rejuvenation" }),
   Rejuvenation9 = Create({ Type = "Spell", ID = 9840, Desc = "Rejuvenation" }),
   Rejuvenation8 = Create({ Type = "Spell", ID = 9839, Desc = "Rejuvenation" }),
   Rejuvenation7 = Create({ Type = "Spell", ID = 8910, Desc = "Rejuvenation" }),
   Rejuvenation6 = Create({ Type = "Spell", ID = 3627, Desc = "Rejuvenation" }),
   Rejuvenation5 = Create({ Type = "Spell", ID = 2091, Desc = "Rejuvenation" }),
   Rejuvenation4 = Create({ Type = "Spell", ID = 2090, Desc = "Rejuvenation" }),
   Rejuvenation3 = Create({ Type = "Spell", ID = 1430, Desc = "Rejuvenation" }),
   Rejuvenation2 = Create({ Type = "Spell", ID = 1058, Desc = "Rejuvenation" }),
   Rejuvenation1 = Create({ Type = "Spell", ID = 774, Desc = "Rejuvenation" }),

   -- Self-cast healing ranks
   SelfHealingTouch13 = Create({ Type = "Spell", ID = 26979, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch12 = Create({ Type = "Spell", ID = 26978, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch11 = Create({ Type = "Spell", ID = 25297, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch10 = Create({ Type = "Spell", ID = 9889, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch9 = Create({ Type = "Spell", ID = 9888, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch8 = Create({ Type = "Spell", ID = 9758, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch7 = Create({ Type = "Spell", ID = 8903, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch6 = Create({ Type = "Spell", ID = 6778, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch5 = Create({ Type = "Spell", ID = 5189, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch4 = Create({ Type = "Spell", ID = 5188, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch3 = Create({ Type = "Spell", ID = 5187, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch2 = Create({ Type = "Spell", ID = 5186, Desc = "Self Healing Touch", Click = { unit = "player" } }),
   SelfHealingTouch1 = Create({ Type = "Spell", ID = 5185, Desc = "Self Healing Touch", Click = { unit = "player" } }),

   SelfRegrowth10 = Create({ Type = "Spell", ID = 26980, Desc = "Self Regrowth", Click = { unit = "player" } }),
   SelfRegrowth9 = Create({ Type = "Spell", ID = 9858, Desc = "Self Regrowth", Click = { unit = "player" } }),
   SelfRegrowth8 = Create({ Type = "Spell", ID = 9857, Desc = "Self Regrowth", Click = { unit = "player" } }),
   SelfRegrowth7 = Create({ Type = "Spell", ID = 9856, Desc = "Self Regrowth", Click = { unit = "player" } }),
   SelfRegrowth6 = Create({ Type = "Spell", ID = 9750, Desc = "Self Regrowth", Click = { unit = "player" } }),
   SelfRegrowth5 = Create({ Type = "Spell", ID = 8941, Desc = "Self Regrowth", Click = { unit = "player" } }),
   SelfRegrowth4 = Create({ Type = "Spell", ID = 8940, Desc = "Self Regrowth", Click = { unit = "player" } }),
   SelfRegrowth3 = Create({ Type = "Spell", ID = 8939, Desc = "Self Regrowth", Click = { unit = "player" } }),
   SelfRegrowth2 = Create({ Type = "Spell", ID = 8938, Desc = "Self Regrowth", Click = { unit = "player" } }),
   SelfRegrowth1 = Create({ Type = "Spell", ID = 8936, Desc = "Self Regrowth", Click = { unit = "player" } }),

   SelfRejuvenation13 = Create({ Type = "Spell", ID = 26982, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation12 = Create({ Type = "Spell", ID = 26981, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation11 = Create({ Type = "Spell", ID = 25299, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation10 = Create({ Type = "Spell", ID = 9841, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation9 = Create({ Type = "Spell", ID = 9840, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation8 = Create({ Type = "Spell", ID = 9839, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation7 = Create({ Type = "Spell", ID = 8910, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation6 = Create({ Type = "Spell", ID = 3627, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation5 = Create({ Type = "Spell", ID = 2091, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation4 = Create({ Type = "Spell", ID = 2090, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation3 = Create({ Type = "Spell", ID = 1430, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation2 = Create({ Type = "Spell", ID = 1058, Desc = "Self Rejuvenation", Click = { unit = "player" } }),
   SelfRejuvenation1 = Create({ Type = "Spell", ID = 774, Desc = "Self Rejuvenation", Click = { unit = "player" } }),

   -- Utility
   RemoveCurse = Create({ Type = "Spell", ID = 2782, Desc = "Remove Curse" }),
   AbolishPoison = Create({ Type = "Spell", ID = 2893, Desc = "Abolish Poison" }),
   Innervate = Create({ Type = "Spell", ID = 29166, Desc = "Innervate" }),
   Barkskin = Create({ Type = "Spell", ID = 22812, Desc = "Barkskin" }),
   EntanglingRoots = Create({ Type = "Spell", ID = 339, useMaxRank = true }),

   -- Health Recovery Items
   HealthstoneMaster = Create({ Type = "Item", ID = 22105, Desc = "Healthstone Master" }),
   HealthstoneMajor = Create({ Type = "Item", ID = 22104, Desc = "Healthstone Major" }),
   SuperHealingPotion = Create({ Type = "Item", ID = 22829, Desc = "Super Healing Potion" }),
   MajorHealingPotion = Create({ Type = "Item", ID = 13446, Desc = "Major Healing Potion" }),

   -- Mana Recovery Items
   SuperManaPotion = Create({ Type = "Item", ID = 22832, Desc = "Super Mana Potion" }),
   DarkRune = Create({ Type = "Item", ID = 20520, Desc = "Dark Rune" }),
   DemonicRune = Create({ Type = "Item", ID = 12662, Desc = "Demonic Rune" }),

   -- Sapper Charges
   GoblinSapperCharge = Create({ Type = "Item", ID = 10646, Desc = "Goblin Sapper Charge" }),
   SuperSapperCharge = Create({ Type = "Item", ID = 23827, Desc = "Super Sapper Charge" }),

   -- Form-aware consumables (Cat Form variants)
   HealthstoneMasterCat = Create({ Type = "Spell", ID = 768, Desc = "Healthstone Master Cat Shift", Click = { macrobefore = "/use item:22105\n" } }),
   HealthstoneMajorCat = Create({ Type = "Spell", ID = 768, Desc = "Healthstone Major Cat Shift", Click = { macrobefore = "/use item:22104\n" } }),
   SuperHealingPotionCat = Create({ Type = "Spell", ID = 768, Desc = "Super Healing Potion Cat Shift", Click = { macrobefore = "/use item:22829\n" } }),
   MajorHealingPotionCat = Create({ Type = "Spell", ID = 768, Desc = "Major Healing Potion Cat Shift", Click = { macrobefore = "/use item:13446\n" } }),
   SuperManaPotionCat = Create({ Type = "Spell", ID = 768, Desc = "Super Mana Potion Cat Shift", Click = { macrobefore = "/use item:22832\n" } }),
   DarkRuneCat = Create({ Type = "Spell", ID = 768, Desc = "Dark Rune Cat Shift", Click = { macrobefore = "/use item:20520\n" } }),
   DemonicRuneCat = Create({ Type = "Spell", ID = 768, Desc = "Demonic Rune Cat Shift", Click = { macrobefore = "/use item:12662\n" } }),

   -- Form-aware consumables (Bear Form variants)
   HealthstoneMasterBear = Create({ Type = "Spell", ID = 9634, Desc = "Healthstone Master Bear Shift", Click = { macrobefore = "/use item:22105\n" } }),
   HealthstoneMajorBear = Create({ Type = "Spell", ID = 9634, Desc = "Healthstone Major Bear Shift", Click = { macrobefore = "/use item:22104\n" } }),
   SuperHealingPotionBear = Create({ Type = "Spell", ID = 9634, Desc = "Super Healing Potion Bear Shift", Click = { macrobefore = "/use item:22829\n" } }),
   MajorHealingPotionBear = Create({ Type = "Spell", ID = 9634, Desc = "Major Healing Potion Bear Shift", Click = { macrobefore = "/use item:13446\n" } }),
   SuperManaPotionBear = Create({ Type = "Spell", ID = 9634, Desc = "Super Mana Potion Bear Shift", Click = { macrobefore = "/use item:22832\n" } }),
   DarkRuneBear = Create({ Type = "Spell", ID = 9634, Desc = "Dark Rune Bear Shift", Click = { macrobefore = "/use item:20520\n" } }),
   DemonicRuneBear = Create({ Type = "Spell", ID = 9634, Desc = "Demonic Rune Bear Shift", Click = { macrobefore = "/use item:12662\n" } }),

   -- Sapper Shifting (Cat Form) - DMH instant-cast sequences
   CatGoblinSapperChargeAndShift = Create({ Type = "Spell", ID = 768, Desc = "Goblin Sapper Cat Shift", Click = { macrobefore = "/dmh start\n/dmh cd sapper\n/use Goblin Sapper Charge\n/cast !Cat Form\n/dmh end\n" } }),
   CatSuperSapperChargeAndShift = Create({ Type = "Spell", ID = 768, Desc = "Super Sapper Cat Shift", Click = { macrobefore = "/dmh start\n/dmh cd sapper\n/use Super Sapper Charge\n/cast !Cat Form\n/dmh end\n" } }),

   -- Racials
   Berserking = Create({ Type = "Spell", ID = 26297 }),
   BloodFury = Create({ Type = "Spell", ID = 33697 }),

   -- CC / Utility
   Cyclone = Create({ Type = "Spell", ID = 33786 }),
   Bash = Create({ Type = "Spell", ID = 8983 }),
   FeralChargeBear = Create({ Type = "Spell", ID = 16979 }),
   Maim = Create({ Type = "Spell", ID = 22570 }),
   NaturesGrasp = Create({ Type = "Spell", ID = 27009 }),
   Hibernate = Create({ Type = "Spell", ID = 18658 }),
}

-- ============================================================================
-- CLASS-SPECIFIC FRAMEWORK REFERENCES
-- ============================================================================
local A = setmetatable(Action[A.PlayerClass], { __index = Action })
NS.A = A

local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local get_spell_mana_cost = NS.get_spell_mana_cost
local try_cast = NS.try_cast
local try_cast_fmt = NS.try_cast_fmt
local is_spell_known = NS.is_spell_known
local PLAYER_UNIT = NS.PLAYER_UNIT
local TARGET_UNIT = NS.TARGET_UNIT

-- ============================================================================
-- GAME CONSTANTS
-- ============================================================================
local Constants = {
   STANCE = {
      CASTER = 0,
      BEAR = 1,
      CAT = 3,
      TRAVEL = 4,
      MOONKIN = 5,
      TREE = 5,
   },

   BUFF_ID = {
      CLEARCASTING = 16870,
      NATURES_GRACE = 16886,
   },

   TTD = {
      RIP_MIN = 10,
      RAKE_MIN = 6,
      BITE_EXECUTE = 6,
      SHORT_FIGHT = 10,
      FORCE_OF_NATURE_MIN = 15,
   },

   ENERGY = {
      CRITICAL = 10,
      CRITICAL_SHIFT = 15,
      MANGLE_POOL = 20,
      BITE_TRICK_MAX = 39,
      RAKE_TRICK_MIN = 35,
      EARLY_SHIFT = 20,
      EARLY_SHIFT_WOLFSHEAD = 25,
   },

   POWERSHIFT = {
      FUROR_ENERGY = 40,
      WOLFSHEAD_BONUS = 20,
      MIN_SHIFT_ENERGY_GAIN = 20,
   },

   HP = {
      EXECUTE = 25,
   },

   DURATION = {
      BITE_MIN_RIP = 3,
   },

   AOE = {
      RAKE_SPREAD_NEARBY = 8,
      HURRICANE_MIN_TARGETS = 3,
   },

   BALANCE = {
      FAERIE_FIRE_REFRESH = 3,
      MANA_TIER1 = 20,
      MANA_TIER2 = 10,
      MANA_LOW = 20,
   },

   BEAR = {
      MANGLE_CD = 6,
      LACERATE_MAX_STACKS = 5,
      LACERATE_DURATION = 15,
      LACERATE_URGENT_REFRESH = 3,
      LACERATE_SWIPE_THRESHOLD = 3,
      DEMO_ROAR_DURATION = 30,
      DEMO_ROAR_REFRESH = 5,
      DEFAULT_MAUL_RAGE = 25,
      DEFAULT_SWIPE_RAGE = 15,
      DEFAULT_SWIPE_TARGETS = 3,
      ENRAGE_RAGE_THRESHOLD = 20,
      DEMO_ROAR_MIN_TTD = 8,
      GROWL_MIN_TTD = 4,
      GROWL_CC_THRESHOLD = 2,
      ENRAGE_HP_SAFETY = 50,
      MAUL_AOE_EXTRA_RAGE = 15,
      FRENZIED_PROACTIVE_HP = 50,
      FRENZIED_PROACTIVE_RAGE = 50,
      DEFAULT_DEMO_ROAR_RANGE = 10,
      DEFAULT_DEMO_ROAR_MIN_BOSSES = 1,
      DEFAULT_DEMO_ROAR_MIN_ELITES = 2,
      DEFAULT_DEMO_ROAR_MIN_TRASH = 5,
      DEFAULT_CROAR_RANGE = 10,
      DEFAULT_CROAR_MIN_BOSSES = 1,
      DEFAULT_CROAR_MIN_ELITES = 3,
   },

   RESTO = {
      EMERGENCY_HP = 30,
      TANK_HEAL_HP = 50,
      STANDARD_HEAL_HP = 80,
      PROACTIVE_HP = 90,
      LIFEBLOOM_REFRESH = 2,
      SWIFTMEND_HP = 50,
   },
}

NS.Constants = Constants

-- ============================================================================
-- HEALING DATA TABLES
-- ============================================================================
local HEALING_TOUCH_RANKS = {
   {spell = A.HealingTouch13, heal = 2908},
   {spell = A.HealingTouch12, heal = 2472},
   {spell = A.HealingTouch11, heal = 2060},
   {spell = A.HealingTouch10, heal = 1890},
   {spell = A.HealingTouch9, heal = 1730},
   {spell = A.HealingTouch8, heal = 1590},
   {spell = A.HealingTouch7, heal = 1440},
   {spell = A.HealingTouch6, heal = 1290},
   {spell = A.HealingTouch5, heal = 1000},
   {spell = A.HealingTouch4, heal = 750},
   {spell = A.HealingTouch3, heal = 450},
   {spell = A.HealingTouch2, heal = 200},
   {spell = A.HealingTouch1, heal = 40},
}

local REGROWTH_RANKS = {
   {spell = A.Regrowth10, heal = 1142},
   {spell = A.Regrowth9, heal = 1003},
   {spell = A.Regrowth8, heal = 897},
   {spell = A.Regrowth7, heal = 803},
   {spell = A.Regrowth6, heal = 721},
   {spell = A.Regrowth5, heal = 650},
   {spell = A.Regrowth4, heal = 556},
   {spell = A.Regrowth3, heal = 256},
   {spell = A.Regrowth2, heal = 162},
   {spell = A.Regrowth1, heal = 93},
}

local REJUVENATION_RANKS = {
   {spell = A.Rejuvenation13, heal = 1344},
   {spell = A.Rejuvenation12, heal = 1192},
   {spell = A.Rejuvenation11, heal = 1060},
   {spell = A.Rejuvenation10, heal = 972},
   {spell = A.Rejuvenation9, heal = 888},
   {spell = A.Rejuvenation8, heal = 820},
   {spell = A.Rejuvenation7, heal = 756},
   {spell = A.Rejuvenation6, heal = 608},
   {spell = A.Rejuvenation5, heal = 488},
   {spell = A.Rejuvenation4, heal = 304},
   {spell = A.Rejuvenation3, heal = 180},
   {spell = A.Rejuvenation2, heal = 84},
   {spell = A.Rejuvenation1, heal = 32},
}

NS.HEALING_TOUCH_RANKS = HEALING_TOUCH_RANKS
NS.REGROWTH_RANKS = REGROWTH_RANKS
NS.REJUVENATION_RANKS = REJUVENATION_RANKS

-- Self-cast healing rank tables
local SELF_HEALING_TOUCH_RANKS = {
   {spell = A.SelfHealingTouch13, heal = 2908},
   {spell = A.SelfHealingTouch12, heal = 2472},
   {spell = A.SelfHealingTouch11, heal = 2060},
   {spell = A.SelfHealingTouch10, heal = 1890},
   {spell = A.SelfHealingTouch9, heal = 1730},
   {spell = A.SelfHealingTouch8, heal = 1590},
   {spell = A.SelfHealingTouch7, heal = 1440},
   {spell = A.SelfHealingTouch6, heal = 1290},
   {spell = A.SelfHealingTouch5, heal = 1000},
   {spell = A.SelfHealingTouch4, heal = 750},
   {spell = A.SelfHealingTouch3, heal = 450},
   {spell = A.SelfHealingTouch2, heal = 200},
   {spell = A.SelfHealingTouch1, heal = 40},
}
local SELF_REGROWTH_RANKS = {
   {spell = A.SelfRegrowth10, heal = 1142},
   {spell = A.SelfRegrowth9, heal = 1003},
   {spell = A.SelfRegrowth8, heal = 897},
   {spell = A.SelfRegrowth7, heal = 803},
   {spell = A.SelfRegrowth6, heal = 721},
   {spell = A.SelfRegrowth5, heal = 650},
   {spell = A.SelfRegrowth4, heal = 556},
   {spell = A.SelfRegrowth3, heal = 256},
   {spell = A.SelfRegrowth2, heal = 162},
   {spell = A.SelfRegrowth1, heal = 93},
}
local SELF_REJUVENATION_RANKS = {
   {spell = A.SelfRejuvenation13, heal = 1344},
   {spell = A.SelfRejuvenation12, heal = 1192},
   {spell = A.SelfRejuvenation11, heal = 1060},
   {spell = A.SelfRejuvenation10, heal = 972},
   {spell = A.SelfRejuvenation9, heal = 888},
   {spell = A.SelfRejuvenation8, heal = 820},
   {spell = A.SelfRejuvenation7, heal = 756},
   {spell = A.SelfRejuvenation6, heal = 608},
   {spell = A.SelfRejuvenation5, heal = 488},
   {spell = A.SelfRejuvenation4, heal = 304},
   {spell = A.SelfRejuvenation3, heal = 180},
   {spell = A.SelfRejuvenation2, heal = 84},
   {spell = A.SelfRejuvenation1, heal = 32},
}

NS.SELF_HEALING_TOUCH_RANKS = SELF_HEALING_TOUCH_RANKS
NS.SELF_REGROWTH_RANKS = SELF_REGROWTH_RANKS
NS.SELF_REJUVENATION_RANKS = SELF_REJUVENATION_RANKS

-- Pre-computed buff ID arrays
local REJUVENATION_BUFF_IDS = {}
local REGROWTH_BUFF_IDS = {}
for i, rank in ipairs(REJUVENATION_RANKS) do REJUVENATION_BUFF_IDS[i] = rank.spell.ID end
for i, rank in ipairs(REGROWTH_RANKS) do REGROWTH_BUFF_IDS[i] = rank.spell.ID end

NS.REJUVENATION_BUFF_IDS = REJUVENATION_BUFF_IDS
NS.REGROWTH_BUFF_IDS = REGROWTH_BUFF_IDS

-- Debuff ID arrays for multi-rank spells
local FAERIE_FIRE_DEBUFF_IDS = { 16857, 17390, 17391, 17392, 27011, 770, 778, 9749, 9907, 26993 }
local DEMO_ROAR_DEBUFF_IDS = { 99, 1735, 9490, 9747, 9898, 26998 }
local MANGLE_DEBUFF_IDS = { 33876, 33982, 33983, 33878, 33986, 33987 }
local RIP_DEBUFF_IDS = { 1079, 9492, 9493, 9752, 9894, 9896, 27008 }
local RAKE_DEBUFF_IDS = { 1822, 1823, 1824, 9904, 27003 }
local MOONFIRE_DEBUFF_IDS = { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835, 26987, 26988 }
local INSECT_SWARM_DEBUFF_IDS = { 5570, 24974, 24975, 24976, 24977, 27013 }

-- Self-buff ID arrays (all ranks + Gift variants for dashboard tracking)
local MOTW_BUFF_IDS = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 21849, 21850, 26991 }
local THORNS_BUFF_IDS = { 467, 782, 1075, 8914, 9756, 9910, 26992 }

NS.FAERIE_FIRE_DEBUFF_IDS = FAERIE_FIRE_DEBUFF_IDS
NS.DEMO_ROAR_DEBUFF_IDS = DEMO_ROAR_DEBUFF_IDS
NS.MANGLE_DEBUFF_IDS = MANGLE_DEBUFF_IDS
NS.THORNS_BUFF_IDS = THORNS_BUFF_IDS

-- ============================================================================
-- PLAYSTYLE CONSTANTS
-- ============================================================================
local PLAYSTYLE_CAT = "cat"
local PLAYSTYLE_BEAR = "bear"
local PLAYSTYLE_BALANCE = "balance"
local PLAYSTYLE_RESTO = "resto"
NS.PLAYSTYLE_CAT = PLAYSTYLE_CAT
NS.PLAYSTYLE_BEAR = PLAYSTYLE_BEAR
NS.PLAYSTYLE_BALANCE = PLAYSTYLE_BALANCE
NS.PLAYSTYLE_RESTO = PLAYSTYLE_RESTO

local PLAYSTYLE_NAMES = {
   [PLAYSTYLE_CAT] = "Cat (Feral DPS)",
   [PLAYSTYLE_BEAR] = "Bear (Feral Tank)",
   [PLAYSTYLE_BALANCE] = "Balance (Moonkin)",
   [PLAYSTYLE_RESTO] = "Resto (Healer)",
   [1] = "Cat (Feral DPS)",
   [2] = "Bear (Feral Tank)",
   [3] = "Balance (Moonkin)",
   [4] = "Resto (Healer)",
}

NS.PLAYSTYLE_NAMES = PLAYSTYLE_NAMES

-- ============================================================================
-- FORM COST UTILITIES
-- ============================================================================
local FORM_COST_CACHE_TTL = 5.0
local form_cost_cache = {
   [A.BearForm.ID]    = { cost = 0, expires = 0 },
   [A.CatForm.ID]     = { cost = 0, expires = 0 },
   [A.MoonkinForm.ID] = { cost = 0, expires = 0 },
   [A.TravelForm.ID]  = { cost = 0, expires = 0 },
}

local function get_form_cost(form_spell)
   local spell_id = form_spell.ID
   local cached = form_cost_cache[spell_id]
   local now = GetTime()
   if cached and now < cached.expires then
      return cached.cost
   end
   local cost = get_spell_mana_cost(form_spell)
   local resolved = (cost and cost > 0) and cost or 0
   if cached then
      cached.cost = resolved
      cached.expires = now + FORM_COST_CACHE_TTL
   end
   return resolved
end

NS.get_form_cost = get_form_cost

-- ============================================================================
-- FAERIE FIRE STRATEGY FACTORY (Druid-specific)
-- ============================================================================
local function create_faerie_fire_strategy(refresh_window, spell_override, only_mine)
   local ff_spell = spell_override or A.FaerieFire
   local ff_caster = only_mine and "player" or nil
   return {
      requires_combat = true,
      requires_enemy = true,
      requires_stealth = false,
      requires_phys_immune = false,
      spell = ff_spell,
      matches = function(context)
         -- Dropdown: "all", "elites", "bosses", "off" (backward compat: true → all)
         local ff_mode = context.settings.maintain_faerie_fire
         if ff_mode == "off" or ff_mode == false or ff_mode == nil then return false end
         if ff_mode == "bosses" or ff_mode == "elites" then
            local classification = _G.UnitClassification(TARGET_UNIT)
            if ff_mode == "bosses" then
               if classification ~= "worldboss" then return false end
            else -- "elites"
               if classification ~= "worldboss" and classification ~= "elite" and classification ~= "rareelite" then return false end
            end
         end
         if ff_spell:IsInRange(TARGET_UNIT) ~= true then return false end
         local ff_duration = Unit(TARGET_UNIT):HasDeBuffs(FAERIE_FIRE_DEBUFF_IDS, ff_caster, true) or 0
         if ff_duration > 0 and (not refresh_window or ff_duration > refresh_window) then return false end
         return true
      end,
      execute = function(icon, context)
         local ff_duration = Unit(TARGET_UNIT):HasDeBuffs(FAERIE_FIRE_DEBUFF_IDS, ff_caster, true) or 0
         if ff_duration == 0 then
            return try_cast(ff_spell, icon, TARGET_UNIT, "[FF] Faerie Fire - Debuff missing")
         end
         return try_cast_fmt(ff_spell, icon, TARGET_UNIT, "[FF]", "Faerie Fire", "Refreshing at %.1fs", ff_duration)
      end,
   }
end

NS.create_faerie_fire_strategy = create_faerie_fire_strategy

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
local STANCE_PLAYSTYLE = {
   [Constants.STANCE.BEAR] = "bear",
   [Constants.STANCE.CAT]  = "cat",
}

rotation_registry:register_class({
   name = "Druid",
   version = "v1.8.11",
   playstyles = {"caster", "cat", "bear", "balance", "resto"},
   idle_playstyle_name = "caster",

   get_active_playstyle = function(context)
      local stance = context.stance
      -- Bear(1) and Cat(3) have reliable fixed stance indices
      local known = STANCE_PLAYSTYLE[stance]
      if known then return known end
      -- Moonkin and Tree share a stance slot; use IsSpellKnown to differentiate
      -- (mutually exclusive 41pt talents, avoids detecting another druid's aura)
      if stance > 0 then
         if _G.IsSpellKnown(24858) then return "balance" end
         if _G.IsSpellKnown(33891) then return "resto" end
      end
      return nil
   end,

   get_idle_playstyle = function(context)
      local stance = context.stance
      if stance == Constants.STANCE.CASTER or stance == Constants.STANCE.MOONKIN then
         return "caster"
      end
      return nil
   end,

   playstyle_spells = {
      cat = {
         { spell = A.CatForm, name = "Cat Form", required = true },
         { spell = A.Shred, name = "Shred", required = true },
         { spell = A.Rip, name = "Rip", required = true },
         { spell = A.Rake, name = "Rake", required = true },
         { spell = A.FerociousBite, name = "Ferocious Bite", required = true },
         { spell = A.MangleCat, name = "Mangle (Cat)", required = false, note = "41pt Feral talent" },
         { spell = A.TigersFury, name = "Tiger's Fury", required = false },
         { spell = A.Prowl, name = "Prowl", required = false },
         { spell = A.Ravage, name = "Ravage", required = false },
         { spell = A.FaerieFire, name = "Faerie Fire (Feral)", required = false },
      },
      bear = {
         { spell = A.BearForm, name = "Dire Bear Form", required = true },
         { spell = A.Maul, name = "Maul", required = true },
         { spell = A.Swipe, name = "Swipe", required = true },
         { spell = A.DemoralizingRoar, name = "Demoralizing Roar", required = true },
         { spell = A.Growl, name = "Growl", required = true },
         { spell = A.MangleBear, name = "Mangle (Bear)", required = false, note = "41pt Feral talent" },
         { spell = A.Lacerate, name = "Lacerate", required = false, note = "requires level 66" },
         { spell = A.FrenziedRegeneration, name = "Frenzied Regeneration", required = false },
         { spell = A.Enrage, name = "Enrage", required = false },
         { spell = A.ChallengingRoar, name = "Challenging Roar", required = false },
         { spell = A.FaerieFire, name = "Faerie Fire (Feral)", required = false },
      },
      balance = {
         { spell = A.MoonkinForm, name = "Moonkin Form", required = true, note = "41pt Balance talent" },
         { spell = A.Starfire, name = "Starfire", required = true },
         { spell = A.Moonfire, name = "Moonfire", required = true },
         { spell = A.Wrath, name = "Wrath", required = true },
         { spell = A.InsectSwarm, name = "Insect Swarm", required = false, note = "Balance talent" },
         { spell = A.Hurricane, name = "Hurricane", required = false },
         { spell = A.ForceOfNature, name = "Force of Nature", required = false, note = "41pt Balance talent" },
         { spell = A.FaerieFireCaster, name = "Faerie Fire", required = false },
         { spell = A.Barkskin, name = "Barkskin", required = false },
      },
      resto = {
         { spell = A.Rejuvenation13, name = "Rejuvenation", required = true },
         { spell = A.Regrowth10, name = "Regrowth", required = true },
         { spell = A.NaturesSwiftness, name = "Nature's Swiftness", required = false, note = "21pt Resto talent" },
         { spell = A.Swiftmend, name = "Swiftmend", required = false, note = "31pt Resto talent" },
         { spell = A.Lifebloom, name = "Lifebloom", required = false, note = "requires level 64" },
         { spell = A.Tranquility, name = "Tranquility", required = false },
         { spell = A.Innervate, name = "Innervate", required = false },
         { spell = A.Barkskin, name = "Barkskin", required = false },
         { spell = A.RemoveCurse, name = "Remove Curse", required = false },
         { spell = A.AbolishPoison, name = "Abolish Poison", required = false },
      },
   },

   playstyle_labels = {
      cat = "Cat (Feral DPS)",
      bear = "Bear (Feral Tank)",
      balance = "Balance (Moonkin)",
      resto = "Resto (Healer)",
   },

   validate_playstyle_extra = function(playstyle, missing_spells, optional_missing)
      if playstyle == "resto" then
         local has_healing_touch = false
         for _, rank in ipairs(HEALING_TOUCH_RANKS or {}) do
            if rank.spell and is_spell_known(rank.spell) then
               has_healing_touch = true
               break
            end
         end
         if not has_healing_touch then
            tinsert(missing_spells, "Healing Touch (any rank)")
         end
      end
   end,

   extend_context = function(ctx)
      ctx.stance = Player:GetStance()
      ctx.is_stealthed = Player:IsStealthed()
      ctx.energy = Player:Energy()
      ctx.cp = Player:ComboPoints()
      ctx.rage = Player:Rage()
      ctx.is_behind = Player:IsBehind(0.3)
      ctx.has_clearcasting = (Unit("player"):HasBuffs(Constants.BUFF_ID.CLEARCASTING) or 0) > 0
      ctx.enemy_count = A.MultiUnits:GetByRange(8)
     
      ctx._cat_valid = false
      ctx._bear_valid = false
      ctx._resto_valid = false
   end,

   gap_handler = function(icon, context)
      if A.FeralChargeBear:IsReady(TARGET_UNIT) then
         return A.FeralChargeBear:Show(icon), "[GAP] Feral Charge"
      end
      if A.Dash:IsReady("player") then
         return A.Dash:Show(icon), "[GAP] Dash"
      end
      return nil
   end,

   dashboard = {
      resource = { type = "mana", label = "Mana" },
      secondary_resource = {
         cat  = { type = "energy", label = "Energy" },
         bear = { type = "rage",   label = "Rage" },
      },
      cooldowns = {
         cat     = { A.TigersFury, A.Trinket1, A.Trinket2 },
         bear    = { A.FrenziedRegeneration, A.Enrage, A.Barkskin, A.Trinket1, A.Trinket2 },
         balance = { A.ForceOfNature, A.Barkskin, A.SelfInnervate, A.Trinket1, A.Trinket2 },
         resto   = { A.NaturesSwiftness, A.Swiftmend, A.SelfInnervate, A.Barkskin, A.Tranquility },
         caster  = { A.Barkskin, A.SelfInnervate },
      },
      buffs = {
         { id = MOTW_BUFF_IDS, label = "MotW" },
         { id = THORNS_BUFF_IDS, label = "Thorns" },
         { id = 16864, label = "OoC" },
         { id = Constants.BUFF_ID.NATURES_GRACE, label = "NG" },
      },
      combo_points = { "cat" },
      debuffs = {
         cat = {
            { id = MANGLE_DEBUFF_IDS, label = "Mangle", target = true },
            { id = RIP_DEBUFF_IDS, label = "Rip", target = true },
            { id = RAKE_DEBUFF_IDS, label = "Rake", target = true },
            { id = FAERIE_FIRE_DEBUFF_IDS, label = "FF", target = true },
         },
         bear = {
            { id = 33745, label = "Lacerate", target = true, show_stacks = true },
            { id = MANGLE_DEBUFF_IDS, label = "Mangle", target = true },
            { id = DEMO_ROAR_DEBUFF_IDS, label = "Demo", target = true },
            { id = FAERIE_FIRE_DEBUFF_IDS, label = "FF", target = true },
         },
         balance = {
            { id = MOONFIRE_DEBUFF_IDS, label = "Moonfire", target = true },
            { id = INSECT_SWARM_DEBUFF_IDS, label = "IS", target = true },
            { id = FAERIE_FIRE_DEBUFF_IDS, label = "FF", target = true },
         },
      },
   },
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Druid]|r Class module loaded")
