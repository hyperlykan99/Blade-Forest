-- SessionStore (M0-A): session-locked persistence on top of a DataStore key.
--
-- One authoritative session per profile key. The lock lives INSIDE the saved
-- record as `_Session`, so the key name and the profile shape stay exactly as
-- before (v3 servers simply ignore the extra field).
--
--   Acquire(key)  -> "ok", data | "locked", info | "corrupt" | "error", err
--   Write(key, data, release, seq) -> "ok" | "lost" | "stale" | "error", err
--
-- Rules
--   * Every read/write goes through UpdateAsync, so the lock check and the
--     write are one atomic step on Roblox's side.
--   * A lock is fresh while now - Lease < LEASE. The owner refreshes Lease on
--     every write (autosave every 60 s), so a live server never loses it.
--   * A stale lock (owner crashed or lost DataStore access for > LEASE) can be
--     taken over. The old owner's next write then sees a foreign session and
--     returns "lost": it never overwrites the newer data.
--   * Release clears `_Session` in the same atomic write as the final save.
--   * M0.1 (H2) write-sequence fence: every profile write may carry a
--     monotonically increasing `seq`, persisted in the record as `_WriteSeq`.
--     A write whose seq is LOWER than the stored one is refused ("stale"), so
--     an older snapshot can never overwrite a newer one, even across servers
--     or after retries. An equal seq is accepted (idempotent retry of the same
--     write). Writes without a seq keep the stored `_WriteSeq` unchanged.
--   * Transient errors retry with bounded exponential backoff. Nothing here
--     ever writes a default/empty profile over an existing one.
--
-- The store and clock are injectable so the same code runs against a mock in
-- tests (ServerStorage.M0Tests) and against the real DataStore in game.

local HttpService = game:GetService("HttpService")

local SessionStore = {}
SessionStore.__index = SessionStore

SessionStore.LEASE = 300            -- seconds a lock stays valid without a refresh
SessionStore.LOCK_RETRIES = 15      -- attempts while another fresh session holds the lock
SessionStore.LOCK_RETRY_WAIT = 3    -- seconds between those attempts (~45 s total)
SessionStore.IO_RETRIES = 4         -- attempts for transient DataStore errors
SessionStore.IO_BACKOFF = { 1, 2, 4, 8 }
SessionStore.MAX_BYTES = 3500000    -- refuse to write a record near the 4 MB key limit

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepCopy(v) end
	return c
end
SessionStore.deepCopy = deepCopy

-- opts: { store = DataStore-like, clock = fn() -> unix seconds, wait = fn(seconds),
--         jobId = string, placeId = number, sessionId = string }
function SessionStore.new(opts)
	local self = setmetatable({}, SessionStore)
	self.store = opts.store
	self.clock = opts.clock or os.time
	self.wait = opts.wait or task.wait
	self.sessionId = opts.sessionId or HttpService:GenerateGUID(false)
	self.jobId = opts.jobId or game.JobId
	self.placeId = opts.placeId or game.PlaceId
	self.lease = opts.lease or SessionStore.LEASE
	self.lockRetries = opts.lockRetries or SessionStore.LOCK_RETRIES
	self.lockRetryWait = opts.lockRetryWait or SessionStore.LOCK_RETRY_WAIT
	self.ioRetries = opts.ioRetries or SessionStore.IO_RETRIES
	self.log = opts.log or function(...) warn("[SessionStore]", ...) end
	return self
end

function SessionStore:_stamp(now)
	return { Id = self.sessionId, Job = self.jobId, Place = self.placeId, Lease = now }
end

function SessionStore:_isForeignFresh(rec, now)
	local s = type(rec) == "table" and rec._Session
	if type(s) ~= "table" then return false end
	if s.Id == self.sessionId then return false end
	return (now - (tonumber(s.Lease) or 0)) < self.lease
end

-- run fn with bounded retries for transient errors; fn returns (ok, ...) via pcall
function SessionStore:_io(label, fn)
	local lastErr
	for attempt = 1, self.ioRetries do
		local ok, err = pcall(fn)
		if ok then return true end
		lastErr = err
		self.log(label .. " failed (attempt " .. attempt .. "): " .. tostring(err))
		if attempt < self.ioRetries then
			self.wait(SessionStore.IO_BACKOFF[attempt] or 8)
		end
	end
	return false, lastErr
end

-- Acquire the session for `key`. Returns:
--   "ok", data (nil for a brand-new profile; `_Session` stripped), info
--   "locked", info   another fresh session still owns it after all retries
--   "corrupt"        the stored value is not a table (left untouched)
--   "error", err     DataStore unavailable after retries
function SessionStore:Acquire(key)
	for lockAttempt = 1, self.lockRetries do
		local status, data, info
		local ok, err = self:_io("Acquire " .. key, function()
			status, data, info = nil, nil, nil
			self.store:UpdateAsync(key, function(old)
				local now = self.clock()
				if old ~= nil and type(old) ~= "table" then
					status = "corrupt"
					return nil -- cancel: never overwrite unreadable data
				end
				if self:_isForeignFresh(old, now) then
					status = "locked"
					info = deepCopy(old._Session)
					return nil -- cancel
				end
				local rec = old or {}
				local prev = type(rec._Session) == "table" and rec._Session or nil
				info = { New = old == nil, TookOverStale = prev ~= nil and prev.Id ~= self.sessionId, Previous = deepCopy(prev) }
				rec._Session = self:_stamp(now)
				status = "ok"
				data = deepCopy(rec)
				return rec
			end)
		end)
		if not ok then return "error", err end
		if status == "ok" then
			data._Session = nil -- `_WriteSeq` stays so the caller continues the sequence
			-- M0.1: the stored write sequence, so a caller starting from a new/empty
			-- record continues the sequence instead of being fenced as "stale"
			info.Seq = tonumber(data._WriteSeq) or 0
			local hasContent = false
			for k in pairs(data) do if k ~= "_WriteSeq" then hasContent = true break end end
			if info.New or not hasContent then data = nil end
			if info.TookOverStale then
				self.log("took over stale session for " .. key .. " (previous job " .. tostring(info.Previous and info.Previous.Job) .. ")")
			end
			return "ok", data, info
		elseif status == "corrupt" then
			return "corrupt"
		elseif status == "locked" then
			if lockAttempt < self.lockRetries then self.wait(self.lockRetryWait) end
		else
			return "error", "UpdateAsync returned without running the transform"
		end
	end
	return "locked"
end

-- Write `data` for `key` only while this session still owns it.
-- release = true clears the lock in the same atomic write.
-- seq (optional, M0.1): monotonic write number; refused if lower than stored.
--   "ok" | "lost" (another session owns the key; nothing written)
--   | "stale" (a newer write already landed; nothing written) | "error", err
function SessionStore:Write(key, data, release, seq)
	local payload = deepCopy(data)
	payload._Session = nil
	payload._WriteSeq = nil
	local okSize, encoded = pcall(HttpService.JSONEncode, HttpService, payload)
	if not okSize then return "error", "profile is not JSON-encodable: " .. tostring(encoded) end
	if #encoded > SessionStore.MAX_BYTES then return "error", "profile too large: " .. #encoded .. " bytes" end

	local status
	local ok, err = self:_io("Write " .. key, function()
		status = nil
		self.store:UpdateAsync(key, function(old)
			local now = self.clock()
			if old ~= nil and type(old) ~= "table" then
				status = "lost"
				return nil
			end
			local s = type(old) == "table" and old._Session or nil
			if type(s) ~= "table" or s.Id ~= self.sessionId then
				-- someone else owns it, or our lock was taken over and released: never overwrite
				status = "lost"
				return nil
			end
			local stored = tonumber(old._WriteSeq) or 0
			if seq ~= nil and seq < stored then
				-- an older snapshot arriving after a newer one: refuse (H2 fence)
				status = "stale"
				return nil
			end
			local rec = deepCopy(payload)
			rec._WriteSeq = (seq ~= nil) and seq or old._WriteSeq
			rec._Session = (not release) and self:_stamp(now) or nil
			status = "ok"
			return rec
		end)
	end)
	if not ok then return "error", err end
	return status or "error", status == nil and "transform not run" or nil
end

-- Write `value` under `key` only if the key is empty (used for one-time
-- pre-migration backups). Returns "written" | "exists" | "error", err, and the
-- value now stored (so the caller can verify it).
function SessionStore:WriteOnce(key, value)
	local status, stored
	local ok, err = self:_io("WriteOnce " .. key, function()
		status, stored = nil, nil
		self.store:UpdateAsync(key, function(old)
			if old ~= nil then
				status = "exists"
				stored = deepCopy(old)
				return nil
			end
			status = "written"
			stored = deepCopy(value)
			return deepCopy(value)
		end)
	end)
	if not ok then return "error", err end
	return status or "error", stored
end

-- Plain read (no lock) used to verify backups.
function SessionStore:Read(key)
	local value
	local ok, err = self:_io("Read " .. key, function()
		value = self.store:GetAsync(key)
	end)
	if not ok then return "error", err end
	return "ok", value
end

return SessionStore
