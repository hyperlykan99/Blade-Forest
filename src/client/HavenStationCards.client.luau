-- HavenStationCards (Claude, issue #1 M1): premium interaction card for station counters.
-- Only prompts the server marked HavenCard (Style=Custom) are drawn here. If anything fails,
-- those prompts fall back to Roblox's default prompt UI locally so stations always stay usable.
if not workspace:GetAttribute("BladeHavenMakeover") then return end
local Players=game:GetService("Players")
local PPS=game:GetService("ProximityPromptService")
local TweenService=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local R=Color3.fromRGB

local function fallback(prompt)
	if prompt:GetAttribute("HavenCard") then prompt.Style=Enum.ProximityPromptStyle.Default end
end

local INK,WALNUT,GOLD,CREAM,MOSS=R(28,20,15),R(46,32,23),R(255,206,112),R(255,246,226),R(120,196,120)
local PAD_NAMES={ButtonX="X",ButtonY="Y",ButtonA="A",ButtonB="B",ButtonR1="RB",ButtonL1="LB"}

local function reduced() return player:GetAttribute("Pref_ReducedMotion")==true end

local function keyText(prompt,input)
	if input==Enum.ProximityPromptInputType.Touch then return "TAP" end
	if input==Enum.ProximityPromptInputType.Gamepad then return PAD_NAMES[prompt.GamepadKeyCode.Name] or prompt.GamepadKeyCode.Name end
	return prompt.KeyboardKeyCode.Name
end

local function build(prompt,input,gui)
	local bb=Instance.new("BillboardGui")
	bb.Name="HavenStationCard" bb.AlwaysOnTop=false bb.LightInfluence=0 bb.ResetOnSpawn=false bb.ClipsDescendants=false
	bb.Size=UDim2.fromOffset(236,66)
	bb.Adornee=prompt.Parent bb.Active=true bb.Parent=prompt.Parent -- local-only instance
	-- Counters sit inside building shells, so the card floats out of the shell toward the viewer
	-- (depth-tested, so it reads as part of the world rather than a sticker on the screen).
	local function place()
		local cam=workspace.CurrentCamera
		local anchor=prompt.Parent
		if not cam or not anchor:IsA("BasePart") then return end
		local d=cam.CFrame.Position-anchor.Position
		d=Vector3.new(d.X,0,d.Z)
		local out=d.Magnitude>0.1 and d.Unit*math.min(6,d.Magnitude*.55) or Vector3.zero
		bb.StudsOffsetWorldSpace=out+Vector3.new(0,5.4,0) -- clears the player's head
	end
	place()
	local follow=game:GetService("RunService").RenderStepped:Connect(place)
	local card=Instance.new("TextButton")
	card.Name="Card" card.AutoButtonColor=false card.Text="" card.Size=UDim2.fromScale(1,1)
	card.BackgroundColor3=WALNUT card.BackgroundTransparency=.06 card.Parent=bb
	Instance.new("UICorner",card).CornerRadius=UDim.new(0,14)
	local grad=Instance.new("UIGradient") grad.Rotation=90
	grad.Color=ColorSequence.new(R(255,255,255),R(170,160,150)) grad.Parent=card
	local edge=Instance.new("UIStroke") edge.Color=GOLD edge.Thickness=1.6 edge.Transparency=.15
	edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border edge.Parent=card
	local scale=Instance.new("UIScale") scale.Parent=card
	-- key chip
	local chip=Instance.new("Frame")
	chip.Name="Key" chip.Size=UDim2.fromOffset(46,46) chip.Position=UDim2.fromOffset(10,10)
	chip.BackgroundColor3=CREAM chip.Parent=card
	Instance.new("UICorner",chip).CornerRadius=UDim.new(0,10)
	local cs=Instance.new("UIStroke") cs.Color=INK cs.Thickness=2 cs.Parent=chip
	local key=Instance.new("TextLabel")
	key.BackgroundTransparency=1 key.Size=UDim2.fromScale(1,1) key.Text=keyText(prompt,input)
	key.FontFace=Font.fromEnum(Enum.Font.FredokaOne) key.TextColor3=INK key.TextScaled=true key.Parent=chip
	local kp=Instance.new("UIPadding") kp.PaddingTop=UDim.new(0,8) kp.PaddingBottom=UDim.new(0,8)
	kp.PaddingLeft=UDim.new(0,6) kp.PaddingRight=UDim.new(0,6) kp.Parent=key
	-- hold ring (fills the chip from the bottom)
	local fill=Instance.new("Frame")
	fill.Name="Hold" fill.AnchorPoint=Vector2.new(0,1) fill.Position=UDim2.fromScale(0,1)
	fill.Size=UDim2.fromScale(1,0) fill.BackgroundColor3=MOSS fill.BackgroundTransparency=.35 fill.ZIndex=0 fill.Parent=chip
	Instance.new("UICorner",fill).CornerRadius=UDim.new(0,10)
	-- text
	local title=Instance.new("TextLabel")
	title.BackgroundTransparency=1 title.Position=UDim2.fromOffset(68,9) title.Size=UDim2.new(1,-80,0,20)
	title.Text=string.upper(prompt.ObjectText) title.TextXAlignment=Enum.TextXAlignment.Left
	title.FontFace=Font.fromEnum(Enum.Font.GothamBold) title.TextScaled=true title.TextColor3=GOLD title.Parent=card
	local action=Instance.new("TextLabel")
	action.BackgroundTransparency=1 action.Position=UDim2.fromOffset(68,30) action.Size=UDim2.new(1,-80,0,27)
	action.Text=prompt.ActionText action.TextXAlignment=Enum.TextXAlignment.Left
	action.FontFace=Font.fromEnum(Enum.Font.FredokaOne) action.TextScaled=true action.TextColor3=CREAM action.Parent=card
	local as=Instance.new("UIStroke") as.Color=INK as.Thickness=1.5 as.Parent=action
	-- behaviour
	local cons={}
	table.insert(cons,card.InputBegan:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.Touch or io.UserInputType==Enum.UserInputType.MouseButton1 then prompt:InputHoldBegin() end
	end))
	table.insert(cons,card.InputEnded:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.Touch or io.UserInputType==Enum.UserInputType.MouseButton1 then prompt:InputHoldEnd() end
	end))
	local holdTween
	table.insert(cons,prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration>0 then
			holdTween=TweenService:Create(fill,TweenInfo.new(prompt.HoldDuration,Enum.EasingStyle.Linear),{Size=UDim2.fromScale(1,1)})
			holdTween:Play()
		end
	end))
	table.insert(cons,prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then holdTween:Cancel() end fill.Size=UDim2.fromScale(1,0)
	end))
	table.insert(cons,prompt.Triggered:Connect(function()
		edge.Color=MOSS
		if not reduced() then scale.Scale=.94 TweenService:Create(scale,TweenInfo.new(.18,Enum.EasingStyle.Back),{Scale=1}):Play() end
		task.delay(.25,function() edge.Color=GOLD end)
	end))
	table.insert(cons,prompt:GetPropertyChangedSignal("ActionText"):Connect(function() action.Text=prompt.ActionText end))
	if reduced() then scale.Scale=1 else
		scale.Scale=.8 TweenService:Create(scale,TweenInfo.new(.2,Enum.EasingStyle.Back),{Scale=1}):Play()
	end
	table.insert(cons,follow)
	return function()
		for _,c in ipairs(cons) do c:Disconnect() end
		bb:Destroy()
	end
end

local ok,err=pcall(function()
	-- BillboardGuis only render when they are not nested inside a ScreenGui, so use a Folder.
	local gui=Instance.new("Folder")
	gui.Name="HavenStationCards" gui.Parent=player:WaitForChild("PlayerGui")
	local open={}
	PPS.PromptShown:Connect(function(prompt,input)
		if prompt.Style~=Enum.ProximityPromptStyle.Custom or not prompt:GetAttribute("HavenCard") then return end
		local okBuild,cleanup=pcall(build,prompt,input,gui)
		if okBuild then open[prompt]=cleanup else warn("Station card:",cleanup) fallback(prompt) end
	end)
	PPS.PromptHidden:Connect(function(prompt)
		local cleanup=open[prompt] open[prompt]=nil
		if cleanup then cleanup() end
	end)
end)
if not ok then
	warn("HavenStationCards disabled:",err)
	for _,p in ipairs(workspace:GetDescendants()) do if p:IsA("ProximityPrompt") then fallback(p) end end
	workspace.DescendantAdded:Connect(function(p) if p:IsA("ProximityPrompt") then fallback(p) end end)
end
