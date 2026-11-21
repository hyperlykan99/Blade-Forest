local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent:WaitForChild("DataService"))
local Progression = require(ReplicatedStorage:WaitForChild("CharacterProgression"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = Instance.new("RemoteFunction")
remote.Name = "CharacterProgression"
local last = {}

remote.OnServerInvoke = function(player, action, arg)
	local data = DataService.Get(player)
	if not data or not player:GetAttribute("Loaded") or player:GetAttribute("Handoff") then return false, "Profile loading" end
	local now = os.clock()
	if last[player] and now - last[player] < 0.25 then return false, "Slow down" end
	last[player] = now
	local tree = data.TechTree
	local ok, why
	if action == "Unlock" and type(arg) == "string" and #arg <= 20 then
		ok, why = Progression.Unlock(data, arg)
	elseif action == "Respec" then
		ok, why = Progression.Respec(tree, arg)
	else
		return false, "Unknown skill tree action"
	end
	if not ok then return false, why end
	DataService.RecalcMultipliers(player)
	DataService.Sync(player)
	return true, { TP = tree.TP, Spent = tree.Spent, Revision = tree.Revision, Nodes = table.clone(tree.Nodes) }
end
remote.Parent = remotes
Players.PlayerRemoving:Connect(function(player) last[player] = nil end)
