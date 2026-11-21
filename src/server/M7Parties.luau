local Players=game:GetService("Players")
local D=require(game.ReplicatedStorage:WaitForChild("M7Design"))
local P={}
local membership,invites,cooldowns={},{},{}
local function available(p)
	return p and p.Parent==Players and p:GetAttribute("Loaded") and not p:GetAttribute("Handoff")
end
local function leave(p)
	local party=membership[p]
	if not party then return end
	membership[p]=nil
	p:SetAttribute("M7PartyLeader",nil)
	table.remove(party.Members,table.find(party.Members,p))
	for _,member in ipairs(party.Members) do member:SetAttribute("M7PartyLeader",party.Members[1].UserId) end
end
local function new(p)
	local party={Members={p}}
	membership[p]=party
	p:SetAttribute("M7PartyLeader",p.UserId)
	return party
end
function P.View(p)
	local party=membership[p]
	local members={}
	if party then
		for i,peer in ipairs(party.Members) do
			table.insert(members,{User=peer.UserId,Name=peer.DisplayName,Island=peer:GetAttribute("CurrentIsland"),
				Run=peer:GetAttribute("M5Run"),Leader=i==1})
		end
	end
	local invitation=invites[p]
	local sender=invitation and invitation.Expires>os.clock() and invitation.From
	return {Members=members,Incoming=sender and {User=sender.UserId,Name=sender.DisplayName} or nil}
end
function P.Action(p,op,a)
	if not available(p) then return false,"Your player profile is unavailable" end
	local party=membership[p]
	if op=="PartyCreate" then
		if party then return false,"You already have a party" end
		new(p) return true
	elseif op=="PartyLeave" then leave(p) return true
	elseif op=="PartyInvite" then
		local other=type(a)=="number" and Players:GetPlayerByUserId(a)
		if not available(other) or other==p or membership[other] then return false,"Select a player outside a party" end
		if party and party.Members[1]~=p then return false,"Only the leader can invite" end
		if party and #party.Members>=D.PartySize then return false,"Party is full" end
		if (cooldowns[p] or 0)>os.clock() then return false,"Wait before sending another invitation" end
		local old=invites[other]
		if old and old.Expires>os.clock() then return false,"That player already has a pending invitation" end
		party=party or new(p)
		invites[other]={From=p,Party=party,Expires=os.clock()+45}
		cooldowns[p]=os.clock()+5
		return true
	elseif op=="PartyAccept" or op=="PartyDecline" then
		local invite=invites[p]
		if not invite or invite.Expires<=os.clock() or invite.From.UserId~=a then return false,"Invitation expired" end
		invites[p]=nil
		if op=="PartyDecline" then return true end
		local destination=invite.Party
		if party or destination.Members[1]~=invite.From or membership[invite.From]~=destination or #destination.Members>=D.PartySize then
			return false,"Invitation is no longer available"
		end
		table.insert(destination.Members,p)
		membership[p]=destination
		p:SetAttribute("M7PartyLeader",destination.Members[1].UserId)
		return true
	elseif op=="PartyKick" or op=="PartyLeader" then
		if not party or party.Members[1]~=p then return false,"Only your leader can do that" end
		local peer=type(a)=="number" and Players:GetPlayerByUserId(a)
		if not peer or peer==p or membership[peer]~=party then return false,"Choose a party member" end
		if op=="PartyKick" then leave(peer)
		else
			local i=table.find(party.Members,peer)
			party.Members[1],party.Members[i]=peer,p
			for _,member in ipairs(party.Members) do member:SetAttribute("M7PartyLeader",peer.UserId) end
		end
		return true
	end
	return false,"Unknown party action"
end
function P.Ready(p)
	local party=membership[p]
	if not party or #party.Members<2 or party.Members[1]~=p then return nil,"A leader with at least two members is required" end
	local members=table.clone(party.Members)
	for _,peer in ipairs(members) do
		if not available(peer) or peer:GetAttribute("M5Run") then return nil,"Every member must be available outside another encounter" end
	end
	return members
end
Players.PlayerRemoving:Connect(function(p)
	leave(p) invites[p]=nil cooldowns[p]=nil
	for other,invite in pairs(invites) do if invite.From==p then invites[other]=nil end end
end)
return P
