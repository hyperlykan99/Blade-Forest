-- P1b.2 Stage D — rebuild the 620 Crystal Wilds trees EXACTLY from docs/p1b_tree_spots_crystal_wilds.csv.
-- Setup: create ServerStorage.P1bTreeSpots (ModuleScript) whose source is:  return [==[<CSV contents>]==]
-- CSV line: x,y,z,type(sans "Crystal_"),scale(relative to template),rotY(deg),mutation("-" = none)
-- (The original run generated these by seeded dart-throwing, seed 20261120; this replays the result.)
-- [paste _guard.luau here]
local Islands = workspace.Islands
assert(not Islands:GetAttribute("P1b2TreesBuilt"), "Stage D already ran")
local TreeKit = require(game.ReplicatedStorage.TreeKit)
local csv = require(game.ServerStorage.P1bTreeSpots)
local function adler(s) local a, b = 1, 0 for i = 1, #s do a = (a + s:byte(i)) % 65521; b = (b + a) % 65521 end return b * 65536 + a end
assert(#csv == 22454 and adler(csv) == 308787882, "tree manifest checksum mismatch")
local n = 0
for line in csv:gmatch("[^\n]+") do
	local x, y, z, t, s, r, mut = line:match("^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$")
	local cf = CFrame.new(tonumber(x), tonumber(y), tonumber(z)) * CFrame.Angles(0, math.rad(tonumber(r)), 0)
	local m = TreeKit.Build("Crystal_" .. t, cf, tonumber(s), true)
	if mut ~= "-" then TreeKit.Mutate(m, mut) end
	m:SetAttribute("Area", "CrystalCanyon"); m:SetAttribute("P1bIsland", "CrystalWilds"); m:SetAttribute("P1bStage", "P1b.2")
	m.Parent = workspace.Breakables; n += 1
end
assert(n == 620, "expected 620 trees, built " .. n)
Islands:SetAttribute("P1b2TreesBuilt", true); Islands:SetAttribute("P1b2TreeSeed", 20261120)
print("Stage D done:", n)
