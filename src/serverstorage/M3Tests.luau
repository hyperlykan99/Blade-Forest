-- Essential Studio checks. Fixtures and model clones are detached from the live place.
local Tests = {}

function Tests.Run(M, C, E, Factory, petTemplates)
	local total, nodes, capstones = 0, 0, 0
	for _, branch in ipairs(M.Branches) do
		assert(#branch.Nodes == 12)
		for _, node in ipairs(branch.Nodes) do
			assert(M.Nodes[node.Id] == node)
			total += node.Cost
			nodes += 1
			if node.Capstone then capstones += 1 end
			for _, parent in ipairs(node.Requires) do
				assert(M.Nodes[parent].Branch == node.Branch and M.Nodes[parent].Level < node.Level)
			end
		end
	end
	assert(#M.Branches == 6 and nodes == 72 and total == 240 and capstones == 6)
	local mastery = { Level = 1, XP = 0 }
	local _, points = M.AddXP(mastery, 100000000)
	assert(mastery.Level == 100 and mastery.XP == 0 and points == total)
	local _, repeated = M.AddXP(mastery, 1000)
	assert(repeated == 0)
	local profile = {
		Mastery = mastery, TechTree = { TP = points, Nodes = {}, Spent = 0, Revision = 0 },
		UnlockedIslands = { TimberHaven = true, CrystalWilds = true, FrostboundReach = true },
		Trait = "AncientRoot", Trait2 = "SapSage", EquippedPets = { "Bunny", "Fox" },
		Pets = { Bunny = 4, Dragon = 1 }, PetGolden = { Bunny = 2 }, PetRainbow = {}, Souls = 250,
	}
	assert(not M.Unlock(profile, "Blade12"))
	for _, branch in ipairs(M.Branches) do
		for _, node in ipairs(branch.Nodes) do
			assert(M.Unlock(profile, node.Id))
			assert(not M.Unlock(profile, node.Id))
		end
	end
	assert(profile.TechTree.TP == 0 and M.Bonuses(profile).Damage > 0)
	local revision = profile.TechTree.Revision
	assert(M.Respec(profile.TechTree, revision))
	assert(profile.TechTree.TP == total and next(profile.TechTree.Nodes) == nil)
	assert(not M.Respec(profile.TechTree, revision))
	assert(E.WalkSpeed({ WalkSpeed = 25 }, 1e9) <= E.MaxLegitWalkSpeed())
	assert(E.RenewalReduction(20, 1) == E.Config.Renewal.MaxReduction)
	assert(E.RenewedRespawn(60, "Legendary", 20, 1) == 60)
	assert(E.LogsBreakdown({ Extra = { Test = { PetLogs = 1e9 } } }).Pet <= 1 + E.Config.Pools.PetLogsCap)
	assert(E.LuckBreakdown({ Extra = { Test = { Luck = 1e9 } } }).Total <= E.Config.Pools.LuckHardCap)
	assert(#C.Weapons == 120 and #C.Traits == 12 and #C.Pets == 21)
	for _, crate in ipairs({ "Logs", "Souls" }) do
		for _, luck in ipairs({ true, false }) do
			local sum = 0
			for _, entry in ipairs(C.GetTraitOdds(crate, luck)) do sum += entry.Chance end
			assert(math.abs(sum - 100) < 1e-8)
		end
	end
	local rng = Random.new(63)
	for _, island in ipairs(M.Islands) do
		assert(#C.PetEggs[island] == 7)
		for _ = 1, 50 do assert(C.RollPet(rng, island).Island == island) end
	end
	local function spend(amount)
		if profile.Souls < amount then return false end
		profile.Souls -= amount
		return true
	end
	assert(not M.Evolve(profile, C, "Dragon", spend))
	table.insert(profile.EquippedPets, "Bunny")
	assert(not M.Evolve(profile, C, "Bunny", spend))
	table.remove(profile.EquippedPets)
	assert(not M.Evolve(profile, C, "Bunny", function() return false end))
	assert(profile.Souls == 250 and profile.Pets.Bunny == 4 and profile.PetGolden.Bunny == 2)
	assert(M.Evolve(profile, C, "Bunny", spend))
	assert(profile.Souls == 200 and profile.Pets.Bunny == 1 and profile.PetGolden.Bunny == 3)
	assert(not M.Evolve(profile, C, "Bunny", spend))
	assert(M.Evolve(profile, C, "Bunny_G", spend))
	assert(profile.Souls == 50 and profile.PetGolden.Bunny == nil and profile.PetRainbow.Bunny == 1)
	assert(profile.Pets.Dragon == 1 and not M.Evolve(profile, C, "Bunny_R", spend))
	local folder = petTemplates:Clone()
	Factory.Populate(folder, C)
	assert(#folder:GetChildren() == 63)
	local counts = {}
	for _, model in ipairs(folder:GetChildren()) do
		local parts = 0
		for _, item in ipairs(model:GetDescendants()) do
			assert(not item:IsA("LuaSourceContainer"))
			if item:IsA("BasePart") then parts += 1 end
		end
		assert(parts > 0)
		counts[model.Name] = parts
	end
	folder:Destroy()
	return { Nodes = nodes, Capstones = capstones, Mastery = mastery.Level, TP = total, Weapons = #C.Weapons,
		Traits = #C.Traits, Pets = #C.Pets, Models = counts }
end

return Tests
