-- Temporary fixture for private Studio tests. Keep outside the place's installed source.
local Run = game:GetService("RunService")
if not Run:IsStudio() or game.PlaceId ~= 103379930563763 or game.GameId ~= 10777797608
	or workspace:GetAttribute("BladeForestQAProfile") ~= true
	or workspace:GetAttribute("BladeForestQASuite") ~= "WorldTravel" then return end

local players = game:GetService("Players")
local storage = game:GetService("ServerStorage")
local config = require(game.ReplicatedStorage.BladeConfig)
local dataService = require(script.Parent.DataService)
local guard = require(script.Parent.MovementGuard).shared
local runs = require(script.Parent.M5Runs)
local bridge = Instance.new("BindableFunction")
bridge.Name = "WorldTravelFixture"

local function replaceChops(data, areas, tree, count)
	for id in pairs(data.Trees) do
		local meta = config.TreeTypes[id]
		if meta and areas[meta.Area] then data.Trees[id] = nil end
	end
	data.Trees[tree] = count
end

bridge.OnInvoke = function(player, input)
	assert(player.Parent == players and player:GetAttribute("QASandbox") and player:GetAttribute("Loaded"))
	local data = assert(dataService.Get(player))
	if input.weapon then
		dataService.AddWeapon(player,input.weapon)
		dataService.Equip(player,input.weapon)
	end
	if input.timber then
		replaceChops(data,{StarterGrove=true,PineForest=true},"Grove_Common",input.timber)
	end
	if input.crystal then replaceChops(data,{CrystalCanyon=true},"Crystal_Common",input.crystal) end
	if input.king then data.BossKills.BladeKing = input.king end
	if input.colossus then data.BossKills.CrystalColossus = input.colossus end
	if input.power then player:SetAttribute("Power",input.power) end
	if input.combat ~= nil then player:SetAttribute("CombatUntil",input.combat and workspace:GetServerTimeNow()+120 or nil) end
	if input.position then
		local at = Vector3.new(table.unpack(input.position))
		local root = player.Character.HumanoidRootPart
		guard:Allow(player,2,nil,at,root.Position)
		root.AssemblyLinearVelocity = Vector3.zero
		player.Character:PivotTo(CFrame.new(at))
	end
	local runOk, runReason
	if input.enter then runOk, runReason = runs.Enter(player,input.enter) end
	if input.exit then runOk, runReason = runs.Exit(player) end
	dataService.Sync(player)
	local saved
	if input.save then saved = dataService.SaveNow(player,false) end
	return {
		island=player:GetAttribute("CurrentIsland"), last=data.LastIsland,
		weapon=data.Equipped, equippedPower=player:GetAttribute("Power"), bestPower=dataService.BestPower(data),
		unlocked=table.clone(data.UnlockedIslands), colossus=workspace:GetAttribute("M4ColossusReady"), dataSaved=saved,
		run=player:GetAttribute("M5Run"), runOk=runOk, runReason=runReason,
		position=tostring(player.Character:GetPivot().Position),
	}
end
bridge.Parent = storage
