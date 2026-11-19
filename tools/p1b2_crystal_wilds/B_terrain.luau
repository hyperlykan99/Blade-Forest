-- P1b.2 Stage B — Crystal Wilds terrain (footprint X 2720–3280, Z −240–240). Seed 20261119.
-- Run-twice guard: Workspace.Islands:GetAttribute("P1b2TerrainBuilt").
-- NOTE: the slab, core copy, paths and flat zones below are exact. The hill pass is a faithful
-- reference of the executed pass (same seed/params) but terrain voxels are not checksummed, so the
-- authoritative v12 terrain is the saved place (and the pre-build snapshot is ServerStorage.P1bBackups).
-- [paste _guard.luau here]
local T, Islands = workspace.Terrain, workspace.Islands
assert(not Islands:GetAttribute("P1b2TerrainBuilt"), "Stage B already ran")
local backups = game.ServerStorage:FindFirstChild("P1bBackups") or Instance.new("Folder", game.ServerStorage)
backups.Name = "P1bBackups"
if not backups:FindFirstChild("CrystalWilds_PreTerrain") then
	local snap = T:CopyRegion(Region3int16.new(Vector3int16.new(670, -24, -70), Vector3int16.new(830, 40, 70)))
	snap.Name = "CrystalWilds_PreTerrain"; snap.Parent = backups
end
-- 1) Base slab
T:FillBlock(CFrame.new(3000, -19, 0), Vector3.new(560, 42, 480), Enum.Material.Rock)
T:FillBlock(CFrame.new(3000, 0, 0), Vector3.new(560, 4, 480), Enum.Material.Grass)
-- 2) Core: copy the ORIGINAL Crystal Canyon core (left intact) and paste +689 voxels (+2756 studs) in X
local core = T:CopyRegion(Region3int16.new(Vector3int16.new(47, -8, -34), Vector3int16.new(90, 16, 34)))
T:PasteRegion(core, Vector3int16.new(736, -8, -34), true) -- core spans X 2944–3116, Z ±136
-- 3) Hills outside the core: 8-stud columns, math.noise amplitude 14 × edge mask; Rock/Basalt patches
local SEED = 20261119
for x = 2724, 3276, 8 do for z = -236, 236, 8 do
	local inCore = x >= 2940 and x <= 3120 and math.abs(z) <= 140
	if not inCore then
		local mask = math.clamp((math.min(x - 2720, 3280 - x, 240 - math.abs(z))) / 60, 0, 1)
		local h = math.max(0, math.noise(x / 90, z / 90, SEED % 1000 / 7) * 14 * mask)
		if h > 1 then
			local mat = math.noise(x / 40, z / 40, 3.3) > 0.25 and Enum.Material.Rock
				or (math.noise(x / 40, z / 40, 7.7) > 0.3 and Enum.Material.Basalt or Enum.Material.Grass)
			T:FillBlock(CFrame.new(x, 2 + h / 2, z), Vector3.new(8, h, 8), mat)
		end
	end
end end
-- 4) Paths: 10-wide Ground strips at y≈2, Air above
local PATHS = { {2810,0,2944,0}, {2920,-160,3140,-160}, {2920,160,3140,160}, {2920,-160,2920,160},
	{3140,-160,3140,160}, {2850,-25,2850,-10}, {2850,-10,2920,-10}, {3140,-160,3150,-150}, {3140,160,3220,150} }
for _, p in ipairs(PATHS) do
	local a, b = Vector3.new(p[1], 0, p[2]), Vector3.new(p[3], 0, p[4])
	local len, mid = (b - a).Magnitude, (a + b) / 2
	local cf = CFrame.lookAt(mid, b + Vector3.new(0, 0, 0.001))
	T:FillBlock(cf + Vector3.new(0, 30, 0), Vector3.new(10, 56, len + 10), Enum.Material.Air)
	T:FillBlock(cf, Vector3.new(10, 4, len + 10), Enum.Material.Ground)
end
-- 5) Flat zones
local function flatRect(cx, cz, hx, hz) T:FillBlock(CFrame.new(cx, 30, cz), Vector3.new(hx*2, 56, hz*2), Enum.Material.Air)
	T:FillBlock(CFrame.new(cx, 0, cz), Vector3.new(hx*2, 4, hz*2), Enum.Material.Grass) end
local function flatCirc(cx, cz, r) T:FillCylinder(CFrame.new(cx, 30, cz), 56, r, Enum.Material.Air)
	T:FillCylinder(CFrame.new(cx, 0, cz), 4, r, Enum.Material.Grass) end
flatRect(2790, 0, 20, 20); flatRect(2850, -40, 20, 15); flatCirc(3150, -150, 56); flatCirc(3220, 150, 14)
Islands:SetAttribute("P1b2TerrainBuilt", true); Islands:SetAttribute("P1b2Seed", SEED)
print("Stage B done")
