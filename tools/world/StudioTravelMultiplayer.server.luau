-- Install temporarily in ServerScriptService alongside StudioTravelFixture.
-- In private Edit mode call StudioTestService:ExecuteMultiplayerTestAsync(2, "WorldTravel2").
local run = game:GetService("RunService")
if not run:IsStudio() or game.PlaceId ~= 103379930563763 or game.GameId ~= 10777797608
	or workspace:GetAttribute("BladeForestQAProfile") ~= true
	or workspace:GetAttribute("BladeForestQASuite") ~= "WorldTravel" then return end
local studio = game:GetService("StudioTestService")
if studio:GetTestArgs() ~= "WorldTravel2" then return end

local players = game:GetService("Players")
local storage = game:GetService("ServerStorage")
local report = {}
local ended = false
local function finish()
	if ended then return end
	ended = true
	studio:EndTest(report)
end
task.delay(85,function()
	report.Timeout = true
	finish()
end)

local function waitUntil(seconds, predicate)
	local deadline = os.clock() + seconds
	repeat
		if predicate() then return true end
		task.wait(.2)
	until os.clock() > deadline
	return false
end

local success, failure = pcall(function()
	assert(waitUntil(53,function()
		local clients = players:GetPlayers()
		report.peakPlayers = math.max(report.peakPlayers or 0,#clients)
		if #clients ~= 2 then return false end
		for _,p in ipairs(clients) do
			if not p:GetAttribute("QASandbox") or not p:GetAttribute("Loaded") or not p.Character
				or p:GetAttribute("IslandArrivalPending") or not p:GetAttribute("CurrentIsland") then return false end
		end
		return true
	end), "Two isolated players did not finish loading")
	local fixture = storage:WaitForChild("WorldTravelFixture")
	local travel = storage:WaitForChild("DevTravel")
	local clients = players:GetPlayers()
	for _,p in ipairs(clients) do
		fixture:Invoke(p,{weapon="CrimsonCrescent",power=250,timber=600,king=1})
		if p:GetAttribute("CurrentIsland") ~= "TimberHaven" then
			local ok, reason = travel:Invoke(p,"TimberHaven")
			assert(ok,reason)
		end
	end
	task.wait(3.2)
	local responses = {}
	for i,p in ipairs(clients) do
		task.spawn(function()
			local success, result = travel:Invoke(p,"CrystalWilds")
			responses[i] = {success,result}
		end)
	end
	assert(waitUntil(18,function() return responses[1] and responses[2] end),"An arrival did not return")
	report.responses = responses
	assert(responses[1][1] and responses[2][1],"At least one eligible travel was refused")
	local roots = {}
	for i,p in ipairs(clients) do
		local position = p.Character.HumanoidRootPart.Position
		roots[i] = Vector2.new(position.X,position.Z)
		assert(p:GetAttribute("CurrentIsland") == "CrystalWilds")
	end
	report.separationStuds = (roots[1] - roots[2]).Magnitude
	assert(report.separationStuds>=5.5,"Safe slots did not separate arrivals")
	task.wait(3.2)
	local ok, reason = travel:Invoke(clients[1],"TimberHaven")
	assert(ok,reason)
	report.independentReturn = clients[2]:GetAttribute("CurrentIsland") == "CrystalWilds"
	assert(report.independentReturn,"Second player moved when the first returned")

	-- Disconnect the second test client only after the server has marked travel pending.
	local disconnecting = clients[2]
	local observer = disconnecting:GetAttributeChangedSignal("IslandTravelling"):Connect(function()
		if report.disconnectPending or not disconnecting:GetAttribute("IslandTravelling") then return end
		report.disconnectPending = true
		report.islandBeforeDisconnect = disconnecting:GetAttribute("CurrentIsland")
		disconnecting:Kick("Isolated Studio travel interruption fixture")
	end)
	local arrived, message = travel:Invoke(disconnecting,"TimberHaven")
	observer:Disconnect()
	report.disconnectedTravel = {arrived,message}
	report.disconnectProtected = report.disconnectPending and not arrived
end)
report.passed = success
if not success then report.error = tostring(failure) end
finish()
