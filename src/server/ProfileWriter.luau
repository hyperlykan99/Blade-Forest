-- ProfileWriter (M0.1, H2/M1): one serialized writer per loaded profile.
--
-- * Saves run strictly one at a time, first come first served. A save starts
--   only after every earlier save of the same profile has RETURNED, and it
--   copies the profile at the moment it starts, so it always carries the
--   newest data. There is no timed fall-through: an overlapping write is
--   impossible by construction (fixes the M0 30-second wait in SaveNow).
-- * Every successful write increments a sequence number that SessionStore
--   persists as `_WriteSeq` and fences on (an older write is refused as
--   "stale"). That is the second, persistent line of defence.
-- * Handoff() is a confirmed final save that releases the session lock (AFK
--   server hop). After it, nothing is written until Resume() re-acquires the
--   lock, which only succeeds if nobody else wrote in between.
--
-- opts = { sessions = SessionStore, key = string, data = profile table,
--          seq = number (stored _WriteSeq at load), wait = fn, clock = fn,
--          maxQueueWait = seconds }

local ProfileWriter = {}
ProfileWriter.__index = ProfileWriter
ProfileWriter.MAX_QUEUE_WAIT = 120 -- a queued save gives up (without writing) after this

function ProfileWriter.new(opts)
	local self = setmetatable({}, ProfileWriter)
	self.sessions = opts.sessions
	self.key = opts.key
	self.data = opts.data
	self.seq = tonumber(opts.seq) or tonumber(opts.data and opts.data._WriteSeq) or 0
	self.wait = opts.wait or task.wait
	self.clock = opts.clock or os.clock
	self.maxQueueWait = opts.maxQueueWait or ProfileWriter.MAX_QUEUE_WAIT
	self.nextTicket = 1
	self.serving = 1
	self.abandoned = {}
	self.lost = false     -- another session owns the key, or a newer write exists
	self.released = false -- our final (release) write succeeded; no more writes
	self.writes = 0       -- successful writes (diagnostics/tests)
	return self
end

-- number of saves queued or in flight
function ProfileWriter:Pending()
	return self.nextTicket - self.serving
end

function ProfileWriter:_advance()
	self.serving += 1
	while self.abandoned[self.serving] do
		self.abandoned[self.serving] = nil
		self.serving += 1
	end
end

-- Save the current profile. release = true also releases the session lock.
-- Returns ok (true only when the DataStore confirmed this write), status
--   status: "ok" | "lost" | "stale" | "released" | "error" | "queue_timeout"
function ProfileWriter:Save(release)
	if self.lost then return false, "lost" end
	if self.released then return false, "released" end
	local ticket = self.nextTicket
	self.nextTicket += 1
	local t0 = self.clock()
	while self.serving ~= ticket do
		if self.clock() - t0 > self.maxQueueWait then
			self.abandoned[ticket] = true -- skipped later; never written
			return false, "queue_timeout"
		end
		self.wait(0.05)
	end
	local okCall, status, err = pcall(function()
		if self.lost then return "lost" end
		if self.released then return "released" end
		local seq = self.seq + 1
		local st, e = self.sessions:Write(self.key, self.data, release, seq)
		if st == "ok" then
			self.seq = seq
			self.data._WriteSeq = seq
			self.writes += 1
			if release then self.released = true end
		elseif st == "lost" or st == "stale" then
			-- someone else owns the profile, or a newer write already landed:
			-- this server's copy must never be written again
			self.lost = true
		end
		return st, e
	end)
	self:_advance()
	if not okCall then return false, "error", status end
	return status == "ok", status, err
end

-- AFK hop (M1): confirmed final save + lock release.
function ProfileWriter:Handoff()
	return self:Save(true)
end

-- After a failed teleport: take the lock back, but only if the record is
-- exactly what we released (same write sequence). Returns
--   "ok" | "conflict" (someone else wrote; lock handed back untouched, writer
--   marked lost) | "locked" | "corrupt" | "error" | "invalid"
function ProfileWriter:Resume()
	if self.lost or not self.released then return "invalid" end
	local st, data, info = self.sessions:Acquire(self.key)
	if st ~= "ok" then return st end
	if (info and info.Seq or -1) ~= self.seq then
		-- another server loaded and saved this profile after our release:
		-- give the lock back without changing anything and never write again
		self.sessions:Write(self.key, data or {}, true)
		self.lost = true
		return "conflict"
	end
	self.released = false
	return "ok"
end

return ProfileWriter
