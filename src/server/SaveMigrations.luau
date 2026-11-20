-- SaveMigrations (M0-B): numbered, idempotent, additive save migrations.
--
-- Rules
--   * A step only ADDS fields. No existing key is renamed or removed.
--   * Each step runs at most once per profile: `_Meta.Applied["<n>"] = true`.
--   * Steps run on a COPY of the profile. Only if every step succeeds is the
--     copy returned; on any error the original table is left untouched and
--     the caller refuses to save (fail closed).
--   * The caller writes a one-time backup of the pre-migration record before
--     the first save at the new version (see DataService).

local SaveMigrations = {}

SaveMigrations.CURRENT = 4

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end

local function nonNegInt(v)
	v = tonumber(v) or 0
	if v ~= v or v < 0 then return 0 end -- NaN / negative
	return math.floor(v)
end

-- step[n] upgrades a profile to version n
SaveMigrations.steps = {
	[4] = function(data)
		-- Future per-item weapon identity (awakening, runes, vault, trading: M6/M7).
		-- Empty in M0. Stacked copies in `Weapons` stay the source of truth.
		if type(data.WeaponItems) ~= "table" then data.WeaponItems = {} end
		-- Weapons whose id is no longer in the catalog are parked here instead of
		-- being deleted on load (the v3 loader dropped them).
		if type(data.RetiredWeapons) ~= "table" then data.RetiredWeapons = {} end
		-- Origin of free Trait Crates, needed for paid-random-item restrictions.
		-- Everything already owned before v4 has unknown origin -> Legacy.
		if type(data.CrateOrigins) ~= "table" then
			data.CrateOrigins = { Earned = 0, Paid = 0, Legacy = nonNegInt(data.FreeCrates) }
		end
		-- Analytics bookkeeping (no personal data). Legacy players do not enter
		-- the new-player onboarding funnel.
		if type(data.Analytics) ~= "table" then
			data.Analytics = { Onboard = {}, Prog = {}, Legacy = true }
		end
		-- Reserved space for later collectible systems (M3/M8). Empty in M0.
		if type(data.Collections) ~= "table" then data.Collections = {} end
		data.Version = 4
	end,
}

-- Returns ok, newData (migrated copy) | ok=false, err
-- `data` is never modified.
function SaveMigrations.Migrate(data)
	if type(data) ~= "table" then return false, "profile is not a table" end
	local work = deepCopy(data)
	if type(work._Meta) ~= "table" then work._Meta = {} end
	if type(work._Meta.Applied) ~= "table" then work._Meta.Applied = {} end
	local from = tonumber(work.Version) or 1
	local applied = {}
	for v = 4, SaveMigrations.CURRENT do
		local key = tostring(v)
		if not work._Meta.Applied[key] then
			local step = SaveMigrations.steps[v]
			if not step then return false, "missing migration step " .. key end
			local ok, err = pcall(step, work)
			if not ok then return false, "step " .. key .. " failed: " .. tostring(err) end
			work._Meta.Applied[key] = true
			table.insert(applied, v)
		end
	end
	if (tonumber(work.Version) or 0) < SaveMigrations.CURRENT then
		return false, "version did not reach " .. SaveMigrations.CURRENT
	end
	work._Meta.MigratedFrom = work._Meta.MigratedFrom or from
	return true, work, applied
end

return SaveMigrations
