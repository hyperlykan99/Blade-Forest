-- AutoChop: tap AUTO (or press F) and your avatar walks to the best tree you
-- can cut, chops it, then moves on. Your blades do the damage as usual; this
-- script only drives the character. Moving yourself turns AUTO off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Breakables = workspace:WaitForChild("Breakables")
local player = Players.LocalPlayer
local F = Enum.Font.FredokaOne

local SEARCH_RADIUS = 160
local BLACKLIST_TIME = 12

local enabled = false
local currentTarget = nil
local blacklist = {} -- [tree] = until (os.clock)
local runId = 0

--------------------------------------------------------------------
-- UI
--------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AutoChopUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local OFF_BG, OFF_STROKE = Color3.fromRGB(110, 115, 125), Color3.fromRGB(60, 62, 70)
local ON_BG, ON_STROKE = Color3.fromRGB(70, 200, 90), Color3.fromRGB(25, 110, 40)

local button = Instance.new("TextButton")
button.Name = "AutoButton"
button.AnchorPoint = Vector2.new(0, 0.5)
button.Position = UDim2.new(0, 14, 0.5, 164)
button.Size = UDim2.fromOffset(140, 54)
button.Font = F
button.TextSize = 21
button.TextColor3 = Color3.new(1, 1, 1)
button.AutoButtonColor = true
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = button

local theme = require(ReplicatedStorage:WaitForChild("UITheme"))
local status = Instance.new("TextLabel")
status.Name = "AutoStatus"
status.LayoutOrder = 20
status.Size = UDim2.new(1, 0, 0, 16)
status.BackgroundColor3 = Color3.fromRGB(41, 32, 28)
status.BackgroundTransparency = 0.25
status.Font = F
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Interactable = false
status.Visible = false
status.Text = ""
status:SetAttribute("NoTheme", true)
theme.Corner(status, 4)
local statusPadding = Instance.new("UIPadding")
statusPadding.PaddingLeft = UDim.new(0, 7)
statusPadding.PaddingRight = UDim.new(0, 7)
statusPadding.Parent = status
theme.AttachToHud(status, "Toasts")

local function setStatus(text, color)
	status.Text = text or ""
	status.Visible = status.Text ~= ""
	status.TextColor3 = (color or Color3.fromRGB(199, 228, 200)):Lerp(Color3.fromRGB(240, 233, 221), 0.45)
end

local function refreshButton()
	button.Text = enabled and "🎯 AUTO: ON" or "🎯 AUTO [F]"
	button.BackgroundColor3 = enabled and ON_BG or OFF_BG
	stroke.Color = enabled and ON_STROKE or OFF_STROKE
	if not enabled then setStatus("") end
end
refreshButton()

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------
local function getChar()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then return char, hum, root end
end

local function myPower() return player:GetAttribute("Power") or 0 end

local function areaUnlocked(areaId)
	local a = areaId and Config.AreaById[areaId]
	if a == nil then return true end
	if myPower() < (a.RequiredPower or 0) then return false end
	-- M1.6: legacy areas behind a later island's gate (server sets "UnlockedIslands")
	local gate = Config.AreaIsland and Config.AreaIsland[areaId]
	if gate and gate ~= Config.HomeIsland then
		local list = player:GetAttribute("UnlockedIslands") or ""
		if not string.find("," .. list .. ",", "," .. gate .. ",", 1, true) then return false end
	end
	return true
end

local function treeAlive(tree)
	return tree and tree.Parent == Breakables and tree.PrimaryPart and (tree:GetAttribute("Health") or 0) > 0
end

-- rough damage per second, only used to rank trees against each other
local function myDps()
	local ok, stats = pcall(Config.GetStats, player)
	if not ok or not stats then return 5 end
	return math.max((stats.Damage or 5) * (stats.Blades or 1) * 1.5, 0.5)
end

local function pickTarget(root)
	local h = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
	local walk = math.max(h and h.WalkSpeed or 16, 1)
	local power, dps = myPower(), myDps()
	local pos = root.Position
	local now = os.clock()
	local best, bestScore = nil, -1
	for _, t in ipairs(Breakables:GetChildren()) do
		local pp = t.PrimaryPart
		if pp and t:GetAttribute("IsTree") and (blacklist[t] or 0) < now then
			local strength = t:GetAttribute("Strength") or 0
			local hp = t:GetAttribute("Health") or 0
			if hp > 0 and strength <= power and areaUnlocked(t:GetAttribute("Area")) then
				local d = (pp.Position - pos).Magnitude
				if d <= SEARCH_RADIUS then
					-- logs per second including the walk there
					local secs = hp / dps + d / walk + 0.4 -- M1.3: real (server-set) Walk Speed
					local score = (t:GetAttribute("Reward") or 1) / secs
					if score > bestScore then best, bestScore = t, score end
				end
			end
		end
	end
	return best
end

local function standPoint(tree, root)
	local pp = tree.PrimaryPart
	local ok, stats = pcall(Config.GetStats, player)
	local reach = ok and stats and stats.Reach or 4
	local dist = math.clamp(reach, 3, 6)
	local c = pp.Position
	local flat = (root.Position - c) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 then flat = Vector3.new(1, 0, 0) end
	return c + flat.Unit * dist
end

-- user moved the stick / pressed WASD -> stop auto
-- (works with or without Roblox's PlayerModule)
local moveGoal = nil -- where AUTO is currently walking the humanoid (nil = standing)
local MOVE_KEYS = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
}
local manualFlag = false
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if MOVE_KEYS[input.KeyCode] then manualFlag = true end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.5 then manualFlag = true end
end)

local offTime = 0
local function userIsMoving(dt)
	if manualFlag then
		manualFlag = false
		return true
	end
	-- touch thumbstick etc: humanoid moving somewhere AUTO didn't send it
	local _, hum, root = getChar()
	if not hum then return false end
	local md = hum.MoveDirection
	local off = false
	if md.Magnitude > 0.5 then
		if not moveGoal then
			off = true
		else
			local want = (moveGoal - root.Position) * Vector3.new(1, 0, 1)
			off = want.Magnitude > 1 and md:Dot(want.Unit) < 0.2
		end
	end
	offTime = off and offTime + dt or 0
	return offTime > 0.35
end

--------------------------------------------------------------------
-- Walking
--------------------------------------------------------------------
-- Walks to goal. Returns true when close, false if stuck/cancelled.
local function walkTo(goal, myRun, tree)
	local _, hum, root = getChar()
	if not hum then return false end

	local waypoints
	if (goal - root.Position).Magnitude > 10 then
		local path = PathfindingService:CreatePath({
			AgentRadius = 1.6, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 5,
		})
		local ok = pcall(function() path:ComputeAsync(root.Position, goal) end)
		if ok and path.Status == Enum.PathStatus.Success then
			waypoints = path:GetWaypoints()
		end
	end
	waypoints = waypoints or { { Position = goal, Action = Enum.PathWaypointAction.Walk } }

	for i, wp in ipairs(waypoints) do
		if i > 1 or #waypoints == 1 then
			if runId ~= myRun or not enabled then return false end
			if tree and not treeAlive(tree) then return true end
			_, hum, root = getChar()
			if not hum then return false end
			if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
			moveGoal = wp.Position
			hum:MoveTo(wp.Position)
			local t0 = os.clock()
			local lastPos, lastMoveT = root.Position, os.clock()
			while true do
				task.wait(0.1)
				if runId ~= myRun or not enabled then return false end
				if tree and not treeAlive(tree) then return true end
				_, hum, root = getChar()
				if not hum then return false end
				local flat = (wp.Position - root.Position) * Vector3.new(1, 0, 1)
				if flat.Magnitude < 2.5 then break end
				if (root.Position - lastPos).Magnitude > 1 then
					lastPos, lastMoveT = root.Position, os.clock()
				elseif os.clock() - lastMoveT > 0.8 then
					hum.Jump = true
					if os.clock() - lastMoveT > 2 then return false end -- stuck
				end
				if os.clock() - t0 > 6 then return false end
				hum:MoveTo(wp.Position) -- MoveTo times out after 8s, keep refreshing
			end
		end
	end
	return true
end

--------------------------------------------------------------------
-- Main loop
--------------------------------------------------------------------
local function rarityColor(tree)
	local r = Config.RarityById[tree:GetAttribute("Rarity") or "Common"]
	return r and r.Color or Color3.new(1, 1, 1)
end

local function runAuto(myRun)
	while enabled and runId == myRun do
		local _, hum, root = getChar()
		if not hum then
			setStatus("Waiting to respawn...")
			task.wait(0.5)
			continue
		end

		local tree = pickTarget(root)
		currentTarget = tree
		if not tree then
			setStatus("No trees you can cut nearby...", Color3.fromRGB(255, 200, 120))
			-- wander a bit so new trees stream in / regrow
			local ang = math.random() * math.pi * 2
			local goal = root.Position + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 25
			if areaUnlocked(Config.GetAreaAt(goal)) then walkTo(goal, myRun) end
			task.wait(0.5)
			continue
		end

		local rarity = tree:GetAttribute("Rarity") or "Common"
		local label = (rarity ~= "Common" and (rarity .. " ") or "") .. (tree:GetAttribute("TreeName") or "Tree")
		setStatus("Walking to " .. label, rarityColor(tree))

		local reached = walkTo(standPoint(tree, root), myRun, tree)
		if runId ~= myRun or not enabled then break end
		if not reached then
			blacklist[tree] = os.clock() + BLACKLIST_TIME
			continue
		end

		-- chop: stand still and let the blades work; nudge closer if nothing happens
		moveGoal = nil
		local _, h2, r2 = getChar()
		if h2 and r2 then h2:MoveTo(r2.Position) end
		setStatus("Chopping " .. label, rarityColor(tree))
		local startHp = tree:GetAttribute("Health") or 0
		local t0, lastHp, lastDrop = os.clock(), startHp, os.clock()
		while treeAlive(tree) and enabled and runId == myRun do
			task.wait(0.15)
			local hp = tree:GetAttribute("Health") or 0
			if hp < lastHp then lastHp, lastDrop = hp, os.clock() end
			if os.clock() - lastDrop > 2.5 then
				_, hum, root = getChar()
				if hum and tree.PrimaryPart then
					moveGoal = tree.PrimaryPart.Position
					hum:MoveTo(tree.PrimaryPart.Position) -- step right up to it
				end
				if os.clock() - lastDrop > 5 then
					blacklist[tree] = os.clock() + BLACKLIST_TIME
					break
				end
			end
			if os.clock() - t0 > 90 then break end
		end
		currentTarget = nil
	end
end

local function setEnabled(on)
	if on and player:GetAttribute("M5Run") then return end
	if on == enabled then return end
	enabled = on
	runId += 1
	refreshButton()
	TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(150, 58) }):Play()
	task.delay(0.12, function()
		TweenService:Create(button, TweenInfo.new(0.12), { Size = UDim2.fromOffset(140, 54) }):Play()
	end)
	if enabled then
		local myRun = runId
		task.spawn(runAuto, myRun)
	else
		currentTarget = nil
		moveGoal = nil
		local _, hum, root = getChar()
		if hum and root and hum.MoveDirection.Magnitude < 0.1 then hum:MoveTo(root.Position) end
	end
end

player:GetAttributeChangedSignal("M5Run"):Connect(function()
	if player:GetAttribute("M5Run") then setEnabled(false) end
end)
button.Activated:Connect(function() setEnabled(not enabled) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F then setEnabled(not enabled) end
end)

-- taking manual control turns AUTO off
RunService.Heartbeat:Connect(function(dt)
	if not enabled then
		manualFlag, offTime = false, 0
		return
	end
	if userIsMoving(dt) then
		moveGoal = nil
		setEnabled(false)
	end
end)

-- expose for other scripts / testing
player:SetAttribute("AutoChop", false)
local lastSent = false
RunService.Heartbeat:Connect(function()
	if lastSent ~= enabled then
		lastSent = enabled
		player:SetAttribute("AutoChop", enabled)
	end
end)

local bindable = Instance.new("BindableFunction")
bindable.Name = "AutoChopToggle"
bindable.OnInvoke = function(on)
	if on == nil then on = not enabled end
	setEnabled(on)
	return enabled
end
bindable.Parent = script
