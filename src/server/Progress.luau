-- Progress: quest + stat counters, and reward granting shared by
-- quests, daily login, playtime gifts and codes.
--   Progress.Add(player, stat, n)   stat = Trees | Rolls | NPCs | Minutes | RarePull | Boss
--   Progress.Grant(player, reward)  reward = { Kind = Logs|Souls|Crate|Boost, ... }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local NotifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local P = {}

local function dayKey() return math.floor(os.time() / 86400) end
local function weekKey() return math.floor((os.time() / 86400 + 3) / 7) end -- weeks start Monday

-- pick 3 quests from a pool, deterministic per player + period
local function pick(pool, seed, n)
	local rng = Random.new(seed)
	local idx = {}
	for i = 1, #pool do idx[i] = i end
	for i = #idx, 2, -1 do
		local j = rng:NextInteger(1, i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(n, #idx) do
		local q = pool[idx[i]]
		out[q.Id] = { Progress = 0, Claimed = false }
	end
	return out
end

-- make sure the player's quests are for the current day/week
function P.Refresh(player)
	local d = DataService.Get(player)
	if not d then return end
	local q = d.Quests
	if q.DayKey ~= dayKey() then
		q.DayKey = dayKey()
		q.Daily = pick(Config.DailyQuests, player.UserId + q.DayKey * 7, 3)
	end
	if q.WeekKey ~= weekKey() then
		q.WeekKey = weekKey()
		q.Weekly = pick(Config.WeeklyQuests, player.UserId * 3 + q.WeekKey * 13, 3)
	end
end

local byId = {}
for _, q in ipairs(Config.DailyQuests) do byId[q.Id] = q end
for _, q in ipairs(Config.WeeklyQuests) do byId[q.Id] = q end
P.QuestById = byId

function P.Add(player, stat, n)
	local d = DataService.Get(player)
	if not d then return end
	n = n or 1
	if stat == "Trees" then d.Stats.TreesChopped += n end
	P.Refresh(player)
	local changed = false
	for _, set in ipairs({ d.Quests.Daily, d.Quests.Weekly }) do
		for id, st in pairs(set) do
			local q = byId[id]
			if q and q.Stat == stat and not st.Claimed and st.Progress < q.Goal then
				st.Progress = math.min(q.Goal, st.Progress + n)
				changed = true
				if st.Progress >= q.Goal then
					NotifyRemote:FireClient(player, "Quest complete: " .. string.format(q.Text, Config.FormatNumber(q.Goal)) .. " - claim it in QUESTS!", "kill")
					player:SetAttribute("QuestReady", true)
				end
			end
		end
	end
	if changed then DataService.Sync(player) end
end

-- Tree index: count every chop per tree type; first chop = new discovery
function P.TreeChopped(player, typeId, mutId)
	local d = DataService.Get(player)
	local tt = typeId and Config.TreeTypes[typeId]
	if not d or not tt then return end
	if mutId and Config.MutationById[mutId] then
		d.MutationsFound = d.MutationsFound or {}
		local firstMut = not d.MutationsFound[mutId]
		d.MutationsFound[mutId] = (d.MutationsFound[mutId] or 0) + 1
		if firstMut then
			local m = Config.MutationById[mutId]
			NotifyRemote:FireClient(player, string.format("%s First %s mutation chopped! (x%d Logs trees)", m.Icon, m.Name, m.LogMult), "rare_Legendary")
			DataService.Sync(player)
		end
	end
	local first = not d.Trees[typeId]
	d.Trees[typeId] = (d.Trees[typeId] or 0) + 1
	if first then
		NotifyRemote:FireClient(player, string.format("🌳 New tree discovered: %s! Claim your reward in INDEX", tt.Name), "rare_" .. tt.Rarity)
		DataService.RecalcMultipliers(player) -- tree index completion bonus
		DataService.Sync(player)
	end
end

function P.Grant(player, rw, why)
	local d = DataService.Get(player)
	if not d or not rw then return end
	if rw.Kind == "Logs" then
		DataService.AddCoins(player, Config.GetTraitCrateCost(d.BestArea) * rw.Mult, nil, true)
	elseif rw.Kind == "Souls" then
		DataService.AddSouls(player, rw.Amount)
	elseif rw.Kind == "Crate" then
		d.FreeCrates = (d.FreeCrates or 0) + rw.Amount
	elseif rw.Kind == "Boost" then
		DataService.AddBoost(player, rw.Boost, rw.Seconds)
	end
	DataService.Sync(player)
	NotifyRemote:FireClient(player, (why and (why .. ": ") or "") .. "+" .. Config.RewardText(rw, d.BestArea), "rare_Epic")
end

return P
