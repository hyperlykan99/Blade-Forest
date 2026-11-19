-- P1b.2r MOVE (exactly as executed 2026-11-19 on dev place, between v14 checkpoint and v15 save).
-- Redistributes the existing 620 Crystal Wilds tree instances to the approved Option A spots with Model:PivotTo.
-- No rebuild, no attribute/scale/effect changes; each tree keeps its exact current rotation.
-- Identity: each tree is matched to its v12 manifest row by its untouched pivot (x,z within 0.15; source spots are
-- >= 7.03 studs apart, destinations >= 3.35, any destination >= 0.67 from any other source). All-or-nothing:
-- classify everything first; abort on any ambiguity/partial state; verify; revert in-place on any failure.
-- Idempotent: a second run returns NO-OP. Requires ServerStorage.P1bBackups.P1b2r_MoveMap
-- (docs/p1b2r/p1b2r_move_map.txt, 25085 bytes, Adler-32 3646164357).
assert(game.PlaceId == 103379930563763 and game.GameId == 10777797608, "ID mismatch")
assert(not game:GetService("RunService"):IsRunning(), "Edit mode only")
local bk = game.ServerStorage.P1bBackups
local map = bk.P1b2r_MoveMap.Value
local function ck(x) local a, b = 1, 0 for i = 1, #x do a = (a + string.byte(x, i)) % 65521; b = (b + a) % 65521 end return b * 65536 + a end
assert(#map == 25085 and ck(map) == 3646164357, "move map checksum mismatch")
local rows = {}
for r in map:gmatch("[^;]+") do
	local t = {} for v in r:gmatch("[^,]+") do table.insert(t, tonumber(v)) end
	table.insert(rows, { src = t[1], sx = t[2], sz = t[3], dx = t[5], dy = t[6], dz = t[7] })
end
assert(#rows == 620)
local TOL = 0.15
local plan, already, seen = {}, 0, {}
local n = 0
for _, m in ipairs(workspace.Breakables:GetChildren()) do
	if m:IsA("Model") then
		local cf = m:GetPivot(); local p = cf.Position
		if p.X >= 2700 and p.X <= 3300 and math.abs(p.Z) <= 300 then
			n += 1
			local s, d = nil, nil
			for i, r in ipairs(rows) do
				if math.sqrt((p.X - r.sx)^2 + (p.Z - r.sz)^2) <= TOL then assert(not s, "ambiguous source match"); s = i end
				if math.sqrt((p.X - r.dx)^2 + (p.Z - r.dz)^2) <= TOL then assert(not d, "ambiguous destination match"); d = i end
			end
			assert((s == nil) ~= (d == nil), ("tree %s at %.2f,%.2f matches neither or both"):format(m.Name, p.X, p.Z))
			local i = s or d
			assert(not seen[i], "row matched twice: " .. i); seen[i] = true
			if s then table.insert(plan, { m = m, orig = cf, row = rows[i] }) else already += 1 end
		end
	end
end
assert(n == 620, "expected 620 trees in bounds, found " .. n)
for i = 1, 620 do assert(seen[i], "row unmatched: " .. i) end
if #plan == 0 then return "NO-OP: all 620 trees already at destinations (idempotent)" end
assert(already == 0, "partial state detected (" .. already .. " already moved); restore checkpoint instead")
local moved = {}
local ok, err = pcall(function()
	for _, it in ipairs(plan) do
		local rot = it.orig - it.orig.Position
		it.m:PivotTo(CFrame.new(it.row.dx, it.row.dy, it.row.dz) * rot)
		table.insert(moved, it)
	end
	for _, it in ipairs(plan) do
		local cf = it.m:GetPivot()
		assert((cf.Position - Vector3.new(it.row.dx, it.row.dy, it.row.dz)).Magnitude < 0.01, "position verify failed")
		local a, b = cf - cf.Position, it.orig - it.orig.Position
		assert((a.LookVector - b.LookVector).Magnitude < 1e-4 and (a.UpVector - b.UpVector).Magnitude < 1e-4, "rotation changed")
		assert(it.m.Parent == workspace.Breakables, "parent changed")
	end
end)
if not ok then
	for _, it in ipairs(moved) do it.m:PivotTo(it.orig) end
	error("MOVE FAILED, reverted " .. #moved .. " trees: " .. tostring(err))
end
workspace.Islands:SetAttribute("P1b2rMoved", true)
workspace.Islands:SetAttribute("P1b2rMoveMapAdler", 3646164357)
return ("MOVED %d trees; verified positions and rotations"):format(#moved)
