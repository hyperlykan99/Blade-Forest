-- Dimensions are in studs. Positions are world-space, and center.Y is the walkable surface.
local L = {}
local V = Vector3.new
L.Attribute = "BladeWorldLayout"
L.Ready = "BladeWorldV2Ready"
L.Timber = {
	Id = "TimberHaven", Center = V(0, 0, -3000), Width = 760, Depth = 640, Arrival = V(-20, 5, -3000),
	Districts = {
		{ "Haven Village", V(-24, 0, -3000), "Arrival, Tutorial, Leaderboards" },
		{ "Crafters' Plaza", V(0, 0, -3125), "Upgrades, Log Market, Forge Workshop" },
		{ "Collectors' Row", V(-144, 0, -3020), "Gallery, Pets, Traits, Altar" },
		{ "Sapling Woods", V(175, 0, -2980), "Starter Grove" },
		{ "Pinewood Hollow", V(40, 0, -2782), "Pine Forest" },
		{ "Elderpine Ridge", V(-284, 0, -2847), "Pine Forest, Ancient Treant" },
		{ "Kingsfall Arena", V(-250, 0, -3230), "Blade King" },
		{ "Portal Cliffs", V(250, 0, -3230), "Crystal Wilds, Frostbound Reach, reserved gates" },
	},
	Forests = {
		{ District=4, Area="StarterGrove", Center=V(171,0,-2967), Cols=15, Rows=18, Step=8.1, Count=270 },
		{ District=4, Area="StarterGrove", Center=V(35,0,-3009), Cols=5, Rows=6, Step=8, Count=30 },
		{ District=5, Area="PineForest", Center=V(55,0,-2780), Cols=25, Rows=18, Step=8.1, Count=450 },
		{ District=6, Area="PineForest", Center=V(-273,0,-2830), Cols=18, Rows=25, Step=7.8, Count=450 },
	},
	Camps = { V(-175,0,-2780), V(191,0,-2808), V(-187,0,-2865), V(-312,0,-2971) },
	Treant = V(-306,0,-2725),
}
L.Frost = {
	Id = "FrostboundReach", Center = V(6000,0,0), Width = 640, Depth = 560, Arrival = V(5750,5,0),
	Districts = {
		{ "Frostgate Outpost", V(5750,0,0), "Return Gate, Eggs, Altar, Forge Annex" },
		{ "Snowfield", V(5880,0,120), "Frost Peaks" },
		{ "Glacier Pass", V(5900,0,-140), "Frost Peaks" },
		{ "Aurora Basin", V(6080,0,60), "Frost Peaks" },
		{ "Giant's Hollow", V(6200,0,190), "Frost Peaks" },
		{ "Monarch's Throne", V(6150,0,-180), "Frost Monarch" },
		{ "Heart of Winter Sanctum", V(6262,0,-59), "Future Heart of Winter encounter" },
		{ "Expedition Gate", V(6270,0,63), "Expeditions and future island gates" },
	},
	Forests = {
		{ District=2, Area="FrostPeaks", Center=V(5865,0,144), Cols=14, Rows=15, Step=7.6, Count=210 },
		{ District=3, Area="FrostPeaks", Center=V(5877,0,-145), Cols=14, Rows=15, Step=7.6, Count=210 },
		{ District=4, Area="FrostPeaks", Center=V(6067,0,46), Cols=14, Rows=15, Step=7.6, Count=210 },
		{ District=5, Area="FrostPeaks", Center=V(6197,0,197), Cols=14, Rows=15, Step=7.6, Count=200 },
	},
}
L.Crystal = {
	Center = V(3000,0,-350), Width = 116, Depth = 116,
	Arrival = V(3000,5,-384), Portal = V(2798,3,-13), Return = V(2798,6,-10),
}
L.Bosses = {
	CrystalColossus = { Name="Crystal Colossus", Center=L.Crystal.Center, Radius=44, HP=80000, HPPerPlayer=26000, Respawn=150,
		Hit=20, XP=850, LogsUnits=2.5, Souls=75, SoulsTop=190, Sigil="Crystal", Weapon="Umbraxe", Island="CrystalWilds",
		Color=Color3.fromRGB(123,225,255), Dark=Color3.fromRGB(48,45,95), Cooldown=5.2, Windup=1.6 },
	FrostMonarch = { Name="Frost Monarch", Center=L.Frost.Districts[6][2], Radius=44, HP=925000, HPPerPlayer=280000, Respawn=220,
		Hit=26, XP=1250, LogsUnits=3.6, Souls=120, SoulsTop=275, Sigil="Frost", Weapon="FrostguardDefender", RunePool="FrostMonarch", Island="FrostboundReach",
		Color=Color3.fromRGB(127,221,252), Dark=Color3.fromRGB(37,72,109), Cooldown=4.8, Windup=1.75 },
}

function L.Enabled()
	return workspace:GetAttribute(L.Attribute) == "v2" and workspace:GetAttribute(L.Ready) == true
end
function L.Contains(island, p, padding)
	local margin = padding or 0
	return math.abs(p.X-island.Center.X) <= island.Width/2+margin and math.abs(p.Z-island.Center.Z) <= island.Depth/2+margin
end
function L.TimberArea(pos)
	for _, plot in ipairs(L.Timber.Forests) do
		if plot.Area == "PineForest" and math.abs(pos.X-plot.Center.X)<=plot.Cols*plot.Step/2+9
			and math.abs(pos.Z-plot.Center.Z)<=plot.Rows*plot.Step/2+9 then return plot.Area end
	end
	for _,i in ipairs({5,6,7}) do
		local c=L.Timber.Districts[i][2]
		if (Vector3.new(pos.X,0,pos.Z)-c).Magnitude<59 then return "PineForest" end
	end
	return "StarterGrove"
end
return L
