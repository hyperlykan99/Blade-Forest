-- BladeConfig: every balance number for the game lives here.
-- Shared by server (damage/rolls) and client (visuals/UI) so they always agree.

local Config = {}
-- M1: every economy number comes from EconomyConfig (generated from tools/econsim/economy_params.json)
local EC = require(script.Parent:WaitForChild("EconomyConfig"))
Config.Economy = EC

--------------------------------------------------------------------
-- World
--------------------------------------------------------------------
Config.SafeZoneCenter = Vector3.new(0, 0, 0)
Config.SafeZoneRadius = 32 -- no PvP / NPC damage inside the spawn plaza
Config.ArenaCenter = Vector3.new(0, 0, -270)
Config.ArenaRadius = 48
Config.BossRespawnTime = 240
Config.BossRewardPool = 5000
Config.PlayerKillReward = 40
Config.BountyPerStreak = 15

function Config.InSafeZone(pos)
	return false -- no safe zones anymore: PvP is a per-player toggle (Config.PvP)
end

--------------------------------------------------------------------
-- Rarities (order matters: low -> high)
-- Chance = base roll odds in %. BasePower is multiplied by the area's PowerMult.
--------------------------------------------------------------------
Config.Rarities = {
	{ Id = "Common",    Color = Color3.fromRGB(175, 175, 180), Chance = 60,    BasePower = 5,   Length = 3.0, SellValue = 1 },
	{ Id = "Uncommon",  Color = Color3.fromRGB(90, 215, 95),   Chance = 25,    BasePower = 9,   Length = 3.3, SellValue = 3 },
	{ Id = "Rare",      Color = Color3.fromRGB(70, 150, 255),  Chance = 10,    BasePower = 16,  Length = 3.7, SellValue = 10 },
	{ Id = "Epic",      Color = Color3.fromRGB(175, 80, 255),  Chance = 4,     BasePower = 30,  Length = 4.1, SellValue = 40, Particle = "Sparkle" },
	{ Id = "Legendary", Color = Color3.fromRGB(255, 190, 40),  Chance = 0.9,   BasePower = 55,  Length = 4.6, SellValue = 200, Particle = "Sparkle" },
	{ Id = "Mythic",    Color = Color3.fromRGB(255, 55, 85),   Chance = 0.09,  BasePower = 100, Length = 5.1, SellValue = 1000, Particle = "Sparkle" },
	{ Id = "Secret",    Color = Color3.fromRGB(255, 255, 255), Chance = 0.01,  BasePower = 180, Length = 5.7, SellValue = 5000, Particle = "Holy", Rainbow = true },
	{ Id = "Divine",    Color = Color3.fromRGB(255, 236, 160), Chance = 0.0001, BasePower = 400, Length = 6.4, SellValue = 50000, Particle = "Holy", Rainbow = true },
}
Config.RarityById = {}
for i, r in ipairs(Config.Rarities) do
	r.Order = i
	Config.RarityById[r.Id] = r
end
Config.RainbowSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
})

--------------------------------------------------------------------
-- Areas. Each area has its own Roll Altar pool (weapons with Area = Id).
-- Add a new area here + weapons with that Area to expand the game.
--------------------------------------------------------------------
Config.Areas = {
	{ Id = "StarterGrove",   Name = "Starter Grove",   PowerMult = 1, RollCost = 50,    RequiredPower = 0,   NoPvP = true, NoNPCs = true },
	{ Id = "PineForest",     Name = "Pine Forest",     PowerMult = 3, RollCost = 1500,  RequiredPower = 40 },
	{ Id = "CrystalCanyon",  Name = "Crystal Canyon",  PowerMult = 9, RollCost = 40000, RequiredPower = 250 },
	{ Id = "FrostPeaks",     Name = "Frost Peaks",     PowerMult = 20, RollCost = 0,    RequiredPower = 2000 },
}
Config.AreaById = {}
for i, a in ipairs(Config.Areas) do
	a.Order = i
	Config.AreaById[a.Id] = a
end

-- Map layout: Starter Grove = inner circle; Crystal Canyon = east valley;
-- everything else (outer ring + boss arena) = Pine Forest.
Config.StarterRadius = 130
function Config.GetAreaAt(pos)
	-- P1a islands: a test island reports its legacy area (keeps gates, prices and indexes unchanged)
	local isl = Config.GetIslandAt and Config.GetIslandAt(pos)
	if isl and isl.LegacyArea then
		return isl.LegacyArea
	end
	if pos.X < -345 then
		return "FrostPeaks"
	end
	if ((pos - Vector3.new(0, pos.Y, 0))).Magnitude <= Config.StarterRadius then
		return "StarterGrove"
	end
	if pos.X > 188 and math.abs(pos.Z) < 132 then
		return "CrystalCanyon"
	end
	return "PineForest"
end

--------------------------------------------------------------------
-- Trees. Strength = Power needed to chop at full speed.
-- Below Strength you only deal WeakDamageMult damage (slow but possible).
--------------------------------------------------------------------
Config.WeakDamageMult = 0.1
-- Every area has its own 5 tree rarities. Weight = spawn share inside that area.
-- Models = templates in ReplicatedStorage.TreeModels (Creator Store trees).
Config.TreeRarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
Config.TreeTypes = {
	-- Starter Grove: very easy, fast respawn
	Grove_Common    = { Area = "StarterGrove",  Rarity = "Common",    Name = "Sapling",        Strength = 1,    Health = 4,     Logs = 1,     Respawn = 4,  Weight = 55 },
	Grove_Uncommon  = { Area = "StarterGrove",  Rarity = "Uncommon",  Name = "Blossom Tree",   Strength = 3,    Health = 10,    Logs = 3,     Respawn = 6,  Weight = 25 },
	Grove_Rare      = { Area = "StarterGrove",  Rarity = "Rare",      Name = "Autumn Maple",   Strength = 8,    Health = 35,    Logs = 10,    Respawn = 10, Weight = 13 },
	Grove_Epic      = { Area = "StarterGrove",  Rarity = "Epic",      Name = "Ruby Maple",     Strength = 16,   Health = 110,   Logs = 40,    Respawn = 20, Weight = 5.5 },
	Grove_Legendary = { Area = "StarterGrove",  Rarity = "Legendary", Name = "Golden Oak",     Strength = 30,   Health = 320,   Logs = 150,   Respawn = 45, Weight = 1.5 },
	-- Pine Forest (Power 40 to enter)
	Pine_Common     = { Area = "PineForest",    Rarity = "Common",    Name = "Spruce",         Strength = 40,   Health = 300,   Logs = 50,    Respawn = 6,  Weight = 55 },
	Pine_Uncommon   = { Area = "PineForest",    Rarity = "Uncommon",  Name = "Tall Pine",      Strength = 60,   Health = 620,   Logs = 110,   Respawn = 9,  Weight = 25 },
	Pine_Rare       = { Area = "PineForest",    Rarity = "Rare",      Name = "Frost Spruce",   Strength = 90,   Health = 1250,  Logs = 260,   Respawn = 14, Weight = 13 },
	Pine_Epic       = { Area = "PineForest",    Rarity = "Epic",      Name = "Ember Pine",     Strength = 140,  Health = 2700,  Logs = 650,   Respawn = 25, Weight = 5.5 },
	Pine_Legendary  = { Area = "PineForest",    Rarity = "Legendary", Name = "Golden Pine",    Strength = 220,  Health = 6200,  Logs = 1900,  Respawn = 50, Weight = 1.5 },
	-- Crystal Canyon (Power 250 to enter)
	Crystal_Common    = { Area = "CrystalCanyon", Rarity = "Common",    Name = "Frost Crystal", Strength = 250,  Health = 3500,  Logs = 900,   Respawn = 8,  Weight = 55 },
	Crystal_Uncommon  = { Area = "CrystalCanyon", Rarity = "Uncommon",  Name = "Amethyst Tree", Strength = 400,  Health = 7000,  Logs = 2000,  Respawn = 12, Weight = 25 },
	Crystal_Rare      = { Area = "CrystalCanyon", Rarity = "Rare",      Name = "Rose Quartz",   Strength = 600,  Health = 13000, Logs = 4200,  Respawn = 18, Weight = 13 },
	Crystal_Epic      = { Area = "CrystalCanyon", Rarity = "Epic",      Name = "Prism Tree",    Strength = 900,  Health = 24000, Logs = 9000,  Respawn = 30, Weight = 5.5 },
	Crystal_Legendary = { Area = "CrystalCanyon", Rarity = "Legendary", Name = "Sun Crystal",   Strength = 1400, Health = 50000, Logs = 25000, Respawn = 60, Weight = 1.5 },
	-- Frost Peaks (Power 2000 to enter)
	Frost_Common    = { Area = "FrostPeaks", Rarity = "Common",    Name = "Snow Spruce",   Strength = 2000,  Health = 40000,  Logs = 9000,   Respawn = 8,  Weight = 55 },
	Frost_Uncommon  = { Area = "FrostPeaks", Rarity = "Uncommon",  Name = "Glacier Pine",  Strength = 4000,  Health = 85000,  Logs = 20000,  Respawn = 12, Weight = 25 },
	Frost_Rare      = { Area = "FrostPeaks", Rarity = "Rare",      Name = "Frostwood",     Strength = 7000,  Health = 160000, Logs = 42000,  Respawn = 18, Weight = 13 },
	Frost_Epic      = { Area = "FrostPeaks", Rarity = "Epic",      Name = "Aurora Tree",   Strength = 12000, Health = 300000, Logs = 90000,  Respawn = 30, Weight = 5.5 },
	Frost_Legendary = { Area = "FrostPeaks", Rarity = "Legendary", Name = "Starfrost Tree", Strength = 20000, Health = 600000, Logs = 250000, Respawn = 60, Weight = 1.5 },
	-- Mythic + Secret: very rare spawns in every area (server-wide announcement + glow)
	Grove_Mythic      = { Area = "StarterGrove",  Rarity = "Mythic", Name = "Sakura Spirit",     Strength = 45,    Health = 1000,    Logs = 600,     Respawn = 90,  Weight = 0.5 },
	Grove_Secret      = { Area = "StarterGrove",  Rarity = "Secret", Name = "Rainbow Tree",      Strength = 70,    Health = 3000,    Logs = 2500,    Respawn = 180, Weight = 0.1 },
	Pine_Mythic       = { Area = "PineForest",    Rarity = "Mythic", Name = "Giant Mushroom",    Strength = 330,   Health = 19000,   Logs = 7500,    Respawn = 100, Weight = 0.5 },
	Pine_Secret       = { Area = "PineForest",    Rarity = "Secret", Name = "Moonlit Bonsai",    Strength = 500,   Health = 55000,   Logs = 30000,   Respawn = 200, Weight = 0.1 },
	Crystal_Mythic    = { Area = "CrystalCanyon", Rarity = "Mythic", Name = "Sky Crystal",       Strength = 2100,  Health = 150000,  Logs = 100000,  Respawn = 110, Weight = 0.5 },
	Crystal_Secret    = { Area = "CrystalCanyon", Rarity = "Secret", Name = "Crystal Heart Tree", Strength = 3200, Health = 450000,  Logs = 400000,  Respawn = 220, Weight = 0.1 },
	Frost_Mythic      = { Area = "FrostPeaks",    Rarity = "Mythic", Name = "Frostleaf Tree",    Strength = 30000, Health = 1800000, Logs = 1000000, Respawn = 120, Weight = 0.5 },
	Frost_Secret      = { Area = "FrostPeaks",    Rarity = "Secret", Name = "Ancient Frost Giant", Strength = 45000, Health = 5500000, Logs = 4000000, Respawn = 240, Weight = 0.1 },
}
for id, t in pairs(Config.TreeTypes) do t.Id = id end
-- M1: one Logs ladder for every area: Logs = area base x rarity step (EconomyConfig.TreeLadder).
-- Crystal Canyon / Frost Peaks values are unchanged within 1%; Starter Grove and Pine Forest
-- rare trees no longer pay 2-5x more per rarity step than every other area.
for _, t in pairs(Config.TreeTypes) do
	local base, step = EC.TreeBaseLogs[t.Area], EC.TreeLadder[t.Rarity]
	if base and step then t.Logs = math.floor(base * step + 0.5) end
end

--------------------------------------------------------------------
-- Tree MUTATIONS: any tree can spawn mutated (rolled on every spawn).
-- More logs, a bit more health, a special look + sparkles.
--------------------------------------------------------------------
Config.Mutations = {
	{ Id = "Golden",  Name = "Golden",  OneIn = 40,  LogMult = 3,  HealthMult = 1.5, Color = Color3.fromRGB(255, 200, 50),  Material = Enum.Material.Foil,          Icon = "✨" },
	{ Id = "Frozen",  Name = "Frozen",  OneIn = 70,  LogMult = 4,  HealthMult = 2,   Color = Color3.fromRGB(150, 220, 255), Material = Enum.Material.Ice,           Icon = "❄️" },
	{ Id = "Shadow",  Name = "Shadow",  OneIn = 200, LogMult = 8,  HealthMult = 3,   Color = Color3.fromRGB(70, 30, 110),   Material = Enum.Material.SmoothPlastic, Icon = "🌑" },
	{ Id = "Rainbow", Name = "Rainbow", OneIn = 800, LogMult = 25, HealthMult = 5,   Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic, Icon = "🌈", Rainbow = true },
}
Config.MutationById = {}
for i, m in ipairs(Config.Mutations) do m.Order = i Config.MutationById[m.Id] = m end

-- rarest first so a lucky roll lands on the best one
function Config.RollMutation(rng)
	for i = #Config.Mutations, 1, -1 do
		local m = Config.Mutations[i]
		if (rng and rng:NextNumber() or math.random()) < 1 / m.OneIn then return m end
	end
	return nil
end

-- recolor a (cloned) tree model for its mutation; used by server trees + client falling trees
function Config.ApplyMutationLook(model, mutId)
	local m = Config.MutationById[mutId or ""]
	if not m then return end
	local i = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("SurfaceAppearance") or d:IsA("Texture") or d:IsA("Decal") then
			d:Destroy()
		elseif d:IsA("BasePart") and d.Name ~= "Hitbox" and d.Transparency < 1 then
			i += 1
			if d:IsA("MeshPart") then pcall(function() d.TextureID = "" end) end
			d.Material = m.Material
			if m.Rainbow then
				d.Color = Color3.fromHSV((i * 0.13) % 1, 0.75, 1)
			else
				-- keep a little of the original shading so the shape still reads
				local h, s, v = d.Color:ToHSV()
				local mh, ms, mv = m.Color:ToHSV()
				d.Color = Color3.fromHSV(mh, ms, math.clamp(mv * (0.7 + v * 0.4), 0, 1))
			end
		end
	end
end

-- weighted pick of a tree type for an area (used by the forest spawner)
function Config.PickTreeType(areaId, rng)
	local list, total = {}, 0
	for id, t in pairs(Config.TreeTypes) do
		if t.Area == areaId then
			table.insert(list, t)
			total += t.Weight
		end
	end
	table.sort(list, function(a, b) return a.Id < b.Id end)
	local r = (rng and rng:NextNumber() or math.random()) * total
	for _, t in ipairs(list) do
		r -= t.Weight
		if r <= 0 then return t end
	end
	return list[#list]
end

--------------------------------------------------------------------
-- Weapons. Model = ReplicatedStorage.BladeModels[Id].
-- Power = rarity BasePower * area PowerMult * Scale.
-- Accent = trail/edge colour. Particle overrides the rarity default.
--------------------------------------------------------------------
local W = {
	-- Starter Grove (15)
	{ Id = "Wooden",          Name = "Wooden Blade",      Type = "Sword",  Rarity = "Common",    Area = "StarterGrove", Scale = 1.0,  Accent = Color3.fromRGB(205, 165, 115) },
	{ Id = "LumberHatchet",   Name = "Lumber Hatchet",    Type = "Axe",    Rarity = "Common",    Area = "StarterGrove", Scale = 1.05, Accent = Color3.fromRGB(200, 200, 205) },
	{ Id = "WoodsmanAxe",     Name = "Woodsman Axe",      Type = "Axe",    Rarity = "Common",    Area = "StarterGrove", Scale = 1.1,  Accent = Color3.fromRGB(190, 220, 170) },
	{ Id = "FarmhandScythe",  Name = "Farmhand Scythe",   Type = "Scythe", Rarity = "Common",    Area = "StarterGrove", Scale = 0.95, Accent = Color3.fromRGB(150, 150, 160) },
	{ Id = "RustySickle",     Name = "Rusty Sickle",      Type = "Scythe", Rarity = "Common",    Area = "StarterGrove", Scale = 0.9,  Accent = Color3.fromRGB(190, 120, 80) },
	{ Id = "Iron",            Name = "Iron Blade",        Type = "Sword",  Rarity = "Uncommon",  Area = "StarterGrove", Scale = 1.0,  Accent = Color3.fromRGB(225, 230, 240) },
	{ Id = "EngravedAxe",     Name = "Engraved Battleaxe",Type = "Axe",    Rarity = "Uncommon",  Area = "StarterGrove", Scale = 1.1,  Accent = Color3.fromRGB(160, 165, 180) },
	{ Id = "WillowScythe",    Name = "Willow Scythe",     Type = "Scythe", Rarity = "Uncommon",  Area = "StarterGrove", Scale = 0.95, Accent = Color3.fromRGB(170, 200, 140) },
	{ Id = "BoneScythe",      Name = "Bone Scythe",       Type = "Scythe", Rarity = "Uncommon",  Area = "StarterGrove", Scale = 1.05, Accent = Color3.fromRGB(235, 225, 200) },
	{ Id = "RoninKatana",     Name = "Ronin Katana",      Type = "Sword",  Rarity = "Uncommon",  Area = "StarterGrove", Scale = 1.0,  Accent = Color3.fromRGB(200, 210, 230) },
	{ Id = "Golden",          Name = "Golden Blade",      Type = "Sword",  Rarity = "Rare",      Area = "StarterGrove", Scale = 1.0,  Accent = Color3.fromRGB(255, 215, 90) },
	{ Id = "EmberHatchet",    Name = "Ember Hatchet",     Type = "Axe",    Rarity = "Rare",      Area = "StarterGrove", Scale = 1.05, Accent = Color3.fromRGB(255, 140, 40), Particle = "Fire" },
	{ Id = "RedcliffAxe",     Name = "Redcliff Axe",      Type = "Axe",    Rarity = "Epic",      Area = "StarterGrove", Scale = 1.0,  Accent = Color3.fromRGB(220, 50, 50) },
	{ Id = "Bloodthorn",      Name = "Bloodthorn Blade",  Type = "Sword",  Rarity = "Legendary", Area = "StarterGrove", Scale = 1.0,  Accent = Color3.fromRGB(230, 30, 50) },
	{ Id = "Starbreaker",     Name = "Azure Starbreaker", Type = "Axe",    Rarity = "Secret",    Area = "StarterGrove", Scale = 1.0,  Accent = Color3.fromRGB(60, 120, 255) },
	-- Pine Forest (10)
	{ Id = "Emerald",         Name = "Emerald Edge",      Type = "Sword",  Rarity = "Rare",      Area = "PineForest",   Scale = 1.0,  Accent = Color3.fromRGB(90, 255, 140) },
	{ Id = "BloodvineScythe", Name = "Bloodvine Scythe",  Type = "Scythe", Rarity = "Rare",      Area = "PineForest",   Scale = 1.05, Accent = Color3.fromRGB(200, 30, 40) },
	{ Id = "SilverLabrys",    Name = "Silver Labrys",     Type = "Axe",    Rarity = "Rare",      Area = "PineForest",   Scale = 1.1,  Accent = Color3.fromRGB(230, 235, 255) },
	{ Id = "Frost",           Name = "Frostbite",         Type = "Sword",  Rarity = "Epic",      Area = "PineForest",   Scale = 1.0,  Accent = Color3.fromRGB(120, 230, 255), Particle = "Frost" },
	{ Id = "WarlordAxe",      Name = "Warlord Axe",       Type = "Axe",    Rarity = "Epic",      Area = "PineForest",   Scale = 1.05, Accent = Color3.fromRGB(240, 240, 240) },
	{ Id = "CrimsonCrescent", Name = "Crimson Crescent",  Type = "Scythe", Rarity = "Epic",      Area = "PineForest",   Scale = 1.1,  Accent = Color3.fromRGB(255, 70, 100) },
	{ Id = "Inferno",         Name = "Inferno",           Type = "Sword",  Rarity = "Legendary", Area = "PineForest",   Scale = 1.0,  Accent = Color3.fromRGB(255, 110, 20), Particle = "Fire" },
	{ Id = "VenomfangAxe",    Name = "Venomfang Axe",     Type = "Axe",    Rarity = "Legendary", Area = "PineForest",   Scale = 1.05, Accent = Color3.fromRGB(110, 255, 60) },
	{ Id = "SoulfireScythe",  Name = "Soulfire Scythe",   Type = "Scythe", Rarity = "Mythic",    Area = "PineForest",   Scale = 1.0,  Accent = Color3.fromRGB(255, 120, 200), Particle = "Fire" },
	{ Id = "StarfallReaper",  Name = "Starfall Reaper",   Type = "Scythe", Rarity = "Secret",    Area = "PineForest",   Scale = 1.0,  Accent = Color3.fromRGB(170, 90, 255), Particle = "Void" },
	-- Crystal Canyon (10)
	{ Id = "GlacierFang",     Name = "Glacier Fang",      Type = "Sword",  Rarity = "Epic",      Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(200, 240, 255), Particle = "Frost" },
	{ Id = "BonewhiteReaper", Name = "Bonewhite Reaper",  Type = "Scythe", Rarity = "Legendary", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(240, 240, 255) },
	{ Id = "SunsteelSword",   Name = "Sunsteel Sword",    Type = "Sword",  Rarity = "Legendary", Area = "CrystalCanyon", Scale = 1.05, Accent = Color3.fromRGB(255, 220, 90), Particle = "Holy" },
	{ Id = "Void",            Name = "Void Reaper",       Type = "Sword",  Rarity = "Mythic",    Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(170, 60, 255), Particle = "Void" },
	{ Id = "Umbraxe",         Name = "Umbraxe",           Type = "Axe",    Rarity = "Mythic",    Area = "CrystalCanyon", Scale = 1.05, Accent = Color3.fromRGB(120, 60, 230), Particle = "Void" },
	{ Id = "ShadowKatana",    Name = "Shadow Katana",     Type = "Sword",  Rarity = "Mythic",    Area = "CrystalCanyon", Scale = 1.1, Accent = Color3.fromRGB(230, 230, 255), Particle = "Void" },
	{ Id = "MagmaHook",       Name = "Magma Hook",        Type = "Scythe", Rarity = "Mythic",    Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(255, 120, 30), Particle = "Fire" },
	{ Id = "Galaxy",          Name = "Galaxy Cleaver",    Type = "Sword",  Rarity = "Secret",    Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(255, 120, 230) },
	{ Id = "Celestial",       Name = "Celestial Divider", Type = "Sword",  Rarity = "Secret",    Area = "CrystalCanyon", Scale = 1.1, Accent = Color3.fromRGB(255, 220, 120) },
	{ Id = "PrismSaber",      Name = "Prism Saber",       Type = "Sword",  Rarity = "Secret",    Area = "CrystalCanyon", Scale = 1.05, Accent = Color3.fromRGB(90, 255, 255) },
	-- Frost Peaks page (Divine chase weapons)
	{ Id = "GlacialEdge",      Name = "Glacial Edge",      Type = "Sword",  Rarity = "Divine", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(150, 230, 255), Particle = "Frost" },
	{ Id = "Dragonflame",      Name = "Dragonflame",       Type = "Sword",  Rarity = "Divine", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(255, 120, 30), Particle = "Fire" },
	{ Id = "SeraphsLight",     Name = "Seraph's Light",    Type = "Sword",  Rarity = "Divine", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(255, 225, 120), Particle = "Holy" },
	{ Id = "FrostboundReaper", Name = "Frostbound Reaper", Type = "Scythe", Rarity = "Divine", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(120, 210, 255), Particle = "Frost" },
	-- Exclusive (Starter Pack) - not in any altar pool
	{ Id = "FoundersEdge",    Name = "Founder's Edge",    Type = "Sword",  Rarity = "Epic",      Area = "StarterGrove", Scale = 1.6, Accent = Color3.fromRGB(200, 90, 255), Particle = "Void", Exclusive = true, FixedPower = 60 },
	-- Exclusive (Soul Shop) - bought with Souls from NPC/PvP kills
	{ Id = "SoulboundBlade",  Name = "Soulbound Blade",   Type = "Sword",  Rarity = "Epic",      Area = "PineForest",   Scale = 1.0, Accent = Color3.fromRGB(190, 160, 255), Particle = "Sparkle", Exclusive = true, SoulCost = 250, FixedPower = 120 },
	{ Id = "SoulHarvester",   Name = "Soul Harvester",    Type = "Scythe", Rarity = "Legendary", Area = "PineForest",   Scale = 1.0, Accent = Color3.fromRGB(80, 255, 220), Particle = "Void", Exclusive = true, SoulCost = 900, FixedPower = 300 },
	{ Id = "ForsakenAxe",     Name = "Forsaken Axe",      Type = "Axe",    Rarity = "Mythic",    Area = "CrystalCanyon", Scale = 0.85, Accent = Color3.fromRGB(150, 70, 255), Particle = "Void", Exclusive = true, SoulCost = 4000, FixedPower = 1000 },
-- M2:BEGIN weapons
	-- M2 expansion (77): tools/m2/roster.py is the source; legacy entries above keep their order
	{ Id = "WoodcuttersHatchet", Name = "Woodcutter's Hatchet", Type = "Axe", Rarity = "Common", Area = "StarterGrove", Scale = 1.0, Accent = Color3.fromRGB(190, 150, 100), Edition = 2 },
	{ Id = "RiverRaiderBlade", Name = "River Raider Blade", Type = "Sword", Rarity = "Common", Area = "StarterGrove", Scale = 1.0, Accent = Color3.fromRGB(170, 140, 110), Edition = 2 },
	{ Id = "RiverlordSaber", Name = "Riverlord's Saber", Type = "Sword", Rarity = "Uncommon", Area = "StarterGrove", Scale = 1.0, Accent = Color3.fromRGB(230, 200, 120), Edition = 2 },
	{ Id = "CaptainsGoldguard", Name = "Captain's Goldguard", Type = "Sword", Rarity = "Uncommon", Area = "StarterGrove", Scale = 1.0, Accent = Color3.fromRGB(255, 210, 90), Edition = 2 },
	{ Id = "AshbarkKnightblade", Name = "Ashbark Knightblade", Type = "Sword", Rarity = "Rare", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(220, 140, 90), Edition = 2 },
	{ Id = "GroundskeeperScythe", Name = "Groundskeeper's Scythe", Type = "Scythe", Rarity = "Rare", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(160, 190, 140), Edition = 2 },
	{ Id = "FurnacecoreLongsword", Name = "Furnacecore Longsword", Type = "Sword", Rarity = "Epic", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(255, 150, 60), Particle = "Fire", Edition = 2 },
	{ Id = "FlametongueSaber", Name = "Flametongue Saber", Type = "Sword", Rarity = "Epic", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(255, 110, 40), Particle = "Fire", Edition = 2 },
	{ Id = "GildedWarden", Name = "Gilded Warden", Type = "Sword", Rarity = "Epic", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(255, 220, 110), Particle = "Sparkle", Edition = 2 },
	{ Id = "WildfireGreatsword", Name = "Wildfire Greatsword", Type = "Sword", Rarity = "Legendary", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(255, 120, 30), Particle = "Fire", Edition = 2 },
	{ Id = "KindledRingblade", Name = "Kindled Ringblade", Type = "Sword", Rarity = "Legendary", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(255, 160, 70), Particle = "Fire", Edition = 2 },
	{ Id = "TridentBlaze", Name = "Trident Blaze", Type = "Sword", Rarity = "Mythic", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(255, 90, 30), Particle = "Fire", Edition = 2 },
	{ Id = "Wyrmfang", Name = "Wyrmfang", Type = "Sword", Rarity = "Mythic", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(255, 70, 40), Particle = "Fire", Edition = 2 },
	{ Id = "EmberkingsCrown", Name = "Emberking's Crown", Type = "Sword", Rarity = "Secret", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(255, 140, 40), Particle = "Fire", Edition = 2 },
	{ Id = "HearthforgeSovereign", Name = "Hearthforge Sovereign", Type = "Sword", Rarity = "Divine", Area = "PineForest", Scale = 1.0, Accent = Color3.fromRGB(255, 180, 70), Particle = "Fire", Edition = 2 },
	{ Id = "ButchersCleaver", Name = "Prospector's Cleaver", Type = "Sword", Rarity = "Common", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(200, 190, 180), Edition = 2 },
	{ Id = "RopegripCutlass", Name = "Ropegrip Cutlass", Type = "Sword", Rarity = "Common", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(190, 170, 140), Edition = 2 },
	{ Id = "DeckhandCutlass", Name = "Canyon Deckhand", Type = "Sword", Rarity = "Common", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(200, 200, 210), Edition = 2 },
	{ Id = "HooktipCutlass", Name = "Hooktip Cutlass", Type = "Sword", Rarity = "Common", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(210, 200, 190), Edition = 2 },
	{ Id = "ProspectorsBlade", Name = "Quarry Iron Blade", Type = "Sword", Rarity = "Common", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(200, 200, 205), Edition = 2 },
	{ Id = "SilvershoreSaber", Name = "Silvershore Saber", Type = "Sword", Rarity = "Uncommon", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(220, 225, 235), Edition = 2 },
	{ Id = "ShellguardCutlass", Name = "Shellguard Cutlass", Type = "Sword", Rarity = "Uncommon", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(240, 200, 120), Edition = 2 },
	{ Id = "ForkguardCutlass", Name = "Forkguard Cutlass", Type = "Sword", Rarity = "Uncommon", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(220, 210, 200), Edition = 2 },
	{ Id = "CanyonSickle", Name = "Canyon Sickle", Type = "Scythe", Rarity = "Uncommon", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(180, 60, 60), Edition = 2 },
	{ Id = "SappersAxe", Name = "Sapper's Axe", Type = "Axe", Rarity = "Uncommon", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(190, 190, 200), Edition = 2 },
	{ Id = "Flintedge", Name = "Flintedge", Type = "Sword", Rarity = "Rare", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(160, 150, 150), Edition = 2 },
	{ Id = "MagmaveinBlade", Name = "Magmavein Blade", Type = "Sword", Rarity = "Rare", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(255, 110, 40), Edition = 2 },
	{ Id = "CharcoalBrand", Name = "Charcoal Brand", Type = "Sword", Rarity = "Rare", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(120, 100, 90), Edition = 2 },
	{ Id = "JadeleafEdge", Name = "Jadeleaf Edge", Type = "Sword", Rarity = "Rare", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(90, 230, 120), Edition = 2 },
	{ Id = "AmethystSickle", Name = "Amethyst Sickle", Type = "Scythe", Rarity = "Rare", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(170, 100, 255), Edition = 2 },
	{ Id = "CraterGreatsword", Name = "Crater Greatsword", Type = "Sword", Rarity = "Epic", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(255, 120, 50), Particle = "Fire", Edition = 2 },
	{ Id = "Geyserfang", Name = "Geyserfang", Type = "Sword", Rarity = "Epic", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(255, 140, 60), Particle = "Fire", Edition = 2 },
	{ Id = "MeteorShard", Name = "Meteor Shard", Type = "Sword", Rarity = "Epic", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(255, 90, 60), Particle = "Fire", Edition = 2 },
	{ Id = "AzureTidecurve", Name = "Azure Tidecurve", Type = "Sword", Rarity = "Epic", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(80, 170, 255), Particle = "Sparkle", Edition = 2 },
	{ Id = "GeodeCleaveaxe", Name = "Fuchsia Geode Cleaveaxe", Type = "Axe", Rarity = "Epic", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(255, 80, 220), Particle = "Sparkle", Edition = 2 },
	{ Id = "ObsidianGlassblade", Name = "Obsidian Glassblade", Type = "Sword", Rarity = "Legendary", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(255, 100, 60), Particle = "Fire", Edition = 2 },
	{ Id = "RosequartzFang", Name = "Rosequartz Fang", Type = "Sword", Rarity = "Legendary", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(255, 150, 200), Particle = "Sparkle", Edition = 2 },
	{ Id = "OpalineEdge", Name = "Opaline Edge", Type = "Sword", Rarity = "Legendary", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(170, 140, 255), Particle = "Sparkle", Edition = 2 },
	{ Id = "GarnetCrystalAxe", Name = "Garnet Crystal Axe", Type = "Axe", Rarity = "Legendary", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(220, 40, 60), Particle = "Sparkle", Edition = 2 },
	{ Id = "ObsidianEclipse", Name = "Obsidian Eclipse", Type = "Sword", Rarity = "Mythic", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(130, 60, 220), Particle = "Void", Edition = 2 },
	{ Id = "GeodeHarvester", Name = "Geode Harvester", Type = "Scythe", Rarity = "Mythic", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(230, 40, 50), Particle = "Void", Edition = 2 },
	{ Id = "SkyshardAegisblade", Name = "Skyshard Aegisblade", Type = "Sword", Rarity = "Secret", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(110, 200, 255), Particle = "Holy", Edition = 2 },
	{ Id = "PrismheartRadiance", Name = "Prismheart Radiance", Type = "Sword", Rarity = "Divine", Area = "CrystalCanyon", Scale = 1.0, Accent = Color3.fromRGB(200, 120, 255), Particle = "Holy", Edition = 2 },
	{ Id = "IcesawBoarder", Name = "Icesaw Boarder", Type = "Sword", Rarity = "Common", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(200, 225, 240), Edition = 2 },
	{ Id = "ShorthiltSaber", Name = "Shorthilt Saber", Type = "Sword", Rarity = "Common", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(210, 220, 230), Edition = 2 },
	{ Id = "GhostshipCutlass", Name = "Ghostship Cutlass", Type = "Sword", Rarity = "Common", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(150, 200, 200), Edition = 2 },
	{ Id = "GlacierWoodsplitter", Name = "Glacier Woodsplitter", Type = "Axe", Rarity = "Common", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(180, 210, 235), Edition = 2 },
	{ Id = "FrostwindKatana", Name = "Frostwind Katana", Type = "Sword", Rarity = "Common", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(200, 215, 230), Edition = 2 },
	{ Id = "HarpoonCutlass", Name = "Harpoon Cutlass", Type = "Sword", Rarity = "Uncommon", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(200, 220, 240), Edition = 2 },
	{ Id = "FrostportOfficer", Name = "Frostport Officer's Sword", Type = "Sword", Rarity = "Uncommon", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(230, 235, 250), Edition = 2 },
	{ Id = "LonghiltBoarder", Name = "Longhilt Boarder", Type = "Sword", Rarity = "Uncommon", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(210, 220, 235), Edition = 2 },
	{ Id = "TundraStoneAxe", Name = "Tundra Stone Axe", Type = "Axe", Rarity = "Uncommon", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(170, 175, 185), Edition = 2 },
	{ Id = "BlackiceKatana", Name = "Blackice Katana", Type = "Sword", Rarity = "Uncommon", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(60, 70, 90), Edition = 2 },
	{ Id = "NorthmanBeardaxe", Name = "Northman Beardaxe", Type = "Axe", Rarity = "Rare", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(170, 190, 210), Edition = 2 },
	{ Id = "FjordSword", Name = "Fjord Sword", Type = "Sword", Rarity = "Rare", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(150, 180, 220), Edition = 2 },
	{ Id = "JaggedFloe", Name = "Jagged Floe", Type = "Sword", Rarity = "Rare", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(160, 220, 255), Edition = 2 },
	{ Id = "FrostwardenBattleaxe", Name = "Frostwarden Battleaxe", Type = "Axe", Rarity = "Rare", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(150, 200, 240), Edition = 2 },
	{ Id = "SnowcapLabrys", Name = "Snowcap Labrys", Type = "Axe", Rarity = "Rare", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(220, 235, 255), Edition = 2 },
	{ Id = "NorthmanGreatsword", Name = "Northman Greatsword", Type = "Sword", Rarity = "Epic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(140, 180, 230), Particle = "Frost", Edition = 2 },
	{ Id = "RunedFrostaxe", Name = "Runed Frostaxe", Type = "Axe", Rarity = "Epic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(120, 200, 255), Particle = "Frost", Edition = 2 },
	{ Id = "SnowlightBlade", Name = "Snowlight Blade", Type = "Sword", Rarity = "Epic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(240, 250, 255), Particle = "Frost", Edition = 2 },
	{ Id = "IcicleSpire", Name = "Icicle Spire", Type = "Sword", Rarity = "Epic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(150, 230, 255), Particle = "Frost", Edition = 2 },
	{ Id = "RimewireScythe", Name = "Rimewire Scythe", Type = "Scythe", Rarity = "Epic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(180, 210, 240), Particle = "Frost", Edition = 2 },
	{ Id = "GlacialSplitter", Name = "Glacial Splitter", Type = "Axe", Rarity = "Legendary", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(90, 170, 255), Particle = "Frost", Edition = 2 },
	{ Id = "CryoMechblade", Name = "Cryo Mechblade", Type = "Sword", Rarity = "Legendary", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(80, 160, 255), Particle = "Frost", Edition = 2 },
	{ Id = "FrostspireGreatsword", Name = "Frostspire Greatsword", Type = "Sword", Rarity = "Legendary", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(200, 220, 240), Particle = "Frost", Edition = 2 },
	{ Id = "IceshardCleaver", Name = "Iceshard Cleaver", Type = "Sword", Rarity = "Legendary", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(140, 220, 255), Particle = "Frost", Edition = 2 },
	{ Id = "HoarfrostAxe", Name = "Hoarfrost Axe", Type = "Axe", Rarity = "Legendary", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(200, 215, 235), Particle = "Frost", Edition = 2 },
	{ Id = "FrostskullRavager", Name = "Frostskull Ravager", Type = "Axe", Rarity = "Mythic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(130, 200, 255), Particle = "Frost", Edition = 2 },
	{ Id = "GlacierBoneReaper", Name = "Glacier Bone Reaper", Type = "Scythe", Rarity = "Mythic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(220, 240, 255), Particle = "Frost", Edition = 2 },
	{ Id = "FrostguardDefender", Name = "Frostguard Defender", Type = "Sword", Rarity = "Mythic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(90, 220, 255), Particle = "Frost", Edition = 2 },
	{ Id = "Iceveil", Name = "Iceveil", Type = "Sword", Rarity = "Mythic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(90, 160, 255), Particle = "Frost", Edition = 2 },
	{ Id = "Shiverfang", Name = "Shiverfang", Type = "Sword", Rarity = "Mythic", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(110, 170, 255), Particle = "Frost", Edition = 2 },
	{ Id = "AuroraCleaver", Name = "Aurora Cleaver", Type = "Axe", Rarity = "Secret", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(100, 220, 255), Particle = "Holy", Edition = 2 },
	{ Id = "RimefrostRequiem", Name = "Rimefrost Requiem", Type = "Sword", Rarity = "Secret", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(170, 230, 255), Particle = "Holy", Edition = 2 },
	{ Id = "PolarNightReaper", Name = "Polar Night Reaper", Type = "Scythe", Rarity = "Secret", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(90, 60, 200), Particle = "Void", Edition = 2 },
	{ Id = "EternalWinter", Name = "Eternal Winter", Type = "Sword", Rarity = "Divine", Area = "FrostPeaks", Scale = 1.0, Accent = Color3.fromRGB(190, 235, 255), Particle = "Frost", Edition = 2 },
-- M2:END weapons
}

--------------------------------------------------------------------
-- RNG ("1 in X"). Rolling checks the rarest weapon first; each one hits
-- with chance luck / OneIn. Nothing hit -> the starter (Wooden).
-- Power comes from how rare a weapon is: Power = 5 * OneIn ^ 0.45
--------------------------------------------------------------------
Config.OneIn = {
	Wooden = 2, RustySickle = 3, FarmhandScythe = 4, LumberHatchet = 6, WoodsmanAxe = 9,
	Iron = 25, WillowScythe = 35, RoninKatana = 50, BoneScythe = 70, EngravedAxe = 100,
	Golden = 250, EmberHatchet = 350, Emerald = 500, BloodvineScythe = 700, SilverLabrys = 1000,
	RedcliffAxe = 2500, Frost = 3500, WarlordAxe = 5000, CrimsonCrescent = 7000, GlacierFang = 10000,
	Bloodthorn = 25000, Inferno = 35000, VenomfangAxe = 50000, BonewhiteReaper = 70000, SunsteelSword = 100000,
	SoulfireScythe = 250000, MagmaHook = 350000, Void = 500000, Umbraxe = 700000, ShadowKatana = 1000000,
	Starbreaker = 1500000, StarfallReaper = 2500000, Galaxy = 4000000, PrismSaber = 6500000, Celestial = 10000000,
	GlacialEdge = 15000000, Dragonflame = 25000000, SeraphsLight = 50000000, FrostboundReaper = 100000000,
-- M2:BEGIN onein
	WoodcuttersHatchet = 5, RiverRaiderBlade = 8, RiverlordSaber = 60, CaptainsGoldguard = 80, AshbarkKnightblade = 400,
	GroundskeeperScythe = 600, FurnacecoreLongsword = 3000, FlametongueSaber = 4000, GildedWarden = 6000, WildfireGreatsword = 30000,
	KindledRingblade = 45000, TridentBlaze = 300000, Wyrmfang = 450000, EmberkingsCrown = 2000000, HearthforgeSovereign = 12000000,
	ButchersCleaver = 4, RopegripCutlass = 5, DeckhandCutlass = 7, HooktipCutlass = 8, ProspectorsBlade = 9,
	SilvershoreSaber = 45, ShellguardCutlass = 55, ForkguardCutlass = 65, CanyonSickle = 75, SappersAxe = 90,
	Flintedge = 300, MagmaveinBlade = 450, CharcoalBrand = 550, JadeleafEdge = 800, AmethystSickle = 900,
	CraterGreatsword = 2800, Geyserfang = 4500, MeteorShard = 5500, AzureTidecurve = 8000, GeodeCleaveaxe = 9000,
	ObsidianGlassblade = 28000, RosequartzFang = 40000, OpalineEdge = 60000, GarnetCrystalAxe = 80000, ObsidianEclipse = 400000,
	GeodeHarvester = 600000, SkyshardAegisblade = 3000000, PrismheartRadiance = 20000000, IcesawBoarder = 5, ShorthiltSaber = 6,
	GhostshipCutlass = 7, GlacierWoodsplitter = 8, FrostwindKatana = 9, HarpoonCutlass = 40, FrostportOfficer = 85,
	LonghiltBoarder = 95, TundraStoneAxe = 110, BlackiceKatana = 120, NorthmanBeardaxe = 350, FjordSword = 650,
	JaggedFloe = 750, FrostwardenBattleaxe = 1100, SnowcapLabrys = 1200, NorthmanGreatsword = 3200, RunedFrostaxe = 6500,
	SnowlightBlade = 7500, IcicleSpire = 12000, RimewireScythe = 15000, GlacialSplitter = 55000, CryoMechblade = 90000,
	FrostspireGreatsword = 120000, IceshardCleaver = 150000, HoarfrostAxe = 180000, FrostskullRavager = 650000, GlacierBoneReaper = 750000,
	FrostguardDefender = 850000, Iceveil = 900000, Shiverfang = 950000, AuroraCleaver = 5000000, RimefrostRequiem = 8000000,
	PolarNightReaper = 9000000, EternalWinter = 40000000,
-- M2:END onein
}
Config.RollInterval = 1.0       -- seconds per free roll
Config.FastRollInterval = 0.6   -- with the Fast Roll pass
Config.LuckyRollEvery = 10      -- every 10th roll has 2x luck
Config.AnnounceServer = 100000  -- 1 in 100K+ -> whole server
Config.AnnounceGlobal = 1000000 -- 1 in 1M+ -> every server

function Config.PowerFromOneIn(x)
	return math.floor(5 * x ^ 0.45 + 0.5)
end

Config.Weapons = W
Config.WeaponById = {}
for i, w in ipairs(W) do
	local r = Config.RarityById[w.Rarity]
	w.Order = i
	w.OneIn = Config.OneIn[w.Id]
	w.Power = w.FixedPower or Config.PowerFromOneIn(w.OneIn or 2)
	w.Length = r.Length
	w.Color = r.Color
	w.EdgeColor = w.Accent or r.Color
	w.Trail = r.Rainbow and Config.RainbowSequence or ColorSequence.new(w.EdgeColor, r.Color)
	w.Particle = w.Particle or r.Particle
	Config.WeaponById[w.Id] = w
end
Config.StarterWeapon = "Wooden"

-- weapons in an area's altar, grouped by rarity
function Config.GetAreaPool(areaId)
	local pool = {}
	for _, w in ipairs(W) do
		if w.Area == areaId and not w.Exclusive then
			pool[w.Rarity] = pool[w.Rarity] or {}
			table.insert(pool[w.Rarity], w)
		end
	end
	return pool
end

-- Back-compat names used by visuals
Config.Blades = W
Config.BladeById = Config.WeaponById
Config.StarterBlade = Config.StarterWeapon

--------------------------------------------------------------------
-- Stars (fuse duplicates). Stars[s+1] = requirement to reach star s.
--------------------------------------------------------------------
Config.MaxStar = 5
Config.FuseCost = { 2, 4, 6, 10, 15 } -- spare copies needed for star 1..5
Config.StarMult = { [0] = 1, 1.15, 1.35, 1.6, 2.0, 2.5 }

-- SHINY crafting: a max-star weapon + ShinyCopies spare copies -> Shiny (x1.5 power, gold sparkle)
Config.ShinyCopies = 5
Config.ShinyMult = 1.5

function Config.GetWeaponPower(id, star, shiny)
	local w = Config.WeaponById[id]
	if not w then return 0 end
	return w.Power * (Config.StarMult[star or 0] or 1) * (shiny and Config.ShinyMult or 1)
end

Config.Pity = { Epic = 100, Legendary = 1000 }

-- LEGACY (unused since rolls became free/HUD-based; M1 altars are per island in
-- EconomyConfig.Altars and Economy.AltarPool). Kept so nothing indexes nil.
Config.Altars = {
	StarterGrove = Vector3.new(-19, 0, -19),
	PineForest = Vector3.new(-150, 0, 16),
	CrystalCanyon = Vector3.new(232, 0, 16),
}
Config.AltarRange = 22

-- Roll odds for an area's altar with luck applied.
-- Luck multiplies the chance of Rare and above; lower rarities shrink to make room.
-- Rarities the altar doesn't contain are dropped and the rest re-normalised.
-- Returns { {Rarity = id, Chance = percent}, ... } low -> high.
function Config.GetRollOdds(areaId, luck)
	luck = math.max(luck or 1, 1)
	local pool = Config.GetAreaPool(areaId)
	local list, total = {}, 0
	for _, r in ipairs(Config.Rarities) do
		if pool[r.Id] then
			local w = r.Chance * (r.Order >= 3 and luck or 1)
			table.insert(list, { Rarity = r.Id, Weight = w })
			total += w
		end
	end
	for _, e in ipairs(list) do
		e.Chance = e.Weight / total * 100
	end
	return list
end

-- "1 in X" text for small chances
function Config.FormatChance(pct)
	if pct >= 1 then
		return string.format("%.1f%%", pct)
	elseif pct >= 0.01 then
		return string.format("%.2f%%", pct)
	end
	return string.format("1 in %s", Config.FormatNumber(100 / pct))
end

--------------------------------------------------------------------
-- Upgrades. Stored on the Player as attribute "Lvl_<Id>".
--------------------------------------------------------------------
-- Long progression: the last levels need Crystal Canyon / Frost Peaks income
-- (and rebirths). Reach also makes the blades physically bigger (BladeSizePerReach).
-- M1: upgrades come from EconomyConfig (Blades, Speed, Damage, Reach, Luck, WalkSpeed, Renewal).
-- Every regular upgrade resets on rebirth. Values: Base + PerLevel * level.
Config.Upgrades = {}
for _, u in ipairs(EC.Upgrades) do
	table.insert(Config.Upgrades, { Id = u.Id, Name = u.Name, Base = u.Base, PerLevel = u.PerLevel, MaxLevel = u.MaxLevel,
		BaseCost = u.BaseCost, CostMult = u.CostMult, Format = u.Format, Resets = u.Resets, Category = u.Category })
end
Config.BladeSizePerReach = 0.025 -- each Reach level = +2.5% blade length & size (x2 at max)
-- Comfort cap: blades never spin faster than this (radians/sec, ~0.9 turns/sec)
-- so nobody gets dizzy. Spin levels past the cap turn into extra damage instead.
Config.MaxSpinSpeed = 5.5

--------------------------------------------------------------------
-- Multipliers
--------------------------------------------------------------------
-- Completing an area's Index gives a permanent bonus (stacks per area).
-- M1 (audit H5/M9): completion is stored per EDITION and never revoked. Edition 1 of each
-- area is the catalog below. Standard = Common..Mythic, Mastery = Secret + Divine.
-- New weapons in M2 open edition 2; edition 1 records keep their bonus forever.
Config.IndexBonus = { Luck = EC.Index.WeaponStandard.Luck + EC.Index.WeaponMastery.Luck, Logs = EC.Index.WeaponStandard.Logs + EC.Index.WeaponMastery.Logs }
Config.IndexEditions = {
	Weapon = {
		StarterGrove = { [1] = { Standard = { "Wooden", "LumberHatchet", "WoodsmanAxe", "FarmhandScythe", "RustySickle", "Iron", "EngravedAxe", "WillowScythe", "BoneScythe", "RoninKatana", "Golden", "EmberHatchet", "RedcliffAxe", "Bloodthorn" }, Mastery = { "Starbreaker" } } },
		PineForest = { [1] = { Standard = { "Emerald", "BloodvineScythe", "SilverLabrys", "Frost", "WarlordAxe", "CrimsonCrescent", "Inferno", "VenomfangAxe", "SoulfireScythe" }, Mastery = { "StarfallReaper" } } },
		CrystalCanyon = { [1] = { Standard = { "GlacierFang", "BonewhiteReaper", "SunsteelSword", "Void", "Umbraxe", "ShadowKatana", "MagmaHook" }, Mastery = { "Galaxy", "Celestial", "PrismSaber" } } },
		-- Frost Peaks has only its 4 Divines: they ARE its standard set (keeps the old +10%/+10% for completers)
		FrostPeaks = { [1] = { Standard = { "GlacialEdge", "Dragonflame", "SeraphsLight", "FrostboundReaper" }, StandardBonusFull = true } },
	},
	-- tree index edition 1 = every tree type of the area as of M1
	Tree = { StarterGrove = { [1] = true }, PineForest = { [1] = true }, CrystalCanyon = { [1] = true }, FrostPeaks = { [1] = true } },
}
-- M2:BEGIN editions
-- M2: index edition 2 = the expansion weapons of each area (bonus x EditionScale[2]); edition 1 records stay
Config.IndexEditions.Weapon.StarterGrove[2] = { Standard = { "WoodcuttersHatchet", "RiverRaiderBlade", "RiverlordSaber", "CaptainsGoldguard" } }
Config.IndexEditions.Weapon.PineForest[2] = { Standard = { "AshbarkKnightblade", "GroundskeeperScythe", "FurnacecoreLongsword", "FlametongueSaber", "GildedWarden", "WildfireGreatsword", "KindledRingblade", "TridentBlaze", "Wyrmfang" }, Mastery = { "EmberkingsCrown", "HearthforgeSovereign" } }
Config.IndexEditions.Weapon.CrystalCanyon[2] = { Standard = { "ButchersCleaver", "RopegripCutlass", "DeckhandCutlass", "HooktipCutlass", "ProspectorsBlade", "SilvershoreSaber", "ShellguardCutlass", "ForkguardCutlass", "CanyonSickle", "SappersAxe", "Flintedge", "MagmaveinBlade", "CharcoalBrand", "JadeleafEdge", "AmethystSickle", "CraterGreatsword", "Geyserfang", "MeteorShard", "AzureTidecurve", "GeodeCleaveaxe", "ObsidianGlassblade", "RosequartzFang", "OpalineEdge", "GarnetCrystalAxe", "ObsidianEclipse", "GeodeHarvester" }, Mastery = { "SkyshardAegisblade", "PrismheartRadiance" } }
Config.IndexEditions.Weapon.FrostPeaks[2] = { Standard = { "IcesawBoarder", "ShorthiltSaber", "GhostshipCutlass", "GlacierWoodsplitter", "FrostwindKatana", "HarpoonCutlass", "FrostportOfficer", "LonghiltBoarder", "TundraStoneAxe", "BlackiceKatana", "NorthmanBeardaxe", "FjordSword", "JaggedFloe", "FrostwardenBattleaxe", "SnowcapLabrys", "NorthmanGreatsword", "RunedFrostaxe", "SnowlightBlade", "IcicleSpire", "RimewireScythe", "GlacialSplitter", "CryoMechblade", "FrostspireGreatsword", "IceshardCleaver", "HoarfrostAxe", "FrostskullRavager", "GlacierBoneReaper", "FrostguardDefender", "Iceveil", "Shiverfang" }, Mastery = { "AuroraCleaver", "RimefrostRequiem", "PolarNightReaper", "EternalWinter" } }
-- M2:END editions
-- Completing an area's TREE index: +5% Logs forever (stacks per area)
Config.TreeIndexBonus = { Logs = 0.05 }

-- One-time reward for every new weapon / tree you add to the Index (claim it there).
-- Logs rewards = Mult x the Trait Crate price of your best area, so they stay useful.
Config.IndexRewards = {
	Common    = { Kind = "Logs", Mult = 0.1 },
	Uncommon  = { Kind = "Logs", Mult = 0.25 },
	Rare      = { Kind = "Logs", Mult = 0.6 },
	Epic      = { Kind = "Souls", Amount = 15 },
	Legendary = { Kind = "Souls", Amount = 40 },
	Mythic    = { Kind = "Crate", Amount = 1 },
	Secret    = { Kind = "Boost", Boost = "MegaLuckPotion", Seconds = 900, Label = "Mega Luck" },
	Divine    = { Kind = "Crate", Amount = 5 },
}
Config.TreeIndexRewards = {
	Common    = { Kind = "Logs", Mult = 0.1 },
	Uncommon  = { Kind = "Logs", Mult = 0.2 },
	Rare      = { Kind = "Logs", Mult = 0.4 },
	Epic      = { Kind = "Souls", Amount = 10 },
	Legendary = { Kind = "Souls", Amount = 25 },
	Mythic    = { Kind = "Crate", Amount = 1 },
	Secret    = { Kind = "Boost", Boost = "LuckPotion", Seconds = 1800, Label = "Luck Potion" },
}

-- Timed boosts (potions etc). Stored as expiry time; stacking adds time.
Config.Boosts = {
	StarterLuck = { Luck = 2 },
	LuckPotion     = { Name = "Luck Potion",      Luck = 3 },
	MegaLuckPotion = { Name = "Mega Luck Potion", Luck = 10 },
	LogBoost       = { Name = "Log Boost",        Logs = 2 },
}

-- Auto roll speed (seconds between rolls). Fast Roll pass uses the fast value.
Config.AutoRollInterval = 1.1
Config.FastAutoRollInterval = 0.4
Config.ById = {}
for _, u in ipairs(Config.Upgrades) do
	Config.ById[u.Id] = u
end

Config.BladeHitRadius = 1.3
Config.BladeHitCooldown = 0.4
Config.BladeHeightOffset = -0.6

function Config.GetLevel(player, id)
	return player:GetAttribute("Lvl_" .. id) or 0
end

function Config.GetValue(id, level)
	local u = Config.ById[id]
	return u.Base + u.PerLevel * level
end

function Config.GetCost(id, level)
	local u = Config.ById[id]
	return math.floor(u.BaseCost * u.CostMult ^ level)
end

-- PvP uses a softer curve so high-tier weapons don't one-shot everyone
function Config.PvPDamage(power)
	return 10 * power ^ 0.35
end

-- Stats for a player OR an NPC model (NPCs use NPC_* attributes).
function Config.GetStats(wielder)
	if wielder:IsA("Player") then
		local weapon = Config.WeaponById[wielder:GetAttribute("EquippedBlade") or ""] or Config.WeaponById[Config.StarterWeapon]
		local star = wielder:GetAttribute("EquippedStar") or 0
		local power = weapon.Power * (Config.StarMult[star] or 1) * (wielder:GetAttribute("EquippedShiny") and Config.ShinyMult or 1)
		local dmgMult = Config.GetValue("Damage", Config.GetLevel(wielder, "Damage"))
		local rawSpeed = Config.GetValue("Speed", Config.GetLevel(wielder, "Speed"))
		local speed = math.min(rawSpeed, Config.MaxSpinSpeed)
		dmgMult *= rawSpeed / speed -- overflow spin = more damage
		return {
			Blade = weapon,
			Star = star,
			Shiny = wielder:GetAttribute("EquippedShiny") == true,
			Power = power,
			-- BladesOff = player stopped their blades (BLADES button); level is capped in case of old saves
			Blades = wielder:GetAttribute("BladesOff") and 0 or (math.floor(Config.GetValue("Blades", math.min(Config.GetLevel(wielder, "Blades"), Config.ById.Blades.MaxLevel))) + (wielder:GetAttribute("BonusBlades") or 0)),
			Speed = speed,
			RawSpeed = rawSpeed,
			Damage = power * dmgMult,
			PvPDamage = Config.PvPDamage(power) * dmgMult,
			Reach = Config.GetValue("Reach", Config.GetLevel(wielder, "Reach")),
			Length = weapon.Length * (1 + Config.BladeSizePerReach * Config.GetLevel(wielder, "Reach")),
			Scale = 1 + Config.BladeSizePerReach * Config.GetLevel(wielder, "Reach"),
			Height = Config.BladeHeightOffset,
		}
	else
		local weapon = Config.WeaponById[wielder:GetAttribute("NPC_BladeType") or ""] or Config.WeaponById.Iron
		local scale = wielder:GetAttribute("NPC_BladeScale") or 1
		local dmg = wielder:GetAttribute("NPC_Damage") or 10
		return {
			Blade = weapon,
			Star = 0,
			Power = dmg,
			Blades = wielder:GetAttribute("NPC_Blades") or 1,
			Speed = math.min((wielder:GetAttribute("NPC_Speed") or 3) * (wielder:GetAttribute("SpeedBoost") or 1), Config.MaxSpinSpeed),
			Damage = dmg,
			PvPDamage = dmg,
			Reach = wielder:GetAttribute("NPC_Reach") or 4,
			Length = weapon.Length * scale,
			Scale = scale,
			Height = wielder:GetAttribute("NPC_BladeHeight") or Config.BladeHeightOffset,
		}
	end
end

-- Each blade: { CFrame = centre (LookVector points outward), Base, Tip }
function Config.GetBlades(rootCFrame, stats, t)
	local result = {}
	local n = stats.Blades
	local center = rootCFrame.Position + Vector3.new(0, stats.Height, 0)
	for i = 1, n do
		local angle = t * stats.Speed + (i - 1) * (2 * math.pi / n)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = center + dir * math.max(stats.Reach - 0.5, 1)
		local tip = base + dir * stats.Length
		local mid = (base + tip) / 2
		result[i] = { CFrame = CFrame.lookAt(mid, mid + dir), Base = base, Tip = tip }
	end
	return result
end

function Config.FormatNumber(n)
	n = math.floor(n)
	if n >= 1e18 then return string.format("%.1fQi", n / 1e18) end
	if n >= 1e15 then return string.format("%.1fQa", n / 1e15) end
	if n >= 1e12 then return string.format("%.1fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	local s = tostring(n)
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

--------------------------------------------------------------------
-- PvP toggle (no safe zones). Both players need PvP ON to hurt each other.
--------------------------------------------------------------------
Config.PvP = {
	LogMult = 1.5,        -- logs bonus while PvP is on
	ToggleCooldown = 10,  -- seconds between toggles
	CombatLock = 15,      -- can't turn PvP off this long after PvP damage
}

-- NPCs only fight players who have PvP on, or who hit them recently
Config.NPCAggroTime = 20
function Config.NPCCanTarget(npc, player)
	if not player then return false end
	if player:GetAttribute("PvP") then return true end
	local t = npc and npc:GetAttribute("Aggro_" .. player.UserId)
	return t ~= nil and workspace:GetServerTimeNow() - t < Config.NPCAggroTime
end

--------------------------------------------------------------------
-- Souls: second currency from NPC + PvP kills, spent in the Soul Shop
--------------------------------------------------------------------
Config.SoulColor = Color3.fromRGB(185, 120, 255)
Config.SoulDrops = {
	Slime = { 1, 5 },
	BigSlime = { 3, 8 },
	GoldenSlime = { 10, 20 },
	Bandit = { 10, 10 },
}
Config.BossSoulPool = 200   -- split by damage dealt (min 5 each)
Config.PvPKillSouls = 15

Config.SoulShop = {
	{ Id = "LuckPotion",  Name = "Luck Potion",      Desc = "3x Luck for 10 min",          Cost = 40,  Kind = "Boost", Boost = "LuckPotion",     Seconds = 600 },
	{ Id = "LogBoost",    Name = "Log Boost",        Desc = "2x Logs for 10 min",          Cost = 60,  Kind = "Boost", Boost = "LogBoost",       Seconds = 600 },
	{ Id = "MegaLuck",    Name = "Mega Luck Potion", Desc = "10x Luck for 5 min",          Cost = 250, Kind = "Boost", Boost = "MegaLuckPotion", Seconds = 300 },
	{ Id = "SoulCrate",   Name = "Soul Trait Crate", Desc = "Better trait odds (no Saplings!)", Cost = 150, Kind = "OpenTraits" },
	{ Id = "SoulboundBlade", Kind = "Weapon", Weapon = "SoulboundBlade" },
	{ Id = "SoulHarvester",  Kind = "Weapon", Weapon = "SoulHarvester" },
	{ Id = "ForsakenAxe",    Kind = "Weapon", Weapon = "ForsakenAxe" },
}
-- M1: permanent Soul upgrades (Souls sink; they feed the capped Logs / Luck pools and
-- are never reset by rebirth). Cost = BaseCost x CostMult^level (EconomyConfig.SoulUpgrades).
for _, su in ipairs(EC.SoulUpgrades) do
	table.insert(Config.SoulShop, { Id = su.Id, Name = su.Name, Desc = su.Desc, Cost = su.BaseCost, Kind = "SoulUpgrade",
		Upgrade = su.Id, MaxLevel = su.MaxLevel })
end
function Config.GetSoulUpgradeCost(id, level)
	for _, su in ipairs(EC.SoulUpgrades) do
		if su.Id == id then return math.floor(su.BaseCost * su.CostMult ^ (level or 0)) end
	end
	return math.huge
end
Config.SoulShopById = {}
for i, item in ipairs(Config.SoulShop) do
	item.Order = i
	if item.Kind == "Weapon" then
		local w = Config.WeaponById[item.Weapon]
		item.Name = w.Name
		item.Cost = w.SoulCost
		item.Desc = string.format("%s %s  -  Power %s", w.Rarity, w.Type, Config.FormatNumber and Config.FormatNumber(w.Power) or tostring(w.Power))
	end
	Config.SoulShopById[item.Id] = item
end
--------------------------------------------------------------------
-- Traits: title over your head + permanent Logs multiplier.
-- Weight = chance in the normal (Logs) crate, SoulWeight = Soul crate.
--------------------------------------------------------------------
Config.Traits = {
	{ Id = "Sapling",      Name = "Sapling",       Mult = 1.25, Weight = 50,  SoulWeight = 0,  Color = Color3.fromRGB(150, 225, 120) },
	{ Id = "Woodcutter",   Name = "Woodcutter",    Mult = 1.5,  Weight = 28,  SoulWeight = 45, Color = Color3.fromRGB(110, 200, 255) },
	{ Id = "Lumberjack",   Name = "Lumberjack",    Mult = 1.75, Weight = 14,  SoulWeight = 32, Color = Color3.fromRGB(255, 165, 60) },
	{ Id = "TimberTitan",  Name = "Timber Titan",  Mult = 2,    Weight = 6,   SoulWeight = 15, Color = Color3.fromRGB(190, 90, 255) },
	{ Id = "ForestWarden", Name = "Forest Warden", Mult = 2.5,  Weight = 1.8, SoulWeight = 7,  Color = Color3.fromRGB(70, 255, 150) },
	{ Id = "AncientRoot",  Name = "Ancient Root",  Mult = 3,    Weight = 0.2, SoulWeight = 1,  Color = Color3.fromRGB(255, 215, 80), Rainbow = true },
}
Config.TraitById = {}
for i, t in ipairs(Config.Traits) do
	t.Order = i
	Config.TraitById[t.Id] = t
end
-- LEGACY (pre-M1) crate prices by BestArea; kept only so old callers still get a number.
Config.TraitCrateCost = { StarterGrove = 750, PineForest = 25000, CrystalCanyon = 600000, FrostPeaks = 8000000 }
Config.SoulCrateCost = 150
-- M1: prices follow the player's PROGRESSION TIER (Economy.PriceTier), not BestArea.
-- `who` = a price unit (number), a Player (reads the server-set "PriceUnit" attribute)
-- or, for old callers only, a legacy area id.
function Config.GetPriceUnit(who)
	if type(who) == "number" then return who end
	if typeof(who) == "Instance" and who:IsA("Player") then
		return who:GetAttribute("PriceUnit") or EC.PriceTiers[1].Unit
	end
	return Config.TraitCrateCost[who or "StarterGrove"] or Config.TraitCrateCost.StarterGrove
end
function Config.GetTraitCrateCost(who)
	return math.floor(Config.GetPriceUnit(who) * EC.Prices.TraitCrate)
end
-- odds table for a crate: { {trait, chancePercent}, ... }
function Config.GetTraitOdds(crate, lucky)
	local key = crate == "Souls" and "SoulWeight" or "Weight"
	local function w(t) return t[key] * ((lucky and t.Mult >= 1.75) and 2 or 1) end
	local total = 0
	for _, t in ipairs(Config.Traits) do total += w(t) end
	local list = {}
	for _, t in ipairs(Config.Traits) do
		table.insert(list, { Trait = t, Chance = w(t) / total * 100 })
	end
	return list
end
--------------------------------------------------------------------
-- STORE (Robux). Paste IDs from create.roblox.com here. 0 = not set up yet
-- (shows as "SOON" in game).
--   GamePasses   -> Monetization > Passes            (bought once, forever)
--   DevProducts  -> Monetization > Developer Products (can be bought again)
--------------------------------------------------------------------
Config.GamePasses = {
	{ Id = "VIP",         PassId = 2094194984, Price = 399, Name = "VIP",           Desc = "+10% Logs, gold VIP tag, 1 free Trait Crate every day" },
	{ Id = "BladeSlot",   PassId = 2092911060, Price = 249, Name = "+1 Blade Slot", Desc = "One extra spinning blade, forever" },
	{ Id = "2xLuck",      PassId = 2093457053, Price = 299, Name = "2x Luck",       Desc = "Double weapon roll luck, forever" },
	{ Id = "2xLogs",      PassId = 2092761109, Price = 299, Name = "2x Logs",       Desc = "Double Logs from everything, forever" },
	{ Id = "FastRoll",    PassId = 2094279037, Price = 149, Name = "Fast Roll",     Desc = "Auto roll almost 3x faster" },
	{ Id = "LuckyCrates", PassId = 2093577035, Price = 199, Name = "Lucky Crates",  Desc = "2x chance for Lumberjack+ traits", RandomItem = true },
}
Config.DevProducts = {
	-- Starter Pack is a one-time buy, so it is sold as a game pass (PassId)
	{ Id = "StarterPack",  ProductId = 0, PassId = 2094327011, Price = 99,  Name = "Starter Pack",       Desc = "Founder's Edge (Epic, exclusive) + 3 Trait Crates + 30 min 2x Luck", OneTime = true },
	{ Id = "LuckPotion",   ProductId = 0, Price = 49,  Name = "Luck Potion",        Desc = "3x Luck for 15 min",  Boost = "LuckPotion",     Seconds = 900 },
	{ Id = "MegaLuck",     ProductId = 0, Price = 199, Name = "Mega Luck Potion",   Desc = "10x Luck for 15 min", Boost = "MegaLuckPotion", Seconds = 900 },
	{ Id = "LogBoost",     ProductId = 0, Price = 79,  Name = "Log Boost",          Desc = "2x Logs for 30 min",  Boost = "LogBoost",       Seconds = 1800 },
	{ Id = "LogPackS",     ProductId = 0, Price = 39,  Name = "Small Log Pack",     Desc = "Logs (grows with your area)", PackMult = 3 },
	{ Id = "LogPackM",     ProductId = 0, Price = 149, Name = "Big Log Pack",       Desc = "Logs (grows with your area)", PackMult = 15 },
	{ Id = "LogPackL",     ProductId = 0, Price = 499, Name = "Huge Log Pack",      Desc = "Logs (grows with your area)", PackMult = 60 },
	{ Id = "TraitCrate1",  ProductId = 0, Price = 29,  Name = "Instant Trait Crate", Desc = "1 Trait Crate roll",  Crates = 1,  RandomItem = true },
	{ Id = "TraitCrate10", ProductId = 0, Price = 249, Name = "Trait Crate x10",    Desc = "10 Trait Crate rolls", Crates = 10, RandomItem = true },
}
Config.PassById, Config.ProductById, Config.ProductByProductId = {}, {}, {}
for i, p in ipairs(Config.GamePasses) do p.Order = i Config.PassById[p.Id] = p end
for i, p in ipairs(Config.DevProducts) do
	p.Order = i
	Config.ProductById[p.Id] = p
	if p.ProductId ~= 0 then Config.ProductByProductId[p.ProductId] = p end
end
Config.StarterPackBonus = { Weapon = "FoundersEdge", Crates = 3, Boost = "StarterLuck", Seconds = 1800 }
Config.VIPDailyCrateHours = 20
-- Log packs scale with the player's progression price unit (M1)
function Config.GetLogPackAmount(productId, who)
	local p = Config.ProductById[productId]
	return math.floor(Config.GetPriceUnit(who) * (p and p.PackMult or 1))
end
--------------------------------------------------------------------
-- Rolling helpers (shared by server roll + client odds display)
--------------------------------------------------------------------
Config.RollPool = {}
for _, w in ipairs(Config.Weapons) do
	if w.OneIn and not w.Exclusive and w.Id ~= Config.StarterWeapon then table.insert(Config.RollPool, w) end
end
table.sort(Config.RollPool, function(a, b) return a.OneIn > b.OneIn end) -- rarest first

-- luck only boosts weapons rarer than 1 in 10 (commons stay common).
-- M1: rarer tiers feel luck less: OneIn / luck ^ gamma(rarity) (EconomyConfig.LuckGamma)
function Config.EffectiveOneIn(w, luck)
	if w.OneIn <= EC.LuckMinOneIn then return w.OneIn end
	return math.max(w.OneIn / math.max(luck or 1, 1) ^ (EC.LuckGamma[w.Rarity] or 1), 1)
end

function Config.RollWeapon(rng, luck)
	for _, w in ipairs(Config.RollPool) do
		if rng:NextNumber() * Config.EffectiveOneIn(w, luck) < 1 then return w end
	end
	return Config.WeaponById[Config.StarterWeapon]
end

function Config.FormatOneIn(x)
	if x >= 1e9 then return string.format("1 in %.1fB", x / 1e9) end
	if x >= 1e6 then return string.format("1 in %gM", math.floor(x / 1e5 + 0.5) / 10) end
	if x >= 1e4 then return string.format("1 in %gK", math.floor(x / 100 + 0.5) / 10) end
	return "1 in " .. Config.FormatNumber(math.floor(x + 0.5))
end
--------------------------------------------------------------------
-- REBIRTH: reset Logs + upgrades for permanent +25% Logs, +10% Luck each
--------------------------------------------------------------------
-- M1: rebirth Logs bonus tapers (Economy: 1 + soft(0.25 n, 3)); luck +0.10 per rebirth into the
-- permanent luck pool. Cost = max(MinCost, Units x Growth^n x price unit) so it tracks the tier.
Config.Rebirth = { LogsPer = EC.Pools.RebirthLogsPer, LuckPer = EC.Rebirth.LuckPer }
function Config.GetRebirthCost(n, who)
	local R = EC.Rebirth
	return math.max(R.MinCost, math.floor(R.Units * R.Growth ^ (n or 0) * Config.GetPriceUnit(who or EC.PriceTiers[2].Unit)))
end

--------------------------------------------------------------------
-- GROUP: join the group for +10% Luck. Put your group id here.
--------------------------------------------------------------------
Config.GroupId = 76836496
Config.GroupLuck = 1.1

--------------------------------------------------------------------
-- LUCK EVENTS (server-wide). One starts every 18-30 minutes.
--------------------------------------------------------------------
Config.Events = {
	{ Id = "GoldenHour", Name = "GOLDEN HOUR", Desc = "2x Luck for everyone!", Luck = 2, Logs = 1, Seconds = 300, Weight = 45, Color = Color3.fromRGB(255, 200, 60) },
	{ Id = "LogRush",    Name = "LOG RUSH",    Desc = "2x Logs for everyone!", Luck = 1, Logs = 2, Seconds = 300, Weight = 40, Color = Color3.fromRGB(240, 150, 60) },
	{ Id = "BloodMoon",  Name = "BLOOD MOON",  Desc = "5x Luck + 1.5x Logs!",  Luck = 5, Logs = 1.5, Seconds = 180, Weight = 15, Color = Color3.fromRGB(230, 40, 60) },
}
Config.EventGap = { 1080, 1800 }

--------------------------------------------------------------------
-- DAILY LOGIN (7 day streak) + PLAYTIME GIFTS (per session)
-- Logs rewards = Mult x the Trait Crate price of your best area.
--------------------------------------------------------------------
Config.DailyRewards = {
	{ Kind = "Logs", Mult = 2 },
	{ Kind = "Souls", Amount = 25 },
	{ Kind = "Boost", Boost = "LuckPotion", Seconds = 900, Label = "Luck Potion" },
	{ Kind = "Logs", Mult = 6 },
	{ Kind = "Crate", Amount = 2 },
	{ Kind = "Souls", Amount = 120 },
	{ Kind = "Boost", Boost = "MegaLuckPotion", Seconds = 900, Label = "Mega Luck" },
}
Config.PlaytimeGifts = {
	{ Minutes = 5,  Kind = "Logs", Mult = 1 },
	{ Minutes = 10, Kind = "Souls", Amount = 15 },
	{ Minutes = 20, Kind = "Boost", Boost = "LuckPotion", Seconds = 600, Label = "Luck Potion" },
	{ Minutes = 30, Kind = "Logs", Mult = 4 },
	{ Minutes = 45, Kind = "Crate", Amount = 1 },
	{ Minutes = 60, Kind = "Boost", Boost = "MegaLuckPotion", Seconds = 600, Label = "Mega Luck" },
	{ Minutes = 90, Kind = "Souls", Amount = 100 },
	{ Minutes = 120, Kind = "Crate", Amount = 3 },
}

--------------------------------------------------------------------
-- QUESTS: 3 daily + 3 weekly. Stat = what counts.
--------------------------------------------------------------------
Config.DailyQuests = {
	{ Id = "dChop",  Stat = "Trees",   Goal = 300,  Text = "Chop %s trees",        Reward = { Kind = "Souls", Amount = 30 } },
	{ Id = "dRoll",  Stat = "Rolls",   Goal = 1500, Text = "Roll %s times",        Reward = { Kind = "Crate", Amount = 1 } },
	{ Id = "dNPC",   Stat = "NPCs",    Goal = 25,   Text = "Defeat %s enemies",     Reward = { Kind = "Souls", Amount = 50 } },
	{ Id = "dPlay",  Stat = "Minutes", Goal = 30,   Text = "Play for %s minutes",  Reward = { Kind = "Boost", Boost = "LuckPotion", Seconds = 900, Label = "Luck Potion" } },
	{ Id = "dRare",  Stat = "RarePull", Goal = 3,   Text = "Roll %s Epic+ weapons", Reward = { Kind = "Logs", Mult = 5 } },
}
Config.WeeklyQuests = {
	{ Id = "wChop", Stat = "Trees",   Goal = 6000,  Text = "Chop %s trees",       Reward = { Kind = "Crate", Amount = 5 } },
	{ Id = "wRoll", Stat = "Rolls",   Goal = 25000, Text = "Roll %s times",       Reward = { Kind = "Boost", Boost = "MegaLuckPotion", Seconds = 1800, Label = "Mega Luck" } },
	{ Id = "wNPC",  Stat = "NPCs",    Goal = 400,   Text = "Defeat %s enemies",    Reward = { Kind = "Souls", Amount = 500 } },
	{ Id = "wBoss", Stat = "Boss",    Goal = 3,     Text = "Defeat the Blade King %s times", Reward = { Kind = "Souls", Amount = 400 } },
}

--------------------------------------------------------------------
-- CODES (type in Settings). Case-insensitive. Add new ones here.
--------------------------------------------------------------------
Config.Codes = EC.Codes -- M1: fixed amounts (audit L10), never scaled by area

--------------------------------------------------------------------
-- PETS (ReplicatedStorage.PetModels, Creator Store models). Hatched from
-- the Pet Egg with Logs; equipped pets follow you and boost Logs / Luck.
--------------------------------------------------------------------
Config.Pets = {
	{ Id = "Bunny",   Name = "Bunny",       Rarity = "Common",    Weight = 45,  Logs = 0.10, Luck = 0 },
	{ Id = "Cat",     Name = "Cat",         Rarity = "Common",    Weight = 30,  Logs = 0.15, Luck = 0 },
	{ Id = "Bear",    Name = "Bear",        Rarity = "Uncommon",  Weight = 14,  Logs = 0.25, Luck = 0 },
	{ Id = "Fox",     Name = "Fox",         Rarity = "Rare",      Weight = 7,   Logs = 0.40, Luck = 0.05 },
	{ Id = "Penguin", Name = "Penguin",     Rarity = "Epic",      Weight = 3,   Logs = 0.60, Luck = 0.10 },
	{ Id = "Owl",     Name = "Snow Owl",    Rarity = "Legendary", Weight = 0.9, Logs = 1.00, Luck = 0.20 },
	{ Id = "Dragon",  Name = "Baby Dragon", Rarity = "Mythic",    Weight = 0.1, Logs = 2.00, Luck = 0.50 },
}
Config.PetById = {}
for i, p in ipairs(Config.Pets) do p.Order = i Config.PetById[p.Id] = p end
Config.MaxPetsEquipped = 3 -- VIP gets +1
Config.PetEggMult = EC.Prices.PetEgg -- egg price = progression price unit x this (M1)
function Config.GetEggCost(who) return math.floor(Config.GetPriceUnit(who) * Config.PetEggMult) end
function Config.RollPet(rng)
	local total = 0
	for _, p in ipairs(Config.Pets) do total += p.Weight end
	local r = (rng and rng:NextNumber() or math.random()) * total
	for _, p in ipairs(Config.Pets) do
		r -= p.Weight
		if r <= 0 then return p end
	end
	return Config.Pets[1]
end

--------------------------------------------------------------------
-- SAWMILL (Log Market): trade Logs for Souls. The rate changes every hour.
--------------------------------------------------------------------
Config.Sawmill = {
	LogsPerSoul = EC.Prices.SawmillLogsPerSoul, -- x progression price unit = Logs for 1 Soul at rate 1.0 (M1)
	RateMin = 0.6, RateMax = 1.6, -- hourly market rate (higher = more Souls)
	DailyCap = 200,       -- max Souls per day from the sawmill
}
function Config.SawmillRate(hourKey)
	local r = Random.new(hourKey * 7919 + 13)
	return math.floor((Config.Sawmill.RateMin + r:NextNumber() * (Config.Sawmill.RateMax - Config.Sawmill.RateMin)) * 100) / 100
end

--------------------------------------------------------------------
-- WORLD BOSS: the Ancient Treant. A giant tree the whole server chops.
-- Rewards are split by how much damage you did.
--------------------------------------------------------------------
Config.WorldBoss = {
	Name = "Ancient Treant",
	Every = 1200,        -- seconds between spawns
	Lifetime = 420,      -- despawns if not chopped in time
	HealthPerPower = 300, -- HP = this x total Power of everyone online (scales with server)
	Position = Vector3.new(0, 0, 205), -- clearing in the north Pine Forest
	MinHealth = 20000,
	TopSouls = 150, Souls = 40, Crates = 1, LogsMult = 3, -- best share / everyone who helped
}

--------------------------------------------------------------------
-- ACHIEVEMENTS (claim in the TROPHY menu). Stat = data path.
--------------------------------------------------------------------
Config.Achievements = {
	{ Id = "chop100",   Name = "Woodcutter",       Desc = "Chop 100 trees",           Stat = "Trees",   Goal = 100,     Reward = { Kind = "Souls", Amount = 20 } },
	{ Id = "chop1k",    Name = "Lumberjack",       Desc = "Chop 1,000 trees",         Stat = "Trees",   Goal = 1000,    Reward = { Kind = "Crate", Amount = 1 } },
	{ Id = "chop10k",   Name = "Forest Feller",    Desc = "Chop 10,000 trees",        Stat = "Trees",   Goal = 10000,   Reward = { Kind = "Crate", Amount = 3 } },
	{ Id = "chop100k",  Name = "Deforester",       Desc = "Chop 100,000 trees",       Stat = "Trees",   Goal = 100000,  Reward = { Kind = "Boost", Boost = "MegaLuckPotion", Seconds = 1800, Label = "Mega Luck" } },
	{ Id = "roll1k",    Name = "Roller",           Desc = "Roll 1,000 times",         Stat = "Rolls",   Goal = 1000,    Reward = { Kind = "Souls", Amount = 30 } },
	{ Id = "roll10k",   Name = "High Roller",      Desc = "Roll 10,000 times",        Stat = "Rolls",   Goal = 10000,   Reward = { Kind = "Crate", Amount = 2 } },
	{ Id = "roll100k",  Name = "Gambler King",     Desc = "Roll 100,000 times",       Stat = "Rolls",   Goal = 100000,  Reward = { Kind = "Boost", Boost = "MegaLuckPotion", Seconds = 3600, Label = "Mega Luck" } },
	{ Id = "rare1k",    Name = "Lucky",            Desc = "Pull a 1 in 1,000 weapon", Stat = "Rarest",  Goal = 1000,    Reward = { Kind = "Souls", Amount = 25 } },
	{ Id = "rare100k",  Name = "Blessed",          Desc = "Pull a 1 in 100K weapon",  Stat = "Rarest",  Goal = 100000,  Reward = { Kind = "Crate", Amount = 3 } },
	{ Id = "rare1m",    Name = "Chosen One",       Desc = "Pull a 1 in 1M weapon",    Stat = "Rarest",  Goal = 1000000, Reward = { Kind = "Crate", Amount = 10 } },
	{ Id = "mutant",    Name = "Mutant Hunter",    Desc = "Chop 25 mutated trees",    Stat = "Mutations", Goal = 25,    Reward = { Kind = "Souls", Amount = 50 } },
	{ Id = "rainbow",   Name = "Over the Rainbow", Desc = "Chop a Rainbow tree",      Stat = "Rainbow", Goal = 1,       Reward = { Kind = "Crate", Amount = 2 } },
	{ Id = "kills50",   Name = "Duelist",          Desc = "Win 50 PvP fights",        Stat = "Kills",   Goal = 50,      Reward = { Kind = "Souls", Amount = 80 } },
	{ Id = "rebirth1",  Name = "Born Again",       Desc = "Rebirth once",             Stat = "Rebirths", Goal = 1,      Reward = { Kind = "Crate", Amount = 1 } },
	{ Id = "rebirth5",  Name = "Phoenix",          Desc = "Rebirth 5 times",          Stat = "Rebirths", Goal = 5,      Reward = { Kind = "Crate", Amount = 5 } },
	{ Id = "pets10",    Name = "Pet Lover",        Desc = "Hatch 10 pets",            Stat = "Hatched", Goal = 10,      Reward = { Kind = "Souls", Amount = 30 } },
	{ Id = "treant",    Name = "Treant Slayer",    Desc = "Help chop the Ancient Treant 3 times", Stat = "Treants", Goal = 3, Reward = { Kind = "Crate", Amount = 2 } },
	{ Id = "shiny",     Name = "Shiny!",           Desc = "Craft a Shiny weapon",     Stat = "Shinies", Goal = 1,       Reward = { Kind = "Souls", Amount = 60 } },
}
function Config.AchievementProgress(d, stat)
	if not d then return 0 end
	local s = d.Stats or {}
	if stat == "Trees" then return s.TreesChopped or 0 end
	if stat == "Rolls" then return d.Rolls and d.Rolls.Total or 0 end
	if stat == "Rarest" then return s.RarestOneIn or 0 end
	if stat == "Kills" then return d.Kills or 0 end
	if stat == "Rebirths" then return d.Rebirths or 0 end
	if stat == "Mutations" then
		local n = 0
		for _, v in pairs(d.MutationsFound or {}) do n += v end
		return n
	end
	if stat == "Rainbow" then return (d.MutationsFound or {}).Rainbow or 0 end
	if stat == "Hatched" then return s.PetsHatched or 0 end
	if stat == "Treants" then return s.Treants or 0 end
	if stat == "Shinies" then
		local n = 0
		for _, e in pairs(d.Weapons or {}) do if e.Shiny then n += 1 end end
		return n
	end
	return 0
end

-- describe a reward for UI
function Config.RewardText(rw, who)
	if rw.Kind == "Logs" then return Config.FormatNumber(Config.GetPriceUnit(who) * rw.Mult) .. " Logs" end
	if rw.Kind == "Souls" then return rw.Amount .. " Souls" end
	if rw.Kind == "Crate" then return rw.Amount .. " Trait Crate" .. (rw.Amount > 1 and "s" or "") end
	if rw.Kind == "Boost" then return (rw.Label or rw.Boost) .. " " .. math.floor(rw.Seconds / 60) .. "m" end
	return "?"
end
--------------------------------------------------------------------
-- Islands (P1a prototype, Island Dev place only).
-- Stable IslandIds. Each island maps to a legacy area id, so saves, area
-- gates, BestArea pricing and the indexes keep working unchanged.
-- Island 1 = the whole existing map (Starter, Pine, Crystal wedge, Frost annex).
--------------------------------------------------------------------
Config.Islands = {
	{ Id = "TimberHaven", Name = "Timber Haven", Order = 1, Center = Vector3.new(0, 0, 0),
		BoundsMin = Vector3.new(-720, -600, -440), BoundsMax = Vector3.new(420, 1200, 440),
		Arrival = Vector3.new(0, 5, 22), LegacyArea = nil, ReleaseState = "available" },
	{ Id = "CrystalWilds", Name = "Crystal Wilds", Order = 2, Center = Vector3.new(3000, 0, 0),
		BoundsMin = Vector3.new(2700, -600, -300), BoundsMax = Vector3.new(3300, 1200, 300),
		Arrival = Vector3.new(2790, 5, 0), LegacyArea = "CrystalCanyon", ReleaseState = "available" },
	{ Id = "FrostboundReach", Name = "Frostbound Reach", Order = 3, Center = Vector3.new(6000, 0, 0),
		BoundsMin = Vector3.new(5660, -600, -320), BoundsMax = Vector3.new(6340, 1200, 320),
		Arrival = Vector3.new(6000, 5, 0), LegacyArea = "FrostPeaks", ReleaseState = "available" },
}
Config.IslandById = {}
for _, isl in ipairs(Config.Islands) do Config.IslandById[isl.Id] = isl end
Config.HomeIsland = "TimberHaven"
Config.TravelCooldown = 3

-- island whose horizontal bounds contain pos, or nil (open water / void)
function Config.GetIslandAt(pos)
	for _, isl in ipairs(Config.Islands) do
		local a, b = isl.BoundsMin, isl.BoundsMax
		if pos.X >= a.X and pos.X <= b.X and pos.Z >= a.Z and pos.Z <= b.Z then return isl end
	end
	return nil
end

-- M1: island gates are staged (EconomyConfig.Gates: Power + requirements, Economy.GateStatus)
function Config.GetIslandRequiredPower(isl)
	local g = isl and EC.Gates[isl.Id]
	if g then return g.Power end
	local a = isl and isl.LegacyArea and Config.AreaById[isl.LegacyArea]
	return a and a.RequiredPower or 0
end
-- legacy areas on the Timber Haven map that belong to a later island's gate
Config.AreaIsland = EC.AreaIsland

--------------------------------------------------------------------
-- M2: catalog fields for all 120 weapons (derived, never saved)
--   Island / Altar   which island altar rolls it (nil = not rollable)
--   Edition          1 = launch + M1 sets, 2 = M2 expansion (index editions)
--   Source           Altar / Starter / StarterPack / SoulShop (+ Attunement for the 3 Divines)
--   VfxTier          0 Common .. 7 Divine (BladeEffects + reveals read this)
--   Future           reserved interfaces only - forging, runes, awakening, trading, vaults,
--                    seasonal variants, guild rewards, new islands. No system uses them yet;
--                    per-item state will live in the saved WeaponItems table (M6).
--------------------------------------------------------------------
Config.Attunement = EC.Essence -- PerRoll, DailyCap, AttuneCost, Attunement[island] = weaponId
Config.AttunementWeapon = {}
for isl, id in pairs(EC.Essence.Attunement) do Config.AttunementWeapon[id] = isl end
Config.WeaponFuture = EC.WeaponFuture -- FavoriteBlocks, MaxFavoriteCopies, PowerCeilingMult
for _, w in ipairs(W) do
	w.Edition = w.Edition or 1
	w.Island = EC.AreaIsland[w.Area]
	w.Altar = (w.OneIn and not w.Exclusive and w.Id ~= Config.StarterWeapon) and w.Island or nil
	w.Source = w.SoulCost and "SoulShop" or (w.Exclusive and "StarterPack") or (w.Id == Config.StarterWeapon and "Starter") or "Altar"
	if Config.AttunementWeapon[w.Id] then w.Source = "Altar + Divine Attunement" end
	w.VfxTier = Config.RarityById[w.Rarity].Order - 1
	w.Future = {
		Forgeable = not w.Exclusive, -- may become a forge input/output (M6)
		RuneSlots = 0,               -- awakening I-III add one slot each (M6)
		MaxAwakening = Config.RarityById[w.Rarity].Order >= Config.RarityById.Epic.Order and 3 or 0,
		Tradeable = not w.Exclusive and w.Id ~= Config.StarterWeapon, -- trading rules decided later
		Vaultable = true,
		SeasonVariantOf = nil,       -- seasonal skins point at their base weapon id
		GuildReward = false,
	}
end

-- how a weapon is obtained (Gallery text)
function Config.AcquireText(w)
	if not w then return "" end
	if w.SoulCost then return "Soul Shop: " .. Config.FormatNumber(w.SoulCost) .. " Souls" end
	if w.Id == Config.StarterWeapon then return "Starter weapon" end
	if w.Exclusive then return "Starter Pack exclusive" end
	local isl = Config.IslandById[w.Island]
	local t = "Roll at the " .. (isl and isl.Name or w.Island) .. " altar (or any later island's)"
	if Config.AttunementWeapon[w.Id] then
		t = t .. "  •  or Divine Attunement: " .. Config.FormatNumber(EC.Essence.AttuneCost) .. " Altar Essence"
	end
	return t
end

return Config
