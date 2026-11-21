local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local M=require(ReplicatedStorage:WaitForChild("M5Design"))
local Analytics=require(script.Parent:WaitForChild("Analytics"))
local events=require(script.Parent:WaitForChild("M5EventTelemetry"))
local Notify=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")
local current

local function close()
	if not current then return end
	local summary=events.Close()
	for _,p in ipairs(Players:GetPlayers()) do
		local chops=summary[p.UserId]
		if chops and chops>0 then
			Analytics.Custom(p,"RegionalForestEvent",chops,{CustomField01=current.Id,CustomField02=current.Island})
		end
	end
	workspace:SetAttribute("M5EventChops",events.Total)
	workspace:SetAttribute("M5EventCompleted",current.Id)
	current=nil
end

local function tick()
	local now=os.time()
	local def,island,start,done=M.EventAt(now)
	local active=now>=start and now<done
	if current and (not active or current.Key~=start) then close() end
	if active and not current then
		current={Id=def.Id,Island=island,Key=start}
		events.Open(def.Id,island)
		workspace:SetAttribute("M5EventId",def.Id)
		workspace:SetAttribute("M5EventIsland",island)
		workspace:SetAttribute("M5EventLogs",def.Logs)
		workspace:SetAttribute("M5EventLuck",def.Luck)
		workspace:SetAttribute("M5EventEnd",done)
		workspace:SetAttribute("M5EventName",def.Name)
		workspace:SetAttribute("M5EventKey",start)
		Notify:FireAllClients(def.Name.." · "..M.Names[island],"rare_Legendary")
	elseif not active then
		-- Publish the next opening and clear the economic effect first.
		if workspace:GetAttribute("M5EventKey") then
			workspace:SetAttribute("M5EventId",nil)
			workspace:SetAttribute("M5EventKey",nil)
			for _,key in ipairs({"Island","Logs","Luck","End","Name"}) do workspace:SetAttribute("M5Event"..key,nil) end
		end
		if now>=done then def,island,start=M.EventAt(start+M.EventSlot) end
		workspace:SetAttribute("M5EventNext",start)
		workspace:SetAttribute("M5EventNextName",def.Name)
		workspace:SetAttribute("M5EventNextIsland",island)
	end
end
while true do tick() task.wait(1.5) end
