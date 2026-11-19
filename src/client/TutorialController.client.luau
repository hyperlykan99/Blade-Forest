-- TutorialController: first-time guide (chop -> upgrade -> roll -> auto).
-- A beam points to the nearest tree, a bouncing arrow points at buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local C = T.Color
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Meta = Remotes:WaitForChild("Meta")
local GetData = Remotes:WaitForChild("GetData")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local Breakables = workspace:WaitForChild("Breakables")

while not player:GetAttribute("Loaded") do task.wait(0.3) end
local ok, data = pcall(function() return GetData:InvokeServer() end)
if not ok or not data or data.TutorialDone then return end

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = pg

local box = Instance.new("Frame")
box.Name = "Guide"
box.AnchorPoint = Vector2.new(0.5, 0)
box.BackgroundColor3 = C.WoodDark
box.BorderSizePixel = 0
box.Parent = gui
T.Corner(box, 7)
T.Stroke(box, C.WoodLight, 1)
local stepLbl = T.Label(box, {
	Position = UDim2.fromOffset(7, 2), Size = UDim2.new(1, -61, 0, 13), Text = "",
	TextSize = 11, TextScaled = false, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left,
})
local text = T.Label(box, {
	Position = UDim2.fromOffset(7, 16), Size = UDim2.new(1, -61, 1, -18),
	Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
})
text:SetAttribute("NoTheme", true)
local limit = Instance.new("UITextSizeConstraint")
limit.MaxTextSize = 13
limit.Parent = text
local skip = T.Button(box, {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0),
	Size = UDim2.fromOffset(46, 44), Text = "SKIP", TextSize = 13, TextScaled = false,
}, C.Grey)
local skipPadding = skip:FindFirstChildOfClass("UIPadding")
skipPadding.PaddingLeft = UDim.new(0, 2)
skipPadding.PaddingRight = UDim.new(0, 2)
skip.TextWrapped = false
local gameUI = pg:WaitForChild("GameUI", math.huge)
local rail = gameUI:WaitForChild("StatusRail")
local feed = gameUI:WaitForChild("Toasts")
local function fitGuide()
	local w = gui.AbsoluteSize.X
	local narrow = w < 640
	local guideWidth = narrow and math.min(w - 100, 246) or math.clamp(w - 450, 180, 284)
	box.Size = UDim2.fromOffset(math.max(146, guideWidth), 54)
	local y = 52
	if narrow then
		local statusBottom = rail.Position.Y.Offset + rail.AbsoluteSize.Y
		local feedBottom = feed.Position.Y.Offset + feed.AbsoluteSize.Y
		y = math.max(60, statusBottom + 6, feedBottom + 6)
	end
	box.Position = UDim2.new(0.5, 0, 0, y)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGuide)
rail:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGuide)
feed:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGuide)
fitGuide()
local arrow = T.Label(gui, { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(29, 29), Text = "👇", Visible = false })

-- beam to the nearest tree
local att0 = Instance.new("Attachment")
local att1 = Instance.new("Attachment")
local beam = Instance.new("Beam")
beam.Attachment0 = att0
beam.Attachment1 = att1
beam.Width0, beam.Width1 = 1.2, 1.2
beam.Color = ColorSequence.new(C.Gold)
beam.LightEmission = 1
beam.Texture = "rbxassetid://446111271"
beam.TextureSpeed = 2
beam.TextureLength = 3
beam.FaceCamera = true
beam.Enabled = false
beam.Parent = workspace.Terrain
att1.Parent = workspace.Terrain

local function findButton(name)
	for _, d in ipairs(pg:GetDescendants()) do
		if d.Name == name and d:IsA("GuiButton") and d.Visible then
			local dock = d.Parent
			if (dock.Name == "LeftDock" or dock.Name == "RightDock") and not dock.Visible then
				return dock.Parent:FindFirstChild(dock.Name == "LeftDock" and "HideLeft" or "HideRight")
			end
			return d
		end
	end
end

local STEPS = {
	{ Text = "Walk into a tree - your spinning blades chop it! Follow the golden line.", Beam = true,
		Done = function(s) local ls = player:FindFirstChild("leaderstats") return ls and ls.Logs.Value > (s.StartLogs or 0) end },
	{ Text = "Nice! Open UPGRADE and buy your first upgrade.", Button = "UpgradesButton",
		Done = function()
			for _, u in ipairs(Config.Upgrades) do if (player:GetAttribute("Lvl_" .. u.Id) or 0) > 0 then return true end end
			return false
		end },
	{ Text = "Press ROLL to get a new weapon. Rolling is FREE - rarer weapons are stronger!", Button = "RollButton",
		Done = function(s) return s.Rolled end },
	{ Text = "Tap AUTO and your avatar chops trees by itself!", Button = "AutoButton",
		Done = function() return player:GetAttribute("AutoChop") == true end },
	{ Text = "You're ready! Tip: AFK mode rolls and chops while you're away. Have fun!", Final = true },
}

local state = { StartLogs = 0, Rolled = false }
task.spawn(function()
	local rc = player.PlayerScripts:WaitForChild("RollController", 10)
	local ev = rc and rc:WaitForChild("RollResult", 10)
	if ev then ev.Event:Connect(function() state.Rolled = true end) end
end)

local finished = false
local function finish()
	if finished then return end
	finished = true
	pcall(function() Meta:InvokeServer("TutorialDone") end)
	beam:Destroy()
	att1:Destroy()
	gui:Destroy()
end
skip.Activated:Connect(finish)

local step = 1
local function nearestTree()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local best, bd
	for _, t in ipairs(Breakables:GetChildren()) do
		local pp = t.PrimaryPart
		if pp and (t:GetAttribute("Strength") or 0) <= (player:GetAttribute("Power") or 0) then
			local d = (pp.Position - root.Position).Magnitude
			if d < 120 and (not bd or d < bd) then best, bd = t, d end
		end
	end
	return best, root
end

local ls = player:WaitForChild("leaderstats")
state.StartLogs = ls:WaitForChild("Logs").Value
local t0 = os.clock()
local lastScan = 0
RunService.RenderStepped:Connect(function()
	if finished then return end
	local s = STEPS[step]
	stepLbl.Text = s.Final and "TUTORIAL COMPLETE" or ("STEP " .. step .. " / " .. (#STEPS - 1))
	text.Text = s.Text
	skip.Text = s.Final and "OK" or "SKIP"
	-- beam
	if s.Beam then
		if os.clock() - lastScan > 0.5 then
			lastScan = os.clock()
			local tree, root = nearestTree()
			if tree and root then
				att0.Parent = root
				att1.WorldPosition = tree.PrimaryPart.Position + Vector3.new(0, 2, 0)
				beam.Enabled = true
			end
		end
	else
		beam.Enabled = false
	end
	-- arrow
	local btn = s.Button and findButton(s.Button)
	if btn then
		arrow.Visible = true
		local p, sz = btn.AbsolutePosition, btn.AbsoluteSize
		p -= gui.AbsolutePosition
		local bob = math.sin(os.clock() * 6) * 3
		arrow.Position = UDim2.fromOffset(p.X + sz.X / 2, p.Y - 4 + bob)
	else
		arrow.Visible = false
	end
	if s.Done and s.Done(state) then
		step += 1
	end
end)
