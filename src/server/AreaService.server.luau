-- AreaService: tracks which area each player is in (attribute "CurrentArea")
-- and blocks players from areas their Power doesn't unlock yet.
-- Gates are walls on the client; this is the server-side safety net.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(script.Parent:WaitForChild("M4WorldRuntime"))
local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local guard = require(script.Parent:WaitForChild("MovementGuard")).shared -- M0.1: sanctioned push-back
local NotifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local lastSafe = {}

Players.PlayerRemoving:Connect(function(p) lastSafe[p] = nil end)

while true do
	task.wait(0.5)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and player:GetAttribute("Loaded") and player:GetAttribute("CurrentIsland") and not player:GetAttribute("IslandArrivalPending") then
			local areaId = Config.GetAreaAt(root.Position)
			local area = Config.AreaById[areaId]
			local power = player:GetAttribute("Power") or 0
			-- M1.6: a legacy area that belongs to a later island (Crystal Canyon wedge,
			-- Frost Peaks annex on the Timber Haven map) also needs that island's gate
			local gateIsland = Config.AreaIsland[areaId]
			local gateOk, gateMsg = true, nil
			if gateIsland and gateIsland ~= Config.HomeIsland and power >= (area.RequiredPower or 0) then
				gateOk, gateMsg = DataService.TryUnlockIsland(player, gateIsland)
			end
			if power < (area.RequiredPower or 0) or not gateOk then
				-- not allowed here: send back
				local isl = Config.IslandById[player:GetAttribute("CurrentIsland")] or Config.IslandById.TimberHaven
				local safe=lastSafe[player]
				local back = (safe and safe.Island==isl.Id and safe.Frame) or CFrame.new(Config.GetArrival(isl))
				guard:Allow(player, 2, nil, back.Position, player.Character:GetPivot().Position) -- M0.1 (H1): server-sanctioned push-back
				player.Character:PivotTo(back)
				NotifyRemote:FireClient(player, gateMsg or string.format("🔒 %s needs %d Power", area.Name, area.RequiredPower), "death")
			else
				lastSafe[player] = { Island=player:GetAttribute("CurrentIsland"), Frame=root.CFrame }
				if player:GetAttribute("CurrentArea") ~= areaId then
					player:SetAttribute("CurrentArea", areaId)
					local d = DataService.Get(player)
					if d and Config.AreaById[d.BestArea] and area.Order > Config.AreaById[d.BestArea].Order then
						d.BestArea = areaId
						NotifyRemote:FireClient(player, "🌲 Entered " .. area.Name .. " for the first time!", "kill")
					end
				end
			end
		end
	end
end
