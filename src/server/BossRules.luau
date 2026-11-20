-- BossRules (M0.1, M5): who scales boss health and who earns boss rewards.
--
-- M0 behaviour:
--   * Treant HP = 300 x total Power of EVERYONE online, including AFK players
--     on other islands who will never fight it
--   * Blade King HP = 8,000 + 3,000 x everyone online
--   * any non-zero Treant damage share paid the full base reward (40+ Souls,
--     a Trait Crate, 3x crate-cost Logs): one touch farmed a crate
-- M0.1:
--   * only players within RANGE studs of the boss (horizontal) count for HP
--   * a Treant reward needs at least MIN_SHARE of the damage OR MIN_HITS
--     blade hits; the top-damage bonus goes to the best ELIGIBLE player
-- Reward AMOUNTS are unchanged (no economy change in M0.1).

local BossRules = {}
BossRules.TREANT_RANGE = 400   -- studs from the Treant
BossRules.KING_RANGE = 200     -- studs from the arena centre
BossRules.MIN_SHARE = 0.02     -- 2% of all damage
BossRules.MIN_HITS = 12        -- or this many hits (~5 s of chopping with 1 blade)

local function flat(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- entries: { { pos = Vector3|{X,Z}|nil, power = number } }. Returns (count, totalPower)
function BossRules.InRange(entries, center, range)
	local n, power = 0, 0
	for _, e in ipairs(entries) do
		if e.pos and flat(e.pos, center) <= range then
			n += 1
			power += (tonumber(e.power) or 5)
		end
	end
	return n, power
end

-- shares: { [uid] = damage }, hits: { [uid] = count }
-- Returns ranked eligible list { {uid, dmg, share} } (best first), the ineligible
-- list (same shape) and the total damage
function BossRules.Rank(shares, hits)
	local total = 0
	for _, v in pairs(shares) do total += v end
	local eligible, ineligible = {}, {}
	for uid, v in pairs(shares) do
		local share = v / math.max(total, 1)
		local e = { uid, v, share }
		if share >= BossRules.MIN_SHARE or (hits[uid] or 0) >= BossRules.MIN_HITS then
			table.insert(eligible, e)
		else
			table.insert(ineligible, e)
		end
	end
	table.sort(eligible, function(x, y) return x[2] > y[2] end)
	return eligible, ineligible, total
end

return BossRules
