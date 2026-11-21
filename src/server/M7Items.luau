-- Inventory guard shared by old and new consumer paths.
local RS=game:GetService("ReplicatedStorage")
local HTTP=game:GetService("HttpService")
local S=require(RS:WaitForChild("M7Design"))
local C=require(RS:WaitForChild("BladeConfig"))
local I=require(RS:WaitForChild("M6Inventory"))
local M={}
M.Default={Schema=1,Vault={},ItemByWeapon={},Trade={Enabled=true,History={},WeaponCredits={},PetCredits={}},
	Titles={},Auras={},Title="",Aura="",FavoriteWeapon="",PetShowcase="",GuildWeek={Key=-1,Values={}},
	Gifting={Outbox={}}}
function M.Vaulted(d,kind,id)
	if not d.M7 then return false end
	for _,record in pairs(d.M7.Vault) do
		if record.Kind==kind and record.Id==id then return true end
	end
	return false
end
function M.Protected(d,kind,id)
	return M.Vaulted(d,kind,id)
end
function M.Owns(d,kind,id)
	if kind=="Weapon" then return C.WeaponById[id] and d.Weapons[id]~=nil end
	if kind~="Pet" then return false end
	local pet=C.PetById[id]
	if not pet then return false end
	local inventory,key=C.PetInventory(d,pet)
	return inventory and (inventory[key] or 0)>0
end
function M.Move(d,slot,kind,id)
	if type(slot)~="number" or slot%1~=0 or slot<1 or slot>S.VaultSize then return false,"Choose a vault slot" end
	local key=tostring(slot)
	local current=d.M7.Vault[key]
	if not kind then
		if not current then return false,"Slot is empty" end
		d.M7.Vault[key]=nil
		return true
	end
	if current or not M.Owns(d,kind,id) or M.Vaulted(d,kind,id) then return false,"Choose an empty slot and an owned item" end
	local guid
	if kind=="Weapon" then
		guid=d.M6.ItemByWeapon[id]
		if not I.Item(d,id) then
			guid=HTTP:GenerateGUID(false)
			d.WeaponItems[guid]={Schema=1,WeaponId=id,Stage=0,Sockets={},Bound=false,TradeLocked=false}
			d.M6.ItemByWeapon[id]=guid
		end
	else
		guid=HTTP:GenerateGUID(false)
	end
	d.M7.Vault[key]={Kind=kind,Id=id,Guid=guid}
	return true
end
local function credits(d,kind)
	return kind=="Weapon" and d.M7.Trade.WeaponCredits or d.M7.Trade.PetCredits
end
local function append(ledger,id,serial,limit)
	local identities=ledger[id] or {}
	if #identities<(limit or 24) and not table.find(identities,serial) then
		table.insert(identities,serial)
		ledger[id]=identities
	end
end
function M.Credit(d,kind,id,before,after,earned)
	if not d.M7 then return end
	local ledger=credits(d,kind)
	local identities=ledger[id] or {}
	-- Retire tracked identities first when an old mechanic consumes a copy.
	local lost=math.min(#identities,math.max(0,before+(earned and 1 or 0)-after))
	for _=1,lost do table.remove(identities) end
	ledger[id]=#identities>0 and identities or nil
	if earned and after>#identities and after>=before+1 then
		local pending=d.M7.Trade.Pending
		local reserved=false
		if pending then
			for _,item in ipairs({pending.Item,pending.Incoming}) do
				if item.Id==id and item.Kind==kind then reserved=true break end
			end
		end
		append(ledger,id,HTTP:GenerateGUID(false),reserved and 23 or 24)
	end
end
function M.Select(d,kind,id)
	if not d.M7.Trade.Enabled or d.M7.Trade.Pending or M.Vaulted(d,kind,id) then return end
	local identities=credits(d,kind)[id]
	local serial=identities and identities[1]
	if not serial then return end
	if kind=="Weapon" then
		local weapon=C.WeaponById[id]
		local entry=d.Weapons[id]
		local item=weapon and I.Item(d,id)
		if not weapon or weapon.Exclusive or not weapon.Future.Tradeable or not entry or entry.Copies<1
			or d.Equipped==id or d.Favorites[id] or item and (item.Bound or item.TradeLocked) then return end
		return {Kind=kind,Id=id,Count=entry.Copies,Serial=serial,Power=C.GetWeaponPower(id,0),Rarity=weapon.Rarity,
			Star=entry.Star,Shiny=entry.Shiny==true}
	elseif kind=="Pet" then
		local pet=C.PetById[id]
		if not pet or (d.Pets[id] or 0)<1 or table.find(d.EquippedPets,id) then return end
		return {Kind=kind,Id=id,Count=d.Pets[id],Serial=serial,Rarity=pet.Rarity}
	end
end
function M.CanReceive(d,item)
	local identities=credits(d,item.Kind)[item.Id]
	return not identities or #identities<24
end
function M.Escrow(d,item)
	if item.Kind=="Weapon" then d.Weapons[item.Id].Copies-=1 else d.Pets[item.Id]-=1 end
	local ledger=credits(d,item.Kind)
	local identities=ledger[item.Id]
	table.remove(identities,table.find(identities,item.Serial))
	if #identities==0 then ledger[item.Id]=nil end
end
function M.Deliver(d,item)
	if item.Kind=="Weapon" then
		local existing=d.Weapons[item.Id]
		if existing then
			existing.Copies+=1
			append(credits(d,item.Kind),item.Id,item.Serial)
		else
			d.Weapons[item.Id]={Copies=0,Star=0,Pulled=0,Shiny=false}
			d.WeaponItems[item.Serial]={Schema=1,WeaponId=item.Id,Stage=0,Sockets={},TradeLocked=false,Bound=false}
			d.M6.ItemByWeapon[item.Id]=item.Serial
		end
	else
		d.Pets[item.Id]=(d.Pets[item.Id] or 0)+1
		append(credits(d,item.Kind),item.Id,item.Serial)
	end
end
function M.Settle(d,userId,journal)
	local pending=d.M7.Trade.Pending
	if not pending then return true end
	if pending.Id~=journal.Id or journal.State~="Committed" and journal.State~="Aborted" then return false end
	local own=journal.Users[tostring(userId)]
	if not own or own.Serial~=pending.Item.Serial or own.Kind~=pending.Item.Kind or own.Id~=pending.Item.Id then return false end
	local other
	for id,item in pairs(journal.Users) do if id~=tostring(userId) then other=item end end
	if not other then return false end
	local won=journal.State=="Committed"
	M.Deliver(d,won and other or own)
	table.insert(d.M7.Trade.History,1,{Id=journal.Id,State=journal.State,At=journal.Closed,
		With=won and other.Owner or nil,Sent=own.Id,SentSerial=own.Serial,Received=won and other.Id or nil,ReceivedSerial=won and other.Serial or nil})
	if #d.M7.Trade.History>32 then table.remove(d.M7.Trade.History) end
	d.M7.Trade.Pending=nil
	return true
end
return M
