local Players=game:GetService("Players")
local Policy=game:GetService("PolicyService")
local Http=game:GetService("HttpService")
local Flags=require(script.Parent:WaitForChild("M7Flags"))
local Items=require(script.Parent:WaitForChild("M7Items"))
local Journal=require(script.Parent:WaitForChild("M7Journal"))
local Data=require(script.Parent:WaitForChild("DataService"))
local T={}
local requests,sessions,spam={},{},{}
local function usable(p)
	return p and p.Parent==Players and Data.IsActive(p) and Data.CanPersist(p)
		and not p:GetAttribute("Handoff") and not p:GetAttribute("M5Run") and Data.Get(p).M7.Trade.Enabled
end
local function select(p,selection)
	if not usable(p) or not selection then return end
	return Items.Select(Data.Get(p),selection.Kind,selection.Id)
end
local function exact(original,current)
	if not original or not current then return false end
	for k,value in pairs(original) do if current[k]~=value then return false end end
	return true
end
local function fingerprint(d)
	local parts={"equip:"..tostring(d.Equipped)}
	for id,weapon in pairs(d.Weapons) do
		local guid=d.M6.ItemByWeapon[id]
		local item=guid and d.WeaponItems[guid]
		table.insert(parts,string.format("%s:%d:%d:%s:%s:%d",id,weapon.Copies or 0,weapon.Star or 0,
			tostring(weapon.Shiny),tostring(d.Favorites[id]),item and item.Stage or 0))
	end
	for _,name in ipairs({"Pets","PetGolden","PetRainbow"}) do
		for id,n in pairs(d[name]) do table.insert(parts,name..":"..id..":"..n) end
	end
	for key,item in pairs(d.M7.Vault) do table.insert(parts,"slot:"..key..":"..item.Guid) end
	for i,id in ipairs(d.EquippedPets) do table.insert(parts,"pet:"..i..":"..id) end
	table.sort(parts)
	return table.concat(parts,"|")
end
local function unchanged(s,p)
	return exact(s.Offers[p],select(p,s.Offers[p])) and s.Starts[p]==fingerprint(Data.Get(p))
end
local function close(s)
	for _,p in ipairs(s.People) do if sessions[p]==s then sessions[p]=nil end end
	s.Closed=true
end
local function allowed(p)
	local okay,policy=pcall(Policy.GetPolicyInfoForPlayerAsync,Policy,p)
	return okay and type(policy)=="table" and policy.IsPaidItemTradingAllowed==true
end
local function settle(s,record)
	if not record then return end
	for _,p in ipairs(s.People) do
		local d=Data.Get(p)
		if d and Data.CanPersist(p) and d.M7.Trade.Pending and d.M7.Trade.Pending.Id==record.Id then
			if Items.Settle(d,p.UserId,record) then Data.RefreshM6(p) else p:Kick("Trade settlement is temporarily unavailable. Rejoin to recover your inventory.") end
			task.spawn(Data.SaveNow,p,false)
		end
	end
end
local function commit(s)
	-- Policy calls can yield. Check the session and offer again before taking inventory.
	for _,p in ipairs(s.People) do if not usable(p) or not allowed(p) then close(s) return end end
	if s.Closed then return end
	local offers={}
	for _,p in ipairs(s.People) do
		local offer=s.Offers[p]
		if not unchanged(s,p) then close(s) return end
		offers[tostring(p.UserId)]={Owner=p.UserId,Kind=offer.Kind,Id=offer.Id,Serial=offer.Serial}
	end
	local id=Http:GenerateGUID(false)
	s.Committing=true
	local record=Journal.Create(id,offers,os.time())
	if not record then close(s) return end
	-- All inventory changes and pending markers are staged synchronously.
	local valid=true
	for _,p in ipairs(s.People) do
		if not unchanged(s,p) or sessions[p]~=s or s.Cancelled then valid=false end
	end
	local aa,bb=offers[tostring(s.People[1].UserId)],offers[tostring(s.People[2].UserId)]
	if valid then
		valid=(aa.Id~=bb.Id or aa.Kind~=bb.Kind)
			and Items.CanReceive(Data.Get(s.People[1]),bb) and Items.CanReceive(Data.Get(s.People[2]),aa)
	end
	if valid then
		for _,p in ipairs(s.People) do
			local d=Data.Get(p)
			local item=offers[tostring(p.UserId)]
			Items.Escrow(d,item)
			d.M7.Trade.Pending={Id=id,Item=item,Incoming=item==aa and bb or aa}
			Data.Sync(p)
		end
		for _,p in ipairs(s.People) do
			if s.Cancelled or not Data.SaveNow(p,false) then valid=false break end
			record=Journal.Decide(id,"Prepared",p.UserId)
			if not record or record.State=="Aborted" then valid=false break end
		end
	end
	if not valid then record=Journal.Decide(id,"Abort") end
	if record and record.State~="Preparing" then settle(s,record)
	else
		-- Ambiguous responses can follow a successful CAS. Keep the durable escrow
		-- and force normal session recovery before this user can trade again.
		for _,p in ipairs(s.People) do
			local d=Data.Get(p)
			if p.Parent and d and d.M7.Trade.Pending then p:Kick("Trade confirmation is pending. Rejoin to reconcile your inventory.") end
		end
	end
	close(s)
end
local function begin(s)
	if s.End or s.Committing then return end
	s.End=workspace:GetServerTimeNow()+5
	task.spawn(function()
		repeat
			for _,p in ipairs(s.People) do
				if not unchanged(s,p) then close(s) return end
			end
			task.wait(.15)
		until s.Closed or not s.End or workspace:GetServerTimeNow()>=s.End
		if not s.Closed and s.End then commit(s) end
	end)
end
function T.View(p,d)
	local s=sessions[p]
	local r=requests[p]
	local view={Execution=Flags.TradeExecution,Enabled=d.M7.Trade.Enabled,History=d.M7.Trade.History,
		Request=r and r.Deadline>os.clock() and r.From.UserId or nil}
	if s then
		local function viewOffer(offer)
			if not offer then return nil end
			local result=table.clone(offer)
			result.Serial=nil
			return result
		end
		for _,member in ipairs(s.People) do
			if member~=p then view.Peer=member.UserId view.Theirs=viewOffer(s.Offers[member]) view.PeerReady=s.Ready[member]==true end
		end
		view.Ours=viewOffer(s.Offers[p]) view.Ready=s.Ready[p]==true view.End=s.End view.Settling=s.Committing
	end
	return view
end
function T.Action(p,action,a,b)
	local d=Data.Get(p)
	if not d then return false,"Profile unavailable" end
	local s=sessions[p]
	if action=="TradeSetting" then
		if type(a)~="boolean" then return false,"Invalid setting" end
		d.M7.Trade.Enabled=a
		if not a and s and not s.Committing then close(s) end
		Data.Sync(p) return true
	end
	if not Flags.TradeExecution then return false,"Trade execution is disabled" end
	if not usable(p) then return false,"Trade unavailable" end
	if action=="TradeAsk" then
		local peer=type(a)=="number" and Players:GetPlayerByUserId(a)
		if not usable(peer) or p==peer or s or sessions[peer] or (spam[p] or 0)>os.clock() then return false,"Trade request unavailable" end
		local previous=requests[peer]
		if previous and previous.Deadline>os.clock() then return false,"That player has a pending request" end
		spam[p]=os.clock()+12 requests[peer]={From=p,Deadline=os.clock()+30}
		return true
	elseif action=="TradeAccept" or action=="TradeDecline" then
		local r=requests[p]
		if not r or r.From.UserId~=a or r.Deadline<=os.clock() then return false,"Request expired" end
		requests[p]=nil
		if action=="TradeDecline" then return true end
		if s or sessions[r.From] or not usable(r.From) then return false,"Request unavailable" end
		s={People={r.From,p},Offers={},Ready={},Starts={}}
		sessions[p]=s sessions[r.From]=s
		return true
	end
	if not s or s.Committing then return false,"No editable trade" end
	if action=="TradeCancel" then close(s) return true end
	if s.End then return false,"Final countdown is active" end
	if action=="TradeOffer" then
		if (a~="Weapon" and a~="Pet") or type(b)~="string" then return false,"Select an eligible item" end
		local offer=Items.Select(d,a,b)
		if not offer then return false,"Item unavailable for trade" end
		s.Offers[p]=offer table.clear(s.Ready) table.clear(s.Starts) return true
	elseif action=="TradeConfirm" then
		for _,member in ipairs(s.People) do if not exact(s.Offers[member],select(member,s.Offers[member])) then
			table.clear(s.Ready) table.clear(s.Starts) return false,"Inventory changed. Refresh the offer."
		end end
		for member in pairs(s.Ready) do
			if s.Starts[member]~=fingerprint(Data.Get(member)) then
				table.clear(s.Ready) table.clear(s.Starts)
				return false,"Inventory changed. Confirm both offers again."
			end
		end
		local left,right=s.Offers[s.People[1]],s.Offers[s.People[2]]
		if left.Id==right.Id and left.Kind==right.Kind then return false,"Choose different items" end
		if not Items.CanReceive(Data.Get(s.People[1]),right) or not Items.CanReceive(Data.Get(s.People[2]),left) then
			return false,"A recipient has reached their tracked-copy limit for this item"
		end
		s.Starts[p]=fingerprint(Data.Get(p))
		s.Ready[p]=true
		for _,member in ipairs(s.People) do if not s.Ready[member] then return true end end
		begin(s) return true
	end
	return false,"Unknown trade operation"
end
Players.PlayerRemoving:Connect(function(p)
	local s=sessions[p]
	if s then
		if s.Committing then s.Cancelled=true else close(s) end
	end
	requests[p]=nil spam[p]=nil
	for recipient,r in pairs(requests) do if r.From==p then requests[recipient]=nil end end
end)
return T
