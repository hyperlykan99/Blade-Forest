-- Ordered stores are week-scoped. A current-server fallback is available when Studio APIs are off.
local DataStoreService=game:GetService("DataStoreService")
local B={}
local servers={}
local cache={}
local function store(week,kind)
	return DataStoreService:GetOrderedDataStore("BladeForest_M5_"..kind,"UTC_"..week)
end
function B.Record(week,kind,uid,value,canPublish)
	if (kind~="Trial" and kind~="Depth") or uid<=0 or value<=0 then return end
	local key=week..":"..kind
	local old=servers[key] or {}
	old[uid]=math.max(old[uid] or 0,value)
	servers[key]=old
	cache[key]=nil
	if canPublish then
		task.spawn(function()
			local ok=pcall(function()
				store(week,kind):UpdateAsync(tostring(uid),function(prior) return math.max(prior or 0,value) end)
			end)
			if not ok then warn("[M5] Weekly leaderboard write unavailable for "..kind) end
		end)
	end
end
function B.Read(week,kind)
	if kind~="Trial" and kind~="Depth" then return nil end
	local key=week..":"..kind
	local existing=cache[key]
	if existing and os.clock()-existing.At<45 then return existing.Data end
	if existing and existing.Busy then return existing.Data end
	local result={Scope="This server",Rows={}}
	cache[key]={At=os.clock(),Data=result,Busy=true}
	local ok,pages=pcall(function() return store(week,kind):GetSortedAsync(false,10) end)
	local values={}
	if ok then
		result.Scope="Weekly global"
		for _,row in ipairs(pages:GetCurrentPage()) do
			local uid=tonumber(row.key)
			if uid then values[uid]=row.value end
		end
	end
	for uid,value in pairs(servers[key] or {}) do values[uid]=math.max(values[uid] or 0,value) end
	for uid,value in pairs(values) do table.insert(result.Rows,{UserId=uid,Value=value}) end
	table.sort(result.Rows,function(a,b) return a.Value==b.Value and a.UserId<b.UserId or a.Value>b.Value end)
	while #result.Rows>10 do table.remove(result.Rows) end
	cache[key]={At=os.clock(),Data=result}
	return result
end
return B
