-- MovementGuard (M0.1, H1): server-side movement sanity for chopping credit.
--
-- The character's position is client-owned, so a speed or teleport exploit
-- could sweep a forest and have every tree credited by CombatServer. This
-- module watches horizontal movement over a sliding window and SUSPENDS
-- CHOPPING CREDIT (blade hits) when movement is impossible for the player's
-- real (server-side) WalkSpeed. It never moves, kills or kicks anyone: a
-- false positive only pauses hits for a few seconds.
--
-- Legitimate movement it must accept:
--   * walking/running at Humanoid.WalkSpeed as the SERVER sees it (future
--     Walk Speed upgrades set it on the server, so they are honoured)
--   * jumping and falling (vertical movement is ignored)
--   * network jitter: positions arrive in bursts, so distance is measured
--     over a WINDOW-second window with a fixed slack
--   * server-sanctioned teleports (island travel, area push-back) -> Allow()
--     with origin and destination. The client can take seconds to apply a
--     server teleport (seen on join) and the server's view of the
--     client-owned character then jumps between the old spot, interpolated
--     points and the destination. For MAX_TRANSIT seconds any position on
--     that path is "transit" (no strike, credit only near the destination);
--     the first position OFF the path (the player walking normally) ends it
--   * respawns -> Reset()
--
-- Pure logic: positions, speeds and time are passed in, so the same code runs
-- in tests with synthetic paths.

local MovementGuard = {}
MovementGuard.__index = MovementGuard

MovementGuard.WINDOW = 2.0        -- seconds of history compared
MovementGuard.TOLERANCE = 1.35    -- x WalkSpeed (latency, slopes, physics)
MovementGuard.SLACK = 10          -- studs always allowed on top (bursty replication)
MovementGuard.MIN_SPEED = 16      -- Roblox default WalkSpeed floor
MovementGuard.SUSPEND = 3         -- seconds without chopping credit after a violation
MovementGuard.STRIKES = 5         -- violations within STRIKE_WINDOW ...
MovementGuard.STRIKE_WINDOW = 60
MovementGuard.LONG_SUSPEND = 30   -- ... give a longer suspension
MovementGuard.ARRIVE_RADIUS = 40  -- studs (horizontal): "at the destination" / "on the teleport path"
MovementGuard.MAX_TRANSIT = 10    -- seconds a sanctioned teleport may take to settle on the server

function MovementGuard.new(opts)
	opts = opts or {}
	local self = setmetatable({}, MovementGuard)
	self.window = opts.window or MovementGuard.WINDOW
	self.tolerance = opts.tolerance or MovementGuard.TOLERANCE
	self.slack = opts.slack or MovementGuard.SLACK
	self.minSpeed = opts.minSpeed or MovementGuard.MIN_SPEED
	self.suspend = opts.suspend or MovementGuard.SUSPEND
	self.state = {} -- [key] = { samples = {{t, x, z}}, graceUntil, suspendedUntil, strikes = {t...}, violations }
	self.onViolation = opts.onViolation -- fn(key, distance, allowed, dt)
	return self
end

local function st(self, key)
	local s = self.state[key]
	if not s then
		s = { samples = {}, graceUntil = 0, suspendedUntil = 0, strikes = {}, violations = 0, path = nil, pathUntil = 0 }
		self.state[key] = s
	end
	return s
end

-- forget history (respawn, join): the next position becomes the new baseline
function MovementGuard:Reset(key)
	local s = st(self, key)
	table.clear(s.samples)
end

-- a server-sanctioned teleport is about to happen.
-- With `target` (and `origin`, the position before the move; defaults to the
-- last sample) the move is tracked as a transit path, see Check. Without a
-- target: accept any movement for `seconds` and rebuild the baseline.
function MovementGuard:Allow(key, seconds, now, target, origin)
	local s = st(self, key)
	now = now or os.clock()
	if target then
		local last = s.samples[#s.samples]
		local ox, oz
		if origin then ox, oz = origin.X, origin.Z elseif last then ox, oz = last[2], last[3] else ox, oz = target.X, target.Z end
		s.path = { ox, oz, target.X, target.Z }
		s.pathUntil = now + MovementGuard.MAX_TRANSIT
	else
		s.graceUntil = math.max(s.graceUntil, now + (seconds or 2))
	end
	table.clear(s.samples)
end

-- horizontal distance from (x, z) to the segment (ax, az)-(bx, bz)
local function segDist(x, z, ax, az, bx, bz)
	local vx, vz = bx - ax, bz - az
	local len2 = vx * vx + vz * vz
	local t = len2 > 0 and math.clamp(((x - ax) * vx + (z - az) * vz) / len2, 0, 1) or 0
	local px, pz = ax + vx * t - x, az + vz * t - z
	return math.sqrt(px * px + pz * pz)
end

function MovementGuard:Remove(key)
	self.state[key] = nil
end

-- Record a position and decide whether this player may be credited for hits now.
-- pos: Vector3 (or {X, Z} table in tests); walkSpeed: server-side Humanoid.WalkSpeed
-- Returns ok (bool), reason
function MovementGuard:Check(key, pos, walkSpeed, now)
	local s = st(self, key)
	local x, z = pos.X, pos.Z
	local path = s.path
	if path then
		local R = MovementGuard.ARRIVE_RADIUS
		if now < s.pathUntil and segDist(x, z, path[1], path[2], path[3], path[4]) <= R then
			-- still settling: never a strike; credit only at the destination
			table.clear(s.samples)
			local dx, dz = x - path[3], z - path[4]
			if dx * dx + dz * dz <= R * R and now >= s.suspendedUntil then return true, "arrived" end
			return false, "transit"
		end
		-- off the path (walking normally) or settle time over: fresh baseline here
		s.path = nil
		table.clear(s.samples)
	end
	if now < s.graceUntil then
		table.clear(s.samples)
		table.insert(s.samples, { now, x, z })
		return true, "grace"
	end
	-- drop samples older than the window, keeping the oldest one inside it
	local samples = s.samples
	while #samples > 1 and now - samples[2][1] >= self.window do
		table.remove(samples, 1)
	end
	local ok, reason = true, "ok"
	local base = samples[1]
	if base then
		local dt = math.max(now - base[1], 0)
		local dx, dz = x - base[2], z - base[3]
		local dist = math.sqrt(dx * dx + dz * dz)
		local speed = math.max(tonumber(walkSpeed) or 0, self.minSpeed)
		local allowed = speed * self.tolerance * dt + self.slack
		if dist > allowed then
			-- impossible movement: suspend credit, restart the baseline here
			s.violations += 1
			table.insert(s.strikes, now)
			while #s.strikes > 0 and now - s.strikes[1] > MovementGuard.STRIKE_WINDOW do table.remove(s.strikes, 1) end
			local len = #s.strikes >= MovementGuard.STRIKES and MovementGuard.LONG_SUSPEND or self.suspend
			s.suspendedUntil = math.max(s.suspendedUntil, now + len)
			table.clear(samples)
			if self.onViolation then pcall(self.onViolation, key, dist, allowed, dt) end
			ok, reason = false, "violation"
		end
	end
	table.insert(samples, { now, x, z })
	if ok and now < s.suspendedUntil then
		ok, reason = false, "suspended"
	end
	return ok, reason
end

function MovementGuard:Violations(key)
	local s = self.state[key]
	return s and s.violations or 0
end

-- the one instance shared by CombatServer (Check), TravelService and
-- AreaService (Allow) and character spawns (Reset)
MovementGuard.shared = MovementGuard.new()

return MovementGuard
