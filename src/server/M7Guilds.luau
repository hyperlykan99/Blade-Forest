local Stores=game:GetService("DataStoreService")
local Http=game:GetService("HttpService")
local Text=game:GetService("TextService")
local RS=game:GetService("ReplicatedStorage")
local D=require(RS:WaitForChild("M7Design"))
local store=Stores:GetDataStore("BladeForest_M7_Guilds_v1")
local board=Stores:GetOrderedDataStore("BladeForest_M7_GuildXP_v1")
local G={}
local function read(key)
	return pcall(store.GetAsync,store,key)
end
local function update(key,fn)
	return pcall(store.UpdateAsync,store,key,fn)
end
local function current(key)
	local value
	local ok=update(key,function(old) value=old return nil end)
	return ok,value
end
local function guildKey(id) return "G:"..id end
local function memberKey(uid) return "M:"..uid end
local function now() return os.time() end
local function count(map)
	local n=0
	for _ in pairs(map) do n+=1 end
	return n
end
local function log(g,action,actor,target,at)
	table.insert(g.Audit,1,{Action=action,Actor=actor,Target=target,At=at})
	if #g.Audit>40 then table.remove(g.Audit) end
end
local function role(g,uid)
	return g.Members[tostring(uid)] and g.Members[tostring(uid)].Role
end
local function manages(r) return r=="Owner" or r=="Officer" end
local function active(g) return type(g)=="table" and not g.Closed end
local function idValid(id) return type(id)=="string" and #id==32 and not id:find("[^a-f0-9]") end
local function uidValid(uid) return type(uid)=="number" and uid%1==0 and uid>0 and uid<1e15 end

local function clearPointer(uid,token)
	-- A tombstone is preferable to RemoveAsync because removal has no compare-and-swap.
	update(memberKey(uid),function(current)
		if current and current.Token==token then return {State="Empty"} end
		return current
	end)
end
local function publish(g)
	local score=g.Closed and 0 or g.XP+1
	task.spawn(function()
		pcall(board.UpdateAsync,board,g.Id,function(prev)
			-- XP only moves forward. Closed records are filtered when rendering.
			return math.max(score,prev or 0)
		end)
	end)
end

local function resolve(uid,claim)
	local key,at=tostring(uid),now()
	local ok,g=update(guildKey(claim.Guild),function(current)
		if not current and claim.Mode=="Create" then
			return {Schema=1,Id=claim.Guild,Name=claim.Name,Description=claim.Description,XP=0,Created=at,
				Members={[key]={Role="Owner",Token=claim.Token,Joined=at}},Invites={},Requests={},Audit={
					{Action="Created",Actor=uid,At=at}},Weekly={Key=-1,Totals={},Credits={},Completed={}}}
		end
		if not active(current) then return current end
		local existing=current.Members[key]
		if existing then return current end
		local invite=current.Invites[key]
		if claim.Mode~="Join" or not invite or invite<at or count(current.Members)>=D.GuildSize then return current end
		current.Members[key]={Role="Member",Token=claim.Token,Joined=at}
		current.Invites[key]=nil current.Requests[key]=nil
		log(current,"Joined",uid,nil,at)
		return current
	end)
	if not ok then return nil,"Guild storage is busy. Your membership request is recoverable." end
	local member=active(g) and g.Members[key]
	if not member or member.Token~=claim.Token then
		clearPointer(uid,claim.Token)
		return nil,"Invitation expired or this guild has no room"
	end
	local done,new=update(memberKey(uid),function(current)
		if current and current.Token==claim.Token then return {Guild=claim.Guild,Token=claim.Token,State="Member"} end
		return current
	end)
	if not done or not new or new.Token~=claim.Token then return nil,"Guild membership is synchronizing" end
	publish(g)
	return g
end
function G.Membership(uid)
	local ok,claim=current(memberKey(uid))
	if not ok then return nil,"Guild storage unavailable" end
	if not claim or claim.State=="Empty" then return nil end
	if claim.State=="Pending" then return resolve(uid,claim) end
	local found,g=current(guildKey(claim.Guild))
	if not found then return nil,"Guild storage unavailable" end
	local row=active(g) and g.Members[tostring(uid)]
	if not row or row.Token~=claim.Token then clearPointer(uid,claim.Token) return nil end
	return g
end
local function claim(uid,id,mode,name,description)
	local token=Http:GenerateGUID(false)
	local proposed={State="Pending",Guild=id,Token=token,Mode=mode,Name=name,Description=description}
	local previously,issue=G.Membership(uid)
	if previously or issue then return false,issue or "Leave your current guild first" end
	local ok,current=update(memberKey(uid),function(old)
		if old and old.State~="Empty" then return old end
		return proposed
	end)
	if not ok or not current then return false,"Guild storage unavailable" end
	if current.Token~=token then return false,"A membership is already being processed" end
	local g,msg=resolve(uid,current)
	return g~=nil,g or msg
end
local function filtered(s,uid,limit,allowEmpty)
	if type(s)~="string" or #s>limit then return nil end
	s=s:match("^%s*(.-)%s*$")
	if s=="" then if allowEmpty then return s end return nil end
	local okay,out=pcall(function()
		return Text:FilterStringAsync(s,uid,Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	if okay and type(out)=="string" then return out end
end
local function change(id,fn)
	if not idValid(id) then return false,"Enter a valid guild code" end
	local outcome,reason
	local ok,g=update(guildKey(id),function(old)
		outcome=false reason="Guild unavailable"
		if not active(old) then return nil end
		outcome,reason=fn(old)
		return outcome and old or nil
	end)
	if not ok then return false,"Guild storage unavailable" end
	return outcome==true,outcome and g or reason
end
local textRate,applyRate={},{}
game.Players.PlayerRemoving:Connect(function(p) textRate[p.UserId]=nil applyRate[p.UserId]=nil end)
function G.Action(p,op,a,b)
	local uid=p.UserId
	local key=tostring(uid)
	local at=now()
	if op=="GuildCreate" or op=="GuildEdit" then
		if (textRate[uid] or 0)>at then return false,"Guild text can be edited once a minute" end
		textRate[uid]=at+60
		local ok,policy=pcall(game:GetService("PolicyService").GetPolicyInfoForPlayerAsync,game:GetService("PolicyService"),p)
		if not ok or type(policy)~="table" or policy.IsContentSharingAllowed~=true then return false,"Guild text sharing is unavailable for this account" end
		local name=filtered(a,uid,32,false)
		local desc=filtered(b,uid,140,true)
		if not name or not desc or #name<3 or not name:find("[%w\128-\255]") then return false,"Enter a guild name and description that pass Roblox filtering" end
		if op=="GuildCreate" then
			local id=(Http:GenerateGUID(false):gsub("-",""))
			return claim(uid,id,"Create",name,desc)
		end
		local g=G.Membership(uid)
		if not g then return false,"No guild membership" end
		return change(g.Id,function(doc)
			if role(doc,uid)~="Owner" then return false,"Only the owner can edit the guild" end
			doc.Name=name doc.Description=desc log(doc,"Profile edited",uid,nil,at)
			return true
		end)
	elseif op=="GuildJoin" then
		if not idValid(a) then return false,"Enter a valid guild code" end
		return claim(uid,a,"Join")
	elseif op=="GuildApply" then
		if (applyRate[uid] or 0)>at then return false,"Wait before sending another application" end
		applyRate[uid]=at+15
		local already,err=G.Membership(uid)
		if already or err then return false,err or "Leave your current guild first" end
		return change(a,function(g)
			for applicant,expiry in pairs(g.Requests) do if expiry<at then g.Requests[applicant]=nil end end
			if g.Requests[key] or count(g.Requests)>=60 or count(g.Members)>=D.GuildSize then return false,"Application already pending or list is full" end
			g.Requests[key]=at+604800 log(g,"Application submitted",uid,nil,at)
			return true
		end)
	end
	local g,err=G.Membership(uid)
	if not g then return false,err or "No guild membership" end
	if op~="GuildLeave" and not uidValid(a) then return false,"Select a player" end
	local target=tostring(a)
	local departed
	local okay,result=change(g.Id,function(doc)
		departed=nil
		local mine=role(doc,uid)
		local theirs=role(doc,a)
		if not mine then return false,"You are no longer a guild member" end
		if op=="GuildLeave" then
			if mine=="Owner" and count(doc.Members)>1 then return false,"Transfer leadership before leaving" end
			departed={User=uid,Token=doc.Members[key].Token}
			doc.Members[key]=nil
			if mine=="Owner" then doc.Closed=true end
		elseif op=="GuildInvite" or op=="GuildApprove" or op=="GuildReject" then
			if not manages(mine) or theirs then return false,"Action requires an officer and a non-member" end
			for applicant,expiry in pairs(doc.Invites) do if expiry<at then doc.Invites[applicant]=nil end end
			if op~="GuildInvite" and (doc.Requests[target] or 0)<at then return false,"This application expired" end
			if op~="GuildReject" then
				if count(doc.Invites)>=60 or count(doc.Members)>=D.GuildSize then return false,"Guild or invitations full" end
				if doc.Invites[target] then return false,"This player already has an invitation" end
				doc.Invites[target]=at+604800
			end
			doc.Requests[target]=nil
		elseif op=="GuildKick" and a~=uid and (mine=="Owner" and theirs or mine=="Officer" and theirs=="Member") then
			departed={User=a,Token=doc.Members[target].Token}
			doc.Members[target]=nil
		elseif op=="GuildRole" and mine=="Owner" and a~=uid and theirs and (b=="Officer" or b=="Member") then
			if b==theirs then return false,"Role already set" end
			doc.Members[target].Role=b
		elseif op=="GuildTransfer" and mine=="Owner" and a~=uid and theirs then
			doc.Members[key].Role="Member" doc.Members[target].Role="Owner"
		else
			return false,"You do not have permission for this guild action"
		end
		log(doc,op,uid,a,at)
		return true
	end)
	if okay and departed then clearPointer(departed.User,departed.Token) end
	if okay and (op=="GuildInvite" or op=="GuildApprove") then
		update("I:"..target,function(old)
			old=old or {}
			for id,row in pairs(old) do if row.Expires<at then old[id]=nil end end
			if count(old)<20 or old[g.Id] then old[g.Id]={Name=g.Name,Expires=at+604800} end
			return old
		end)
	end
	return okay,result
end
function G.Snapshot(g,uid)
	if not active(g) then return end
	local orders={}
	local members={}
	local week=g.Weekly.Key==D.Week(now()) and g.Weekly or {Totals={},Credits={},Completed={}}
	for key,row in pairs(g.Members) do
		table.insert(members,{User=tonumber(key),Role=row.Role,Contribution=week.Credits[key] or {}})
	end
	for _,contract in ipairs(D.Contracts) do
		table.insert(orders,{Id=contract.Key,Name=contract.Name,Target=contract.Target,Count=week.Totals[contract.Key] or 0,
			Done=week.Completed[contract.Key]==true,XP=contract.XP})
	end
	local show=manages(role(g,uid))
	return {Id=g.Id,Name=g.Name,Description=g.Description,Level=D.GuildLevel(g.XP),XP=g.XP,Members=members,Contracts=orders,
		Role=role(g,uid),Requests=show and g.Requests or nil,Audit=show and g.Audit or nil}
end

function G.Record(d,kind,amount,tag)
	local member=d.M7.GuildWeek
	local week=D.Week(now())
	if not d.M7.ActiveGuild or d.M7.ActiveGuild~=tag then return end
	if member.Key~=week or member.Guild~=tag then
		member={Key=week,Guild=tag,Values={}} d.M7.GuildWeek=member
	end
	for _,c in ipairs(D.Contracts) do
		if c.Key==kind then member.Values[kind]=math.min(c.PersonalCap,(member.Values[kind] or 0)+amount) break end
	end
end
function G.Contribute(g,uid,ledger)
	local at=now()
	local wk=D.Week(at)
	if ledger.Key~=wk or ledger.Guild~=g.Id then return g end
	local key=tostring(uid)
	local previous=g.Weekly.Key==wk and g.Weekly.Credits[key]
	local work=false
	for k,v in pairs(ledger.Values) do if v>(previous and previous[k] or 0) then work=true break end end
	if not work then return g end
	local ok,new=change(g.Id,function(doc)
		if not role(doc,uid) then return false,"Membership changed" end
		if doc.Weekly.Key~=wk then doc.Weekly={Key=wk,Totals={},Credits={},Completed={}} end
		local w=doc.Weekly
		local old=w.Credits[key] or {}
		for _,c in ipairs(D.Contracts) do
			local high=math.min(c.PersonalCap,ledger.Values[c.Key] or 0)
			local low=old[c.Key] or 0
			if high>low then
				old[c.Key]=high
				w.Totals[c.Key]=(w.Totals[c.Key] or 0)+high-low
				if w.Totals[c.Key]>=c.Target and not w.Completed[c.Key] then
					w.Completed[c.Key]=true doc.XP+=c.XP
					log(doc,"Weekly contract completed",uid,c.Key,at)
				end
			end
		end
		w.Credits[key]=old
		return true
	end)
	if ok then publish(new) return new end
	return g
end
function G.Inbox(uid)
	local ok,result=read("I:"..uid)
	local rows={}
	if ok and result then
		for id,row in pairs(result) do
			if row.Expires>now() then table.insert(rows,{Id=id,Name=row.Name,Expires=row.Expires}) end
		end
	end
	return rows
end
function G.Inspect(id,uid)
	if not idValid(id) then return nil end
	local ok,g=current(guildKey(id))
	if ok then return G.Snapshot(g,uid) end
end
local boardCache,boardTime={},0
function G.Board()
	if os.clock()<boardTime then return boardCache end
	boardTime=os.clock()+60
	local ok,page=pcall(board.GetSortedAsync,board,false,20)
	if not ok then return boardCache end
	local result={}
	for _,entry in ipairs(page:GetCurrentPage()) do
		local found,g=read(guildKey(entry.key))
		if found and active(g) then
			table.insert(result,{Id=g.Id,Name=g.Name,XP=g.XP,Level=D.GuildLevel(g.XP)})
		end
		if #result==10 then break end
	end
	boardCache=result
	return result
end
return G
