-- HudExtras: small always-on HUD bits
--  * BLADES ON/OFF button (next to PvP) - stop your blades from spinning
--  * Active potion timers in the shared status rail
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local T = require(ReplicatedStorage:WaitForChild("UITheme"))
local C = T.Color
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Meta = Remotes:WaitForChild("Meta")
local DataSync = Remotes:WaitForChild("DataSync")
local GetData = Remotes:WaitForChild("GetData")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HudExtras"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------
-- BLADES ON/OFF
--------------------------------------------------------------------
local actionBar = gui.Parent:WaitForChild("RollUI"):WaitForChild("RollBar")
local bladesBtn = T.Button(actionBar, { Name = "BladeToggle", Text = "" }, C.Leaf)
local function refreshBlades()
	local off = player:GetAttribute("BladesOff") == true
	bladesBtn.Text = off and "BLADES\nOFF" or "BLADES\nON"
	bladesBtn.BackgroundColor3 = off and C.Grey or C.Leaf
end
player:GetAttributeChangedSignal("BladesOff"):Connect(refreshBlades)
refreshBlades()
local busy = false
bladesBtn.Activated:Connect(function()
	if busy then return end
	busy = true
	local turnOn = player:GetAttribute("BladesOff") == true
	pcall(function() Meta:InvokeServer("SetBlades", turnOn) end)
	busy = false
end)

--------------------------------------------------------------------
-- Boost / potion chips
--------------------------------------------------------------------
local ICONS = { StarterLuck = "🍀", LuckPotion = "🍀", MegaLuckPotion = "🍀", LogBoost = "🪵" }
local function boostLabel(id, b)
	if b.Luck and b.Luck > 1 then return string.format("x%s Luck", tostring(b.Luck)) end
	if b.Logs and b.Logs > 1 then return string.format("x%s Logs", tostring(b.Logs)) end
	return b.Name or id
end

local bar = Instance.new("Frame")
bar.Name = "BoostBar"
bar.LayoutOrder = 4
bar.Size = UDim2.new(1, 0, 0, 19)
bar.BackgroundColor3 = C.WoodDark
bar.BorderSizePixel = 0
bar.Visible = false
T.AttachToHud(bar, "StatusRail")
T.Corner(bar, 6)
local boostText = T.Label(bar, {
	Position = UDim2.fromOffset(5, 0), Size = UDim2.new(1, -10, 1, 0), Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
})
local limit = Instance.new("UITextSizeConstraint")
limit.MaxTextSize = 12
limit.Parent = boostText

local boosts = {}
local function fmt(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60) end
	return string.format("%d:%02d", s // 60, s % 60)
end

local function setData(d)
	boosts = (d and d.Boosts) or {}
end
DataSync.OnClientEvent:Connect(setData)
task.spawn(function()
	local ok, d = pcall(function() return GetData:InvokeServer() end)
	if ok and d then setData(d) end
end)

while true do
	local now = workspace:GetServerTimeNow()
	local active = {}
	for id, expires in pairs(boosts) do
		if expires > now and Config.Boosts[id] then table.insert(active, id) end
	end
	bar.Visible = #active > 0
	if #active > 0 then
		-- Several simultaneous potions share one line. Keep their order stable.
		table.sort(active)
		local index = math.floor(now / 4) % #active + 1
		local id = active[index]
		local left = boosts[id] - now
		local count = #active > 1 and string.format("  (%d/%d)", index, #active) or ""
		boostText.Text = (ICONS[id] or "✨") .. " " .. boostLabel(id, Config.Boosts[id]) .. "  " .. fmt(left) .. count
		boostText.TextColor3 = left < 60 and C.Red:Lerp(C.Cream, 0.5) or C.Cream
	end
	task.wait(0.5)
end
