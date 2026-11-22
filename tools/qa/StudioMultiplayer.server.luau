-- Install temporarily under ServerScriptService and run StudioTestService's
-- ExecuteMultiplayerTestAsync(2, "BladeForestQA2") from the private Edit model.
-- The caller must opt the private editor into its separate QA data namespace.
local Run=game:GetService("RunService")
if not Run:IsStudio() or game.PlaceId~=103379930563763 or game.GameId~=10777797608
	or workspace:GetAttribute("BladeForestQAProfile")~=true then return end
local Studio=game:GetService("StudioTestService")
if Studio:GetTestArgs()~="BladeForestQA2" then return end
local Players=game:GetService("Players")
local Store=game:GetService("ServerStorage")
local Data=require(script.Parent.DataService)
local Party=require(script.Parent.M7Parties)
local Runs=require(script.Parent.M5Runs)
local Design=require(game.ReplicatedStorage.M5Design)
local report={}
local finished=false
local function finish()
	if finished then return end
	finished=true
	local ok=pcall(function()
		game:GetService("DataStoreService"):GetDataStore("BF_QA1_LocalMultiplayer"):SetAsync("Build69",report)
	end)
	report.EvidenceSaved=ok
	Studio:EndTest(report)
end
task.delay(70,function() report.Timeout=true finish() end)
local function untilReady(fn,secs)
	local stop=os.clock()+secs
	repeat
		if fn() then return true end
		task.wait(.25)
	until os.clock()>stop
	return false
end
local outcome,issue=pcall(function()
	assert(untilReady(function()
		local pp=Players:GetPlayers()
		report.PeakPlayers=math.max(report.PeakPlayers or 0,#pp)
		if #pp<2 then return false end
		for _,p in ipairs(pp) do
			if not p:GetAttribute("QASandbox") or not p:GetAttribute("Loaded") or not p.Character
				or p:GetAttribute("IslandArrivalPending") or p:GetAttribute("CurrentIsland")~="TimberHaven" then return false end
		end
		return true
	end,40),"Two isolated profiles did not finish loading")
	local a,b=table.unpack(Players:GetPlayers())
	report.Players=#Players:GetPlayers()
	local travel=Store.DevTravel
	local moved={}
	for _,p in ipairs({a,b}) do task.spawn(function() moved[p]=travel:Invoke(p,"CrystalWilds",{unlock=true,cooldown=true}) end) end
	assert(untilReady(function() return moved[a]~=nil and moved[b]~=nil end,14),"Travel did not return for both clients")
	assert(moved[a] and moved[b],"One simultaneous arrival failed")
	local space=(a.Character.HumanoidRootPart.Position-b.Character.HumanoidRootPart.Position).Magnitude
	report.CrystalArrivalSeparationStuds=space
	assert(space>=6,"Simultaneous arrival slot overlap")
	assert(travel:Invoke(a,"TimberHaven",{cooldown=true}))
	assert(b:GetAttribute("CurrentIsland")=="CrystalWilds")
	report.IndependentReturn=true
	assert(Party.Action(a,"PartyInvite",b.UserId))
	assert(Party.Action(b,"PartyAccept",a.UserId))
	local roster=Party.Ready(a)
	assert(roster and #roster==2,"Party membership or leader mismatch")
	report.Party=true
	for _,p in ipairs(roster) do
		local d=Data.Get(p)
		assert(p:GetAttribute("QASandbox"))
		d.UnlockedIslands.FrostboundReach=true
		Data.AddWeapon(p,"FrostboundReaper")
		Data.Equip(p,"FrostboundReaper")
		assert(travel:Invoke(p,"FrostboundReach",{cooldown=true}))
		p.Character:PivotTo(CFrame.new(Design.Expedition.Entry+Vector3.new(0,4,p==a and -3 or 3)))
	end
	local started,msg=Runs.EnterParty(roster)
	assert(started,msg)
	assert(a:GetAttribute("M5Run")=="Expedition" and b:GetAttribute("M5Run")=="Expedition")
	local distance=(a.Character.HumanoidRootPart.Position-b.Character.HumanoidRootPart.Position).Magnitude
	report.ExpeditionSeparationStuds=distance
	assert(distance>=6 and distance<=20)
	local frames={}
	for i=1,100 do frames[i]=Run.Heartbeat:Wait()*1000 end
	table.sort(frames)
	report.ServerP50Ms=frames[50]
	report.ServerP95Ms=frames[95]
	report.ServerMaxMs=frames[100]
	report.ServerMemoryMb=game:GetService("Stats"):GetTotalMemoryUsageMb()
	report.UpdateBudget=game:GetService("DataStoreService"):GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
end)
report.Passed=outcome
if not outcome then report.Error=tostring(issue) end
finish()
