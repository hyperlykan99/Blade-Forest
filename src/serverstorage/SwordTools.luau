-- Edit-time helper: turns a Creator Store sword (Tool/Accessory/Model) into a
-- clean, script-free, anchored Model whose WorldPivot has the blade's long axis
-- on UpVector and its width on RightVector.
local M = {}
local AssetService = game:GetService("AssetService")

-- Old-style parts use a SpecialMesh whose visual size is hidden from Size.
-- Rebuild them as real MeshParts so bounding boxes are correct.
local function convertSpecialMesh(c)
	local sm = c:FindFirstChildOfClass("SpecialMesh")
	if not sm or sm.MeshType ~= Enum.MeshType.FileMesh or sm.MeshId == "" then return c end
	local ok, mp = pcall(function()
		return AssetService:CreateMeshPartAsync(sm.MeshId)
	end)
	if not ok or not mp then return c end
	mp.Size = mp.MeshSize * sm.Scale
	mp.TextureID = sm.TextureId
	mp.CFrame = c.CFrame * CFrame.new(sm.Offset)
	mp.Color = c.Color
	mp.Material = c.Material
	mp.Reflectance = c.Reflectance
	mp.Transparency = c.Transparency
	mp.Name = c.Name
	for _, ch in ipairs(c:GetChildren()) do
		if not ch:IsA("SpecialMesh") then ch.Parent = mp end
	end
	c:Destroy()
	return mp
end

function M.Clean(src)
	local m = Instance.new("Model")
	m.Name = src.Name
	local parts = {}
	if src:IsA("BasePart") then table.insert(parts, src) end
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end
	for _, p in ipairs(parts) do
		if p.Transparency < 0.98 then
			local c = convertSpecialMesh(p:Clone())
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("JointInstance")
					or d:IsA("WeldConstraint") or d:IsA("TouchTransmitter") or d:IsA("BasePart") then
					d:Destroy()
				end
			end
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.CastShadow = false
			c.Massless = true
			c.Parent = m
		end
	end
	local best, bestVol = nil, 0
	for _, p in ipairs(m:GetChildren()) do
		local v = p.Size.X * p.Size.Y * p.Size.Z
		if v > bestVol then best, bestVol = p, v end
	end
	if not best then return nil end
	m.PrimaryPart = best
	local cf, size = m:GetBoundingBox()
	local axes = { { size.X, cf.RightVector }, { size.Y, cf.UpVector }, { size.Z, cf.LookVector } }
	table.sort(axes, function(a, b) return a[1] > b[1] end)
	m.PrimaryPart = nil
	m.WorldPivot = CFrame.fromMatrix(cf.Position, axes[2][2], axes[1][2])
	return m, axes[1][1]
end

return M
