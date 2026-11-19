-- ExtrasService: pets, sawmill (log market), achievements and the
-- Ancient Treant world boss. Client talks to it with Remotes.Extras.
--   Extras:InvokeServer("Hatch", count)          -> results
--   Extras:InvokeServer("EquipPet", petId) / ("UnequipPet", petId) / ("EquipBestPets")
--   Extras:InvokeServer("SawmillSell", fraction)  -> souls
--   Extras:InvokeServer("ClaimAchievement", id)
--   Extras:InvokeServer("SawmillInfo")            -> { Rate, Cap, Today, LogsPerSoul }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify")
local DataService = require(script.Parent:WaitForChild("DataService"))
local Progress = require(script.Parent:WaitForChild("Progress"))

local Extras = Remotes:FindFirstChild("Extras") or Instance.new("RemoteFunction")
Extras.Name = "Extras"
Extras.Parent = Remotes

local rng = Random.new()
local function today() return math.floor(os.time() / 86400) end
local function hourKey() return math.floor(os.time() / 3600) end

local function maxPets(player)
	return Config.MaxPetsEquipped + (player:GetAttribute("Pass_VIP") and 1 or 0)
end

--------------------------------------------------------------------
-- Achievements: badge on the tile when something can be claimed
--------------------------------------------------------------------
local function achievementReady(player)
	local d = DataService.Get(player)
	if not d then return end
	local ready = 0
	for _, a in ipairs(Config.Achievements) do
		if not d.Achievements[a.Id] and Config.AchievementProgress(d, a.Stat) >= a.Goal then ready += 1 end
	end
	player:SetAttribute("AchReady", ready)
end

--------------------------------------------------------------------
-- Remote
--------------------------------------------------------------------
local last = {}
Extras.OnServerInvoke = function(player, action, a)
	local d = DataService.Get(player)
	if not d then return false, "Loading..." end
	if os.clock() - (last[player] or 0) < 0.2 then return false, "Slow down" end
	last[player] = os.clock()

	if action == "Hatch" then
		local n = (a == 3) and 3 or 1
		local cost = Config.GetEggCost(d.BestArea) * n
		if not DataService.SpendCoins(player, cost) then return false, "Need " .. Config.FormatNumber(cost) .. " Logs" end
		local results = {}
		for _ = 1, n do
			local p = Config.RollPet(rng)
			d.Pets[p.Id] = (d.Pets[p.Id] or 0) + 1
			d.Stats.PetsHatched = (d.Stats.PetsHatched or 0) + 1
			table.insert(results, p.Id)
			-- auto-equip into a free slot
			if #d.EquippedPets < maxPets(player) then table.insert(d.EquippedPets, p.Id) end
			if Config.RarityById[p.Rarity].Order >= 5 then
				NotifyRemote:FireAllClients(string.format("🥚 %s hatched a %s %s!", player.DisplayName, p.Rarity, p.Name), "rare_" .. p.Rarity)
			end
		end
		DataService.RecalcMultipliers(player)
		DataService.Sync(player)
		achievementReady(player)
		return true, results

	elseif action == "EquipPet" then
		local p = Config.PetById[a]
		if not p or not d.Pets[a] then return false, "Not owned" end
		local using = 0
		for _, id in ipairs(d.EquippedPets) do if id == a then using += 1 end end
		if using >= d.Pets[a] then return false, "All equipped" end
		if #d.EquippedPets >= maxPets(player) then return false, "Slots full" end
		table.insert(d.EquippedPets, a)
		DataService.RecalcMultipliers(player)
		DataService.Sync(player)
		return true

	elseif action == "UnequipPet" then
		local i = table.find(d.EquippedPets, a)
		if not i then return false, "Not equipped" end
		table.remove(d.EquippedPets, i)
		DataService.RecalcMultipliers(player)
		DataService.Sync(player)
		return true

	elseif action == "EquipBestPets" then
		local list = {}
		for id, count in pairs(d.Pets) do
			if Config.PetById[id] then for _ = 1, count do table.insert(list, id) end end
		end
		table.sort(list, function(x, y)
			local px, py = Config.PetById[x], Config.PetById[y]
			return px.Logs + px.Luck * 2 > py.Logs + py.Luck * 2
		end)
		d.EquippedPets = {}
		for i = 1, math.min(#list, maxPets(player)) do table.insert(d.EquippedPets, list[i]) end
		DataService.RecalcMultipliers(player)
		DataService.Sync(player)
		return true

	elseif action == "SawmillInfo" then
		if d.Sawmill.Day ~= today() then d.Sawmill.Day = today() d.Sawmill.Souls = 0 end
		return true, {
			Rate = Config.SawmillRate(hourKey()),
			NextRate = Config.SawmillRate(hourKey() + 1),
			SecondsLeft = 3600 - os.time() % 3600,
			Cap = Config.Sawmill.DailyCap,
			Today = d.Sawmill.Souls,
			LogsPerSoul = Config.GetTraitCrateCost(d.BestArea) * Config.Sawmill.LogsPerSoul,
		}

	elseif action == "SawmillSell" then
		local frac = tonumber(a)
		if not frac or frac <= 0 or frac > 1 then return false, "?" end
		if d.Sawmill.Day ~= today() then d.Sawmill.Day = today() d.Sawmill.Souls = 0 end
		local left = Config.Sawmill.DailyCap - d.Sawmill.Souls
		if left <= 0 then return false, "Sawmill is closed for you today - come back tomorrow!" end
		local rate = Config.SawmillRate(hourKey())
		local logsPerSoul = Config.GetTraitCrateCost(d.BestArea) * Config.Sawmill.LogsPerSoul / rate
		local souls = math.min(left, math.floor(d.Logs * frac / logsPerSoul))
		if souls < 1 then return false, "Need " .. Config.FormatNumber(logsPerSoul) .. " Logs for 1 Soul" end
		local cost = math.ceil(souls * logsPerSoul)
		if not DataService.SpendCoins(player, cost) then return false, "Not enough Logs" end
		d.Sawmill.Souls += souls
		DataService.AddSouls(player, souls)
		DataService.Sync(player)
		NotifyRemote:FireClient(player, string.format("🪚 Sold %s Logs for %d Souls", Config.FormatNumber(cost), souls), "rare_Epic")
		return true, souls

	elseif action == "ClaimAchievement" then
		local ach
		for _, x in ipairs(Config.Achievements) do if x.Id == a then ach = x end end
		if not ach then return false, "?" end
		if d.Achievements[a] then return false, "Already claimed" end
		if Config.AchievementProgress(d, ach.Stat) < ach.Goal then return false, "Not done yet" end
		d.Achievements[a] = true
		Progress.Grant(player, ach.Reward, "🏆 " .. ach.Name)
		achievementReady(player)
		return true
	end
	return false, "?"
end

-- refresh the achievement badge every so often (stats change all the time)
task.spawn(function()
	while true do
		task.wait(15)
		for _, p in ipairs(Players:GetPlayers()) do pcall(achievementReady, p) end
	end
end)
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)

--------------------------------------------------------------------
-- World boss: the Ancient Treant
--------------------------------------------------------------------
local WB = Config.WorldBoss
local down = ServerStorage:FindFirstChild("WorldBossDown") or Instance.new("BindableEvent")
down.Name = "WorldBossDown"
down.Parent = ServerStorage

local Breakables = workspace:WaitForChild("Breakables")
local TreeModels = ReplicatedStorage:WaitForChild("TreeModels")
local current

local function groundY(x, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rp)
	return r and r.Position.Y or 0
end

local function spawnTreant()
	local totalPower = 0
	for _, p in ipairs(Players:GetPlayers()) do totalPower += (p:GetAttribute("Power") or 5) end
	local hp = math.max(WB.MinHealth, math.floor(totalPower * WB.HealthPerPower))
	local tpl = TreeModels:FindFirstChild("Grove_Legendary_1") or TreeModels:GetChildren()[1]
	local m = tpl:Clone()
	m.Name = "AncientTreant"
	m:ScaleTo(tpl:GetScale() * 3.4)
	local pos = WB.Position
	m:PivotTo(CFrame.new(pos.X, groundY(pos.X, pos.Z), pos.Z))
	for k in pairs(m:GetAttributes()) do m:SetAttribute(k, nil) end
	m:SetAttribute("WorldBoss", true)
	m:SetAttribute("Kind", "Treant")
	m:SetAttribute("Health", hp)
	m:SetAttribute("MaxHealth", hp)
	m:SetAttribute("Strength", 0)
	m:SetAttribute("Reward", 0)
	m:SetAttribute("ExpiresAt", workspace:GetServerTimeNow() + WB.Lifetime)
	-- glow
	local pp = m.PrimaryPart
	if pp then
		local att = Instance.new("Attachment") att.Position = Vector3.new(0, 18, 0) att.Parent = pp
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 25 e.Lifetime = NumberRange.new(1.5, 2.5) e.Speed = NumberRange.new(2, 6)
		e.SpreadAngle = Vector2.new(180, 180) e.Size = NumberSequence.new(1.6, 0) e.LightEmission = 1
		e.Color = ColorSequence.new(Color3.fromRGB(140, 255, 120), Color3.fromRGB(255, 230, 120))
		e.Shape = Enum.ParticleEmitterShape.Sphere e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Parent = att
		local l = Instance.new("PointLight") l.Range = 40 l.Brightness = 2 l.Color = Color3.fromRGB(160, 255, 140) l.Parent = att
	end
	m.Parent = Breakables
	current = m
	workspace:SetAttribute("TreantAlive", true)
	NotifyRemote:FireAllClients("🌳 The ANCIENT TREANT has awakened in the north Pine Forest! Chop it together for big rewards!", "boss")
end

down.Event:Connect(function(m)
	if m ~= current then return end
	current = nil
	workspace:SetAttribute("TreantAlive", false)
	-- split rewards by damage share
	local shares, total = {}, 0
	for k, v in pairs(m:GetAttributes()) do
		local uid = tonumber(k:match("^Dmg_(%d+)$") or "")
		if uid then shares[uid] = v total += v end
	end
	local ranked = {}
	for uid, v in pairs(shares) do table.insert(ranked, { uid, v }) end
	table.sort(ranked, function(x, y) return x[2] > y[2] end)
	for i, r in ipairs(ranked) do
		local p = Players:GetPlayerByUserId(r[1])
		local d = p and DataService.Get(p)
		if d then
			local share = r[2] / math.max(total, 1)
			local souls = math.floor(WB.Souls + (WB.TopSouls - WB.Souls) * share)
			DataService.AddSouls(p, souls)
			DataService.AddCoins(p, Config.GetTraitCrateCost(d.BestArea) * WB.LogsMult, nil, true)
			d.FreeCrates = (d.FreeCrates or 0) + WB.Crates + (i == 1 and 1 or 0)
			d.Stats.Treants = (d.Stats.Treants or 0) + 1
			DataService.Sync(p)
			NotifyRemote:FireClient(p, string.format("🌳 Treant chopped! #%d (%d%% damage): +%d Souls, +%d Trait Crate%s, +Logs",
				i, math.floor(share * 100 + 0.5), souls, WB.Crates + (i == 1 and 1 or 0), (i == 1) and "s" or ""), "boss")
			achievementReady(p)
		end
	end
	NotifyRemote:FireAllClients("🌳 The Ancient Treant has been chopped down!", "boss")
	workspace:SetAttribute("TreantNext", workspace:GetServerTimeNow() + WB.Every)
end)

workspace:SetAttribute("TreantAlive", false)
workspace:SetAttribute("TreantNext", workspace:GetServerTimeNow() + 300) -- first one 5 min after server start
task.spawn(function()
	while true do
		task.wait(2)
		local now = workspace:GetServerTimeNow()
		if current and current.Parent then
			if now > (current:GetAttribute("ExpiresAt") or now + 1) then
				current:Destroy()
				current = nil
				workspace:SetAttribute("TreantAlive", false)
				workspace:SetAttribute("TreantNext", now + WB.Every)
				NotifyRemote:FireAllClients("🌳 The Ancient Treant went back to sleep...", "boss")
			end
		elseif #Players:GetPlayers() > 0 and now >= (workspace:GetAttribute("TreantNext") or 0) then
			workspace:SetAttribute("TreantNext", now + WB.Every)
			spawnTreant()
		end
	end
end)

-- Studio test hook: ServerStorage.DevExtras:Invoke("Treant")
if game:GetService("RunService"):IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "DevExtras"
	bf.OnInvoke = function(what)
		if what == "Treant" and not current then spawnTreant() return true end
		return false
	end
	bf.Parent = ServerStorage
end
