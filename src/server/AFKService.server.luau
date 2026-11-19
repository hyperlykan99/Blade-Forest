-- AFKService: anti idle-kick. Roblox disconnects players idle for 20 min;
-- when an AFK player gets close, we move them to a fresh server (same game)
-- and their client resumes AFK mode with the session stats carried over.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent:WaitForChild("DataService"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AFKRejoin = Remotes:FindFirstChild("AFKRejoin") or Instance.new("RemoteEvent")
AFKRejoin.Name = "AFKRejoin"
AFKRejoin.Parent = Remotes

local busy = {}
AFKRejoin.OnServerEvent:Connect(function(player, session)
	if busy[player] or RunService:IsStudio() then return end
	busy[player] = true
	if type(session) ~= "table" then session = {} end
	pcall(DataService.Save, player)
	local opts = Instance.new("TeleportOptions")
	opts:SetTeleportData({ ResumeAFK = true, Session = session })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, opts)
	end)
	if not ok then
		warn("[AFK] rejoin failed:", err)
		busy[player] = nil
	end
end)
Players.PlayerRemoving:Connect(function(p) busy[p] = nil end)
