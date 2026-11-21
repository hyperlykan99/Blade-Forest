local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local M=require(ReplicatedStorage:WaitForChild("M5Design"))
local player=Players.LocalPlayer
local effects={}
for _,event in ipairs(M.Events) do effects[event.Id]=event end
local anchor=Instance.new("Part")
anchor.Name="LocalRegionalForestEvent"
anchor.Size=Vector3.new(24,.2,24) anchor.Anchored=true anchor.Transparency=1
anchor.CanCollide=false anchor.CanTouch=false anchor.CanQuery=false anchor.CastShadow=false
anchor.Parent=workspace
local p=Instance.new("ParticleEmitter")
p.Enabled=false p.Texture="rbxasset://textures/particles/sparkles_main.dds"
p.Shape=Enum.ParticleEmitterShape.Box p.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
p.EmissionDirection=Enum.NormalId.Bottom p.SpreadAngle=Vector2.new(45,45)
p.Lifetime=NumberRange.new(.6,1.15) p.Size=NumberSequence.new(.25)
p.Parent=anchor
local color=Instance.new("ColorCorrectionEffect")
color.Name="M5RegionalEventTone" color.Enabled=false color.Parent=Lighting
while true do
	task.wait(.25)
	local ev=effects[workspace:GetAttribute("M5EventId")]
	local island=player:GetAttribute("CurrentIsland")
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local active=ev and root and island==workspace:GetAttribute("M5EventIsland")
		and not player:GetAttribute("M5Run") and (workspace:GetAttribute("M5EventEnd") or 0)>workspace:GetServerTimeNow()
	p.Enabled=active and player:GetAttribute("Pref_Graphics")~="Low" or false
	color.Enabled=active==true
	if active then
		anchor.Position=root.Position+Vector3.new(0,9,0)
		p.Color=ColorSequence.new(ev.Color)
		p.Rate=ev.Id=="Blizzard" and 14 or ev.Id=="MeteorGrove" and 8 or 6
		p.Speed=ev.Id=="MeteorGrove" and NumberRange.new(14,22) or NumberRange.new(3,8)
		color.TintColor=Color3.new(1,1,1):Lerp(ev.Color,.23)
		color.Brightness=ev.Id=="CrystalBloom" and .018 or -.018
	end
end
