-- PlaytimeGifts (M0.1, H6): playtime-gift progress stored in the profile.
--
-- M0 tracked gifts per SERVER VISIT in server memory, so every rejoin (and
-- every AFK server hop) restarted the ladder: rejoining every 10 minutes paid
-- the 5- and 10-minute gifts again and again.
--
-- Now a "visit" lives in the profile (d.Playtime) and survives server hops:
--   * rejoining within RESUME_WINDOW of the last recorded playtime CONTINUES
--     the same visit (progress and claimed gifts kept) - this covers AFK hops,
--     disconnects and quick rejoins
--   * a longer break starts a new visit (fresh ladder, as before), but only
--     MAX_VISITS visits per UTC day can pay gifts; after that the ladder is
--     shown as done until tomorrow
-- Gifts already claimed are never re-paid within a visit, and earned rewards
-- are not taken away: a reached gift stays claimable for the rest of its visit.
-- Pure logic (state table + times passed in) so it is unit-testable.

local P = {}
P.RESUME_WINDOW = 1800 -- seconds: gap that still counts as the same visit
P.MAX_VISITS = 3       -- visits per UTC day that can pay gifts

function P.Default()
	return { Seconds = 0, Claimed = {}, LastSeen = 0, Day = 0, Visits = 0 }
end

local function norm(state)
	state.Seconds = math.max(0, math.floor(tonumber(state.Seconds) or 0))
	state.LastSeen = tonumber(state.LastSeen) or 0
	state.Day = tonumber(state.Day) or 0
	state.Visits = math.max(0, math.floor(tonumber(state.Visits) or 0))
	if type(state.Claimed) ~= "table" then state.Claimed = {} end
end

-- Called when the profile is loaded in a server. Returns "resumed" | "new" | "capped"
function P.Begin(state, now, dayKey)
	norm(state)
	if state.LastSeen > 0 and now - state.LastSeen <= P.RESUME_WINDOW and now >= state.LastSeen then
		state.LastSeen = now
		return "resumed"
	end
	if state.Day ~= dayKey then
		state.Day = dayKey
		state.Visits = 0
	end
	state.Visits += 1
	state.Seconds = 0
	state.Claimed = {}
	state.LastSeen = now
	return state.Visits > P.MAX_VISITS and "capped" or "new"
end

-- add played seconds (called once a minute while the player is in game)
function P.Tick(state, seconds, now)
	norm(state)
	state.Seconds += seconds
	state.LastSeen = now
end

function P.Capped(state)
	return (tonumber(state.Visits) or 0) > P.MAX_VISITS
end

-- index i into gifts (Config.PlaytimeGifts). Returns ok, reason
function P.CanClaim(state, i, gifts)
	norm(state)
	local g = type(i) == "number" and gifts[i] or nil
	if not g then return false, "?" end
	if P.Capped(state) then return false, "Playtime gifts are done for today - back tomorrow!" end
	if state.Claimed[tostring(i)] then return false, "Already claimed" end
	if state.Seconds < g.Minutes * 60 then return false, "Not yet!" end
	return true
end

function P.Claim(state, i, gifts)
	local ok, why = P.CanClaim(state, i, gifts)
	if not ok then return false, why end
	state.Claimed[tostring(i)] = true -- string keys: safe in JSON/DataStore
	return true
end

-- indices claimed in this visit (for the client's GiftsClaimed attribute)
function P.ClaimedList(state, gifts)
	local parts = {}
	for i = 1, #gifts do
		if P.Capped(state) or (type(state.Claimed) == "table" and state.Claimed[tostring(i)]) then table.insert(parts, tostring(i)) end
	end
	return table.concat(parts, ",")
end

return P
