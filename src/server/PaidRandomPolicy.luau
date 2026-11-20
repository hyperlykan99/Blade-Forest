-- PaidRandomPolicy (M0-D): server-side eligibility for paid random items.
--
-- Roblox policy (create.roblox.com/docs/production/monetization/paid-random-items,
-- PolicyService.ArePaidRandomItemsRestricted): a restricted player must not
-- interact with paid random item generators, whether paid with Robux directly
-- or with in-experience currency bought with Robux.
--
-- Pathway classification used here:
--   TraitCrate_Logs / PetEgg_Logs : PAID only when Logs can be bought with Robux
--                                   (any log-pack developer product has a real ProductId)
--   TraitCrate_Souls              : FREE (Souls are never sold for Robux)
--   Free crate, origin Earned     : FREE (quests, achievements, gifts, codes, Treant)
--   Free crate, origin Paid       : PAID (Robux crate products, Starter Pack, VIP daily)
--   Free crate, origin Legacy     : UNKNOWN origin (owned before v4) -> treated as PAID
--   Lucky Crates pass             : PAID odds modifier -> not applied for restricted players
--   Weapon rolls                  : free action; paid Luck boosts are odds modifiers.
--                                   Not changed in M0 (M1 scope); see M0 results doc.
--
-- If eligibility cannot be established, the player is treated as RESTRICTED
-- (fail closed) and the lookup is retried later.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))

local Policy = {}
Policy.CACHE_OK = 600      -- seconds a successful lookup is reused
Policy.CACHE_FAIL = 60     -- seconds before retrying a failed lookup

local cache = {} -- [player] = { restricted = bool, known = bool, at = os.clock() }

-- test hooks (Studio only): attributes on the player
--   M0_TestRestricted = true/false  -> overrides the lookup
--   M0_TestPolicyFail = true        -> simulates a PolicyService failure
local function studioOverride(player)
	if not RunService:IsStudio() then return nil end
	if player:GetAttribute("M0_TestPolicyFail") then return "fail" end
	local v = player:GetAttribute("M0_TestRestricted")
	if v ~= nil then return v == true end
	return nil
end

-- Returns restricted (bool), known (bool)
function Policy.IsRestricted(player)
	local o = studioOverride(player)
	if o == "fail" then return true, false end
	if o ~= nil then return o, true end
	local c = cache[player]
	if c and os.clock() - c.at < (c.known and Policy.CACHE_OK or Policy.CACHE_FAIL) then
		return c.restricted, c.known
	end
	local ok, info
	for attempt = 1, 2 do
		ok, info = pcall(function() return PolicyService:GetPolicyInfoForPlayerAsync(player) end)
		if ok and type(info) == "table" then break end
		if attempt < 2 then task.wait(0.5) end
	end
	if ok and type(info) == "table" and type(info.ArePaidRandomItemsRestricted) == "boolean" then
		cache[player] = { restricted = info.ArePaidRandomItemsRestricted, known = true, at = os.clock() }
		return info.ArePaidRandomItemsRestricted, true
	end
	cache[player] = { restricted = true, known = false, at = os.clock() }
	return true, false
end

-- true once any Logs pack can actually be bought with Robux
function Policy.LogsArePaidCurrency()
	for _, p in ipairs(Config.DevProducts) do
		if p.PackMult and p.ProductId and p.ProductId ~= 0 then return true end
	end
	return false
end

local MSG_RESTRICTED = "Paid random items aren't available for your account."
local MSG_UNKNOWN = "Couldn't check item eligibility right now. Please try again in a minute."

-- Gate for spending a currency on a random reward.
-- pathway: "TraitCrate_Logs" | "PetEgg_Logs" | "TraitCrate_Souls"
-- Returns ok, message
function Policy.CheckCurrencySpend(player, pathway)
	local paid = false
	if pathway == "TraitCrate_Logs" or pathway == "PetEgg_Logs" then
		paid = Policy.LogsArePaidCurrency()
	end
	if not paid then return true end
	local restricted, known = Policy.IsRestricted(player)
	if restricted then return false, known and MSG_RESTRICTED or MSG_UNKNOWN end
	return true
end

-- Which free-crate origins this player may open. Returns allowPaidOrigins, message-if-none
function Policy.FreeCrateAccess(player)
	local restricted, known = Policy.IsRestricted(player)
	if restricted then return false, known and MSG_RESTRICTED or MSG_UNKNOWN end
	return true
end

-- Whether a paid odds modifier (Lucky Crates pass) may be applied.
function Policy.AllowPaidOddsModifier(player)
	local restricted = Policy.IsRestricted(player)
	return not restricted
end

Players.PlayerRemoving:Connect(function(p) cache[p] = nil end)

return Policy
