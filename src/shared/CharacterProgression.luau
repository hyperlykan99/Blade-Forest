-- Stable M3 IDs. Each branch contributes to one existing capped economy channel.
local M = {}
M.MaxLevel = 100
M.EvolutionCopies = 3
M.EvolutionCosts = { Golden = 50, Rainbow = 150 }
M.Milestones = { [25] = 10, [50] = 10, [75] = 10, [100] = 10 }
M.Islands = { "TimberHaven", "CrystalWilds", "FrostboundReach" }
M.IslandNames = { TimberHaven = "Timber Haven", CrystalWilds = "Crystal Wilds", FrostboundReach = "Frostbound Reach" }

local conditions = {
	{ "Always", function() return true end },
	{ "Mastery 10+", function(d) return d.Mastery.Level >= 10 end },
	{ "Crystal Wilds unlocked", function(d) return d.UnlockedIslands.CrystalWilds == true end },
	{ "Primary trait equipped", function(d) return type(d.Trait) == "string" end },
	{ "Mastery 25+", function(d) return d.Mastery.Level >= 25 end },
	{ "At least one pet equipped", function(d) return #d.EquippedPets > 0 end },
	{ "Frostbound Reach unlocked", function(d) return d.UnlockedIslands.FrostboundReach == true end },
	{ "At least two pets equipped", function(d) return #d.EquippedPets >= 2 end },
	{ "Mastery 50+", function(d) return d.Mastery.Level >= 50 end },
	{ "Secondary trait equipped", function(d) return d.UnlockedIslands.FrostboundReach == true and type(d.Trait2) == "string" end },
	{ "Mastery 75+", function(d) return d.Mastery.Level >= 75 end },
	{ "Mastery 100", function(d) return d.Mastery.Level == 100 end },
}

local branchSpecs = {
	{ "Blade", "Blade Mastery", "⚔", "Damage", "tree damage pool", 0.010, {
		"True Edge", "Steady Orbit", "Crystal Cleave", "Inscribed Steel", "Tempered Arc", "Pack Strike",
		"Ice Cutter", "Flanking Blades", "Heartwood Splitter", "Twin Engraving", "Peerless Edge", "Crown of Steel",
	} },
	{ "Forest", "Forest Mastery", "♣", "Logs", "permanent Logs pool", 0.025, {
		"Fieldcraft", "Seasoned Hands", "Crystal Sap", "Bark Blessing", "Canopy Harvest", "Pack Haul",
		"Winter Timber", "Timber Caravan", "Old Growth", "Twin Bark Seals", "Verdant Dominion", "Heart of the Forest",
	} },
	{ "Fortune", "Fortune Mastery", "✦", "Luck", "permanent Luck pool", 0.018, {
		"Fortune Seed", "Lucky Streak", "Facet Finder", "Omen Reader", "Silver Lining", "Lucky Companion",
		"Winter Star", "Twinned Charms", "Gilded Fate", "Double Omen", "Starlit Path", "Wheel of Fortune",
	} },
	{ "Explorer", "Explorer Mastery", "✧", "Mobility", "movement cap", 0.11, {
		"Trail Boots", "Wayfinder", "Crystal Footing", "Traveler's Mark", "Long March", "Scouting Partner",
		"Glacier Step", "Expedition Party", "Fleetfoot", "Double Trail Sign", "Far Horizon", "Worldwalker",
	} },
	{ "Artisan", "Artisan Mastery", "◆", "PetLogs", "pet Logs pool while a pet is equipped", 0.017, {
		"Carved Collar", "Fine Stitching", "Crystal Harness", "Runed Tag", "Masterwork Saddle", "Bonded Leash",
		"Frostweave", "Pack Harness", "Guildwork", "Twin Signatures", "Heirloom Craft", "Master Artisan",
	} },
	{ "Guardian", "Guardian Mastery", "⬡", "Renewal", "eligible tree regrowth reduction", 0.004, {
		"Seed Keeper", "Grove Sentinel", "Crystal Nursery", "Ward Seal", "Lifeweaver", "Forest Familiar",
		"Winter Greenhouse", "Grove Patrol", "Second Spring", "Twin Wards", "Elder Warden", "Evergreen Covenant",
	} },
}

M.Branches, M.Nodes = {}, {}
local levels = { 2, 6, 12, 18, 25, 32, 40, 48, 55, 64, 75, 90 }
local function nodeId(branch, i) return string.format("%s%02d", branch, i) end
for _, spec in ipairs(branchSpecs) do
	local id, name, icon, channel, label, step, names = table.unpack(spec)
	local branch = { Id = id, Name = name, Icon = icon, Nodes = {} }
	for i, title in ipairs(names) do
		local tier = math.ceil(i / 4)
		local cost = ({ 2, 3, 5 })[tier]
		local amount = step * (i == 12 and 3 or tier)
		local requirement = i == 12 and { nodeId(id, 9), nodeId(id, 10), nodeId(id, 11) }
			or i > 3 and { nodeId(id, i - 3) } or {}
		local gain
		if channel == "Mobility" then
			gain = string.format("+%.2f studs/s within the movement cap", amount)
		else
			gain = string.format("+%g%% to the %s", amount * 100, label)
		end
		local node = {
			Id = nodeId(id, i), Name = title, Tier = tier, Cost = cost, Level = levels[i], Branch = id,
			Requires = requirement, Capstone = i == 12, Channel = channel, Amount = amount,
			Condition = conditions[i][1], Applies = conditions[i][2], Description = gain,
		}
		branch.Nodes[i] = node
		M.Nodes[node.Id] = node
	end
	table.insert(M.Branches, branch)
end

function M.XPToNext(level)
	return level < M.MaxLevel and math.floor(110 + 32 * level ^ 1.48) or 0
end

function M.TreeXP(rarityOrder, island, mutation)
	local weight = ({ 3, 5, 8, 13, 23, 40, 75, 100 })[rarityOrder] or 3
	local tier = table.find(M.Islands, island) or 1
	return weight * tier + (mutation and 4 * tier or 0)
end

function M.AddXP(mastery, xp)
	local previous = mastery.Level
	local reward = 0
	if previous == M.MaxLevel then return previous, reward end
	mastery.XP += xp
	while mastery.Level < M.MaxLevel and mastery.XP >= M.XPToNext(mastery.Level) do
		mastery.XP -= M.XPToNext(mastery.Level)
		mastery.Level += 1
		if mastery.Level % 2 == 0 then reward += 4 end
		reward += M.Milestones[mastery.Level] or 0
	end
	if mastery.Level == M.MaxLevel then mastery.XP = 0 end
	return previous, reward
end

function M.CanUnlock(data, node)
	if not node then return false, "Unknown skill" end
	if data.TechTree.Nodes[node.Id] then return false, "Already unlocked" end
	if data.Mastery.Level < node.Level then return false, string.format("Requires Mastery %d", node.Level) end
	for _, id in ipairs(node.Requires) do
		if not data.TechTree.Nodes[id] then return false, "Requires " .. M.Nodes[id].Name end
	end
	if data.TechTree.TP < node.Cost then return false, "Not enough Tech Points" end
	return true
end

function M.Unlock(data, id)
	local node = type(id) == "string" and M.Nodes[id]
	local ok, why = M.CanUnlock(data, node)
	if not ok then return false, why end
	local tree = data.TechTree
	tree.Nodes[id] = true
	tree.TP -= node.Cost
	tree.Spent += node.Cost
	tree.Revision += 1
	return true
end

function M.Respec(tree, revision)
	if revision ~= tree.Revision or tree.Spent <= 0 then return false, "Skill tree has changed. Choose an action again." end
	local refund = 0
	for id, owned in pairs(tree.Nodes) do
		if owned == true and M.Nodes[id] then
			refund += M.Nodes[id].Cost
			tree.Nodes[id] = nil
		end
	end
	tree.TP += refund
	tree.Spent = 0
	tree.Revision += 1
	return true
end

function M.Bonuses(data)
	local bonuses = { Logs = (data.Mastery.Level - 1) * 0.005, Luck = 0, Damage = 0, Mobility = 0, PetLogs = 0, Renewal = 0 }
	for id, owned in pairs(data.TechTree.Nodes) do
		local node = owned == true and M.Nodes[id]
		if node and node.Applies(data) and (node.Channel ~= "PetLogs" or #data.EquippedPets > 0) then
			bonuses[node.Channel] += node.Amount
		end
	end
	return bonuses
end

function M.Trait(data, slot)
	if slot == 2 then return data.Trait2, data.Trait2Locked end
	return data.Trait, data.TraitLocked
end

function M.PetKey(id, stage)
	return stage == "Golden" and id .. "_G" or stage == "Rainbow" and id .. "_R" or id
end

-- The callback spends the validated currency and must not yield. The server
-- supplies DataService.SpendSouls, which also updates the player's leaderstats.
function M.Evolve(data, config, key, spend)
	local pet = type(key) == "string" and config.PetById[key]
	if not pet or pet.Stage == "Rainbow" then return false, "Choose a normal or Golden pet" end
	local nextStage = pet.Stage == "Golden" and "Rainbow" or "Golden"
	local inventory, id = config.PetInventory(data, pet)
	local count = inventory[id] or 0
	local needed = M.EvolutionCopies
	if count < needed then return false, string.format("Need %d matching copies", needed) end
	local equipped = 0
	for _, equippedKey in ipairs(data.EquippedPets) do
		if equippedKey == key then equipped += 1 end
	end
	if count - equipped < needed then return false, "Unequip matching copies first" end
	local result = config.PetById[M.PetKey(id, nextStage)]
	local target = config.PetInventory(data, result)
	local cost = M.EvolutionCosts[nextStage]
	if not spend(cost) then return false, string.format("Need %d Souls", cost) end
	inventory[id] = count > needed and count - needed or nil
	target[id] = (target[id] or 0) + 1
	return true, result
end

return M
