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

local Layout=require(ReplicatedStorage:WaitForChild("M4Layout"))
local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local guard = require(script.Parent:WaitForChild("MovementGuard")).shared -- M0.1: sanctioned teleports
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify")

local TravelRemote = Remotes:FindFirstChild("Travel") or Instance.new("RemoteFunction")
TravelRemote.Name = "Travel"
TravelRemote.Parent = Remotes
local ArrivalEffect = Remotes:FindFirstChild("IslandArrivalEffect") or Instance.new("RemoteEvent")
ArrivalEffect.Name = "IslandArrivalEffect"
ArrivalEffect.Parent = Remotes
local runtime = require(script.Parent:WaitForChild("M4WorldRuntime"))

local STREAM_TIMEOUT = 8
local lastTravel = {} -- [player] = os.clock()
local busy = {} -- [player] = true while a travel is running

local spawned = {} -- authoritative initialized character, never inferred from its position

local function home() return Config.IslandById[Config.HomeIsland] end

local function isUnlocked(player, isl, checkOnly)
	if isl.ReleaseState ~= "available" then return false, isl.Name .. " is not open yet" end
	if isl.Id == Config.HomeIsland then return true end
	local d = DataService.Get(player)
	if not d then return false, "Loading..." end
	-- P1a: AreaService still enforces the legacy area Power gate on every island,
	-- so travel must meet it too (a saved unlock alone would just bounce the player back)
	local need = Config.GetIslandRequiredPower(isl)
	if (player:GetAttribute("Power") or 0) < need then
		return false, string.format("🔒 %s needs %d Power", isl.Name, need)
	end
	-- M1.6 staged gate: Power + active requirements (Blade King, tree counts); planned
	-- requirements (unbuilt bosses) never block. Unlocked once = unlocked for good.
	if not checkOnly then return DataService.TryUnlockIsland(player, isl.Id) end
	local ok, requirements = DataService.IslandGate(player, isl.Id)
	if ok then return true end
	local missing = {}
	for _, requirement in ipairs(requirements) do
		if requirement.Stage == "active" and not requirement.Met then
			table.insert(missing, string.format("%s (%s/%s)", requirement.Text,
				Config.FormatNumber(requirement.Have), Config.FormatNumber(requirement.Need)))
		end
	end
	return false, "🔒 " .. isl.Name .. ": " .. table.concat(missing, " • ")
end

-- arrival spot: center first, then a ring of 8 so players don't stack.
-- M-1: the slot is chosen right before PivotTo with no yield in between, and a
-- just-used slot stays reserved briefly so another player arriving in the next
-- moments (before positions replicate) can't pick the same one.
local RESERVE_SECONDS = 2
local reserved = {} -- [islandId] = { [slot] = { player = Player, untilT = os.clock() deadline } }

local function slotPosition(isl, slot)
	local arrival = isl.ArrivalOverride or Config.GetArrival(isl)
	if slot == 0 then return arrival end
	local a = (slot - 1) * math.pi / 4
	return arrival + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)
end

local function releasePlayer(player)
	for _, slots in pairs(reserved) do
		for slot, r in pairs(slots) do
			if r.player == player then slots[slot] = nil end
		end
	end
end

local function reserve(isl, slot, player)
	releasePlayer(player) -- a player holds at most one reservation
	local key = isl.ReserveKey or isl.Id
	reserved[key] = reserved[key] or {}
	reserved[key][slot] = { player = player, untilT = os.clock() + RESERVE_SECONDS }
end

-- never yields
local function freeSpot(isl, forPlayer)
	local now = os.clock()
	local slots = reserved[isl.ReserveKey or isl.Id]
	for slot = 0, 8 do
		local p = slotPosition(isl, slot)
		local r = slots and slots[slot]
		local taken = r ~= nil and r.player ~= forPlayer and r.untilT > now and r.player.Parent ~= nil
		if not taken then
			for _, other in ipairs(Players:GetPlayers()) do
				local root = other ~= forPlayer and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - p).Magnitude < 3 then taken = true break end
			end
		end
		if not taken then return CFrame.new(p), slot end
	end
	return nil
end

local function setIsland(player, isl)
	player:SetAttribute("CurrentIsland", isl.Id)
	local d = DataService.Get(player)
	if d then d.LastIsland = isl.Id end
end

-- stream the destination in, then move the character (yields)
local function place(player, isl, beforeLanding)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return false, "No character" end
	-- arrival models are Persistent (always on every client); still preload the area
	-- around the island's fixed arrival anchor (this yields)
	local streamed, streamErr = pcall(function() player:RequestStreamAroundAsync(isl.ArrivalOverride or Config.GetArrival(isl), STREAM_TIMEOUT) end)
	if not streamed then
		warn("[Travel] stream request failed for", player.Name, isl.Id, streamErr)
		return false, "Couldn't load " .. isl.Name .. " - try again"
	end
	if player.Parent ~= Players or player.Character ~= char or not root:IsDescendantOf(char) or hum.Health <= 0 then
		return false, "Character changed during travel"
	end
	-- M-1: choose the landing slot and move in one step; nothing from here to PivotTo yields
	local cf, slot = freeSpot(isl, player)
	if not cf then return false, "Arrival is busy. Try again." end
	if beforeLanding then
		local allowed, reason = beforeLanding()
		if not allowed then return false, reason end
	end
	guard:Allow(player, 3, nil, cf.Position, root.Position) -- M0.1 (H1): server-sanctioned teleport to cf
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	char:PivotTo(cf)
	reserve(isl, slot, player)
	return true
end

local function blocked(player)
	if player:GetAttribute("M5Run") then return "Exit your run to travel" end
	if player:GetAttribute("Handoff") then return "Profile is moving servers" end
	if (player:GetAttribute("CombatUntil") or 0) > workspace:GetServerTimeNow() then return "You're in combat!" end
	return nil
end

local function moveFromPortal(player, island, beforeLanding)
	local character = player.Character
	busy[player] = character
	player:SetAttribute("IslandTravelling", true)
	local success, message = place(player, island, function()
		local reason = blocked(player)
		if reason then return false, reason end
		if beforeLanding then return beforeLanding() end
		return true
	end)
	if busy[player] == character then
		busy[player] = nil
		player:SetAttribute("IslandTravelling", nil)
	end
	if success then ArrivalEffect:FireClient(player, island.ArrivalOverride or Config.GetArrival(island)) end
	return success, message
end

-- bypass is only ever passed by the Studio-only DevTravel hook below
local function travel(player, islandId, bypass)
	if player:GetAttribute("M5Run") then return false,"Exit your run to travel" end
	if type(islandId) ~= "string" then return false, "Bad destination" end
	local isl = Config.IslandById[islandId]
	if not isl then return false, "Unknown island" end
	if not player:GetAttribute("Loaded") or not player.Character or spawned[player]~=player.Character then return false, "Loading destination..." end
	if player:GetAttribute("Handoff") then return false,"Profile is moving servers" end
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
		local ok, why = isUnlocked(player, isl, true)
		if not ok then return false, why end
	end
	lastTravel[player] = now
	local ok, why = moveFromPortal(player, isl, function()
		if bypass and bypass.unlock then return true end
		return isUnlocked(player, isl)
	end)
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
	local waypoint = prompt:GetAttribute("M4Waypoint")
	local to = prompt:GetAttribute("TravelTo")
	if not waypoint and type(to) ~= "string" then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local anchor = prompt.Parent
	if not prompt.Enabled or not prompt:IsDescendantOf(workspace) or not root or not anchor or not anchor:IsA("BasePart")
		or (root.Position-anchor.Position).Magnitude > prompt.MaxActivationDistance + 4 then return end
	if waypoint then
		local annex = workspace:FindFirstChild("M4ActiveWorld")
		if not runtime.Crystal or not annex or not prompt:IsDescendantOf(annex) or spawned[player]~=player.Character
			or player:GetAttribute("CurrentIsland")~="CrystalWilds" or busy[player] then return end
		local reason = blocked(player)
		if reason then NotifyRemote:FireClient(player, reason, "death") return end
		local arena = waypoint=="ColossusArena"
		if not arena and waypoint~="CrystalPlaza" then return end
		local island = table.clone(Config.IslandById.CrystalWilds)
		island.ArrivalOverride = arena and Layout.Crystal.Arrival or Layout.Crystal.Return
		island.ReserveKey = waypoint
		local ok, why=moveFromPortal(player,island)
		if not ok then NotifyRemote:FireClient(player,tostring(why),"death") end
		return
	end
	local ok, res = travel(player, to)
	if not ok then NotifyRemote:FireClient(player, tostring(res), "death") end
end)

-- Server-only return channel for M5 arenas. It shares the normal arrival path.
local returnFromRun=Instance.new("BindableFunction")
returnFromRun.Name="M5Return"
returnFromRun.OnInvoke=function(player,origin)
	if not player:GetAttribute("M5Run") or player:GetAttribute("M5RunOrigin")~=origin then return false end
	local island=Config.IslandById[origin] or home()
	if not isUnlocked(player,island) then island=home() end
	local success=place(player,island)
	if success then setIsland(player,island) end
	return success
end
returnFromRun.Parent=game:GetService("ServerStorage")

local launching = {}
local function initializeCharacter(player, char)
	if not player:GetAttribute("Loaded") or player.Character~=char or spawned[player]==char or launching[player]==char then return end
	launching[player]=char
	player:SetAttribute("IslandArrivalPending",true)
	local root=char:WaitForChild("HumanoidRootPart",10)
	if not root or player.Character~=char or launching[player]~=char then
		if launching[player]==char then
			launching[player]=nil
			player:SetAttribute("IslandArrivalPending",nil)
		end
		return
	end
	local d=DataService.Get(player)
	if not d then launching[player]=nil player:SetAttribute("IslandArrivalPending",nil) return end
	local island=Config.IslandById[player:GetAttribute("CurrentIsland") or d.LastIsland or ""] or home()
	if not isUnlocked(player,island) then island=home() end
	busy[player]=char
	local ok=place(player,island)
	if launching[player]~=char then return end
	busy[player],launching[player]=nil,nil
	if player.Character~=char then return end
	if ok then
		spawned[player]=char
		setIsland(player,island)
	end
	player:SetAttribute("IslandArrivalPending",nil)
	if not ok and player.Parent then
		task.delay(1,function() initializeCharacter(player,char) end)
	end
end

local function onPlayer(player)
	local function update()
		local char=player.Character
		if char then task.spawn(initializeCharacter,player,char) end
	end
	player.CharacterAdded:Connect(update)
	player:GetAttributeChangedSignal("Loaded"):Connect(update)
	player.CharacterRemoving:Connect(function()
		releasePlayer(player)
		launching[player],spawned[player],busy[player]=nil,nil,nil
		player:SetAttribute("IslandTravelling",nil)
	end)
	update()
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(p)
	lastTravel[p],busy[p],launching[p],spawned[p]=nil,nil,nil,nil
	releasePlayer(p)
end)

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
