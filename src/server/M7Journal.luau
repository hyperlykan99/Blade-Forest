local QA=require(script.Parent:WaitForChild("QAIsolation"))
-- The journal owns the only global decision. M0 owns profile session fencing.
local Store=game:GetService("DataStoreService"):GetDataStore(QA.StoreName("BladeForest_M7_Trades_v1"))
local Items=require(script.Parent:WaitForChild("M7Items"))
local J={}
local function update(id,fn)
	local ok,out=pcall(function() return Store:UpdateAsync(id,fn) end)
	if ok then return out end
end
function J.Change(record,action,userId,now)
	if not record then return nil end
	if record.State~="Preparing" then return record end
	if action=="Abort" or now>=record.Expires then
		record.State="Aborted" record.Closed=now
	elseif action=="Prepared" and record.Users[tostring(userId)] then
		record.Prepared[tostring(userId)]=true
		for uid in pairs(record.Users) do if not record.Prepared[uid] then return record end end
		record.State="Committed" record.Closed=now
	end
	return record
end
function J.Create(id,users,now)
	return update(id,function(previous)
		return previous or {Schema=1,Id=id,State="Preparing",Users=users,Expires=now+90,Prepared={}}
	end)
end
function J.Decide(id,action,uid)
	local now=os.time()
	return update(id,function(previous) return J.Change(previous,action,uid,now) end)
end
function J.Recover(d,uid)
	local pending=d.M7.Trade.Pending
	if not pending then return true end
	local record=J.Decide(pending.Id,"Abort",uid)
	return record~=nil and Items.Settle(d,uid,record)
end
return J
