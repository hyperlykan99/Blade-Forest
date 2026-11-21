local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = remotes:WaitForChild("CharacterProgression")
local M = require(ReplicatedStorage:WaitForChild("CharacterProgression"))
local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local palette = {
	Color3.fromRGB(213, 112, 89), Color3.fromRGB(141, 196, 112), Color3.fromRGB(244, 198, 103),
	Color3.fromRGB(118, 202, 219), Color3.fromRGB(193, 150, 230), Color3.fromRGB(130, 180, 228),
}
local ink = Color3.fromRGB(24, 22, 32)
local parchment = Color3.fromRGB(236, 221, 182)
local muted = Color3.fromRGB(136, 128, 145)

local gui = Instance.new("ScreenGui")
gui.Name = "CharacterProgressionUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")

local tile = Instance.new("TextButton")
tile.Name = "CharacterProgressionButton"
tile.Text = "MASTERY"
tile.Size = UDim2.fromOffset(76, 76)
tile.Parent = gui

local panel, body, close = T.Panel(gui, "CharacterProgressionPanel", "MASTERY & TECH TREE", palette[3], 790, 0.86)
panel.Size = UDim2.new(0.90, 0, 0.86, 0)
body.BackgroundColor3 = ink
body.BackgroundTransparency = 0
local function label(parent, name, position, size, text, color, textSize)
	local item = T.Label(parent, {
		Name = name, Position = position, Size = size, Text = text, TextColor3 = color or parchment,
		TextScaled = false, TextSize = textSize or 15, TextWrapped = true,
	})
	return item
end

local hud = Instance.new("Frame")
hud.Name = "MasteryProgress"
hud.Size = UDim2.new(1, 0, 0, 22)
hud.LayoutOrder = 7
hud.BackgroundColor3 = ink
T.AttachToHud(hud, "StatusRail")
T.Corner(hud, 6)
local hudLine = label(hud, "Level", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.78), "", parchment, 12)
local hudFill = Instance.new("Frame")
hudFill.Name = "Fill"
hudFill.Position = UDim2.fromScale(0, 0.82)
hudFill.Size = UDim2.fromScale(0, 0.18)
hudFill.BorderSizePixel = 0
hudFill.BackgroundColor3 = palette[3]
hudFill.Parent = hud

local status = label(body, "Progress", UDim2.fromOffset(8, 2), UDim2.new(1, -16, 0, 27), "", parchment, 15)
local nav = Instance.new("Frame")
nav.Name = "Branches"
nav.Position = UDim2.fromOffset(6, 35)
nav.Size = UDim2.new(1, -12, 0, 62)
nav.BackgroundTransparency = 1
nav.Parent = body
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(1 / 3, -4, 0, 27)
grid.CellPadding = UDim2.fromOffset(4, 4)
grid.FillDirectionMaxCells = 3
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = nav

local canvas = Instance.new("ScrollingFrame")
canvas.Name = "BranchMap"
canvas.Position = UDim2.fromOffset(7, 100)
canvas.Size = UDim2.new(1, -14, 1, -204)
canvas.BackgroundColor3 = Color3.fromRGB(21, 28, 37)
canvas.BorderSizePixel = 0
canvas.ScrollBarThickness = 4
canvas.ScrollingDirection = Enum.ScrollingDirection.Y
canvas.CanvasSize = UDim2.new(0, 0, 0, 280)
canvas.Parent = body
T.Corner(canvas, 12)
local map = Instance.new("Frame")
map.Name = "Constellation"
map.BackgroundTransparency = 1
map.Size = UDim2.new(1, -6, 0, 280)
map.Parent = canvas
local grain = Instance.new("UIGradient")
grain.Color = ColorSequence.new(Color3.fromRGB(41, 48, 67), Color3.fromRGB(17, 22, 30))
grain.Rotation = 90
grain.Parent = canvas

local detail = label(body, "SkillPreview", UDim2.new(0, 8, 1, -103), UDim2.new(1, -16, 0, 58),
	"Select a skill to inspect its effects and requirements.", parchment, 13)
detail.TextXAlignment = Enum.TextXAlignment.Left
local unlock = T.Button(body, { Name = "Unlock", Position = UDim2.new(0, 8, 1, -38),
	Size = UDim2.new(0.57, -12, 0, 32), Text = "Unlock Skill" }, palette[2])
local respec = T.Button(body, { Name = "Respec", Position = UDim2.new(0.57, 0, 1, -38),
	Size = UDim2.new(0.43, -8, 0, 32), Text = "Respec" }, Color3.fromRGB(70, 67, 94))

local data, selected, confirming, busy, message
local branchIndex = 1
local tabs = {}
local ownedColor = Color3.fromRGB(55, 100, 86)
local lockedColor = Color3.fromRGB(49, 49, 62)

local function level()
	return player:GetAttribute("MasteryLevel") or 1
end

local function updateProgress()
	local current = level()
	local xp = player:GetAttribute("MasteryXP") or 0
	local goal = M.XPToNext(current)
	local ratio = goal > 0 and math.clamp(xp / goal, 0, 1) or 1
	hudLine.Text = goal > 0 and string.format("Mastery %d  •  %d%%", current, math.floor(ratio * 100))
		or "Mastery 100  •  MAX"
	hudFill.Size = UDim2.fromScale(ratio, 0.18)
	local xpLabel = goal > 0 and string.format("%d / %d XP", xp, goal) or "Maximum level"
	status.Text = string.format("Mastery %d  •  %s  •  %d Tech Points", current, xpLabel, data and data.TechTree.TP or 0)
end

local function showDetail()
	local node = selected and M.Nodes[selected]
	if data and node then
		local ready, why = M.CanUnlock(data, node)
		local owned = data.TechTree.Nodes[node.Id]
		local canApply = node.Applies(data) and (node.Channel ~= "PetLogs" or #data.EquippedPets > 0)
		local effectStatus = owned and (canApply and "Active" or "Conditional bonus inactive") or (ready and "Available" or why)
		local requirements = {}
		for _, id in ipairs(node.Requires) do table.insert(requirements, M.Nodes[id].Name) end
		local parents = #requirements > 0 and " · After " .. table.concat(requirements, " + ") or ""
		detail.Text = message or string.format("%s%s  •  %s\n%s  ·  %s\nMastery %d · %d TP%s",
			node.Name, node.Capstone and "  ✦" or "", effectStatus, node.Description, node.Condition, node.Level, node.Cost, parents)
		unlock.Text = owned and "Unlocked" or string.format("Unlock • %d TP", node.Cost)
		unlock.Active = not busy and ready
		unlock.BackgroundColor3 = ready and palette[2] or lockedColor
	else
		detail.Text = message or "Select a skill to inspect its effects and requirements."
		unlock.Text = "Select a skill"
		unlock.Active = false
		unlock.BackgroundColor3 = lockedColor
	end
	local spent = data and data.TechTree.Spent or 0
	respec.Active = spent > 0 and not busy
	respec.Text = confirming and string.format("Refund %d TP?", spent) or "Respec"
end

local function center(i)
	return Vector2.new(map.AbsoluteSize.X * (((i - 1) % 3) + 0.5) / 3, 34 + math.floor((i - 1) / 3) * 67)
end
local function draw()
	if not panel.Visible then return end
	map:ClearAllChildren()
	local branch = M.Branches[branchIndex]
	local color = palette[branchIndex]
	for i, tab in ipairs(tabs) do
		tab.BackgroundColor3 = i == branchIndex and palette[i]:Lerp(ink, 0.24) or Color3.fromRGB(54, 50, 61)
	end
	for i, node in ipairs(branch.Nodes) do
		for _, id in ipairs(node.Requires) do
			local parent = tonumber(string.sub(id, -2))
			local a, b = center(parent), center(i)
			local delta = b - a
			local edge = Instance.new("Frame")
			edge.Name = "Prerequisite"
			edge.AnchorPoint = Vector2.new(0.5, 0.5)
			edge.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
			edge.Size = UDim2.fromOffset(delta.Magnitude, 2)
			edge.Rotation = math.deg(math.atan2(delta.Y, delta.X))
			edge.BackgroundColor3 = data and data.TechTree.Nodes[id] and color or muted
			edge.BorderSizePixel = 0
			edge.Parent = map
		end
	end
	for i, node in ipairs(branch.Nodes) do
		local pos = center(i)
		local owned = data and data.TechTree.Nodes[node.Id]
		local ready = data and M.CanUnlock(data, node)
		local fill = owned and ownedColor or ready and color:Lerp(ink, 0.60) or lockedColor
		local card = T.Button(map, {
			Name = node.Id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y),
			Size = UDim2.new(1 / 3, -10, 0, 49), Text = "", ZIndex = 2,
		}, fill)
		T.Stroke(card, node.Id == selected and parchment or owned and color or muted, node.Id == selected and 2 or 1)
		local title = label(card, "Title", UDim2.fromOffset(3, 4), UDim2.new(1, -6, 0, 22), node.Name, parchment, 13)
		title.ZIndex = 3
		local state = owned and "✓ UNLOCKED" or ready and string.format("%d TP", node.Cost) or string.format("LV %d · %d TP", node.Level, node.Cost)
		local hint = label(card, "State", UDim2.fromOffset(2, 27), UDim2.new(1, -4, 0, 15),
			node.Capstone and "✦ " .. state or state, owned and color or parchment, 10)
		hint.ZIndex = 3
		card.Activated:Connect(function()
			selected, confirming, message = node.Id, false, nil
			draw()
		end)
	end
	showDetail()
end

for i, branch in ipairs(M.Branches) do
	local tab = T.Button(nav, { Name = branch.Id, LayoutOrder = i, Text = branch.Icon .. "  " .. branch.Name:gsub(" Mastery", "") }, ink)
	tabs[i] = tab
	tab.Activated:Connect(function()
		branchIndex, selected, confirming, message = i, nil, false, nil
		canvas.CanvasPosition = Vector2.zero
		draw()
	end)
end

local function send(action, value)
	if busy or not data then return end
	busy = true
	local called, ok, result = pcall(remote.InvokeServer, remote, action, value)
	busy = false
	if called and ok then
		data.TechTree = result
		message = nil
	else
		message = called and tostring(result) or "Could not reach the server. Try again."
	end
	updateProgress()
	draw()
end
unlock.Activated:Connect(function()
	if selected and data and M.CanUnlock(data, M.Nodes[selected]) then
		confirming = false
		send("Unlock", selected)
	end
end)
respec.Activated:Connect(function()
	if not data or data.TechTree.Spent <= 0 or busy then return end
	if confirming then
		confirming = false
		send("Respec", data.TechTree.Revision)
	else
		confirming = true
		message = "Refund every unlocked skill and return its Tech Points."
		showDetail()
	end
end)
tile.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then draw() end
end)
close.Activated:Connect(function()
	panel.Visible, confirming, message = false, false, nil
end)
map:GetPropertyChangedSignal("AbsoluteSize"):Connect(draw)
player:GetAttributeChangedSignal("MasteryXP"):Connect(updateProgress)
player:GetAttributeChangedSignal("MasteryLevel"):Connect(updateProgress)
local function receive(snapshot)
	if not snapshot or not snapshot.TechTree or not snapshot.Mastery then return end
	data = snapshot
	updateProgress()
	draw()
end
remotes:WaitForChild("DataSync").OnClientEvent:Connect(receive)
task.spawn(function()
	local ok, snapshot = pcall(function() return remotes:WaitForChild("GetData"):InvokeServer() end)
	if ok and not data then receive(snapshot) end
end)
updateProgress()
