local D={}
local V=Vector3.new
D.MaterialNames={Bark="Bark",Crystal="Crystal Shards",Frost="Frost Cores",ExpeditionFrostCore="Expedition Cores",
	TrialSeal="Trial Seals",Essence="Altar Essence",Souls="Souls",TrialToken="Trial Tokens",
	SigilBark="Bark Sigils",SigilCrystal="Crystal Sigils",SigilFrost="Frost Sigils"}
D.ForgeSites={TimberHaven=V(30,0,-3112),FrostboundReach=V(5778,0,25)}
D.WinterSite=V(6262,0,-35)
D.MaterialByIsland={TimberHaven="Bark",CrystalWilds="Crystal",FrostboundReach="Frost"}
D.SigilByIsland={TimberHaven="Bark",CrystalWilds="Crystal",FrostboundReach="Frost"}
D.MaterialPerDay=80
D.ChopsPerMaterial=12
D.SalvagesPerDay=48
D.AwakeningMultiplier={1.2,1.4,1.6}
D.Awakening={
	{ Island="TimberHaven", Costs={Bark=35,Crystal=15,Essence=1500,Souls=175} },
	{ Island="CrystalWilds", Costs={Crystal=40,Frost=25,Essence=4500,Souls=450} },
	{ Island="FrostboundReach", Costs={Frost=55,ExpeditionFrostCore=8,Essence=10000,Souls=950} },
}
D.Recipes={
	{Id="Hearth",Name="Hearthsteel commission",Island="TimberHaven",Mastery=8,Weapon="FurnacecoreLongsword",Costs={Bark=42,Essence=650,Souls=120}},
	{Id="Prism",Name="Prismatic commission",Island="CrystalWilds",Mastery=19,Weapon="PrismSaber",Costs={Bark=30,Crystal=60,Essence=2400,Souls=280}},
	{Id="Glacier",Name="Glacier commission",Island="FrostboundReach",Mastery=30,Weapon="FrostspireGreatsword",Costs={Crystal=45,Frost=65,ExpeditionFrostCore=2,Essence=5200,Souls=520}},
	{Id="Aurora",Name="Aurora masterwork",Island="FrostboundReach",Mastery=50,Weapon="AuroraCleaver",Costs={Crystal=55,Frost=100,ExpeditionFrostCore=14,Essence=25000,Souls=1800}},
	{Id="HearthDivine",Name="Sovereign masterwork",Island="FrostboundReach",Mastery=70,Weapon="HearthforgeSovereign",Costs={Bark=160,Crystal=80,Frost=80,TrialSeal=3,Essence=100000,Souls=2600}},
	{Id="PrismDivine",Name="Radiance masterwork",Island="FrostboundReach",Mastery=85,Weapon="PrismheartRadiance",Costs={Crystal=160,Frost=95,ExpeditionFrostCore=24,TrialSeal=5,Essence=100000,Souls=3400}},
	{Id="WinterKey",Name="Winter Key",Island="FrostboundReach",Mastery=1,Key=true,Costs={SigilBark=1,SigilCrystal=1,SigilFrost=1}},
}
D.Trials={
	{Id="Trial01",Name="Bronze trial commission",Island="TimberHaven",Mastery=1,Weapon="AshbarkKnightblade",TrialScore=4,Costs={TrialToken=45}},
	{Id="Trial02",Name="Silver trial commission",Island="CrystalWilds",Mastery=1,Weapon="CanyonSickle",TrialScore=8,Costs={TrialToken=85,TrialSeal=1}},
	{Id="Trial03",Name="Gold trial commission",Island="FrostboundReach",Mastery=1,Weapon="Iceveil",TrialScore=13,Costs={TrialToken=140,TrialSeal=2}},
}
D.ByRecipe={}
D.Routes={}
local function route(id,name)
	local routes=D.Routes[id] or {}
	table.insert(routes,name) D.Routes[id]=routes
end
for _,list in ipairs({D.Recipes,D.Trials}) do
	for _,r in ipairs(list) do
		D.ByRecipe[r.Id]=r
		if r.Weapon then route(r.Weapon,r.TrialScore and "Trial commission" or "Forge commission") end
	end
end
D.RunecraftSoul={85,175,350,725}
D.RerollSoul={30,60,120,240}
D.RuneRarity={"Etched","Refined","Radiant","Ancient"}
D.RuneTypes={
	{Id="Harvest",Name="Harvest",Channel="Logs",Amounts={.035,.065,.10,.15},Cap=.30},
	{Id="Edge",Name="Edge",Channel="Damage",Amounts={.025,.045,.075,.11},Cap=.22},
	{Id="Spirit",Name="Spirit",Channel="Souls",Amounts={.025,.045,.075,.11},Cap=.22},
	{Id="Fortune",Name="Fortune",Channel="Luck",Amounts={.04,.075,.11,.16},Cap=.32},
	{Id="Mutation",Name="Mutation",Channel="Mutation",Amounts={.045,.08,.125,.18},Cap=.36},
}
D.RuneById={}
D.Runes={}
for _,group in ipairs(D.RuneTypes) do
	for i,rarity in ipairs(D.RuneRarity) do
		local id=group.Id..i
		local rune={Id=id,Name=rarity.." "..group.Name,Rank=i,Type=group.Id,Channel=group.Channel,Amount=group.Amounts[i],Cap=group.Cap}
		D.RuneById[id]=rune table.insert(D.Runes,rune)
	end
end
D.RuneCraft={
	{Bark=8},
	{Crystal=12},
	{Frost=20},
	{Frost=30,ExpeditionFrostCore=5},
}
D.Raids={
	{Id="TreantRaid",Name="Ancient Treant Raid",Island="TimberHaven",Position=V(-286,0,-3078),Power=40,HP=55000,Hit=18,
		Material="Bark",Sigil="Bark",Weapon="WildfireGreatsword",Color=Color3.fromRGB(155,222,111)},
	{Id="HydraRaid",Name="Crystal Hydra",Island="CrystalWilds",Position=V(3124,0,-350),Power=250,HP=245000,Hit=26,
		Material="Crystal",Sigil="Crystal",Weapon="SkyshardAegisblade",Color=Color3.fromRGB(125,213,255)},
	{Id="GiantRaid",Name="Frost Giant",Island="FrostboundReach",Position=V(6072,0,219),Power=2000,HP=1350000,Hit=32,
		Material="Frost",Sigil="Frost",Weapon="GlacialSplitter",Color=Color3.fromRGB(181,226,252)},
}
D.Heart={Id="HeartOfWinter",Name="Heart of Winter",Island="FrostboundReach",Power=2000,HP=1750000,Hit=34,
	Material="Frost",Weapon="EternalWinter",Color=Color3.fromRGB(179,132,251)}
for _,raid in ipairs(D.Raids) do route(raid.Weapon,raid.Name.." first victory") end
route(D.Heart.Weapon,"Heart of Winter weekly clear")
D.RaidPeriod=1200 D.RaidLength=420
D.HeartLength=540 D.HeartCapacity=4 D.HeartQueue=8
D.RaidClaimsPerDay=3 D.HeartClaimsPerDay=3
function D.RaidAt(now)
	local slot=math.floor(now/D.RaidPeriod)
	local start=slot*D.RaidPeriod
	return D.Raids[slot%#D.Raids+1],start,start+D.RaidLength
end
return D
