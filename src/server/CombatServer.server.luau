-- CombatServer: player data, shop, and ALL blade damage (PvP, NPCs, props).
-- Blades are drawn on clients; the server decides every hit from the same math.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShopAction = Remotes.ShopAction
local HitsRemote = Remotes.Hits
local ShatterRemote = Remotes.Shatter
local RewardRemote = Remotes.Reward
local NotifyRemote = Remotes.Notify

local Breakables = workspace:WaitForChild("Breakables")
local Enemies = workspace:WaitForChild("Enemies")

local TICK = 0.05
local EFFECT_RANGE = 220 -- only send hit/shatter effects to players this close

--------------------------------------------------------------------
-- Data
--------------------------------------------------------------------
-- All saving/loading lives in DataService (ServerScriptService.DataService)
local DataService = require(script.Parent:WaitForChild("DataService"))
local Progress = require(script.Parent:WaitForChild("Progress"))

local function addCoins(player, amount, pos)
	return DataService.AddCoins(player, amount, pos)
end

local function soulsFor(kind)
	local r = kind and Config.SoulDrops[kind]
	if not r then return 0 end
	return math.random(r[1], r[2])
end

--------------------------------------------------------------------
-- Shop
--------------------------------------------------------------------
ShopAction.OnServerInvoke = function(player, action, id, value)
	if not DataService.Get(player) then return false, "Loading..." end

	if action == "Upgrade" then
		local u = Config.ById[id]
		if not u then return false, "?" end
		local level = Config.GetLevel(player, id)
		if level >= u.MaxLevel then return false, "MAXED" end
		if not DataService.SpendCoins(player, Config.GetCost(id, level)) then return false, "Need more logs" end
		DataService.SetLevel(player, id, level + 1)
		return true

	elseif action == "Equip" then
		return DataService.Equip(player, id)

	elseif action == "AutoEquip" then
		DataService.SetAutoEquip(player, value == true)
		return true

	elseif action == "Fuse" then
		return DataService.Fuse(player, id)

	elseif action == "Setting" then
		if id == "AutoFuse" then
			return DataService.SetSetting(player, id, value == true)
		elseif id == "AutoSellBelow" then
			return DataService.SetSetting(player, id, value)
		end
		return false, "?"
	end
	return false, "?"
end

--------------------------------------------------------------------
-- Breakable respawning (props come back after a while, growing in)
--------------------------------------------------------------------
local TreeKit = require(game:GetService("ServerStorage"):WaitForChild("TreeKit"))
local templates = {}
for _, m in ipairs(Breakables:GetChildren()) do
	if not m:GetAttribute("IsTree") then templates[m] = m:Clone() end
end

local function growIn(new)
	local final = new:GetScale()
	new:ScaleTo(final * 0.15)
	new.Parent = Breakables
	for i = 1, 12 do
		task.wait(0.03)
		if not new.Parent then return end
		local a = i / 12
		new:ScaleTo(final * (0.15 + 0.85 * (1 - (1 - a) ^ 3)))
	end
	new:ScaleTo(final)
end

local function respawnLater(model)
	if model:GetAttribute("IsTree") then
		-- trees regrow on the same spot with a freshly rolled rarity
		local spot = model:GetPivot()
		local area = model:GetAttribute("Area") or Config.GetAreaAt(spot.Position)
		task.delay(model:GetAttribute("Respawn") or 10, function()
			local new = TreeKit.BuildRandom(area, spot)
			local rar = new:GetAttribute("Rarity")
			local mut = new:GetAttribute("Mutation")
			if mut == "Shadow" or mut == "Rainbow" then
				local a = Config.AreaById[area]
				local md = Config.MutationById[mut]
				NotifyRemote:FireAllClients(string.format("%s A %s grew in the %s!", md.Icon, new:GetAttribute("TreeName"), a and a.Name or area),
					mut == "Rainbow" and "rare_Secret" or "rare_Mythic")
			elseif rar == "Legendary" or rar == "Mythic" or rar == "Secret" then
				local a = Config.AreaById[area]
				local icon = rar == "Secret" and "🌈" or (rar == "Mythic" and "🔥" or "✨")
				NotifyRemote:FireAllClients(string.format("%s A %s %s grew in the %s!", icon, rar, new:GetAttribute("TreeName"), a and a.Name or area), "rare_" .. rar)
			end
			growIn(new)
		end)
		return
	end
	local template = templates[model]
	templates[model] = nil
	if not template then return end
	task.delay(model:GetAttribute("Respawn") or 30, function()
		local new = template:Clone()
		templates[new] = template
		growIn(new)
	end)
end

--------------------------------------------------------------------
-- Effects helpers
--------------------------------------------------------------------
local function nearbyPlayers(pos, range)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - pos).Magnitude <= range then
			table.insert(list, p)
		end
	end
	return list
end

-- info (optional): { Tree = true, Base = Vector3, Killer = userId, Logs = n }
local function shatter(target, pos, info)
	local parts = {}
	local list = target:IsA("BasePart") and { target } or {}
	if info and info.Tree then list = {} end -- clients rebuild trees from TreeModels
	for _, d in ipairs(target:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 and not (info and info.Tree) then
			table.insert(list, d)
		end
	end
	for i, p in ipairs(list) do
		if i > 16 then break end
		table.insert(parts, {
			p.CFrame, p.Size, p.Color, p.Material.Name,
			p:IsA("Part") and p.Shape.Name or "Block", p.Transparency,
		})
	 end
	for _, p in ipairs(nearbyPlayers(pos, EFFECT_RANGE)) do
		ShatterRemote:FireClient(p, pos, parts, target:GetAttribute("Kind") or target.Name, info)
	end
end

local pendingHits = {}
-- hit = { pos, damage, target, weak, attackerUserId }
local function queueHit(pos, damage, target, weak, attackerId)
	damage = damage >= 10 and math.floor(damage) or math.floor(damage * 10 + 0.5) / 10
	table.insert(pendingHits, { pos, damage, target, weak or false, attackerId or 0 })
end

local function flushHits()
	if #pendingHits == 0 then return end
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local mine = {}
			for _, h in ipairs(pendingHits) do
				if (h[1] - root.Position).Magnitude <= EFFECT_RANGE then
					table.insert(mine, h)
				end
			end
			if #mine > 0 then HitsRemote:FireClient(p, mine) end
		end
	end
	table.clear(pendingHits)
end

local function ensureHealthBar(target)
	if target:FindFirstChild("HealthBar", true) then return end
	local adornee = target:IsA("BasePart") and target or target.PrimaryPart
	if not adornee then return end
	local ext = target:IsA("Model") and target:GetExtentsSize() or target.Size
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(90, 10)
	gui.StudsOffsetWorldSpace = Vector3.new(0, math.min(ext.Y, 14) * 0.5 + 2.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	bg.Parent = gui
	Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	gui.Parent = adornee
	local function update()
		local hp = math.max(target:GetAttribute("Health") or 0, 0)
		local max = target:GetAttribute("MaxHealth") or 1
		fill.Size = UDim2.fromScale(hp / max, 1)
	end
	target:GetAttributeChangedSignal("Health"):Connect(update)
	update()
end

--------------------------------------------------------------------
-- Player kills / streaks
--------------------------------------------------------------------
local lastAttacker = setmetatable({}, { __mode = "k" }) -- [humanoid] = {player, time}

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	-- debris chunks pass through players
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then d.CollisionGroup = "Characters" end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then d.CollisionGroup = "Characters" end
	end)
	hum.Died:Connect(function()
		local info = lastAttacker[hum]
		local streak = player:GetAttribute("Streak") or 0
		player:SetAttribute("Streak", 0)
		if info and info.Player ~= player and os.clock() - info.Time < 10 and info.Player.Parent then
			local killer = info.Player
			local reward = Config.PlayerKillReward + streak * Config.BountyPerStreak
			local root = char:FindFirstChild("HumanoidRootPart")
			addCoins(killer, reward, root and root.Position)
			DataService.AddKill(killer)
			local newStreak = (killer:GetAttribute("Streak") or 0) + 1
			killer:SetAttribute("Streak", newStreak)
			DataService.AddSouls(killer, Config.PvPKillSouls, root and root.Position)
			NotifyRemote:FireClient(killer, string.format("You sliced %s!  +%d logs  +%d Souls", player.DisplayName, reward, Config.PvPKillSouls), "kill")
			NotifyRemote:FireClient(player, string.format("%s sliced you!", killer.DisplayName), "death")
			if newStreak >= 3 and newStreak % 2 == 1 then
				NotifyRemote:FireAllClients(string.format("%s is on a %d kill streak! Bounty: %d", killer.DisplayName, newStreak, Config.PlayerKillReward + newStreak * Config.BountyPerStreak), "streak")
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	DataService.Load(player)
end)
for _, p in ipairs(Players:GetPlayers()) do
	p.CharacterAdded:Connect(function(char) onCharacter(p, char) end)
	if p.Character then task.spawn(onCharacter, p, p.Character) end
	task.spawn(DataService.Load, p)
end

--------------------------------------------------------------------
-- Damage
--------------------------------------------------------------------
local damageShare = setmetatable({}, { __mode = "k" }) -- [npcModel] = {[player] = dmg}

local function killNPC(model, killer, pos)
	if model:GetAttribute("Dead") then return end
	model:SetAttribute("Dead", true)
	if model:GetAttribute("IsBoss") then
		local shares = damageShare[model] or {}
		local total = 0
		for _, d in pairs(shares) do total += d end
		for p, d in pairs(shares) do
			if p.Parent then
				local amt = math.max(100, math.floor(Config.BossRewardPool * d / math.max(total, 1)))
				local souls = math.max(5, math.floor(Config.BossSoulPool * d / math.max(total, 1)))
				addCoins(p, amt, pos)
				DataService.AddSouls(p, souls, pos)
				Progress.Add(p, "Boss", 1)
				Progress.Add(p, "NPCs", 1)
				NotifyRemote:FireClient(p, string.format("Blade King defeated! +%s logs  +%d Souls", Config.FormatNumber(amt), souls), "boss")
			end
		end
		NotifyRemote:FireAllClients("The Blade King has fallen!", "boss")
	elseif killer then
		addCoins(killer, model:GetAttribute("Reward") or 10, pos)
		local kind = CollectionService:HasTag(model, "Bandit") and "Bandit" or model:GetAttribute("Kind")
		DataService.AddSouls(killer, soulsFor(kind), pos and pos + Vector3.new(0, 2, 0))
		Progress.Add(killer, "NPCs", 1)
	end
	shatter(model, pos)
	model:Destroy()
end

local function applyDamage(attacker, target, damage, hitPos, weak)
	local attackerPlayer = attacker:IsA("Player") and attacker or nil
	local hum = target:FindFirstChildOfClass("Humanoid")

	if hum then
		if hum.Health <= 0 then return end
		if target:FindFirstChildOfClass("ForceField") then return end
		hum:TakeDamage(damage)
		queueHit(hitPos, damage, target, false, attackerPlayer and attackerPlayer.UserId)
		local victim = Players:GetPlayerFromCharacter(target)
		if victim then
			if attackerPlayer then
				lastAttacker[hum] = { Player = attackerPlayer, Time = os.clock() }
				-- PvP combat lock: neither player can switch PvP off for a while
				local untilT = workspace:GetServerTimeNow() + Config.PvP.CombatLock
				attackerPlayer:SetAttribute("CombatUntil", untilT)
				victim:SetAttribute("CombatUntil", untilT)
			end
		else
			-- NPC: remember who hit it so it fights back (even with PvP off)
			if attackerPlayer then
				target:SetAttribute("Aggro_" .. attackerPlayer.UserId, workspace:GetServerTimeNow())
				damageShare[target] = damageShare[target] or {}
				damageShare[target][attackerPlayer] = (damageShare[target][attackerPlayer] or 0) + damage
			end
			if hum.Health <= 0 then
				killNPC(target, attackerPlayer, hitPos)
			end
		end
		return
	end

	-- attribute-health target (props + slimes)
	local hp = target:GetAttribute("Health")
	if not hp or hp <= 0 then return end
	local worldBoss = target:GetAttribute("WorldBoss")
	if attackerPlayer and not target:GetAttribute("IsTree") and not worldBoss then
		target:SetAttribute("Aggro_" .. attackerPlayer.UserId, workspace:GetServerTimeNow()) -- slimes fight back
	end
	if worldBoss and attackerPlayer then
		-- remember each player's share of the damage (rewards are split by it)
		local key = "Dmg_" .. attackerPlayer.UserId
		target:SetAttribute(key, (target:GetAttribute(key) or 0) + math.min(damage, hp))
	end
	hp -= damage
	target:SetAttribute("Health", hp)
	queueHit(hitPos, damage, target, weak, attackerPlayer and attackerPlayer.UserId)
	if hp > 0 then
		ensureHealthBar(target)
		return
	end

	if worldBoss then
		-- ExtrasService hands out the shared rewards
		local ev = game:GetService("ServerStorage"):FindFirstChild("WorldBossDown")
		if ev then ev:Fire(target) end
		shatter(target, hitPos)
		target:Destroy()
		return
	end

	local earned = 0
	if attackerPlayer then
		-- trees: logs fly into the player (client shows the +N), so no floating text here
		earned = addCoins(attackerPlayer, target:GetAttribute("Reward") or 1, not target:GetAttribute("IsTree") and hitPos or nil) or 0
		if not target:GetAttribute("IsTree") then
			DataService.AddSouls(attackerPlayer, soulsFor(target:GetAttribute("Kind")), hitPos + Vector3.new(0, 2, 0))
			Progress.Add(attackerPlayer, "NPCs", 1)
		else
			Progress.Add(attackerPlayer, "Trees", 1)
			Progress.TreeChopped(attackerPlayer, target:GetAttribute("TreeType"), target:GetAttribute("Mutation"))
		end
	end
	local info
	if target:GetAttribute("IsTree") and target:IsA("Model") and target.PrimaryPart then
		local pp = target.PrimaryPart
		info = {
			Tree = true,
			Base = pp.Position - Vector3.new(0, pp.Size.Y / 2, 0), -- hitbox sits on the ground
			Template = target:GetAttribute("Template"),
			Pivot = target:GetPivot(),
			Scale = target:GetScale(),
			Rarity = target:GetAttribute("Rarity"),
			Mutation = target:GetAttribute("Mutation"),
			Killer = attackerPlayer and attackerPlayer.UserId or 0,
			Logs = earned,
			From = attacker:IsA("Player") and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
				and attacker.Character.HumanoidRootPart.Position or hitPos,
		}
	end
	if info and attackerPlayer and (info.Rarity == "Legendary" or info.Rarity == "Mythic" or info.Rarity == "Secret"
		or info.Mutation == "Shadow" or info.Mutation == "Rainbow") then
		NotifyRemote:FireAllClients(string.format("✨ %s chopped a %s %s! (+%s Logs)", attackerPlayer.DisplayName, info.Rarity,
			target:GetAttribute("TreeName") or "Tree", Config.FormatNumber(earned)), "rare_" .. info.Rarity)
	end
	shatter(target, hitPos, info)
	if target.Parent == Breakables then
		respawnLater(target)
	end
	target:Destroy()
end

--------------------------------------------------------------------
-- Hit detection
--------------------------------------------------------------------
local targetCache = setmetatable({}, { __mode = "k" })
local function resolveTarget(part)
	local cached = targetCache[part]
	if cached ~= nil then return cached or nil end
	local node = part
	while node and node ~= workspace do
		if node:GetAttribute("Health") ~= nil then break end
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then break end
		node = node.Parent
	end
	if node == workspace then node = nil end
	targetCache[part] = node or false
	return node
end

local function closestPoint(part, p)
	if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
		local c = part.Position
		local r = part.Size.X / 2
		local v = p - c
		if v.Magnitude <= r then return p end
		return c + v.Unit * r
	end
	local cf = part.CFrame
	local half = part.Size / 2
	local l = cf:PointToObjectSpace(p)
	return cf:PointToWorldSpace(Vector3.new(
		math.clamp(l.X, -half.X, half.X),
		math.clamp(l.Y, -half.Y, half.Y),
		math.clamp(l.Z, -half.Z, half.Z)
	))
end

-- returns hit position if the blade touches any of these parts
local SAMPLES = { 0, 0.33, 0.66, 1 }
local function bladeTouches(blade, parts, slack)
	for _, s in ipairs(SAMPLES) do
		local pt = blade.Base:Lerp(blade.Tip, s)
		for _, part in ipairs(parts) do
			local c = closestPoint(part, pt)
			if (c - pt).Magnitude <= slack then
				return c
			end
		end
	end
	return nil
end

local cooldowns = setmetatable({}, { __mode = "k" }) -- [target][attacker][bladeIndex] = time

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function processWielder(wielder, char, root, now, filterChars)
	local stats = Config.GetStats(wielder)
	local blades = Config.GetBlades(root.CFrame, stats, now)
	local isPlayer = wielder:IsA("Player")
	local attackerPvP = isPlayer and wielder:GetAttribute("PvP") == true

	overlap.FilterDescendantsInstances = isPlayer and filterChars.All or filterChars.PlayersOnly
	local center = root.Position + Vector3.new(0, stats.Height, 0)
	local parts = workspace:GetPartBoundsInRadius(center, stats.Reach + stats.Length + 2, overlap)
	if #parts == 0 then return end

	local grouped = {}
	for _, part in ipairs(parts) do
		if not part:IsDescendantOf(char) then
			local t = resolveTarget(part)
			if t then
				grouped[t] = grouped[t] or {}
				table.insert(grouped[t], part)
			end
		end
	end

	local slack = Config.BladeHitRadius * stats.Scale
	for target, tparts in pairs(grouped) do
		local allowed = true
		local victimPlayer = Players:GetPlayerFromCharacter(target)
		if victimPlayer then
			if isPlayer then
				-- PvP only when BOTH players have it switched on
				allowed = attackerPvP and victimPlayer:GetAttribute("PvP") == true
			else
				-- NPCs only hurt players with PvP on, or who attacked them
				allowed = Config.NPCCanTarget(wielder, victimPlayer)
			end
		elseif not isPlayer then
			allowed = false -- NPC blades only hurt players
		end

		if allowed then
			cooldowns[target] = cooldowns[target] or {}
			local cd = cooldowns[target][wielder]
			if not cd then
				cd = {}
				cooldowns[target][wielder] = cd
			end
			for i, blade in ipairs(blades) do
				if now - (cd[i] or 0) >= Config.BladeHitCooldown then
					local hitPos = bladeTouches(blade, tparts, slack)
					if hitPos then
						cd[i] = now
						local dmg = victimPlayer and stats.PvPDamage or stats.Damage
						local weak = false
						local strength = target:GetAttribute("Strength")
						if strength and isPlayer and stats.Power < strength then
							dmg *= Config.WeakDamageMult
							weak = true
						end
						applyDamage(wielder, target, dmg, hitPos, weak)
						if not target.Parent then break end
					end
				end
			end
		end
	end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK then return end
	acc = 0
	local now = workspace:GetServerTimeNow()

	-- filters: players hit everything; NPCs only hit player characters
	local chars = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(chars, p.Character) end
	end
	local all = table.clone(chars)
	table.insert(all, Breakables)
	table.insert(all, Enemies)
	local filterChars = { All = all, PlayersOnly = chars }

	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and p:GetAttribute("Loaded") then
			processWielder(p, char, root, now, filterChars)
		end
	end

	if #chars > 0 then
		for _, npc in ipairs(CollectionService:GetTagged("BladeNPC")) do
			local root = npc:FindFirstChild("HumanoidRootPart")
			local hum = npc:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and npc:IsDescendantOf(workspace) then
				processWielder(npc, npc, root, now, filterChars)
			end
		end
	end

	flushHits()
end)
