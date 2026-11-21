local Edition=require(script.Parent:WaitForChild("M8Edition"))
local D={ContentVersion=1,Editions={Edition},Day=86400,Week=604800}
local start=1795305600 -- 2026-11-22 00:00 UTC
D.Seasons={{
	Id="VerdantOath01",Name="The Verdant Oath",Description="Renew the old forest oath. Restore its groves, honor the wardens, and wear the colors of Timber Haven.",
	Start=start,Finish=start+8*D.Week,ClaimGrace=7*D.Day,XPPerLevel=500,
	Track={
		{Essence=20,XP=40},{Logs=.25,Souls=8,XP=65},{Cosmetic="VerdantScout",Title=true},{Essence=40,XP=100},
		{Logs=.45,Souls=14,XP=130},{Cosmetic="VerdantScout",Aura=true},{Essence=65,XP=180},
		{Logs=.65,Souls=20,XP=225},{Weapon="FurnacecoreLongsword",Essence=90},
		{Cosmetic="VerdantWarden",Title=true},{Logs=1,Souls=36,XP=350},{Cosmetic="VerdantWarden",Aura=true,Essence=180,XP=500},
	},
	Challenges={
		{Id="Replant",Name="Renew the old roads",Source="Trees",Goal=220,XP=145},
		{Id="Oathwork",Name="Honor your contracts",Source="Contracts",Goal=5,XP=225},
		{Id="TimedGrove",Name="Race the forest",Source="Trials",Goal=2,XP=170},
		{Id="Protect",Name="Defend the living woods",Source="Boss",Goal=1,XP=120},
	},
	Events={
		{Id="FirstThaw",Name="Lanterns in the Leaves",FromWeek=2,ThroughWeek=3,Source="Trees",Goal=400,XP=250},
		{Id="WardensCall",Name="Call of the Wardens",FromWeek=6,ThroughWeek=7,Source="Contracts",Goal=6,XP=350},
	},
}}
D.Sources={
	Trees={Every=10,XP=3,Cap=51},Daily={XP=55,Cap=165},Weekly={XP=160,Cap=320},
	Trials={XP=45,Cap=90},Boss={XP=40,Cap=80},Depths={XP=30,Cap=90},
}
D.BySeason={}
for _,s in ipairs(D.Seasons) do D.BySeason[s.Id]=s end
function D.Active(now)
	for _,s in ipairs(D.Seasons) do if now>=s.Start and now<s.Finish then return s end end
end
function D.WeekAt(s,now)
	return math.clamp(math.floor((now-s.Start)/D.Week)+1,1,math.ceil((s.Finish-s.Start)/D.Week))
end
D.Cosmetics={
	{Id="VerdantScout",Title="Grove Scout",Aura="Greenlight Mantle",Kind="Season",Count=0,Color=Color3.fromRGB(106,222,163)},
	{Id="VerdantWarden",Title="Verdant Warden",Aura="Heartwood Halo",Kind="Season",Count=0,Color=Color3.fromRGB(244,199,106)},
}
D.Milestones={
	{Percent=10,Essence=28,XP=65},
	{Percent=25,Logs=.5,Souls=16,XP=180},
	{Percent=50,Weapon="PrismSaber",Essence=100,XP=350},
	{Percent=75,Logs=1.35,Souls=45,Essence=160,XP=650},
	{Percent=100,Weapon="AuroraCleaver",Essence=350,XP=750},
}
D.Achievements={}
D.ByAchievement={}
local function achievement(id,category,name,metric,goal,tier,badge)
	local r={Id=id,Category=category,Name=name,Metric=metric,Goal=goal,Tier=tier,BadgeId=badge}
	table.insert(D.Achievements,r) D.ByAchievement[id]=r
end
achievement("ChopI","Chopping","First clearing","Chops",30,1)
achievement("ChopII","Chopping","Timber runner","Chops",1000,2)
achievement("ChopIII","Chopping","Forest keeper","Chops",15000,3)
achievement("RareI","Rare discoveries","Curious naturalist","Trees",12,1)
achievement("RareII","Rare discoveries","Mutation hunter","Mutations",3,2)
achievement("RareIII","Rare discoveries","An extraordinary roll","Rarest",10000,3)
achievement("WeaponI","Weapons","Full rack","Weapons",15,1)
achievement("WeaponII","Weapons","Blade archivist","Weapons",60,2)
achievement("WeaponIII","Weapons","Living armory","Weapons",119,3)
achievement("PetI","Pets","Critter companion","Pets",5,1)
achievement("PetII","Pets","Gilded companion","Evolved",3,2)
achievement("PetIII","Pets","Forest menagerie","Pets",21,3)
achievement("BossI","Bosses","Kingfall","BladeKing",1,1)
achievement("BossII","Bosses","Monarch's end","FrostMonarch",1,2)
achievement("BossIII","Bosses","Winter's end","Heart",1,3)
achievement("RaidI","Raids","Answered the horn","Raids",1,1)
achievement("RaidII","Raids","Three banners","RaidKinds",3,3)
achievement("TrialI","Trials","Beat the bell","Trials",1,1)
achievement("TrialII","Trials","Precision timber","TrialBest",13,2)
achievement("ExpeditionI","Expeditions","Below the snow","Depth",3,1)
achievement("ExpeditionII","Expeditions","Into the deep","Depth",12,3)
achievement("CraftI","Crafting","From the forge","Crafts",1,1)
achievement("CraftII","Crafting","Awakened steel","Awakened",3,3)
achievement("MasterI","Mastery","Studied the grove","Mastery",15,1)
achievement("MasterII","Mastery","Master of the woods","Mastery",100,3)
achievement("SocialI","Social","Proud collection","Showcase",1,1)
achievement("SocialII","Social","Never alone","Party",1,2)
achievement("SocialIII","Social","Guild colors","Guild",1,2)
D.AchievementRewards={{Essence=12,XP=40},{Logs=.25,Souls=8,Essence=22,XP=95},{Logs=.5,Souls=18,Essence=42,XP=175}}
D.WeaponRoutes={PrismSaber="Foundations collection 50%",AuroraCleaver="Foundations collection 100%",FurnacecoreLongsword="The Verdant Oath, Season Level 9"}
D.Guide={
	{Id="Move",Text="Use WASD, the stick or touch controls. Walk close to a tree so your orbiting blade can chop it."},
	{Id="Upgrade",Button="UpgradesButton",Text="Open Upgrade and spend Logs to improve your blades. An extra blade hits more trees."},
	{Id="Roll",Button="RollButton",Text="Roll for a weapon at your island altar. Equip stronger finds in Weapons or turn on Auto Equip."},
	{Id="Pets",Button="PetsButton",Text="Visit the egg nest or open Pets. Hatch and equip a companion when you can afford the egg."},
	{Id="Traits",Button="TraitsButton",Text="Open Traits to inspect your trait and the available crate options."},
	{Id="Mastery",Button="CharacterProgressionButton",Text="Chopping earns Mastery XP. Open Mastery and spend earned Tech Points on the Tech Tree."},
	{Id="Contracts",Button="M5AdventuresButton",Text="Choose a Contract in Adventures. Try the 60-second solo Trial when you are ready."},
	{Id="Portals",Text="Follow signs to Portal Cliffs. The Crystal Wilds gate lists the weapon Power and progression you still need."},
	{Id="Forge",Button="M6ForgeButton",Text="Visit the Forge Workshop in Crafters’ Plaza. Awakening starts with an eligible five-star weapon.",Mastery=8},
	{Id="Social",Button="M7SocialButton",Text="Open Social for the vault, profiles, parties, and guilds. Party encounters still check every player's eligibility."},
}
return D
