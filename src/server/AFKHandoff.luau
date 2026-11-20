-- AFKHandoff (M0.1, M1): the anti-idle server hop as a safe lock handoff.
--
-- Old flow (M0): save WITHOUT releasing, teleport, and let the new server wait
-- up to 45 s for PlayerRemoving to release the lock; a failed release meant a
-- kick and up to 300 s lockout.
--
-- New flow:
--   1. the hop is allowed at most once per MIN_INTERVAL seconds per player
--      (and not in the first MIN_INTERVAL seconds after joining)
--   2. HandoffRelease: rewards stop (attribute "Handoff"), a CONFIRMED final
--      save releases the session lock. If it is not confirmed, nothing
--      happens: the player simply stays in this server.
--   3. teleport. The new server acquires the already-released lock at once.
--   4. teleport fails (immediately, or later via TeleportInitFailed) ->
--      ResumeAfterHandoff re-acquires the lock if nobody wrote since.
--
-- The client's session table is display-only (AFK panel stats). It is
-- sanitised before it is put in TeleportData and is NEVER used for rewards.

local AFKHandoff = {}
AFKHandoff.MIN_INTERVAL = 300 -- seconds

local MAX_NEW = 40

-- Returns a safe copy of the client's AFK session stats (display only).
function AFKHandoff.Sanitize(session, weaponById, now)
	now = now or os.time()
	local out = { Rolls = 0, Logs = 0, Souls = 0, BestOneIn = 0, New = {} }
	if type(session) ~= "table" then
		out.Start = now
		return out
	end
	local function num(v, lo, hi)
		v = tonumber(v)
		if not v or v ~= v or v == math.huge or v == -math.huge then return lo end
		return math.clamp(math.floor(v), lo, hi)
	end
	local start = tonumber(session.Start)
	out.Start = (start and start == start and math.abs(start) ~= math.huge) and math.clamp(math.floor(start), now - 7 * 86400, now) or now
	out.Rolls = num(session.Rolls, 0, 1e7)
	out.Logs = num(session.Logs, 0, 1e15)
	out.Souls = num(session.Souls, 0, 1e9)
	out.BestOneIn = num(session.BestOneIn, 0, 1e10)
	if type(session.BestId) == "string" and #session.BestId <= 40 and weaponById[session.BestId] then
		out.BestId = session.BestId
	end
	if type(session.New) == "table" then
		for _, id in ipairs(session.New) do
			if #out.New >= MAX_NEW then break end
			if type(id) == "string" and #id <= 40 and weaponById[id] then table.insert(out.New, id) end
		end
	end
	return out
end

-- deps = {
--   now() -> seconds, joinedAt(player) -> seconds, lastHop(player) -> seconds|nil,
--   setLastHop(player, t), release(player) -> ok, why,
--   teleport(player, teleportData) -> ok, err, resume(player) -> ok, why,
--   log(msg) }
-- Returns status: "too_soon" | "release_failed" | "teleported" | "resumed" | "resume_failed"
function AFKHandoff.Run(player, session, deps)
	local now = deps.now()
	if now - (deps.joinedAt(player) or now) < AFKHandoff.MIN_INTERVAL then return "too_soon" end
	local last = deps.lastHop(player)
	if last and now - last < AFKHandoff.MIN_INTERVAL then return "too_soon" end
	deps.setLastHop(player, now)
	local ok, why = deps.release(player)
	if not ok then
		deps.log("handoff save not confirmed (" .. tostring(why) .. "): player stays in this server")
		return "release_failed"
	end
	local tok, terr = deps.teleport(player, { ResumeAFK = true, Session = session })
	if tok then return "teleported" end
	deps.log("teleport failed: " .. tostring(terr) .. " - re-acquiring the profile")
	local rok = deps.resume(player)
	return rok and "resumed" or "resume_failed"
end

return AFKHandoff
