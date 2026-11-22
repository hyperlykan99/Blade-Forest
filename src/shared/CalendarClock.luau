-- Absolute UTC schedules and engine-relative encounter timers use different clocks.
local Clock={}
Clock.OffsetAttribute="BladeCalendarUTCOffset"
function Clock.UTC()
	local offset=workspace:GetAttribute(Clock.OffsetAttribute)
	if type(offset)=="number" then return workspace:GetServerTimeNow()+offset end
	return os.time()
end
return table.freeze(Clock)
