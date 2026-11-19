-- AreaService: tracks which area each player is in (attribute "CurrentArea")
-- and blocks players from areas their Power doesn't unlock yet.
-- Gates are walls on the client; this is the server-side safety net.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local NotifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local lastSafe = {}

Players.PlayerRemoving:Connect(function(p) lastSafe[p] = nil end)

while true do
	task.wait(0.5)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and player:GetAttribute("Loaded") then
			local areaId = Config.GetAreaAt(root.Position)
			local area = Config.AreaById[areaId]
			local power = player:GetAttribute("Power") or 0
			if power < (area.RequiredPower or 0) then
				-- not allowed here: send back
				local back = lastSafe[player] or CFrame.new(0, 5, 16)
				player.Character:PivotTo(back)
				NotifyRemote:FireClient(player, string.format("🔒 %s needs %d Power", area.Name, area.RequiredPower), "death")
			else
				lastSafe[player] = root.CFrame
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
