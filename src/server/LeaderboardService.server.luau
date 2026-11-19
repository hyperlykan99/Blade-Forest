-- LeaderboardService: global top lists (OrderedDataStores).
--   Logs (total ever earned), Hours played, Rolls, Rarest pull, Kills, Souls earned
-- Fills the plaza boards and answers the in-game TOP menu.
-- In Studio (no DataStore access) the boards show players in this server.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Leaderboards")

local BOARDS = {
	{ Id = "Logs",   Title = "MOST LOGS",    Get = function(d) return d.Stats.LogsEarned end },
	{ Id = "Rarest", Title = "RAREST PULL",  Get = function(d) return d.Stats.RarestOneIn end },
	{ Id = "Hours",  Title = "MOST HOURS",   Get = function(d) return math.floor(d.Stats.PlaySeconds / 60) end }, -- stored in minutes
	{ Id = "Rolls",  Title = "MOST ROLLS",   Get = function(d) return d.Rolls.Total end },
	{ Id = "Kills",  Title = "MOST KILLS",   Get = function(d) return d.Kills end },
	{ Id = "Souls",  Title = "MOST SOULS",   Get = function(d) return d.Stats.SoulsEarned end },
}
local TOP = 50

local stores = {}
for _, b in ipairs(BOARDS) do
	local ok, s = pcall(function() return DataStoreService:GetOrderedDataStore("LB_v1_" .. b.Id) end)
	if ok then stores[b.Id] = s end
end

local cache = {} -- [boardId] = { {UserId, Name, Value}, ... }
local names = {}
local function nameOf(userId)
	if names[userId] then return names[userId] end
	local p = Players:GetPlayerByUserId(userId)
	if p then names[userId] = p.DisplayName return names[userId] end
	local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	names[userId] = ok and n or ("#" .. userId)
	return names[userId]
end

local function formatValue(id, v)
	if id == "Rarest" then
		if v <= 0 then return "-" end
		-- show the weapon too when we know it
		return Config.FormatOneIn(v)
	end
	if id == "Hours" then return string.format("%.1fh", v / 60) end
	return Config.FormatNumber(v)
end

-- local fallback: everyone in this server
local function localBoard(b)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = DataService.Get(p)
		if d then table.insert(list, { UserId = p.UserId, Name = p.DisplayName, Value = b.Get(d) or 0 }) end
	end
	table.sort(list, function(a, c) return a.Value > c.Value end)
	return list
end

local globalOk = false
local function refreshBoards()
	for _, b in ipairs(BOARDS) do
		local list
		local s = stores[b.Id]
		if s then
			local ok, pages = pcall(function() return s:GetSortedAsync(false, TOP) end)
			if not ok and game:GetService("RunService"):IsStudio() then
				stores = {} -- Studio without API access: use this server's players only
			end
			if ok and pages then
				globalOk = true
				list = {}
				for _, e in ipairs(pages:GetCurrentPage()) do
					local uid = tonumber(e.key)
					if uid then table.insert(list, { UserId = uid, Name = nameOf(uid), Value = e.value }) end
				end
			end
		end
		cache[b.Id] = list or localBoard(b)
	end
	-- plaza boards
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Leaderboards")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			local id = m:GetAttribute("Board")
			local face = m:FindFirstChild("Face", true)
			local rows = face and face:FindFirstChild("BoardGui") and face.BoardGui:FindFirstChild("Rows")
			local list = cache[id]
			if rows and list then
				for i = 1, 10 do
					local row = rows:FindFirstChild("Row" .. i)
					local e = list[i]
					if row then
						row.PlayerName.Text = e and e.Name or "-"
						row.Value.Text = e and formatValue(id, e.Value) or ""
					end
				end
			end
		end
	end
end

local function pushPlayer(p)
	local d = DataService.Get(p)
	if not d or d._NoSave then return end
	for _, b in ipairs(BOARDS) do
		local s = stores[b.Id]
		if not s then return end
		local v = math.floor(b.Get(d) or 0)
		if s and v > 0 then
			pcall(function() s:SetAsync(tostring(p.UserId), v) end)
			task.wait(0.5)
		end
	end
end

Remote.OnServerInvoke = function(player)
	local out = {}
	for _, b in ipairs(BOARDS) do
		local list = {}
		for i, e in ipairs(cache[b.Id] or {}) do
			if i > TOP then break end
			table.insert(list, { Name = e.Name, UserId = e.UserId, Text = formatValue(b.Id, e.Value) })
		end
		table.insert(out, { Id = b.Id, Title = b.Title, List = list })
	end
	return out, globalOk
end

-- save each player's numbers on a rotation + when they leave
Players.PlayerRemoving:Connect(function(p) task.spawn(pushPlayer, p) end)
task.spawn(function()
	while true do
		for _, p in ipairs(Players:GetPlayers()) do
			pushPlayer(p)
			task.wait(4)
		end
		task.wait(60)
	end
end)
task.spawn(function()
	task.wait(5)
	while true do
		refreshBoards()
		task.wait(globalOk and 120 or 15)
	end
end)
