-- P1b.2 Stage C — arrival plaza (Persistent), return pad, rim walls. Exact geometry as built.
-- [paste _guard.luau here]
local Islands, T = workspace.Islands, workspace.Terrain
assert(not Islands:FindFirstChild("CrystalWilds_Plaza"), "Stage C already ran")
-- Carve plaza + ramp terrain to y 0 so the floor sits flush
T:FillBlock(CFrame.new(2790, 30, 0), Vector3.new(44, 60, 44), Enum.Material.Air)
T:FillBlock(CFrame.new(2818, 30, 0), Vector3.new(12, 60, 12), Enum.Material.Air)
T:FillBlock(CFrame.new(2790, -2, 0), Vector3.new(44, 4, 44), Enum.Material.Ground)
T:FillBlock(CFrame.new(2818, -2, 0), Vector3.new(12, 4, 12), Enum.Material.Ground)
local m = Instance.new("Model"); m.Name = "CrystalWilds_Plaza"; m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
local function part(name, cls, size, cf, props)
	local p = Instance.new(cls); p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do p[k] = v end
	p:SetAttribute("P1bStage", "P1b.2"); p.Parent = m; return p
end
local stone = { Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 110, 150) }
part("ArrivalFloor", "Part", Vector3.new(44, 2, 44), CFrame.new(2790, 1, 0), stone)
part("RampBase", "Part", Vector3.new(12, 2, 12), CFrame.new(2818, 1, 0), stone)
part("Ramp", "WedgePart", Vector3.new(12, 2, 12), CFrame.new(2818, 3, 0) * CFrame.Angles(0, math.rad(90), 0), stone)
part("ArrivalMarker", "Part", Vector3.new(6, 0.2, 6), CFrame.new(2790, 2.1, 0),
	{ Material = Enum.Material.Neon, Color = Color3.fromRGB(170, 120, 255), CanCollide = false })
local pad = part("ReturnPad", "Part", Vector3.new(8, 1, 8), CFrame.new(2775, 2.5, 16),
	{ Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 200, 120) })
pad:SetAttribute("TravelTo", "TimberHaven")
local pp = Instance.new("ProximityPrompt"); pp.ActionText = "Travel"; pp.ObjectText = "Timber Haven"
pp.HoldDuration = 0.4; pp.MaxActivationDistance = 10; pp:SetAttribute("TravelTo", "TimberHaven"); pp.Parent = pad
local label = part("IslandLabel", "Part", Vector3.new(1, 1, 1), CFrame.new(2790, 14, 0), { Transparency = 1, CanCollide = false })
local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(300, 60); bb.Parent = label
local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1
tl.Text = "CRYSTAL WILDS"; tl.TextScaled = true; tl.Font = Enum.Font.FredokaOne; tl.TextColor3 = Color3.new(1, 1, 1); tl.Parent = bb
m.PrimaryPart = m.ArrivalFloor; m.Parent = Islands
local b = Instance.new("Model"); b.Name = "CrystalWilds_Bounds"
for _, w in ipairs({ {"W", Vector3.new(2719,36,0), Vector3.new(2,80,484)}, {"E", Vector3.new(3281,36,0), Vector3.new(2,80,484)},
	{"N", Vector3.new(3000,36,241), Vector3.new(564,80,2)}, {"S", Vector3.new(3000,36,-241), Vector3.new(564,80,2)} }) do
	local p = Instance.new("Part"); p.Name = "RimWall_" .. w[1]; p.Size = w[3]; p.CFrame = CFrame.new(w[2])
	p.Anchored = true; p.Transparency = 1; p:SetAttribute("P1bStage", "P1b.2"); p.Parent = b
end
b.Parent = Islands
-- Old P1a test model: back up, then remove (only after arrival validation passes)
local old = Islands:FindFirstChild("CrystalWilds")
if old then
	local bk = game.ServerStorage.P1bBackups
	if not bk:FindFirstChild("CrystalWilds_P1aTestModel") then local c = old:Clone(); c.Name = "CrystalWilds_P1aTestModel"; c.Parent = bk end
	old:Destroy()
end
print("Stage C done")
