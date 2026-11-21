-- TraitService: Trait Crates (Logs or Souls) -> a title over your head and a
-- permanent Logs multiplier. If you already have a trait you choose to keep
-- the old one or take the new one. Locking your trait blocks rolling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyRemote = Remotes:WaitForChild("Notify")
local DataService = require(script.Parent:WaitForChild("DataService"))
local Policy = require(script.Parent:WaitForChild("PaidRandomPolicy")) -- M0-D server-side eligibility

local TraitAction = Remotes:FindFirstChild("TraitAction") or Instance.new("RemoteFunction")
TraitAction.Name = "TraitAction"
TraitAction.Parent = Remotes

local M = require(ReplicatedStorage:WaitForChild("CharacterProgression"))
local rng = Random.new()
local lastRoll = {}

--------------------------------------------------------------------
-- Title over the head (billboard is created by PvPService)
--------------------------------------------------------------------
local function applyTitle(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local bb = head and head:WaitForChild("Overhead", 5)
	local title = bb and bb:FindFirstChild("Title")
	if not title then return end
	local d = DataService.Get(player)
	local t = d and d.Trait and Config.TraitById[d.Trait]
	if not t then
		title.Visible = false
		return
	end
	title.Visible = true
	title.Text = t.Name
	title.TextColor3 = t.Color
	local grad = title:FindFirstChild("Rainbow")
	if t.Rainbow then
		title.TextColor3 = Color3.new(1, 1, 1)
		if not grad then
			grad = Instance.new("UIGradient")
			grad.Name = "Rainbow"
			grad.Color = Config.RainbowSequence
			grad.Parent = title
		end
	elseif grad then
		grad:Destroy()
	end
end

local function applyTrait(player)
	local d = DataService.Get(player)
	local t = d and d.Trait and Config.TraitById[d.Trait]
	player:SetAttribute("Trait", t and t.Id or nil)
	player:SetAttribute("TraitMult", t and t.Mult or 1)
	DataService.RecalcMultipliers(player)
	task.spawn(applyTitle, player)
end

local function setTrait(player, d, slot, id)
	if slot == 1 then d.Trait = id else d.Trait2 = id end
	applyTrait(player)
	DataService.Sync(player)
	local t = Config.TraitById[id]
	if t.Mult >= 2.5 then
		NotifyRemote:FireAllClients(string.format("%s got the %s trait! (x%s Logs)", player.DisplayName, t.Name, tostring(t.Mult)), t.Rainbow and "rare_Secret" or "rare_Mythic")
	end
end

local function roll(crate, lucky)
	local odds = Config.GetTraitOdds(crate, lucky)
	local r = rng:NextNumber() * 100
	for _, o in ipairs(odds) do
		r -= o.Chance
		if r <= 0 and o.Chance > 0 then return o.Trait.Id end
	end
	return odds[#odds].Trait.Id
end

--------------------------------------------------------------------
-- Remote: Roll(crate) / Choose(keepNew) / Lock(on)
--------------------------------------------------------------------
local busy = {}
local function perform(player, action, arg, slot)
	local d = DataService.Get(player)
	if not d or not player:GetAttribute("Loaded") or player:GetAttribute("Handoff") then return false, "Loading..." end
	if action == "Odds" then
		return true, player:GetAttribute("Pass_LuckyCrates") == true and Policy.AllowPaidOddsModifier(player)
	end
	slot = slot == nil and 1 or slot
	if slot ~= 1 and slot ~= 2 then return false, "Unknown slot" end
	if slot == 2 and d.UnlockedIslands.FrostboundReach ~= true then return false, "Unlock Frostbound Reach first" end
	local current, locked = M.Trait(d, slot)
	local other = M.Trait(d, 3 - slot)
	local offer = d.TraitOffer
	local hasOffer = offer.Slot == 1 or offer.Slot == 2
	if action == "Pending" then
		local previous = M.Trait(d, offer.Slot)
		if hasOffer and Config.TraitById[offer.Id] and Config.TraitById[previous] then
			return true, { Slot = offer.Slot, Result = offer.Id, Current = previous, Pending = true }
		end
		return true
	end

	if action == "Roll" then
		if arg ~= "Souls" and arg ~= "Free" and arg ~= "Logs" then return false, "Unknown crate" end
		if os.clock() - (lastRoll[player] or -1) < 0.4 then return false, "Slow down" end
		if locked then return false, "Unlock this trait slot before rolling" end
		if hasOffer then
			local previous = M.Trait(d, offer.Slot)
			if Config.TraitById[offer.Id] and Config.TraitById[previous] then
				return true, { Slot = offer.Slot, Result = offer.Id, Current = previous, Pending = true }
			end
			d.TraitOffer = {}
		end
		lastRoll[player] = os.clock()

		-- Eligibility may yield. Recheck the authoritative profile before currency changes.
		local lucky = player:GetAttribute("Pass_LuckyCrates") == true and Policy.AllowPaidOddsModifier(player)
		local allowPaid
		local allowed, msg = true
		if arg == "Free" then
			allowPaid = Policy.FreeCrateAccess(player)
		else
			allowed, msg = Policy.CheckCurrencySpend(player, "TraitCrate_" .. arg)
		end
		if not allowed then return false, msg end
		if DataService.Get(player) ~= d or not player.Parent or player:GetAttribute("Handoff") then return false, "Profile unavailable" end
		if arg == "Free" then
			local ok, why = DataService.SpendCrate(player, allowPaid)
			if not ok then
				return false, why == "restricted" and "Only earned Trait Crates can be opened on your account." or "No free crates left"
			end
		elseif arg == "Souls" then
			if not DataService.SpendSouls(player, Config.SoulCrateCost) then
				return false, string.format("Need %d Souls", Config.SoulCrateCost)
			end
		else
			local cost = Config.GetTraitCrateCost(player)
			if not DataService.SpendCoins(player, cost) then
				return false, string.format("Need %s Logs", Config.FormatNumber(cost))
			end
		end
		local id = roll(arg == "Souls" and "Souls" or "Logs", lucky)
		DataService.Sync(player)
		if id == current or id == other then
			return true, { Result = id, Same = true, OtherSlot = id == other }
		end
		if not current then
			setTrait(player, d, slot, id)
			return true, { Result = id, Applied = true }
		end
		d.TraitOffer = { Slot = slot, Id = id }
		return true, { Result = id, Current = current, Pending = true }
	elseif action == "Choose" and type(arg) == "boolean" then
		if not hasOffer or offer.Slot ~= slot then return false, "No pending roll for this slot" end
		d.TraitOffer = {}
		DataService.Sync(player)
		if arg and not locked and offer.Id ~= other then
			setTrait(player, d, slot, offer.Id)
			return true, { Trait = offer.Id }
		end
		return true, { Trait = current }
	elseif action == "Lock" and type(arg) == "boolean" then
		if hasOffer then return false, "Choose whether to keep your roll first" end
		if slot == 1 then d.TraitLocked = arg else d.Trait2Locked = arg end
		DataService.Sync(player)
		return true, { Locked = arg }
	end
	return false, "Unknown trait action"
end

TraitAction.OnServerInvoke = function(player, action, arg, slot)
	if busy[player] then return false, "Trait request in progress" end
	busy[player] = true
	local called, ok, result = pcall(perform, player, action, arg, slot)
	busy[player] = nil
	if not called then
		warn("[TraitService] " .. tostring(ok))
		return false, "Trait request failed"
	end
	return ok, result
end

--------------------------------------------------------------------
-- Join / respawn
--------------------------------------------------------------------
local function onPlayer(player)
	task.spawn(function()
		while player.Parent and not player:GetAttribute("Loaded") do task.wait(0.2) end
		if player.Parent then applyTrait(player) end
	end)
	player.CharacterAdded:Connect(function()
		if player:GetAttribute("Loaded") then task.spawn(applyTitle, player) end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(p)
	lastRoll[p] = nil
end)
