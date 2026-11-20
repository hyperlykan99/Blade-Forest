-- ReceiptProcessor (M0-C): developer-product receipt decisions, with all
-- dependencies injected so the exact same logic runs in StoreService and in
-- the M0 test harness.
--
-- deps = {
--   getPlayer(userId) -> player | nil
--   product(productId) -> product config | nil
--   isActive(player) -> bool        (profile loaded AND owned by this server)
--   canPersist(player) -> bool      (real saves possible; false for Studio test profiles)
--   getData(player) -> profile table
--   grant(player, product)          (may throw)
--   saveNow(player) -> bool         (true only when the DataStore write is confirmed)
--   afterRestore(player)            (refresh leaderstats/multipliers after a rollback)
--   report(player, outcome, productKey)
-- }
--
-- Decisions
--   * Unknown product / player absent / data not loaded / profile not owned
--     -> NotProcessedYet (Roblox re-delivers the receipt later).
--   * Purchase id recorded and saved -> PurchaseGranted (duplicate delivery).
--   * Purchase id recorded but its save not yet confirmed -> save again;
--     Granted only if confirmed, else NotProcessedYet.
--   * New receipt -> snapshot, record id + grant together, save. A throwing
--     grant restores the snapshot. Granted only after a confirmed save.
-- Purchase ids are never pruned.

local ReceiptProcessor = {}

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end

local function restoreInto(d, snap)
	for k in pairs(d) do d[k] = nil end
	for k, v in pairs(snap) do d[k] = v end
end

function ReceiptProcessor.new(deps)
	local self = { deps = deps, unconfirmed = {} }

	function self.process(receipt)
		local NotYet = Enum.ProductPurchaseDecision.NotProcessedYet
		local Granted = Enum.ProductPurchaseDecision.PurchaseGranted
		local p = deps.product(receipt.ProductId)
		local player = deps.getPlayer(receipt.PlayerId)
		if not p then return NotYet, "unknown_product" end
		if not player then return NotYet, "player_absent" end
		if not deps.isActive(player) or not deps.canPersist(player) then return NotYet, "not_loaded_or_not_owned" end
		local d = deps.getData(player)
		if type(d) ~= "table" then return NotYet, "no_data" end
		d.Purchases = d.Purchases or {}
		local pid = receipt.PurchaseId
		if type(pid) ~= "string" or pid == "" then return NotYet, "bad_purchase_id" end

		if d.Purchases[pid] then
			if self.unconfirmed[pid] then
				if deps.saveNow(player) then
					self.unconfirmed[pid] = nil
					deps.report(player, "Granted", p.Id)
					return Granted, "confirmed_on_retry"
				end
				deps.report(player, "Deferred", p.Id)
				return NotYet, "save_unconfirmed"
			end
			deps.report(player, "Duplicate", p.Id)
			return Granted, "duplicate"
		end

		local snap = deepCopy(d)
		d.Purchases[pid] = true
		local ok, err = pcall(deps.grant, player, p)
		if not ok then
			restoreInto(d, snap)
			pcall(deps.afterRestore, player)
			deps.report(player, "Failed", p.Id)
			return NotYet, "grant_error: " .. tostring(err)
		end
		self.unconfirmed[pid] = true
		if deps.saveNow(player) then
			self.unconfirmed[pid] = nil
			deps.report(player, "Granted", p.Id)
			return Granted, "granted"
		end
		deps.report(player, "Deferred", p.Id)
		return NotYet, "save_unconfirmed"
	end

	function self.pending()
		local list = {}
		for k in pairs(self.unconfirmed) do table.insert(list, k) end
		return list
	end

	return self
end

return ReceiptProcessor
