-- WorldServer: spawns slimes, bandit NPCs (with their own spinning blades)
-- and the Blade King boss. Damage/rewards are handled by CombatServer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local NotifyRemote = ReplicatedStorage:WaitForChild("Remotes").Notify
local Enemies = workspace:WaitForChild("Enemies")

local rng = Random.new()
-- Creator Store character + slime models (cleaned, no scripts)
local NPCModels = game:GetService("ServerStorage"):WaitForChild("NPCModels")
-- default R15 animations
local ANIM_IDS = { walk = "rbxassetid://507777826", idle = "rbxassetid://507766388", run = "rbxassetid://507767714" }
local function defaultAnims()
	local t = {}
	for k, id in pairs(ANIM_IDS) do
		local a = Instance.new("Animation")
		a.AnimationId = id
		t[k] = a
	end
	return t
end
-- Rogue Lumberjack camps (built in Map.Camps, each has a Center attribute)
local campCenters = {}
local campsFolder = workspace:WaitForChild("Map"):FindFirstChild("Camps")
if campsFolder then
	for _, c in ipairs(campsFolder:GetChildren()) do
		local v = c:GetAttribute("Center")
		if v then table.insert(campCenters, v) end
	end
end

local function flatDist(a, b)
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end

-- nearest living player this NPC may fight: PvP on, or hit this NPC recently
local function nearestTarget(pos, range, npc)
	local best, bestDist = nil, range
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and Config.NPCCanTarget(npc, p)
			and Config.GetAreaAt(root.Position) ~= "StarterGrove" then -- NPCs never chase into the Starter Grove
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best
end

local function countTag(tag)
	local n = 0
	for _, m in ipairs(CollectionService:GetTagged(tag)) do
		if m:IsDescendantOf(Enemies) then n += 1 end
	end
	return n
end

local function ringPoint(r0, r1, avoidEast)
	for _ = 1, 30 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(r0, r1)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local okEast = not (avoidEast and p.X > 190 and math.abs(p.Z) < 125)
		if okEast and (p - Config.ArenaCenter).Magnitude > 65 then
			return p
		end
	end
	return Vector3.new(0, 0, 80)
end

--------------------------------------------------------------------
-- Slimes
--------------------------------------------------------------------
local SLIME_TYPES = {
	Slime = { Size = 3, Health = 30, Reward = 5, Color = Color3.fromRGB(90, 220, 90), Hop = 22, Touch = 6 },
	BigSlime = { Size = 6, Health = 160, Reward = 25, Color = Color3.fromRGB(70, 140, 255), Hop = 16, Touch = 12 },
	GoldenSlime = { Size = 4, Health = 500, Reward = 120, Color = Color3.fromRGB(255, 205, 50), Hop = 28, Touch = 10 },
}
-- where each slime type lives
local terrainOnly = RaycastParams.new() -- P1b.2: ground lookup for the Crystal Wilds zone
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local SLIME_ZONES = {
	{ Type = "Slime", Max = 12, Point = function() return ringPoint(142, 200, true) end },
	{ Type = "BigSlime", Max = 8, Point = function() return ringPoint(150, 270, true) end },
	{ Type = "GoldenSlime", Max = 4, Point = function() return Vector3.new(rng:NextNumber(215, 305), 0, rng:NextNumber(-100, 100)) end },
	-- P1b.2: additional Golden Slime zone on Crystal Wilds. Same tag, so it SHARES the Max = 4 cap above
	-- (total Golden Slimes unchanged); spawns on the terrain surface.
	{ Type = "GoldenSlime", Max = 4, Point = function()
		local x, z = rng:NextNumber(3080, 3220), rng:NextNumber(-180, -60)
		local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), terrainOnly)
		return Vector3.new(x, hit and hit.Position.Y or 2, z)
	end },
}

local function spawnSlime(typeName, pos)
	local t = SLIME_TYPES[typeName]
	local slime = Instance.new("Part")
	slime.Name = typeName
	slime.Size = Vector3.new(t.Size, t.Size * 0.75, t.Size)
	slime.Color = t.Color
	slime.Material = typeName == "GoldenSlime" and Enum.Material.Foil or Enum.Material.SmoothPlastic
	slime.Transparency = 1 -- physics body; the Creator Store slime model below is the look
	slime.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	slime:SetAttribute("Kind", typeName)
	slime:SetAttribute("Health", t.Health)
	slime:SetAttribute("MaxHealth", t.Health)
	slime:SetAttribute("Reward", t.Reward)
	CollectionService:AddTag(slime, "Slime_" .. typeName)

	do
		local look = NPCModels.SlimeLook:Clone()
		look:ScaleTo(look:GetScale() * t.Size / 5)
		local body = look.PrimaryPart
		body.Color = t.Color
		if typeName == "GoldenSlime" then body.Material = Enum.Material.Foil end
		look:PivotTo(slime.CFrame * CFrame.new(0, -slime.Size.Y / 2 + t.Size / 2 * 0.95, 0) * CFrame.Angles(0, math.pi, 0))
		for _, p in ipairs(look:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = slime
				w.Part1 = p
				w.Parent = p
			end
		end
		look.Parent = slime
	end

	local att = Instance.new("Attachment", slime)
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.RigidityEnabled = true
	align.CFrame = slime.CFrame.Rotation
	align.Parent = slime

	local touchCd = {}
	slime.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		local player = hum and Players:GetPlayerFromCharacter(hit.Parent)
		if player and hum.Health > 0 and Config.NPCCanTarget(slime, player) then
			if os.clock() - (touchCd[hum] or 0) > 1 then
				touchCd[hum] = os.clock()
				hum:TakeDamage(t.Touch)
			end
		end
	end)

	slime.Parent = Enemies
	slime:SetNetworkOwner(nil)

	local home = pos
	task.spawn(function()
		while slime.Parent do
			task.wait(rng:NextNumber(1, 2.2))
			if not slime.Parent then break end
			local target = nearestTarget(slime.Position, 45, slime)
			local dir
			if target then
				dir = (target.Position - slime.Position) * Vector3.new(1, 0, 1)
			elseif flatDist(slime.Position, home) > 40 then
				dir = (home - slime.Position) * Vector3.new(1, 0, 1)
			else
				local a = rng:NextNumber(0, 6.28)
				dir = Vector3.new(math.cos(a), 0, math.sin(a))
			end
			-- never hop into the safe zone
			local next = slime.Position + dir.Unit * 8
			if Config.InSafeZone(next) or Config.GetAreaAt(next) == "StarterGrove" then
				dir = (slime.Position - Config.SafeZoneCenter) * Vector3.new(1, 0, 1)
			end
			if dir.Magnitude > 0.1 then
				dir = dir.Unit
				align.CFrame = CFrame.lookAt(Vector3.zero, dir)
				slime.AssemblyLinearVelocity = dir * t.Hop + Vector3.new(0, 30, 0)
			end
			if slime.Position.Y < -50 then slime:Destroy() end
		end
	end)
end

--------------------------------------------------------------------
-- Humanoid NPCs (bandits + boss)
--------------------------------------------------------------------
local function makeRig(colors)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = colors.Head
	desc.TorsoColor = colors.Torso
	desc.LeftArmColor = colors.Arms
	desc.RightArmColor = colors.Arms
	desc.LeftLegColor = colors.Legs
	desc.RightLegColor = colors.Legs
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	local animate = model:FindFirstChild("Animate")
	local anims = {}
	if animate then
		for _, name in ipairs({ "walk", "idle", "run" }) do
			local holder = animate:FindFirstChild(name)
			local anim = holder and holder:FindFirstChildOfClass("Animation")
			if anim then anims[name] = anim:Clone() end
		end
		animate:Destroy() -- LocalScripts don't run on NPCs; we play anims from here
	end
	return model, anims
end

local function weldTo(part, target, offset)
	part.CFrame = target.CFrame * offset
	part.CanCollide = false
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = target
	w.Part1 = part
	w.Parent = part
	part.Parent = target.Parent
end

-- generic chase AI with walk animation
local function runNPC(model, anims, opts)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local walkTrack = anims.walk and animator:LoadAnimation(anims.walk)
	local idleTrack = anims.idle and animator:LoadAnimation(anims.idle)
	if idleTrack then idleTrack:Play() end

	hum.Running:Connect(function(speed)
		if not walkTrack then return end
		if speed > 0.5 then
			if not walkTrack.IsPlaying then walkTrack:Play(0.2) end
			walkTrack:AdjustSpeed(speed / 14)
		else
			walkTrack:Stop(0.2)
		end
	end)

	task.spawn(function()
		local wanderTarget = opts.Home
		while model.Parent and hum.Health > 0 do
			local target = nearestTarget(root.Position, opts.AggroRange, model)
			if target and flatDist(target.Position, opts.Home) > opts.Leash then
				target = nil -- don't chase out of our territory
			end
			if target then
				hum:MoveTo(target.Position)
			else
				if flatDist(root.Position, wanderTarget) < 4 or rng:NextNumber() < 0.08 then
					local a = rng:NextNumber(0, 6.28)
					local r = rng:NextNumber(0, opts.WanderRadius)
					wanderTarget = opts.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				end
				hum:MoveTo(wanderTarget)
			end
			if opts.OnTick then opts.OnTick(target) end
			task.wait(0.35)
		end
	end)
end

local campCursor = 0
local function spawnBandit()
	local home
	if #campCenters > 0 then
		-- each camp gets its turn; bandits stay around their camp
		campCursor = campCursor % #campCenters + 1
		local c = campCenters[campCursor]
		local a = rng:NextNumber(0, 6.28)
		home = c + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)
	else
		home = ringPoint(155, 265, true)
	end
	local model = NPCModels.RogueLumberjack:Clone()
	local anims = defaultAnims()
	model.Name = "Bandit"
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth = 220
	hum.Health = 220
	hum.WalkSpeed = 13
	hum.DisplayName = "Rogue Lumberjack"
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	hum.BreakJointsOnDeath = false
	model:SetAttribute("Reward", 50)
	model:SetAttribute("NPC_Blades", 2)
	model:SetAttribute("NPC_Speed", 3.2)
	model:SetAttribute("NPC_Damage", 7)
	model:SetAttribute("NPC_Reach", 3.5)
	model:SetAttribute("NPC_BladeType", "Iron")

	model:PivotTo(CFrame.new(home + Vector3.new(0, 4, 0)))
	model.Parent = Enemies
	model.HumanoidRootPart:SetNetworkOwner(nil)
	CollectionService:AddTag(model, "BladeNPC")
	CollectionService:AddTag(model, "Bandit")

	hum.Died:Connect(function()
		task.delay(3, function() if model.Parent then model:Destroy() end end)
	end)
	runNPC(model, anims, { Home = home, AggroRange = 55, Leash = 90, WanderRadius = 16 })
end

--------------------------------------------------------------------
-- Boss: the Blade King
--------------------------------------------------------------------
local bossAlive = false

local function spawnBoss()
	bossAlive = true
	workspace:SetAttribute("BossAlive", true)
	local model = NPCModels.BladeKing:Clone()
	local anims = defaultAnims()
	model.Name = "Blade King"
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hp = math.clamp(8000 + 3000 * #Players:GetPlayers(), 8000, 60000)
	hum.MaxHealth = hp
	hum.Health = hp
	hum.WalkSpeed = 11
	hum.DisplayName = "☠ Blade King ☠"
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.NameDisplayDistance = 0
	hum.BreakJointsOnDeath = false
	model:SetAttribute("IsBoss", true)
	model:SetAttribute("NPC_Blades", 8)
	model:SetAttribute("NPC_Speed", 1.8)
	model:SetAttribute("NPC_Damage", 22)
	model:SetAttribute("NPC_Reach", 9)
	model:SetAttribute("NPC_BladeType", "Void")
	model:SetAttribute("NPC_BladeScale", 2)

	model:ScaleTo(2)
	model:PivotTo(CFrame.new(Config.ArenaCenter + Vector3.new(0, 12, 0)))
	model.Parent = Enemies
	model.HumanoidRootPart:SetNetworkOwner(nil)
	CollectionService:AddTag(model, "BladeNPC")
	CollectionService:AddTag(model, "Boss")

	NotifyRemote:FireAllClients("☠ The Blade King has appeared in the arena! ☠", "boss")

	local root = model.HumanoidRootPart
	local nextFrenzy = os.clock() + 10
	runNPC(model, anims, {
		Home = Config.ArenaCenter,
		AggroRange = Config.ArenaRadius + 30,
		Leash = Config.ArenaRadius + 6,
		WanderRadius = 12,
		OnTick = function(target)
			-- keep blades at normal player waist height (boss is huge)
			model:SetAttribute("NPC_BladeHeight", (Config.ArenaCenter.Y + 3) - root.Position.Y)
			if target and os.clock() > nextFrenzy then
				nextFrenzy = os.clock() + 14
				model:SetAttribute("SpeedBoost", 2.6)
				model:SetAttribute("Frenzy", true)
				task.delay(4, function()
					if model.Parent then
						model:SetAttribute("SpeedBoost", 1)
						model:SetAttribute("Frenzy", false)
					end
				end)
			end
		end,
	})

	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) and bossAlive then
			bossAlive = false
			workspace:SetAttribute("BossAlive", false)
			workspace:SetAttribute("BossSpawnAt", workspace:GetServerTimeNow() + Config.BossRespawnTime)
		end
	end)
	hum.Died:Connect(function()
		task.delay(3, function() if model.Parent then model:Destroy() end end)
	end)
end

--------------------------------------------------------------------
-- Main loop
--------------------------------------------------------------------
workspace:SetAttribute("BossAlive", false)
workspace:SetAttribute("BossSpawnAt", workspace:GetServerTimeNow() + 90) -- first boss 90s after server start

local BANDIT_COUNT = math.max(8, #campCenters * 3)
local lastBandit = 0

while true do
	for _, zone in ipairs(SLIME_ZONES) do
		if countTag("Slime_" .. zone.Type) < zone.Max then
			spawnSlime(zone.Type, zone.Point())
		end
	end
	if countTag("Bandit") < BANDIT_COUNT and os.clock() - lastBandit > 6 then
		lastBandit = os.clock()
		task.spawn(spawnBandit)
	end
	if not bossAlive and #Players:GetPlayers() > 0 and workspace:GetServerTimeNow() >= workspace:GetAttribute("BossSpawnAt") then
		task.spawn(spawnBoss)
	end
	task.wait(0.5)
end
