-- P1b.2r ROLLBACK: return the 620 Crystal Wilds trees to their exact pre-move pivots.
-- Preferred rollback is Version History -> restore v14 "P1b.2r PRE-DENSE-REDISTRIBUTION".
-- This script is the in-place alternative. It uses ServerStorage.P1bBackups.P1b2r_PreMoveSnapshot (exact CFrames)
-- and P1b2r_MoveMap (destination -> src row). PivotTo only; idempotent; set DRY_RUN = false to apply.
-- Run in Edit mode only, and only while the trees are untouched by play (trees that respawned in a saved
-- session would no longer be the same instances; Edit-mode trees never respawn).
local DRY_RUN = true
assert(game.PlaceId == 103379930563763 and game.GameId == 10777797608, "ID mismatch")
assert(not game:GetService("RunService"):IsRunning(), "Edit mode only")
local HS = game:GetService("HttpService")
local bk = game.ServerStorage.P1bBackups
local rows = {}
for r in bk.P1b2r_MoveMap.Value:gmatch("[^;]+") do
	local t = {} for v in r:gmatch("[^,]+") do table.insert(t, tonumber(v)) end
	table.insert(rows, { src = t[1], sx = t[2], sz = t[3], dx = t[5], dz = t[7] })
end
assert(#rows == 620, "move map missing")
local snap = {}
for _, part in ipairs(bk.P1b2r_PreMoveSnapshot:GetChildren()) do
	for _, t in ipairs(HS:JSONDecode(part.Value)) do
		local c = {} for v in t.cf:gmatch("[^,]+") do table.insert(c, tonumber(v)) end
		snap[t.src] = CFrame.new(table.unpack(c))
	end
end
local cnt = 0 for _ in pairs(snap) do cnt += 1 end
assert(cnt == 620, "snapshot incomplete: " .. cnt)
local plan, atOrig, seen, n = {}, 0, {}, 0
for _, m in ipairs(workspace.Breakables:GetChildren()) do
	if m:IsA("Model") then
		local p = m:GetPivot().Position
		if p.X >= 2700 and p.X <= 3300 and math.abs(p.Z) <= 300 then
			n += 1
			local d, s
			for _, r in ipairs(rows) do
				if math.abs(p.X - r.dx) < 0.15 and math.abs(p.Z - r.dz) < 0.15 then assert(not d, "ambiguous"); d = r end
				if math.abs(p.X - r.sx) < 0.15 and math.abs(p.Z - r.sz) < 0.15 then assert(not s, "ambiguous"); s = r end
			end
			assert((d == nil) ~= (s == nil), "tree matches neither/both: " .. m.Name)
			local r = d or s
			assert(not seen[r.src], "duplicate row " .. r.src); seen[r.src] = true
			if d then table.insert(plan, { m = m, target = snap[r.src], cur = m:GetPivot() }) else atOrig += 1 end
		end
	end
end
assert(n == 620, "expected 620 trees, found " .. n)
if #plan == 0 then return "NO-OP: all 620 trees already at original pivots" end
assert(atOrig == 0, "partial state; use Version History v14")
local maxShift = 0
for _, it in ipairs(plan) do maxShift = math.max(maxShift, (it.target.Position - it.cur.Position).Magnitude) end
if DRY_RUN then return ("DRY RUN OK: %d trees would return to exact snapshot pivots (max shift %.1f studs)"):format(#plan, maxShift) end
local done = {}
local ok, err = pcall(function()
	for _, it in ipairs(plan) do it.m:PivotTo(it.target); table.insert(done, it) end
	for _, it in ipairs(plan) do assert((it.m:GetPivot().Position - it.target.Position).Magnitude < 0.001, "verify failed") end
end)
if not ok then for _, it in ipairs(done) do it.m:PivotTo(it.cur) end error("ROLLBACK FAILED, re-applied dense layout: " .. tostring(err)) end
workspace.Islands:SetAttribute("P1b2rMoved", nil)
return ("ROLLED BACK %d trees to exact pre-move pivots"):format(#plan)
