-- P1b.2 Stage E — localized, reversible light budget adjustment (NO TreeKit change).
-- Disables the MutationFX PointLight on Frozen-mutation trees built by P1b.2 (14 lights; 51 → 37).
-- Pass REVERT = true to re-enable.
-- [paste _guard.luau here]
local REVERT = false
local k = 0
for _, m in ipairs(workspace.Breakables:GetChildren()) do
	if m:GetAttribute("P1bIsland") == "CrystalWilds" then
		for _, l in ipairs(m:GetDescendants()) do
			if l:IsA("PointLight") then
				if REVERT and l:GetAttribute("P1bLightDisabled") then l.Enabled = true; l:SetAttribute("P1bLightDisabled", nil); k += 1
				elseif not REVERT and m:GetAttribute("Mutation") == "Frozen" and l.Parent.Name == "MutationFX" and l.Enabled then
					l.Enabled = false; l:SetAttribute("P1bLightDisabled", true); k += 1 end
			end
		end
	end
end
print(REVERT and "re-enabled" or "disabled", k)
