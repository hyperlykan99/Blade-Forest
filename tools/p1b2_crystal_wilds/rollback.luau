-- P1b.2 manual rollback (preferred rollback: Version History → restore v9 "P1b.2 PRE-CRYSTAL-CONSTRUCTION").
-- Scripts: revert src/shared/BladeConfig.luau and src/server/WorldServer.server.luau to commit 7f925b4.
-- [paste _guard.luau here]
local Islands, bk = workspace.Islands, game.ServerStorage.P1bBackups
workspace.Terrain:PasteRegion(bk.CrystalWilds_PreTerrain, Vector3int16.new(670, -24, -70), true)
local n = 0
for _, m in ipairs(workspace.Breakables:GetChildren()) do -- bounds-based: P1b tags are lost on respawn
	if m:IsA("Model") then local p = m:GetPivot().Position
		if p.X >= 2700 and p.X <= 3300 and math.abs(p.Z) <= 300 then m:Destroy(); n += 1 end end
end
for _, name in ipairs({ "CrystalWilds_Plaza", "CrystalWilds_Bounds" }) do local o = Islands:FindFirstChild(name); if o then o:Destroy() end end
if not Islands:FindFirstChild("CrystalWilds") then local c = bk.CrystalWilds_P1aTestModel:Clone(); c.Name = "CrystalWilds"; c.Parent = Islands end
for _, a in ipairs({ "P1b2TerrainBuilt", "P1b2Seed", "P1b2TreesBuilt", "P1b2TreeSeed" }) do Islands:SetAttribute(a, nil) end
print("rolled back; trees removed:", n)
