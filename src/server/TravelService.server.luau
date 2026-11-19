-- TravelService (P1a prototype - Island Dev place only)
-- Server-authoritative travel between islands inside the SAME place.
-- No TeleportService: the character is streamed-in and pivoted to a safe arrival spot.
--   Remotes.Travel:InvokeServer(islandId) -> ok, islandId | reason
--   Island pads: any ProximityPrompt with attribute TravelTo = islandId
-- Checks: valid + available island, unlocked (saved or legacy Power gate),
-- loaded + alive, not PvP combat-locked, cooldown, one travel at a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify")

local TravelRemote = Remotes:FindFirstChild("Travel") or Instance.new("RemoteFunction")
TravelRemote.Name = "Travel"
TravelRemote.Parent = Remotes

local STREAM_TIMEOUT = 8
local lastTravel = {} -- [player] = os.clock()
local busy = {} -- [player] = true while a travel is running

local function home() return Config.IslandById[Config.HomeIsland] end

local function isUnlocked(player, isl)
	if isl.ReleaseState ~= "available" then return false, isl.Name .. " is not open yet" end
	if isl.Id == Config.HomeIsland then return true end
	local d = DataService.Get(player)
	if not d then return false, "Loading..." end
	d.UnlockedIslands = d.UnlockedIslands or {}
	if d.UnlockedIslands[isl.Id] then return true end
	local need = Config.GetIslandRequiredPower(isl)
	if (player:GetAttribute("Power") or 0) >= need then
		d.UnlockedIslands[isl.Id] = true -- remember it (same rule as the legacy area gate)
		return true
	end
	return false, string.format("🔒 %s needs %d Power", isl.Name, need)
end

-- arrival spot: center first, then a ring of 8 so players don't stack
local function freeSpot(isl)
	for slot = 0, 8 do
		local a = (slot - 1) * math.pi / 4
		local p = isl.Arrival + (slot == 0 and Vector3.zero or Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6))
		local taken = false
		for _, other in ipairs(Players:GetPlayers()) do
			local r = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - p).Magnitude < 3 then taken = true break end
		end
		if not taken then return CFrame.new(p) end
	end
	return CFrame.new(isl.Arrival)
end

local function setIsland(player, isl)
	player:SetAttribute("CurrentIsland", isl.Id)
	local d = DataService.Get(player)
	if d then d.LastIsland = isl.Id end
end

-- stream the destination in, then move the character (yields)
local function place(player, isl)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return false, "No character" end
	local cf = freeSpot(isl)
	pcall(function() player:RequestStreamAroundAsync(cf.Position, STREAM_TIMEOUT) end)
	if player.Character ~= char or not root.Parent or hum.Health <= 0 then return false, "Character changed during travel" end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	char:PivotTo(cf)
	return true
end

-- bypass is only ever passed by the Studio-only DevTravel hook below
local function travel(player, islandId, bypass)
	if type(islandId) ~= "string" then return false, "Bad destination" end
	local isl = Config.IslandById[islandId]
	if not isl then return false, "Unknown island" end
	if not player:GetAttribute("Loaded") then return false, "Loading..." end
	if busy[player] then return false, "Already travelling" end
	local now = os.clock()
	local wait = Config.TravelCooldown - (now - (lastTravel[player] or -math.huge))
	if wait > 0 and not (bypass and bypass.cooldown) then
		return false, string.format("Wait %.1fs before travelling again", wait)
	end
	if (player:GetAttribute("CombatUntil") or 0) > workspace:GetServerTimeNow() then
		return false, "You're in combat!"
	end
	if player:GetAttribute("CurrentIsland") == isl.Id and not (bypass and bypass.same) then
		return false, "You're already on " .. isl.Name
	end
	if not (bypass and bypass.unlock) then
		local ok, why = isUnlocked(player, isl)
		if not ok then return false, why end
	end
	lastTravel[player] = now
	busy[player] = true
	local ok, why = place(player, isl)
	busy[player] = nil
	if not ok then return false, why end
	setIsland(player, isl)
	NotifyRemote:FireClient(player, "🧭 Arrived at " .. isl.Name, "kill")
	return true, isl.Id
end

TravelRemote.OnServerInvoke = function(player, islandId)
	local ok, res = travel(player, islandId)
	if not ok then NotifyRemote:FireClient(player, tostring(res), "death") end
	return ok, res
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local to = prompt:GetAttribute("TravelTo")
	if type(to) ~= "string" then return end
	local ok, res = travel(player, to)
	if not ok then NotifyRemote:FireClient(player, tostring(res), "death") end
end)

-- respawn and rejoin: put the character back on its current island
local function onCharacter(player, char)
	local id = player:GetAttribute("CurrentIsland")
	if not id or id == Config.HomeIsland then return end
	local isl = Config.IslandById[id]
	if not char:WaitForChild("HumanoidRootPart", 10) then return end
	task.wait() -- let the default spawn finish first
	if not isl or not isUnlocked(player, isl) then setIsland(player, home()) return end
	busy[player] = true
	place(player, isl)
	busy[player] = nil
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	task.spawn(function()
		while player.Parent and not player:GetAttribute("Loaded") do task.wait(0.2) end
		if not player.Parent then return end
		local d = DataService.Get(player)
		local isl = d and Config.IslandById[d.LastIsland or ""]
		if not isl or not isUnlocked(player, isl) then isl = home() end
		player:SetAttribute("CurrentIsland", isl.Id)
		if d then d.LastIsland = isl.Id end
		if player.Character and isl.Id ~= Config.HomeIsland then onCharacter(player, player.Character) end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(p) lastTravel[p], busy[p] = nil, nil end)

-- Studio-only test hook (never reachable by clients):
-- ServerStorage.DevTravel:Invoke(player, islandId, { unlock = true, cooldown = true, same = true })
if RunService:IsStudio() then
	local bf = game:GetService("ServerStorage"):FindFirstChild("DevTravel") or Instance.new("BindableFunction")
	bf.Name = "DevTravel"
	bf.OnInvoke = function(player, islandId, bypass)
		return travel(player, islandId, type(bypass) == "table" and bypass or nil)
	end
	bf.Parent = game:GetService("ServerStorage")
end
