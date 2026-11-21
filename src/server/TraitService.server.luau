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

local rng = Random.new()
local pending = {}  -- [player] = traitId waiting for keep/replace
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

local function setTrait(player, id)
	local d = DataService.Get(player)
	d.Trait = id
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
TraitAction.OnServerInvoke = function(player, action, arg)
	local d = DataService.Get(player)
	if not d then return false, "Loading..." end

	if action == "Roll" then
		if os.clock() - (lastRoll[player] or 0) < 0.4 then return false, "Slow down" end
		if d.TraitLocked then return false, "Your trait is locked 🔒 - unlock it to roll" end
		local crate = (arg == "Souls" or arg == "Free") and arg or "Logs"
		if crate == "Free" then
			local allowPaid = Policy.FreeCrateAccess(player)
			local ok, why = DataService.SpendCrate(player, allowPaid)
			if not ok then
				if why == "restricted" then
					return false, "Only Trait Crates earned in-game can be opened on your account."
				end
				return false, "No free crates left"
			end
		elseif crate == "Souls" then
			if not DataService.SpendSouls(player, Config.SoulCrateCost) then
				return false, string.format("Need %d Souls", Config.SoulCrateCost)
			end
		else
			local allowed, msg = Policy.CheckCurrencySpend(player, "TraitCrate_Logs")
			if not allowed then return false, msg end
			local cost = Config.GetTraitCrateCost(player) -- M1: progression tier
			if not DataService.SpendCoins(player, cost) then
				return false, string.format("Need %s Logs", Config.FormatNumber(cost))
			end
		end
		lastRoll[player] = os.clock()
		local lucky = player:GetAttribute("Pass_LuckyCrates") == true and Policy.AllowPaidOddsModifier(player)
		local id = roll(crate == "Souls" and "Souls" or "Logs", lucky)
		DataService.Sync(player)
		if not d.Trait then
			pending[player] = nil
			setTrait(player, id)
			return true, { Result = id, Applied = true }
		end
		if id == d.Trait then
			pending[player] = nil
			return true, { Result = id, Same = true }
		end
		pending[player] = id
		return true, { Result = id, Current = d.Trait, Pending = true }

	elseif action == "Choose" then
		local id = pending[player]
		pending[player] = nil
		if id and arg == true then
			setTrait(player, id)
			return true, { Trait = id }
		end
		return true, { Trait = d.Trait }

	elseif action == "Lock" then
		d.TraitLocked = arg == true
		DataService.Sync(player)
		return true, { Locked = d.TraitLocked }
	end
	return false, "?"
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
	pending[p] = nil
	lastRoll[p] = nil
end)
