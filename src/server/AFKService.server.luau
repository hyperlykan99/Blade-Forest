-- AFKService: anti idle-kick. Roblox disconnects players idle for 20 min;
-- when an AFK player gets close, we move them to a fresh server (same game)
-- and their client resumes AFK mode with the session stats carried over.
-- M0.1 (M1): the hop is a confirmed lock handoff (see AFKHandoff): the profile
-- is saved and its session lock RELEASED before the teleport, rewards stop
-- during the handoff, a failed teleport re-acquires the profile, and the
-- client-supplied session stats are sanitised and used for display only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AFKHandoff = require(script.Parent:WaitForChild("AFKHandoff"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AFKRejoin = Remotes:FindFirstChild("AFKRejoin") or Instance.new("RemoteEvent")
AFKRejoin.Name = "AFKRejoin"
AFKRejoin.Parent = Remotes

local busy = {}
local joinedAt = {}
local lastHop = {}

local function teleport(player, data)
	local opts = Instance.new("TeleportOptions")
	opts:SetTeleportData(data)
	return pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, opts)
	end)
end

local deps = {
	now = os.clock,
	joinedAt = function(p) return joinedAt[p] end,
	lastHop = function(p) return lastHop[p] end,
	setLastHop = function(p, t) lastHop[p] = t end,
	release = DataService.HandoffRelease,
	teleport = teleport,
	resume = DataService.ResumeAfterHandoff,
	log = function(msg) warn("[AFK]", msg) end,
}

AFKRejoin.OnServerEvent:Connect(function(player, session)
	if busy[player] or RunService:IsStudio() then return end -- teleports do not work in Studio
	busy[player] = true
	local clean = AFKHandoff.Sanitize(session, Config.WeaponById, os.time())
	local status = AFKHandoff.Run(player, clean, deps)
	if status ~= "teleported" then busy[player] = nil end
end)

-- a teleport can also fail after TeleportAsync returned (e.g. the target server
-- could not be reached): take the profile back if we released it for the hop
TeleportService.TeleportInitFailed:Connect(function(player, result, err)
	if player:GetAttribute("Handoff") then
		warn("[AFK] teleport init failed:", tostring(result), tostring(err), "- re-acquiring the profile")
		DataService.ResumeAfterHandoff(player)
	end
	busy[player] = nil
end)

Players.PlayerAdded:Connect(function(p) joinedAt[p] = os.clock() end)
for _, p in ipairs(Players:GetPlayers()) do joinedAt[p] = joinedAt[p] or os.clock() end
Players.PlayerRemoving:Connect(function(p) busy[p], joinedAt[p], lastHop[p] = nil, nil, nil end)
