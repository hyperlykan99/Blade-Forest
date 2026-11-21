-- Stable catalog and limits. This module is safe to use on both client and server.
local M={}
M.Islands={"TimberHaven","CrystalWilds","FrostboundReach"}
M.Names={TimberHaven="Timber Haven",CrystalWilds="Crystal Wilds",FrostboundReach="Frostbound Reach"}
M.Chains={
	TimberHaven={
		{"Welcome to Haven","Visit","TimberHaven",1,"Arrive in Timber Haven"},
		{"First timber","Trees","TimberHaven",12,"Chop 12 Timber Haven trees"},
		{"Learn the grove","Types","StarterGrove",3,"Discover 3 Starter Grove tree types"},
		{"A sharper edge","Power",nil,40,"Own a weapon with at least 40 Power"},
		{"Down the forest trail","Landmark","Pinewood",1,"Visit Pinewood Hollow"},
		{"A companion joins","PetTypes",nil,1,"Own a pet"},
		{"A mark of your own","Trait",nil,1,"Equip a primary trait"},
		{"The hollow harvest","Trees","TimberHaven",250,"Chop 250 Timber Haven trees"},
		{"Kingsfall champion","Boss","BladeKing",1,"Defeat Blade King with eligible participation"},
		{"Beyond the cliffs","Unlock","CrystalWilds",1,"Unlock Crystal Wilds"},
	},
	CrystalWilds={
		{"Through the crystal gate","Visit","CrystalWilds",1,"Arrive in Crystal Wilds"},
		{"Crystalwood","Trees","CrystalWilds",100,"Chop 100 Crystal Wilds trees"},
		{"Canyon survey","Types","CrystalCanyon",4,"Discover 4 Crystal Canyon tree types"},
		{"The wilds lookout","Landmark","CrystalLookout",1,"Visit the Crystal Wilds plaza"},
		{"Light in the canopy","Mutations",nil,5,"Chop 5 mutated trees anywhere"},
		{"Crystal companion","IslandPet","CrystalWilds",1,"Own a Crystal Wilds pet"},
		{"A thousand edges","Power",nil,1000,"Own a weapon with at least 1,000 Power"},
		{"The Colossus trial","Boss","CrystalColossus",1,"Defeat Crystal Colossus with eligible participation"},
		{"Crystal quartermaster","Trees","CrystalWilds",3000,"Chop 3,000 Crystal trees"},
		{"Open Frostgate","Unlock","FrostboundReach",1,"Unlock Frostbound Reach"},
	},
	FrostboundReach={
		{"Beyond Frostgate","Visit","FrostboundReach",1,"Arrive in Frostbound Reach"},
		{"Winter timber","Trees","FrostboundReach",100,"Chop 100 Frost trees"},
		{"Through the flurries","Landmark","Aurora",1,"Visit Aurora Basin"},
		{"The frost field guide","Types","FrostPeaks",4,"Discover 4 Frost Peaks tree types"},
		{"Twin marks","Trait",nil,2,"Equip different traits in both slots"},
		{"Winter companion","IslandPet","FrostboundReach",1,"Own a Frostbound Reach pet"},
		{"Beneath the ice","Depth",nil,2,"Finish expedition depth 2 in any week"},
		{"The crown breaks","Boss","FrostMonarch",1,"Defeat Frost Monarch with eligible participation"},
		{"The winter harvest","Trees","FrostboundReach",1800,"Chop 1,800 Frost trees"},
		{"Master of the Reach","Types","FrostPeaks",7,"Discover all 7 Frost Peaks tree types"},
	},
}
M.Landmarks={
	Pinewood={Island="TimberHaven",Position=Vector3.new(40,0,-2782),Radius=42,Legacy=Vector3.new(0,0,172)},
	CrystalLookout={Island="CrystalWilds",Position=Vector3.new(2790,2,0),Radius=35},
	Aurora={Island="FrostboundReach",Position=Vector3.new(6080,0,60),Radius=43,Legacy=Vector3.new(6000,0,0)},
}
-- { name, metric, area source, base goal by island tier, Logs unit, Souls }
M.ContractCatalog={
	Daily={
		Woodwork={"Timber work","Trees","current",{45,75,95},.43,4},
		Homewood={"Home grove","Trees","TimberHaven",{35,75,120},.36,3},
		Fortune={"Altar practice","Rolls",nil,{50,85,120},.40,4},
		OpenTrail={"Forest effort","Chops",nil,{65,95,125},.48,4},
		Hatched={"Companion care","Pets",nil,{1,1,2},.36,4},
		Movement={"Explore the routes","Visits",nil,{1,2,2},.28,3},
		Marathon={"The long trail","Chops",nil,{100,150,200},.60,6},
		Bosswork={"Boss challenger","Bosses",nil,{1,1,1},.57,8},
		Trial={"Timed harvest","TrialFinishes",nil,{1,1,1},.32,4},
	},
	Weekly={
		Forest={"Weekly timber","Trees","current",{420,650,850},1.25,14},
		Rolls={"Altar circuit","Rolls",nil,{380,700,1000},1.15,14},
		Camps={"Island champions","Bosses",nil,{3,4,5},1.50,22},
		Sweep={"Forest sweep","Chops",nil,{650,975,1350},1.45,18},
		Pets={"Companion keeper","Pets",nil,{5,7,9},1.05,12},
		Tour={"Island routes","Visits",nil,{5,8,10},.88,11},
		Practice={"Trial practice","TrialFinishes",nil,{3,4,5},1.05,13},
	},
}
M.ContractOrder={
	Daily={"Woodwork","Homewood","Fortune","OpenTrail","Hatched","Movement","Marathon","Bosswork","Trial"},
	Weekly={"Forest","Rolls","Camps","Sweep","Pets","Tour","Practice"},
}
M.Periods={Daily={Offer=5,Pick=3},Weekly={Offer=4,Pick=2}}
M.Metrics={Trees="Trees chopped",Chops="Trees chopped",Rolls="Altar rolls",Pets="Pets hatched",Visits="Island arrivals",Bosses="Boss credits",TrialFinishes="Trials finished"}
M.Trial={Seconds=60, TokenCap=24, Ranks={"Bronze","Silver","Gold","Platinum","Diamond"},
	Goals={{4,8,13,19,26},{4,8,12,17,23},{4,7,11,16,21}}, Tokens={2,4,6,9,12}}
M.Shop={
	Logs={Name="Timber cache",Cost=12,Limit=2,Logs=.50},
	Souls={Name="Soul cache",Cost=14,Limit=2,Souls=15},
	Seal={Name="Trial Seal",Cost=18,Limit=2,Material="TrialSeal",Amount=1},
}
M.Expedition={Seconds=900, RewardClaimsPerDay=6, SlotStride=170, Entry=Vector3.new(6270,0,52), Material="ExpeditionFrostCore"}
M.Events={
	{Id="CrystalBloom",Name="Crystal Bloom",Island="CrystalWilds",Duration=420,Logs=1.25,Luck=1.45,Color=Color3.fromRGB(134,255,216)},
	{Id="Blizzard",Name="Blizzard",Island="FrostboundReach",Duration=360,Logs=1.42,Luck=1.10,Color=Color3.fromRGB(181,223,255)},
	{Id="MeteorGrove",Name="Meteor Grove",Duration=300,Logs=1.35,Luck=1.55,Color=Color3.fromRGB(255,157,102)},
}
M.EventSlot=1200
M.EventDelay=120
function M.Day(now) return math.floor(now/86400) end
function M.Week(now) return math.floor((M.Day(now)+3)/7) end
function M.Reset(period,key)
	return period=="Daily" and (key+1)*86400 or ((key+1)*7-3)*86400
end
function M.IslandTier(unlocked)
	for i=#M.Islands,1,-1 do if unlocked and unlocked[M.Islands[i]] then return i end end
	return 1
end
function M.TrialRank(tier,score)
	local rank=0
	for i,goal in ipairs(M.Trial.Goals[tier]) do if score>=goal then rank=i end end
	return rank
end
function M.DepthTrees(depth)
	return math.min(12,4+math.floor(depth/2))
end
function M.DepthHealth(depth)
	return math.floor(23000*1.115^math.min(depth-1,120)*(1+math.max(0,depth-121)*.055))
end
function M.DepthReward(depth)
	return {Logs=.22+math.min(depth,18)*.035, Souls=6+math.min(depth,18), XP=55+math.min(depth,30)*5, Materials=1+(depth%5==0 and 1 or 0)}
end
function M.EventAt(now)
	local slot=math.floor(now/M.EventSlot)
	local ev=M.Events[slot%#M.Events+1]
	local start=slot*M.EventSlot+M.EventDelay
	local island=ev.Island or M.Islands[math.floor(slot/#M.Events)%#M.Islands+1]
	return ev,island,start,start+ev.Duration
end
return M
