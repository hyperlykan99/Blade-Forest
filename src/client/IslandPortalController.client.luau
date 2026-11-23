local Players = game:GetService("Players")
local Prompts = game:GetService("ProximityPromptService")
local Replicated = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local config = require(Replicated:WaitForChild("BladeConfig"))
local economy = require(Replicated:WaitForChild("Economy"))
local effects = require(script.Parent:WaitForChild("ForestEffects"))
local remotes = Replicated:WaitForChild("Remotes")

local screen = Instance.new("ScreenGui")
screen.Name = "IslandPortalStatus"
screen.ResetOnSpawn = false
screen.DisplayOrder = 7
screen.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0,1)
panel.Position = UDim2.fromScale(.035,.77)
panel.Size = UDim2.new(.66,0,0,0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(34,30,26)
panel.BackgroundTransparency = .08
panel.Visible = false
panel.Parent = screen
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0,10)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(174,137,87)
stroke.Parent = panel
local size = Instance.new("UISizeConstraint")
size.MaxSize = Vector2.new(390,300)
size.Parent = panel
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0,8)
padding.PaddingBottom = UDim.new(0,8)
padding.PaddingLeft = UDim.new(0,12)
padding.PaddingRight = UDim.new(0,12)
padding.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0,3)
layout.Parent = panel

local function label(order, height, color, font)
	local text = Instance.new("TextLabel")
	text.LayoutOrder = order
	text.Size = UDim2.new(1,0,0,0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.BackgroundTransparency = 1
	text.Font = font
	text.TextSize = height
	text.TextWrapped = true
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = panel
	return text
end

local title = label(1,18,Color3.fromRGB(249,222,163),Enum.Font.GothamBold)
local details = label(2,14,Color3.fromRGB(241,238,229),Enum.Font.Gotham)
local action = label(3,14,Color3.fromRGB(249,222,163),Enum.Font.GothamBold)
local shown = {}
local originals = setmetatable({}, {__mode = "k"})
local serial = 0
local data

local function refresh()
	local latest
	local index = 0
	for prompt, order in pairs(shown) do
		if prompt:IsDescendantOf(workspace) and order > index then latest, index = prompt, order end
	end
	if not latest then panel.Visible = false return end

	local id = latest:GetAttribute("TravelTo")
	local island = config.IslandById[id]
	local listed = {}
	local requirementsMet = true
	local powersMet = true
	local persistent = id == config.HomeIsland or data and data.UnlockedIslands and data.UnlockedIslands[id] == true
	local available = island and island.ReleaseState == "available"
	title.Text = island and island.Name or latest.ObjectText
	if available and id ~= config.HomeIsland then
		local power = player:GetAttribute("Power") or 0
		local needed = config.GetIslandRequiredPower(island)
		powersMet = power >= needed
		table.insert(listed, string.format("%s Equipped Power   %d / %d", powersMet and "✓" or "Missing", power, needed))
		local progression, requirements = economy.GateStatus(id, {
			BestPower = player:GetAttribute("BestPower") or 0,
			BossKills = data and data.BossKills,
			TreesByArea = economy.TreesByArea(data and data.Trees),
		})
		requirementsMet = persistent or progression
		for _, requirement in ipairs(requirements) do
			if requirement.Id ~= "power" and requirement.Stage == "active" then
				local state = requirement.Met and "✓" or persistent and "Waived" or "Missing"
				table.insert(listed, string.format("%s %s   %d / %d", state, requirement.Text, requirement.Have, requirement.Need))
			elseif requirement.Id == "power" and not persistent and not requirement.Met and powersMet then
				table.insert(listed, string.format("Missing best owned Power   %d / %d", requirement.Have, requirement.Need))
			end
		end
	end
	local same = player:GetAttribute("CurrentIsland") == id
	local ready = data ~= nil and available and powersMet and requirementsMet and not same
	local status = same and "You are here" or not available and "Unavailable" or not data and "Loading progress…"
		or ready and "Travel" or "Locked"
	latest.ActionText = status
	details.Text = table.concat(listed, "\n")
	details.Visible = #listed > 0
	action.Text = persistent and available and id ~= config.HomeIsland and status .. "  ·  Permanent unlock" or status
	panel.Visible = true
end

Prompts.PromptShown:Connect(function(prompt)
	if typeof(prompt:GetAttribute("TravelTo")) ~= "string" then return end
	serial += 1
	originals[prompt] = prompt.ActionText
	shown[prompt] = serial
	refresh()
end)
Prompts.PromptHidden:Connect(function(prompt)
	if not shown[prompt] then return end
	shown[prompt] = nil
	if originals[prompt] and prompt.Parent then prompt.ActionText = originals[prompt] end
	originals[prompt] = nil
	refresh()
end)
for _, key in ipairs({"Power","BestPower","CurrentIsland"}) do player:GetAttributeChangedSignal(key):Connect(refresh) end
workspace:GetAttributeChangedSignal("M4ColossusReady"):Connect(refresh)
local revisions = 0
remotes:WaitForChild("DataSync").OnClientEvent:Connect(function(snapshot)
	revisions += 1
	data = snapshot
	refresh()
end)
task.spawn(function()
	local ok, snapshot = pcall(function() return remotes:WaitForChild("GetData"):InvokeServer() end)
	if ok and revisions == 0 then data = snapshot refresh() end
end)

remotes:WaitForChild("IslandArrivalEffect").OnClientEvent:Connect(function(point)
	if effects.Quality() < 2 then return end
	local deadline = os.clock() + 2
	repeat
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - point).Magnitude < 16 and effects.Near(point,100) then
			local color = Color3.fromRGB(155,218,206)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = {char}
			params.RespectCanCollide = true
			local floor = workspace:Raycast(point + Vector3.new(0,1,0),Vector3.new(0,-12,0),params)
			effects.Burst("Glint",point,color,8,100)
			effects.Ring(floor and floor.Position or point - Vector3.new(0,4,0),color,6,.4)
			return
		end
		task.wait(.07)
	until os.clock() >= deadline
end)
