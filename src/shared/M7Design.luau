local S={}
S.PartySize=4
S.GuildSize=30
S.VaultSize=6
S.GuildLevels={0,350,850,1700,3000,5000,8000,12500,19000,27000}
S.Contracts={
	{Key="Trees",Name="Woodland stewards",Target=1800,PersonalCap=450,XP=550},
	{Key="Boss",Name="Island defenders",Target=12,PersonalCap=4,XP=750},
	{Key="Depth",Name="Into the frost",Target=30,PersonalCap=10,XP=850},
}
S.Cosmetics={
	{Id="FirstGrowth",Title="Woodland Keeper",Aura="Spring Leaves",Kind="Trees",Count=1000,Color=Color3.fromRGB(116,219,120)},
	{Id="BladeArchivist",Title="Blade Archivist",Aura="Amber Pages",Kind="Weapons",Count=30,Color=Color3.fromRGB(255,185,95)},
	{Id="MasterPath",Title="Master of the Forest",Aura="Forest Light",Kind="Mastery",Count=50,Color=Color3.fromRGB(129,255,216)},
	{Id="IslandGuard",Title="Island Guardian",Aura="Glacial Guard",Kind="Bosses",Count=3,Color=Color3.fromRGB(103,189,253)},
	{Id="RaidVanguard",Title="Raid Vanguard",Aura="Vanguard Flame",Kind="Raids",Count=3,Color=Color3.fromRGB(255,112,112)},
	{Id="WinterVictor",Title="Winter Victor",Aura="Winter Crown",Kind="Heart",Count=1,Color=Color3.fromRGB(189,134,255)},
	{Id="GuildBanner",Title="Banner Keeper",Aura="Guild Pennant",Kind="Guild",Count=3,Color=Color3.fromRGB(255,225,147)},
	{Id="SeasonedGuild",Title="Forest Standard",Aura="Astral Standard",Kind="Guild",Count=7,Color=Color3.fromRGB(185,169,255)},
}
for _,cosmetic in ipairs(require(script.Parent:WaitForChild("M8Design")).Cosmetics) do
	table.insert(S.Cosmetics,cosmetic)
end
S.CosmeticById={}
for _,c in ipairs(S.Cosmetics) do S.CosmeticById[c.Id]=c end
function S.Week(now)
	return math.floor((now+259200)/604800)
end
function S.GuildLevel(xp)
	local level=1
	for i,threshold in ipairs(S.GuildLevels) do if xp>=threshold then level=i end end
	return level
end
return S
