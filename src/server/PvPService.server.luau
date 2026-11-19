-- PvPService: per-player PvP switch (no safe zones).
--   * PvP ON  -> x1.5 logs, can fight other PvP players, NPCs may attack you
--   * PvP OFF -> nobody can hurt you except NPCs you attacked yourself
--   * 10s between toggles, can't switch OFF within 15s of PvP damage
--   * a red "PvP" tag floats over your head while it's on

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BladeConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PvPToggle = Remotes:WaitForChild("PvPToggle")
local NotifyRemote = Remotes:WaitForChild("Notify")
local DataService = require(script.Parent:WaitForChild("DataService"))

local F = Enum.Font.FredokaOne
local PVP_RED = Color3.fromRGB(255, 70, 70)

--------------------------------------------------------------------
-- Overhead tag (shared billboard; Traits will add their title here too)
--------------------------------------------------------------------
local function getOverhead(char)
	local head = char and char:FindFirstChild("Head")
	if not head then return nil end
	local bb = head:FindFirstChild("Overhead")
	if bb then return bb end
	bb = Instance.new("BillboardGui")
	bb.Name = "Overhead"
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = bb

	local title = Instance.new("TextLabel") -- trait title (step 7)
	title.Name = "Title"
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = F
	title.TextScaled = true
	title.TextStrokeTransparency = 0.2
	title.Visible = false
	title.Parent = bb

	local pvp = Instance.new("TextLabel")
	pvp.Name = "PvPTag"
	pvp.LayoutOrder = 2
	pvp.Size = UDim2.new(0, 84, 0, 24)
	pvp.BackgroundColor3 = Color3.fromRGB(120, 20, 25)
	pvp.BackgroundTransparency = 0.15
	pvp.Font = F
	pvp.TextScaled = true
	pvp.TextColor3 = Color3.new(1, 1, 1)
	pvp.Text = "⚔ PvP"
	pvp.Visible = false
	pvp.Parent = bb
	Instance.new("UICorner", pvp).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke")
	st.Color = PVP_RED
	st.Thickness = 2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = pvp
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 2), UDim.new(0, 2)
	pad.Parent = pvp

	bb.Parent = head
	return bb
end

local function refreshTag(player)
	local bb = getOverhead(player.Character)
	if bb then bb.PvPTag.Visible = player:GetAttribute("PvP") == true end
end

--------------------------------------------------------------------
-- Toggle
--------------------------------------------------------------------
local function setPvP(player, on)
	player:SetAttribute("PvP", on)
	player:SetAttribute("PvPToggleAt", workspace:GetServerTimeNow())
	DataService.RecalcMultipliers(player)
	refreshTag(player)
end

PvPToggle.OnServerInvoke = function(player, wantOn)
	if not player:GetAttribute("Loaded") then return false, "Loading..." end
	local now = workspace:GetServerTimeNow()
	local cur = player:GetAttribute("PvP") == true
	if wantOn == nil then wantOn = not cur end
	wantOn = wantOn == true
	if wantOn == cur then return true, nil, cur end

	local since = now - (player:GetAttribute("PvPToggleAt") or 0)
	if since < Config.PvP.ToggleCooldown then
		return false, string.format("Wait %ds to switch PvP again", math.ceil(Config.PvP.ToggleCooldown - since)), cur
	end
	if not wantOn then
		local lock = (player:GetAttribute("CombatUntil") or 0) - now
		if lock > 0 then
			return false, string.format("In combat! PvP stays on for %ds", math.ceil(lock)), cur
		end
	end

	setPvP(player, wantOn)
	if wantOn then
		NotifyRemote:FireClient(player, string.format("⚔ PvP ON  -  x%.1f Logs! Other PvP players and NPCs can attack you", Config.PvP.LogMult), "streak")
	else
		NotifyRemote:FireClient(player, "PvP OFF  -  you're safe from other players", "kill")
	end
	return true, nil, wantOn
end

--------------------------------------------------------------------
-- Join / respawn
--------------------------------------------------------------------
local function onPlayer(player)
	player:SetAttribute("PvP", false)
	player:SetAttribute("PvPToggleAt", 0)
	player:SetAttribute("CombatUntil", 0)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Head", 10)
		refreshTag(player)
	end)
	if player.Character then refreshTag(player) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
