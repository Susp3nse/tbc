
TellMeWhenDB = {
["profileKeys"] = {
},
["global"] = {
["TextLayouts"] = {
["bar2"] = {
{
},
{
},
},
["bar1"] = {
{
},
{
},
},
["TMW:textlayout:1TYfkpegTiCv"] = {
{
},
},
["icon1"] = {
{
},
{
},
},
["TMW:textlayout:1RFt2HZe_Cbk"] = {
{
},
},
["TMW:textlayout:1S6ieoFev4r0"] = {
{
},
},
["icon2"] = {
{
},
},
["TMW:textlayout:1Rh4g1a9S6Uf"] = {
{
},
},
["TMW:textlayout:1TMvg5InaYOw"] = {
{
["Shadow"] = 0.5,
["Anchors"] = {
{
["y"] = -2,
},
},
},
{
["Shadow"] = 0.5,
},
{
["Shadow"] = 0.5,
},
{
["Anchors"] = {
{
["y"] = -1.5,
["x"] = -0.5,
["point"] = "TOPRIGHT",
["relativePoint"] = "TOPRIGHT",
},
},
["Name"] = "2002 Bold",
["DefaultText"] = "[ActionRank]",
["Size"] = 6,
},
["n"] = 4,
},
["TMW:textlayout:1RkGJEN4L5o_"] = {
{
},
{
},
},
},
["HelpSettings"] = {
["SCROLLBAR_DROPDOWN"] = false,
["SUG_FIRSTHELP"] = true,
},
["Groups"] = {
{
["BackdropColor"] = "cb000000",
["Point"] = {
["y"] = -30,
["relativeTo"] = "TargetFrame",
["point"] = "BOTTOMLEFT",
["relativePoint"] = "BOTTOMLEFT",
["x"] = -5,
},
["Scale"] = 1.18,
["TextureName"] = "Blizzard Raid Bar",
["Locked"] = true,
["Columns"] = 1,
["BackdropColor_Enable"] = true,
["Icons"] = {
{
["Unit"] = "target",
["Type"] = "TheAction - UnitCasting",
["Enabled"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
["BackdropColor"] = "7f330c0a",
["BarDisplay_Invert"] = true,
["TimerBar_MiddleColor"] = "ffff0000",
["TimerBar_CompleteColor"] = "ffff0000",
["NoPocketwatch"] = true,
},
},
["Name"] = "Target Castbar",
["SettingsPerView"] = {
["bar"] = {
["SizeX"] = 170,
["BorderInset"] = true,
["BorderIcon"] = 0.5,
},
},
["Conditions"] = {
{
["Type"] = "LUA",
["Name"] = "return Action and Action.IsInitialized and GetToggle(1, \"TargetCastBar\")",
},
["n"] = 1,
},
["View"] = "bar",
["GUID"] = "TMW:group:1TQgp5sK81OZ",
},
},
["AllowCombatConfig"] = true,
["OS"] = 1769968194,
["ActionDB"] = {
[5] = {
["PvP"] = {
["PurgeLow"] = {
[1044] = {
["dur"] = 1.5,
},
[8936] = {
["dur"] = 0,
["onlyBear"] = true,
},
[774] = {
["dur"] = 0,
["onlyBear"] = true,
},
[1126] = {
["dur"] = 0,
["onlyBear"] = true,
},
},
["Disease"] = {
},
["PurgeHigh"] = {
[20216] = {
["dur"] = 0,
},
[17730] = {
["dur"] = 2,
},
[13896] = {
["dur"] = 1.5,
},
[10060] = {
["dur"] = 4,
},
[12042] = {
["dur"] = 4,
},
[11129] = {
["dur"] = 4,
},
[16188] = {
["dur"] = 1.5,
},
[128] = {
["dur"] = 2,
},
[18288] = {
["dur"] = 10,
},
[1022] = {
["dur"] = 1,
},
[16166] = {
["dur"] = 1.5,
},
[18708] = {
["dur"] = 0,
},
[17729] = {
["dur"] = 2,
},
},
["Poison"] = {
[3043] = {
["dur"] = 1.5,
},
[3332] = {
},
[19386] = {
["dur"] = 0,
},
[3034] = {
["dur"] = 2,
},
[1978] = {
["dur"] = 3,
},
[2094] = {
["dur"] = 2.5,
},
},
["Magic"] = {
[122] = {
["dur"] = 1,
},
[20683] = {
},
[710] = {
},
[4068] = {
},
[26108] = {
["dur"] = 1,
},
[1499] = {
["dur"] = 1,
},
[18425] = {
["dur"] = 1,
},
[20066] = {
["dur"] = 1.5,
},
[19185] = {
["dur"] = 1.5,
},
[8122] = {
["dur"] = 1.5,
},
[15487] = {
["dur"] = 1,
},
[19821] = {
},
[15269] = {
["dur"] = 1,
},
[14325] = {
},
[28271] = {
["dur"] = 1.5,
},
[28272] = {
["dur"] = 1.5,
},
[8312] = {
["dur"] = 1,
},
[17820] = {
},
[6789] = {
["dur"] = 1,
},
[851] = {
["dur"] = 1.5,
},
[853] = {
["dur"] = 0,
},
[605] = {
["dur"] = 0,
},
[339] = {
["dur"] = 1,
},
[9484] = {
["dur"] = 1,
},
[17390] = {
["dur"] = 0,
},
[24259] = {
["dur"] = 1,
},
[17286] = {
},
[835] = {
["dur"] = 1,
},
[9159] = {
},
[18278] = {
},
[22519] = {
["dur"] = 1,
},
[2637] = {
["dur"] = 1.5,
},
[6358] = {
["dur"] = 1.5,
},
[5484] = {
["dur"] = 1.5,
},
[118] = {
["dur"] = 1.5,
},
[5782] = {
["dur"] = 1.5,
},
},
["BlessingofProtection"] = {
[20253] = {
["dur"] = 2.6,
},
[5211] = {
["dur"] = 1.6,
},
[5246] = {
["dur"] = 4.5,
},
[14251] = {
["dur"] = 5,
["LUA"] = "return Unit(thisunit):IsMelee() and Unit(thisunit):HasBuffs(\"DamageBuffs_Melee\") > 0",
},
[9005] = {
["dur"] = 1.6,
},
[1833] = {
["dur"] = 3,
},
[5530] = {
["dur"] = 2.6,
},
[19503] = {
["dur"] = 3,
},
[12798] = {
["dur"] = 2.6,
},
[12809] = {
["dur"] = 4,
},
[19410] = {
["dur"] = 2.8,
},
[23365] = {
["dur"] = 5,
["LUA"] = "return Unit(thisunit):IsMelee() and Unit(thisunit):HasBuffs(\"DamageBuffs_Melee\") > 0",
},
[408] = {
["dur"] = 4.5,
},
[20685] = {
["dur"] = 3,
},
[56] = {
["dur"] = 3,
},
[676] = {
["dur"] = 5,
["LUA"] = "return Unit(thisunit):IsMelee() and Unit(thisunit):HasBuffs(\"DamageBuffs_Melee\") > 0",
},
[16922] = {
["dur"] = 3,
},
},
["BlackList"] = {
},
["PurgeFriendly"] = {
[605] = {
["canStealOrPurge"] = true,
},
},
["Curse"] = {
[1714] = {
["dur"] = 3,
},
[21330] = {
},
[702] = {
["dur"] = 3,
},
[1490] = {
},
[17862] = {
},
[603] = {
},
[9035] = {
},
[8277] = {
},
},
["Enrage"] = {
[18499] = {
["dur"] = 1,
},
[12880] = {
["dur"] = 1,
},
},
["Frenzy"] = {
},
["BlessingofFreedom"] = {
[19185] = {
["dur"] = 2,
},
[22519] = {
["dur"] = 2,
},
[339] = {
["dur"] = 2,
},
[23694] = {
["dur"] = 2,
},
[13809] = {
["dur"] = 0,
},
[19675] = {
["dur"] = 2,
},
[19229] = {
["dur"] = 2,
},
[25999] = {
["dur"] = 2,
},
[12494] = {
["dur"] = 2,
},
[122] = {
["dur"] = 2,
},
},
["BlessingofSacrifice"] = {
[1833] = {
["dur"] = 3,
},
[408] = {
["dur"] = 4.5,
},
[12809] = {
["dur"] = 4,
},
},
["Vanish"] = {
[122] = {
},
[22519] = {
},
[339] = {
},
},
},
["PvE"] = {
["PurgeLow"] = {
},
["Disease"] = {
[3429] = {
},
[9775] = {
},
[3256] = {
},
[16461] = {
},
[18289] = {
},
[21062] = {
},
[14535] = {
},
[16143] = {
},
[14539] = {
},
[8137] = {
},
[7901] = {
},
[23155] = {
},
[5413] = {
},
[8138] = {
},
[8139] = {
},
[12245] = {
},
[8014] = {
},
[10136] = {
},
[18633] = {
},
[7102] = {
},
[3150] = {
},
[8016] = {
},
[4316] = {
},
[3584] = {
},
[16128] = {
},
[8600] = {
},
[3427] = {
},
[18270] = {
},
[11374] = {
},
[15848] = {
},
[16448] = {
},
[12946] = {
["LUA"] = " return not UnitIsUnit(thisunit, \"player\") ",
},
[16458] = {
},
[30113] = {
},
[9796] = {
},
[6817] = {
},
[6819] = {
},
[6951] = {
},
[3439] = {
},
},
["PurgeHigh"] = {
[19714] = {
},
},
["Poison"] = {
[3609] = {
["LUA"] = " return not UnitIsUnit(thisunit, \"player\") ",
},
[23260] = {
},
[15475] = {
},
[24688] = {
["dur"] = 1.5,
},
[25262] = {
},
[20629] = {
["dur"] = 1.5,
},
[16460] = {
},
[22335] = {
},
[22661] = {
},
[14532] = {
},
[14110] = {
},
[3332] = {
},
[28311] = {
},
[17197] = {
},
[13526] = {
},
[21069] = {
},
[14534] = {
},
[5105] = {
},
[4286] = {
},
[17196] = {
},
[8256] = {
},
[13582] = {
},
[18949] = {
["dur"] = 1.5,
},
[3388] = {
},
[23169] = {
},
},
["Magic"] = {
[16838] = {
["dur"] = 1,
},
[8150] = {
["dur"] = 1,
},
[12742] = {
["dur"] = 2,
},
[17293] = {
["dur"] = 1,
},
[11264] = {
["dur"] = 6,
},
[22274] = {
},
[10730] = {
},
[16798] = {
["dur"] = 1,
},
[7399] = {
},
[113] = {
["dur"] = 12,
},
[11836] = {
["dur"] = 1,
},
[7967] = {
},
[19702] = {
["dur"] = 1.5,
},
[11020] = {
["dur"] = 1,
},
[228] = {
},
[19393] = {
["dur"] = 1.5,
},
[28406] = {
},
[8281] = {
["dur"] = 0.5,
},
[13327] = {
["dur"] = 1,
},
[7074] = {
["dur"] = 1,
},
[8142] = {
["dur"] = 4,
},
[19659] = {
},
[19408] = {
},
[23603] = {
},
[6728] = {
["dur"] = 1,
},
[13880] = {
["dur"] = 1.5,
},
[17172] = {
},
[12890] = {
["LUA"] = " return not UnitIsUnit(thisunit, \"player\") ",
},
[7964] = {
["dur"] = 1,
},
[16104] = {
["dur"] = 1,
["LUA"] = " return not UnitIsUnit(thisunit, \"player\") ",
},
[23952] = {
["dur"] = 2,
},
[20740] = {
},
[19369] = {
["dur"] = 1.5,
},
},
["BlessingofProtection"] = {
[5134] = {
["dur"] = 8,
},
[21869] = {
["dur"] = 6,
},
[18431] = {
["dur"] = 2.6,
},
},
["BlackList"] = {
},
["PurgeFriendly"] = {
[605] = {
["canStealOrPurge"] = true,
},
[15859] = {
},
[12888] = {
},
},
["Curse"] = {
[11963] = {
},
[15730] = {
},
[19713] = {
},
[16567] = {
},
[18702] = {
},
[19372] = {
},
[16336] = {
},
[24054] = {
},
[6909] = {
},
[16429] = {
},
[7068] = {
["dur"] = 1.5,
},
[13524] = {
},
[3387] = {
},
[26977] = {
},
[7621] = {
},
[16098] = {
},
[19703] = {
},
[11960] = {
},
[17738] = {
},
[13619] = {
},
[12480] = {
},
[24306] = {
},
[22371] = {
},
[4060] = {
},
[21330] = {
},
[21056] = {
},
[16071] = {
},
[28342] = {
},
[17105] = {
},
[19716] = {
},
},
["Enrage"] = {
},
["Frenzy"] = {
[19451] = {
["dur"] = 1.5,
},
},
["BlessingofFreedom"] = {
[23414] = {
["dur"] = 2,
},
[15474] = {
["dur"] = 2,
},
[19636] = {
["dur"] = 2,
},
[8377] = {
["dur"] = 2,
},
[745] = {
["dur"] = 2,
},
[113] = {
["dur"] = 2,
},
[8142] = {
["dur"] = 2,
},
[11820] = {
["dur"] = 2,
},
[13099] = {
["dur"] = 2,
},
[14030] = {
["dur"] = 2,
},
[12252] = {
["dur"] = 2,
},
[11264] = {
["dur"] = 2,
},
[8346] = {
["dur"] = 2,
},
[4962] = {
["dur"] = 2,
},
[8312] = {
["dur"] = 2,
},
[7295] = {
["dur"] = 2,
},
[19306] = {
["dur"] = 2,
},
[6533] = {
["dur"] = 2,
},
},
["BlessingofSacrifice"] = {
},
["Vanish"] = {
},
},
},
["Ver"] = 2,
["InterfaceLanguage"] = "Auto",
["minimap"] = {
},
},
["NumGroups"] = 1,
["Account"] = "GSSwYvC08orRuWqnQmATfFbNdsHB0TaqB/zXnJ4YDrgya4G6SN2ubq6uqc9K68t5kf4UblfrKDjGFgV+/s+Av2UC2pM6UPyxbNbFBmUvrXaV5IO9wh0SAT6yzfMrjmEvUZhlsQw6dNXYf0lyBJlDV1skeBk49okS/x5JZmMcJ45gPrvU/ruGcNTgvVpX6kcMEigXGmZIPZaMh0e1KidPSURrGj3h437qoclYEEg7VVOW/r36nPtqC8GfO+iqJacTQumvg7+HXQb/czB1K3bSHY+cs99dhBO2nfizYTHynqOWFpB5DdYCWm4fUEg68xJd7bMtT5bnnH2BwndJaPteAEf4z9XqhLcjXDhL3MXBgaSapXGZlgqrDZnl+IrdRnz0A8uwJd2EjWYQnqY6iVRceb9HGhuIGK18r5BLcPS4xlRWOn9hc7tt1PLO2kG+LshhnzPTjnH61xDkAvKZEC5tOmEsJg==",
},
["Version"] = 12000703,
["profiles"] = {
["__template__"] = {
["TextureName"] = "Flat",
["Version"] = 12000703,
["NumGroups"] = 6,
["CodeSnippets"] = {
["n"] = 0,
},
["Groups"] = {
{
["GUID"] = "TMW:group:1Rhh0xLqd4g8",
["Point"] = {
["y"] = 12,
["x"] = -29,
["point"] = "TOPLEFT",
["relativePoint"] = "TOPLEFT",
},
["Scale"] = 0.600000023841858,
["TimerBar_CompleteColor"] = "ff000000",
["Name"] = "Shown Main",
["TimerBar_StartColor"] = "ff000000",
["Locked"] = true,
["Columns"] = 8,
["Icons"] = {
{
["Enabled"] = true,
["Type"] = "meta",
["Icons"] = {
"TMW:icon:1T0KeNg=IDQd",
},
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["Enabled"] = true,
["Type"] = "meta",
["Icons"] = {
"TMW:icon:1T0KeNh2uwMT",
},
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["GUID"] = "TMW:icon:1T0MjrGnynSL",
["Type"] = "meta",
["Enabled"] = true,
["Icons"] = {
"TMW:icon:1T0Kg0ZzHksM",
},
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["GUID"] = "TMW:icon:1T0NdouSxYDb",
["Type"] = "meta",
["Enabled"] = true,
["Icons"] = {
"TMW:icon:1T0Kg0a1tFci",
},
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["Enabled"] = true,
["Type"] = "meta",
["Icons"] = {
"TMW:icon:1T0Kg0a6eYf9",
},
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["Enabled"] = true,
["Type"] = "meta",
["Icons"] = {
"TMW:icon:1T0Kg0aBPYen",
},
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["Enabled"] = true,
["Type"] = "meta",
["Icons"] = {
"TMW:icon:1T0Kg0aG1oeM",
},
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["Enabled"] = true,
["Type"] = "meta",
["Icons"] = {
"TMW:icon:1T0Kg0aKbPUI",
},
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
},
["TimerBar_MiddleColor"] = "ff000000",
},
{
["GUID"] = "TMW:group:1T0KXe2TsCkW",
["Point"] = {
["y"] = 50,
["x"] = -29.0000038146973,
["point"] = "TOPLEFT",
["relativePoint"] = "TOPLEFT",
},
["Scale"] = 0.600000023841858,
["TimerBar_CompleteColor"] = "ff000000",
["Name"] = "Hidden APL",
["TimerBar_StartColor"] = "ff000000",
["Locked"] = true,
["Columns"] = 8,
["Icons"] = {
{
["GUID"] = "TMW:icon:1T0KeNg=IDQd",
["Type"] = "conditionicon",
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "Rotation(thisobj)",
["Type"] = "LUA",
},
["n"] = 1,
},
["FakeHidden"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["GUID"] = "TMW:icon:1T0KeNh2uwMT",
["Type"] = "conditionicon",
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "Rotation(thisobj)",
["Type"] = "LUA",
},
["n"] = 1,
},
["FakeHidden"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["GUID"] = "TMW:icon:1T0Kg0ZzHksM",
["Type"] = "conditionicon",
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "Rotation(thisobj)",
["Type"] = "LUA",
},
["n"] = 1,
},
["FakeHidden"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["GUID"] = "TMW:icon:1T0Kg0a1tFci",
["Type"] = "conditionicon",
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "Rotation(thisobj)",
["Type"] = "LUA",
},
["n"] = 1,
},
["FakeHidden"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["GUID"] = "TMW:icon:1T0Kg0a6eYf9",
["Type"] = "conditionicon",
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "Rotation(thisobj)",
["Type"] = "LUA",
},
["n"] = 1,
},
["FakeHidden"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["GUID"] = "TMW:icon:1T0Kg0aBPYen",
["Type"] = "conditionicon",
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "Rotation(thisobj)",
["Type"] = "LUA",
},
["n"] = 1,
},
["FakeHidden"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["GUID"] = "TMW:icon:1T0Kg0aG1oeM",
["Type"] = "conditionicon",
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "Rotation(thisobj)",
["Type"] = "LUA",
},
["n"] = 1,
},
["FakeHidden"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["GUID"] = "TMW:icon:1T0Kg0aKbPUI",
["Type"] = "conditionicon",
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "Rotation(thisobj)",
["Type"] = "LUA",
},
["n"] = 1,
},
["FakeHidden"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
{
["ShowTimerText"] = true,
["States"] = {
{
},
nil,
{
},
{
},
},
},
},
["TimerBar_MiddleColor"] = "ff000000",
},
{
["GUID"] = "TMW:group:1P3cu8AAtSYM",
["Columns"] = 1,
["Name"] = "Visible APL",
["SettingsPerView"] = {
["icon"] = {
["BorderInset"] = true,
["BorderIcon"] = 1.5,
},
},
["Locked"] = true,
["Conditions"] = {
{
["Name"] = "return not GetToggle(1, \"DisableRotationDisplay\")",
["Type"] = "LUA",
},
["n"] = 1,
},
["Icons"] = {
{
["GUID"] = "TMW:icon:1T0MjsTsMtq6",
["Type"] = "meta",
["Events"] = {
{
["OnlyShown"] = true,
["Type"] = "Lua",
["Lua"] = "Action.ToggleMainUI()",
["Event"] = "OnRightClick",
},
["n"] = 1,
},
["Enabled"] = true,
["Icons"] = {
"TMW:icon:1ThI9XCjZDaF",
"TMW:icon:1T0MjrGnynSL",
"TMW:icon:1ThI9XCnmSqm",
},
["States"] = {
{
},
nil,
{
},
{
},
},
},
},
["Point"] = {
["x"] = -0.0001220703125,
["relativeTo"] = "TMW:group:1TMvhh5X05mC",
},
},
{
["GUID"] = "TMW:group:1TMvhh5X05mC",
["Point"] = {
["y"] = 44.58755493164063,
["x"] = -302.7022399902344,
["point"] = "BOTTOM",
["relativePoint"] = "BOTTOM",
},
["Columns"] = 1,
["Level"] = 11,
["Conditions"] = {
{
["Name"] = "return not GetToggle(1, \"DisableRotationDisplay\") and not GetToggle(1, \"DisableRotationModes\")",
["Type"] = "LUA",
},
["n"] = 1,
},
["Icons"] = {
{
["Enabled"] = true,
["Type"] = "conditionicon",
["Events"] = {
{
["OnlyShown"] = true,
["Type"] = "Lua",
["Lua"] = "if IsShiftKeyDown() then\n    Action.ToggleBurst()\nelseif IsControlKeyDown() then\n    Action.ToggleMode()\nelseif IsAltKeyDown() then\n    Action.ToggleAoE()\nelse\n    Action.PrintHelpToggle()\nend",
["Event"] = "OnLeftClick",
},
{
["OnlyShown"] = true,
["Type"] = "Lua",
["Lua"] = "Action.ToggleMainUI()",
["Event"] = "OnRightClick",
},
["n"] = 2,
},
["SettingsPerView"] = {
["icon"] = {
["TextLayout"] = "TMW:textlayout:1TMvg5InaYOw",
["Texts"] = {
"[ActionBurst]",
},
},
},
["CustomTex"] = "NONE",
["States"] = {
{
},
{
["Alpha"] = 1,
},
{
},
{
},
},
},
},
["Name"] = "Visible APL Layout",
},
{
["GUID"] = "TMW:group:1ThI5PpEuV8I",
["Point"] = {
["y"] = 2,
["relativeTo"] = "PlayerFrame",
["x"] = -21,
},
["Locked"] = true,
["Columns"] = 1,
["Icons"] = {
{
["Enabled"] = true,
["ShowTimer"] = true,
["ShowTimerText"] = true,
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Conditions"] = {
{
["Name"] = "return LossOfControl:IsEnabled(\"PlayerFrame\")",
["Type"] = "LUA",
},
["n"] = 1,
},
["Type"] = "TheAction - LossOfControl",
["States"] = {
{
["Alpha"] = 0,
},
{
["Alpha"] = 1,
},
{
},
{
},
},
},
},
["Name"] = "Visible LoC PlayerFrame",
},
{
["GUID"] = "TMW:group:1ThI9JkxdKiN",
["Scale"] = 1,
["Name"] = "Hidden LoC RotationFrame",
["Columns"] = 1,
["Locked"] = true,
["Rows"] = 2,
["Icons"] = {
{
["GUID"] = "TMW:icon:1ThI9XCjZDaF",
["ShowTimer"] = true,
["FakeHidden"] = true,
["ShowTimerText"] = true,
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "return LossOfControl:IsEnabled(\"RotationFrame\") and LossOfControl:GetFrameOrder() <= 3",
["Type"] = "LUA",
},
["n"] = 1,
},
["Type"] = "TheAction - LossOfControl",
["States"] = {
{
["Alpha"] = 0,
},
{
["Alpha"] = 1,
},
{
},
{
},
[102] = {
["Alpha"] = 1,
},
},
},
{
["GUID"] = "TMW:icon:1ThI9XCnmSqm",
["ShowTimer"] = true,
["FakeHidden"] = true,
["ShowTimerText"] = true,
["SettingsPerView"] = {
["icon"] = {
["Texts"] = {
[2] = "",
},
},
},
["Enabled"] = true,
["Conditions"] = {
{
["Name"] = "return LossOfControl:IsEnabled(\"RotationFrame\") and LossOfControl:GetFrameOrder() > 1",
["Type"] = "LUA",
},
["n"] = 1,
},
["Type"] = "TheAction - LossOfControl",
["States"] = {
{
["Alpha"] = 0,
},
{
["Alpha"] = 1,
},
{
},
{
},
[102] = {
["Alpha"] = 1,
},
},
},
},
["Point"] = {
["y"] = -15,
["x"] = -29,
["point"] = "TOPLEFT",
["relativePoint"] = "TOPLEFT",
},
},
},
["Locked"] = true,
["ActionDB"] = {
{
["ColorPickerConfig"] = {
["progressBar"] = {
["color"] = {
},
},
["font"] = {
["color"] = {
["normal"] = {
},
["subtitle"] = {
},
["disabled"] = {
},
["tooltip"] = {
},
["header"] = {
},
},
},
["highlight"] = {
["color"] = {
},
["blank"] = {
},
},
["backdrop"] = {
["panel"] = {
["a"] = 0.8,
["r"] = 0.0588,
["g"] = 0.0588,
["b"] = 0,
},
["highlight"] = {
},
["border"] = {
},
["button"] = {
},
["buttonDisabled"] = {
},
["borderDisabled"] = {
},
["slider"] = {
},
},
},
["AuraDuration"] = true,
["CheckDeadOrGhost"] = true,
["CheckCombat"] = false,
["DisableMinimap"] = false,
["AutoShoot"] = true,
["ReTarget"] = true,
["DisableBlackBackground"] = false,
["StopAtBreakAble"] = false,
["AntiFakePauses"] = {
false,
false,
false,
false,
false,
false,
},
["CheckDeadOrGhostTarget"] = true,
["DisableRegularFrames"] = false,
["Potion"] = true,
["TargetRealHealth"] = true,
["AuraCCPortrait"] = true,
["TargetPercentHealth"] = true,
["DisableRotationDisplay"] = false,
["DisableSounds"] = true,
["DisableRotationModes"] = false,
["LOSCheck"] = true,
["Racial"] = true,
["TargetCastBar"] = true,
["cameraDistanceMaxZoomFactor"] = true,
["ReFocus"] = true,
["AutoTarget"] = true,
["StopCast"] = true,
["CVars"] = {
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
},
["Role"] = "AUTO",
["LetMeCast"] = true,
["LossOfControlPlayerFrame"] = true,
["CheckEatingOrDrinking"] = true,
["Trinkets"] = {
true,
true,
},
["CheckMount"] = true,
["HideOnScreenshot"] = true,
["FPS"] = -0.01,
["ColorPickerUse"] = false,
["Burst"] = "Auto",
["DisablePrint"] = false,
["ColorPickerOption"] = "panel",
["ColorPickerElement"] = "backdrop",
["LossOfControlRotationFrame"] = false,
["DisableAddonsCheck"] = false,
["DisableClassPortraits"] = false,
["BossMods"] = true,
["CheckSpellIsTargeting"] = true,
["LossOfControlTypes"] = {
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
true,
},
["LetMeDrag"] = false,
["AutoAttack"] = false,
["CheckLootFrame"] = true,
["HealthStone"] = 20,
},
{
["UseFrenziedRegen"] = true,
["UseTrinket1"] = true,
["UseOpener"] = true,
["UseMangledOpener"] = false,
["UseInnervateSelf"] = true,
["FocusProwl"] = true,
["BiteExecuteHP"] = 25,
["RestoEnableDPS"] = true,
["UseForceOfNature"] = true,
["MaintainInsectSwarm"] = true,
["RestoEmergencyHP"] = 20,
["UseTigersFury"] = false,
["RestoTankHealHP"] = 50,
["Playstyle"] = "cat",
["ManaReserve"] = 900,
["RipRefreshTime"] = 0,
["HealthstoneHP"] = 30,
["AutoRemovePoison"] = true,
["RestoStandardHealHP"] = 70,
["MaintainFaerieFire"] = true,
["MaintainLacerate"] = true,
["AutoRemoveCurse"] = true,
["ProwlDistance"] = 15,
["RipMinCP"] = 4,
["FBMinRipDuration"] = 6,
["MaulRageThreshold"] = 60,
["DebugMode"] = true,
["BiteExecuteTTD"] = 6,
["UseChallengingRoar"] = true,
["UseTrinket2"] = true,
["MaintainRip"] = true,
["BalanceTier1Mana"] = 40,
["TigersFuryEnergy"] = 100,
["MaxRakeTargets"] = 4,
["HurricaneMinTargets"] = 3,
["FBMinEnergy"] = 35,
["RipMinTTD"] = 12,
["MaintainMoonfire"] = true,
["EnrageRageThreshold"] = 20,
["UseHealthstone"] = true,
["UseEnrage"] = true,
["RestoProactiveHP"] = 85,
["EmergencyHealHP"] = 30,
["AutoPowershift"] = true,
["HealingPotionHP"] = 25,
["ForceOfNatureMinTTD"] = 30,
["RestoDPSThreshold"] = 95,
["PowershiftMinMana"] = 25,
["MaintainDemoRoar"] = true,
["SwipeMinTargets"] = 1,
["RestoManaConserve"] = 40,
["CriticalHealHP"] = 20,
["RejuvenationHP"] = 70,
["UseHealingPotion"] = true,
["RakeRefreshTime"] = 0,
["AoEEnemyCount"] = 3,
["UseRakeTrick"] = true,
["RegrowthHP"] = 30,
["UseRacial"] = true,
["SpreadRake"] = true,
["RestoPrioritizeTank"] = true,
["UseGrowl"] = true,
["BalanceTier2Mana"] = 20,
["EnableAoE"] = true,
["InnervateMana"] = 30,
["DebugSystem"] = false,
},
{
["QluaActions"] = {
},
["luaActions"] = {
},
["macroActions"] = {
},
["AutoHidden"] = true,
["disabledActions"] = {
},
},
{
["MainPvE"] = {
["Min"] = 34,
["enUS"] = {
},
["Max"] = 51,
},
["UseHeal"] = true,
["MousePvP"] = {
["Min"] = 27,
["enUS"] = {
},
["Max"] = 44,
},
["MouseAuto"] = true,
["Heal"] = {
["Min"] = 54,
["enUS"] = {
["Healing Touch"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 25297,
["useRacial"] = true,
},
["Greater Heal"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 2060,
["useRacial"] = true,
},
["Prayer of Healing"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 596,
["useRacial"] = true,
},
["Tranquility"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 740,
["useRacial"] = true,
},
["Lesser Heal"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 2050,
["useRacial"] = true,
},
["Lesser Healing Wave"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 8004,
["useRacial"] = true,
},
["Heal"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 6064,
["useRacial"] = true,
},
["Chain Heal"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 1064,
["useRacial"] = true,
},
["Flash of Light"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 19750,
["useRacial"] = true,
},
["Regrowth"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 8936,
["useRacial"] = true,
},
["Healing Wave"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 331,
["useRacial"] = true,
},
["Holy Light"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 635,
["useRacial"] = true,
},
},
["Max"] = 92,
},
["PvP"] = {
["Min"] = 58,
["enUS"] = {
["Crippling Poison"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 3420,
["useRacial"] = true,
},
["Shackle Undead"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 9484,
["useRacial"] = true,
},
["Deadly Poison"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 2823,
["useRacial"] = true,
},
["Ghost Wolf"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 2645,
["useRacial"] = true,
},
["Instant Poison"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 8681,
["useRacial"] = true,
},
["Scare Beast"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 1513,
["useRacial"] = true,
},
["Turn Undead"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 2878,
["useRacial"] = true,
},
["Create Soulstone"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 693,
["useRacial"] = true,
},
["Hibernate"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 2637,
["useRacial"] = true,
},
["Howl of Terror"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 5484,
["useRacial"] = true,
},
["Inferno"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 1122,
["useRacial"] = true,
},
["Wyvern Sting"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 19386,
["useRacial"] = true,
},
["Banish"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 710,
["useRacial"] = true,
},
["Rebirth"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 20484,
["useRacial"] = true,
},
["Fear"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 5782,
["useRacial"] = true,
},
["Mind-numbing Poison"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 5763,
["useRacial"] = true,
},
["Mind Control"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 605,
["useRacial"] = true,
},
["Create Healthstone"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 11730,
["useRacial"] = true,
},
["Entangling Roots"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 339,
["useRacial"] = true,
},
["Wound Poison"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 13220,
["useRacial"] = true,
},
["Mana Burn"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 8129,
["useRacial"] = true,
},
["Revive Pet"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 982,
["useRacial"] = true,
},
["Polymorph"] = {
["Enabled"] = true,
["useKick"] = true,
["useCC"] = true,
["ID"] = 118,
["useRacial"] = true,
},
},
["Max"] = 89,
},
["HealOnlyHealers"] = true,
["BlackList"] = {
["enUS"] = {
},
},
["MousePvE"] = {
["Min"] = 16,
["enUS"] = {
},
["Max"] = 47,
},
["MainPvP"] = {
["Min"] = 24,
["enUS"] = {
},
["Max"] = 46,
},
["UsePvP"] = true,
["PvPOnlySmart"] = true,
["UseMain"] = true,
["MainAuto"] = true,
["UseMouse"] = true,
},
{
["UsePurge"] = false,
["UseExpelFrenzy"] = false,
["UseDispel"] = true,
["PvP"] = {
["BlackList"] = {
["enUS"] = {
},
},
["Poison"] = {
["enUS"] = {
["Viper Sting"] = {
["Enabled"] = true,
["Dur"] = 2,
["Role"] = "ANY",
["Name"] = "Viper Sting",
["ID"] = 3034,
["Stack"] = 0,
},
["Blind"] = {
["Enabled"] = true,
["Dur"] = 2.5,
["Role"] = "ANY",
["Name"] = "Blind",
["ID"] = 2094,
["Stack"] = 0,
},
["Wyvern Sting"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Wyvern Sting",
["ID"] = 19386,
["Stack"] = 0,
},
["Scorpid Sting"] = {
["Enabled"] = true,
["Dur"] = 1.5,
["Role"] = "ANY",
["Name"] = "Scorpid Sting",
["ID"] = 3043,
["Stack"] = 0,
},
["Slow Poison"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Slow Poison",
["ID"] = 3332,
["Stack"] = 0,
},
["Serpent Sting"] = {
["Enabled"] = true,
["Dur"] = 3,
["Role"] = "ANY",
["Name"] = "Serpent Sting",
["ID"] = 1978,
["Stack"] = 0,
},
},
},
["Curse"] = {
["enUS"] = {
["Curse of the Elements"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of the Elements",
["ID"] = 1490,
["Stack"] = 0,
},
["Corrupted Fear"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Corrupted Fear",
["ID"] = 21330,
["Stack"] = 0,
},
["Curse of Weakness"] = {
["Enabled"] = true,
["Dur"] = 3,
["Role"] = "ANY",
["Name"] = "Curse of Weakness",
["ID"] = 702,
["Stack"] = 0,
},
["Hex of Weakness"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Hex of Weakness",
["ID"] = 9035,
["Stack"] = 0,
},
["Curse of Shadow"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of Shadow",
["ID"] = 17862,
["Stack"] = 0,
},
["Curse of Tongues"] = {
["Enabled"] = true,
["Dur"] = 3,
["Role"] = "ANY",
["Name"] = "Curse of Tongues",
["ID"] = 1714,
["Stack"] = 0,
},
["Voodoo Hex"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Voodoo Hex",
["ID"] = 8277,
["Stack"] = 0,
},
["Curse of Doom"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of Doom",
["ID"] = 603,
["Stack"] = 0,
},
},
},
},
["UseExpelEnrage"] = false,
["PvE"] = {
["BlackList"] = {
["enUS"] = {
},
},
["Poison"] = {
["enUS"] = {
["Creeper Venom"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Creeper Venom",
["ID"] = 14532,
["Stack"] = 0,
},
["Deadly Poison"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Deadly Poison",
["ID"] = 13582,
["Stack"] = 0,
},
["Festering Bite"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Festering Bite",
["ID"] = 16460,
["Stack"] = 0,
},
["Deadly Leech Poison"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Deadly Leech Poison",
["ID"] = 3388,
["Stack"] = 0,
},
["Corrosive Poison"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Corrosive Poison",
["ID"] = 13526,
["Stack"] = 0,
},
["Corrosive Venom Spit"] = {
["Enabled"] = true,
["Dur"] = 1.5,
["Role"] = "ANY",
["Name"] = "Corrosive Venom Spit",
["ID"] = 20629,
["Stack"] = 0,
},
["Barbed Sting"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Barbed Sting",
["ID"] = 14534,
["Stack"] = 0,
},
["Entropic Sting"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Entropic Sting",
["ID"] = 23260,
["Stack"] = 0,
},
["Brood Affliction: Green"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Brood Affliction: Green",
["ID"] = 23169,
["Stack"] = 0,
},
["Paralyzing Poison"] = {
["Enabled"] = true,
["Dur"] = 0,
["LUA"] = " return not UnitIsUnit(thisunit, \"player\") ",
["Role"] = "ANY",
["Name"] = "Paralyzing Poison",
["ID"] = 3609,
["Stack"] = 0,
},
["Seeping Willow"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Seeping Willow",
["ID"] = 17196,
["Stack"] = 0,
},
["Lethal Toxin"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Lethal Toxin",
["ID"] = 8256,
["Stack"] = 0,
},
["Bloodpetal Poison"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Bloodpetal Poison",
["ID"] = 14110,
["Stack"] = 0,
},
["Slime Bolt"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Slime Bolt",
["ID"] = 28311,
["Stack"] = 0,
},
["Abomination Spit"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Abomination Spit",
["ID"] = 25262,
["Stack"] = 0,
},
["Maggot Goo"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Maggot Goo",
["ID"] = 17197,
["Stack"] = 0,
},
["Enervate"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Enervate",
["ID"] = 22661,
["Stack"] = 0,
},
["Aspect of Venoxis"] = {
["Enabled"] = true,
["Dur"] = 1.5,
["Role"] = "ANY",
["Name"] = "Aspect of Venoxis",
["ID"] = 24688,
["Stack"] = 0,
},
["Larva Goo"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Larva Goo",
["ID"] = 21069,
["Stack"] = 0,
},
["Slow Poison"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Slow Poison",
["ID"] = 3332,
["Stack"] = 0,
},
["Bottle of Poison"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Bottle of Poison",
["ID"] = 22335,
["Stack"] = 0,
},
["Poisonous Spit"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Poisonous Spit",
["ID"] = 4286,
["Stack"] = 0,
},
["Minor Scorpion Venom Effect"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Minor Scorpion Venom Effect",
["ID"] = 5105,
["Stack"] = 0,
},
["Baneful Poison"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Baneful Poison",
["ID"] = 15475,
["Stack"] = 0,
},
["Atal'ai Poison"] = {
["Enabled"] = true,
["Dur"] = 1.5,
["Role"] = "ANY",
["Name"] = "Atal'ai Poison",
["ID"] = 18949,
["Stack"] = 0,
},
},
},
["Curse"] = {
["enUS"] = {
["Curse of the Elemental Lord"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of the Elemental Lord",
["ID"] = 26977,
["Stack"] = 0,
},
["Veil of Shadow"] = {
["Enabled"] = true,
["Dur"] = 1.5,
["Role"] = "ANY",
["Name"] = "Veil of Shadow",
["ID"] = 7068,
["Stack"] = 0,
},
["Shrink"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Shrink",
["ID"] = 24054,
["Stack"] = 0,
},
["Tainted Mind"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Tainted Mind",
["ID"] = 16567,
["Stack"] = 0,
},
["Curse of the Firebrand"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of the Firebrand",
["ID"] = 16071,
["Stack"] = 0,
},
["Curse of Stalvan"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of Stalvan",
["ID"] = 13524,
["Stack"] = 0,
},
["Gehennas' Curse"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Gehennas' Curse",
["ID"] = 19716,
["Stack"] = 0,
},
["Curse of Impotence"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of Impotence",
["ID"] = 22371,
["Stack"] = 0,
},
["Rage of Thule"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Rage of Thule",
["ID"] = 3387,
["Stack"] = 0,
},
["Curse of the Darkmaster"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of the Darkmaster",
["ID"] = 18702,
["Stack"] = 0,
},
["Banshee Curse"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Banshee Curse",
["ID"] = 17105,
["Stack"] = 0,
},
["Curse of the Dreadmaul"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of the Dreadmaul",
["ID"] = 11960,
["Stack"] = 0,
},
["Arugal's Curse"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Arugal's Curse",
["ID"] = 7621,
["Stack"] = 0,
},
["Delusions of Jin'do"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Delusions of Jin'do",
["ID"] = 24306,
["Stack"] = 0,
},
["Curse of Thorns"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of Thorns",
["ID"] = 6909,
["Stack"] = 0,
},
["Corrupted Fear"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Corrupted Fear",
["ID"] = 21330,
["Stack"] = 0,
},
["Piercing Shadow"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Piercing Shadow",
["ID"] = 16429,
["Stack"] = 0,
},
["Lucifron's Curse"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Lucifron's Curse",
["ID"] = 19703,
["Stack"] = 0,
},
["Hex of Jammal'an"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Hex of Jammal'an",
["ID"] = 12480,
["Stack"] = 0,
},
["Ancient Hysteria"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Ancient Hysteria",
["ID"] = 19372,
["Stack"] = 0,
},
["Haunting Phantoms"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Haunting Phantoms",
["ID"] = 16336,
["Stack"] = 0,
},
["Curse of Blood"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of Blood",
["ID"] = 16098,
["Stack"] = 0,
},
["Breath of Sargeras"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Breath of Sargeras",
["ID"] = 28342,
["Stack"] = 0,
},
["Shazzrah's Curse"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Shazzrah's Curse",
["ID"] = 19713,
["Stack"] = 0,
},
["Wracking Pains"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Wracking Pains",
["ID"] = 13619,
["Stack"] = 0,
},
["Discombobulate"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Discombobulate",
["ID"] = 4060,
["Stack"] = 0,
},
["Curse of the Plague Rat"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of the Plague Rat",
["ID"] = 17738,
["Stack"] = 0,
},
["Mark of Kazzak"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Mark of Kazzak",
["ID"] = 21056,
["Stack"] = 0,
},
["Curse of Mending"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Curse of Mending",
["ID"] = 15730,
["Stack"] = 0,
},
["Enfeeble"] = {
["Enabled"] = true,
["Dur"] = 0,
["Role"] = "ANY",
["Name"] = "Enfeeble",
["ID"] = 11963,
["Stack"] = 0,
},
},
},
},
},
{
["UseLeft"] = true,
["PvP"] = {
["UnitName"] = {
["enUS"] = {
["earthbind totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
["counterstrike totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
["tremor totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
["healing tide totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
["skyfury totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
["alliance battle standard"] = {
["Enabled"] = true,
["Button"] = "LEFT",
},
["spirit link totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
["wind rush totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
["ancestral protection totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
["horde battle standard"] = {
["Enabled"] = true,
["Button"] = "LEFT",
},
["grounding totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
["capacitor totem"] = {
["Enabled"] = true,
["Button"] = "LEFT",
["isTotem"] = true,
},
},
},
["GameToolTip"] = {
["enUS"] = {
["horde flag"] = {
["Enabled"] = true,
["Button"] = "RIGHT",
},
["alliance flag"] = {
["Enabled"] = true,
["Button"] = "RIGHT",
},
},
},
["UI"] = {
["enUS"] = {
},
},
},
["UseRight"] = true,
["PvE"] = {
["UnitName"] = {
["enUS"] = {
},
},
["GameToolTip"] = {
["enUS"] = {
},
},
["UI"] = {
["enUS"] = {
},
},
},
},
{
["msgList"] = {
},
["DisableReToggle"] = false,
["Channels"] = {
false,
true,
true,
},
},
{
["SelectSortMethod"] = "HP",
["SelectResurrects"] = false,
["MultiplierIncomingDamageLimit"] = 0.15,
["AutoHide"] = true,
["OffsetTanksShields"] = 0,
["OffsetTanksHoTs"] = 0,
["Profiles"] = {
},
["MultiplierPetsInCombat"] = 1.35,
["OffsetHealersDispel"] = 0,
["SelectPets"] = true,
["OffsetHealersHoTs"] = 0,
["OffsetDamagersUtils"] = 0,
["ManaManagementManaBoss"] = 30,
["OffsetSelfFocused"] = 0,
["OffsetDamagersHoTs"] = 0,
["HealingEngineAPI"] = true,
["ManaManagementStopAtHP"] = 40,
["OffsetSelfUnfocused"] = 0,
["UnitIDs"] = {
["raidpet30"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet2"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["party3"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet27"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet6"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid9"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid3"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid22"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet12"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid37"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid6"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet32"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet28"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid12"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["player"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid19"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid39"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["partypet2"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet26"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid27"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet23"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet17"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid40"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["focus"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet18"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet15"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid33"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet35"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid24"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet10"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet39"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["partypet4"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet11"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid29"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid25"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["party1"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid15"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid14"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet3"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet25"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet34"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet37"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet36"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid28"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid11"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid13"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["pet"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid7"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet29"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid35"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet38"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid38"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid16"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet40"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet16"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet31"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet13"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["partypet3"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet24"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid26"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet8"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid5"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet7"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid10"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid18"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet19"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid4"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid17"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet9"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet22"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet5"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet20"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["party4"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid20"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid31"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid34"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid2"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid36"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet4"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet1"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["partypet1"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet14"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid23"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid8"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid32"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid1"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet33"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid21"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raidpet21"] = {
["isPet"] = true,
["Role"] = "AUTO",
["Enabled"] = true,
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["raid30"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
["party2"] = {
["Enabled"] = true,
["Role"] = "AUTO",
["useUtils"] = true,
["LUA"] = "",
["useHoTs"] = true,
["useShields"] = true,
["useDispel"] = true,
},
},
["AfterTargetEnemyOrBossDelay"] = 0,
["ManaManagementPredictVariation"] = 4,
["OffsetTanksUtils"] = 0,
["OffsetSelfDispel"] = 0,
["PredictOptions"] = {
true,
true,
true,
true,
false,
true,
},
["OffsetTanks"] = 0,
["OffsetMode"] = "FIXED",
["ManaManagementStopAtTTD"] = 6,
["OffsetHealersUtils"] = 0,
["MultiplierPetsOutCombat"] = 1.15,
["SelectStopOptions"] = {
false,
false,
false,
false,
false,
false,
},
["AfterMouseoverEnemyDelay"] = 0,
["Profile"] = "",
["OffsetHealersShields"] = 0,
["OffsetHealers"] = 0,
["OffsetDamagers"] = 0,
["MultiplierThreat"] = 0.95,
["OffsetTanksDispel"] = 0,
["OffsetDamagersDispel"] = 0,
["OffsetDamagersShields"] = 0,
},
{
["Framework"] = "MetaEngine",
["MetaEngine"] = {
["checkselfcast"] = false,
["arena"] = true,
["PrioritizePassive"] = true,
["raid"] = true,
["Hotkeys"] = {
{
["meta"] = 1,
["action"] = "AntiFake CC",
["hotkey"] = "",
},
{
["meta"] = 2,
["action"] = "AntiFake Interrupt",
["hotkey"] = "",
},
{
["meta"] = 3,
["action"] = "Rotation",
["hotkey"] = "F1",
},
{
["meta"] = 4,
["action"] = "Secondary Rotation",
["hotkey"] = "",
},
{
["meta"] = 5,
["action"] = "Trinket Rotation",
["hotkey"] = "",
},
nil,
{
["meta"] = 7,
["action"] = "AntiFake CC Focus",
["hotkey"] = "",
},
{
["meta"] = 8,
["action"] = "AntiFake Interrupt Focus",
["hotkey"] = "",
},
{
["meta"] = 9,
["action"] = "AntiFake CC2",
["hotkey"] = "",
},
{
["meta"] = 10,
["action"] = "AntiFake CC2 Focus",
["hotkey"] = "",
},
},
["party"] = true,
},
},
{
["SavedSettings"] = {
["DRUID"] = {
},
},
},
{
["allowSamePixel"] = false,
["CustomLogic"] = {
},
},
{
["CustomDefensives"] = {
},
},
{
["CustomInterrupts"] = {
},
},
{
["CustomBossModRules"] = {
},
},
{
["CustomArenaLogic"] = {
["DRUID"] = {
["ArenaEnemy"] = {
},
["ArenaParty"] = {
},
},
},
},
{
["CustomHealingLogic"] = {
["DRUID"] = {
},
},
["HealingPriority"] = {
["DRUID"] = {
},
},
["UseCustomHealing"] = false,
},
["Ver"] = 4,
},
["WarnInvalids"] = false,
},
},
}
