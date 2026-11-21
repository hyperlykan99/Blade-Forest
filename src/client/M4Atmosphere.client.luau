-- Client-only biome presentation. Asset attribution is in the M4 results.
local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local SoundService=game:GetService("SoundService")
local Layout=require(ReplicatedStorage:WaitForChild("M4Layout"))
local player=Players.LocalPlayer
local sfx=SoundService:WaitForChild("SFX",12)
local group=Instance.new("Folder")
group.Name="M4LocalAmbience"
group.Parent=workspace
local rgb=Color3.fromRGB
local palettes={
	TimberHaven={ Tint=rgb(255,245,225), Bright=.02, Saturation=.045 },
	FrostboundReach={ Tint=rgb(226,241,255), Bright=.018, Saturation=-.055 },
}
local clips={
	{ "TimberHaven","Haven birds",9112835056,Vector3.new(153,3,-2970),110,.16 },
	{ "TimberHaven","West waterfall",9120550180,Vector3.new(-360,5,-2681),78,.13 },
	{ "TimberHaven","East waterfall",9120550180,Vector3.new(340,5,-3319),78,.13 },
	{ "FrostboundReach","Frostbound wind",551546110,Vector3.new(6055,12,48),300,.14 },
}
local tint=Instance.new("ColorCorrectionEffect")
tint.Name="M4BiomeTone"
tint.Enabled=false
tint.Parent=Lighting
local sounds={}
for _,c in ipairs(clips) do
	local anchor=Instance.new("Part")
	anchor.Name=c[2]
	anchor.Size=Vector3.one
	anchor.Position=c[4]
	anchor.Transparency=1
	anchor.Anchored=true
	anchor.CanCollide=false anchor.CanQuery=false anchor.CanTouch=false anchor.CastShadow=false
	anchor.Parent=group
	local sound=Instance.new("Sound")
	sound.Name=c[2]
	sound.SoundId="rbxassetid://"..c[3]
	sound.Volume=c[6]
	sound.SoundGroup=sfx
	sound.Looped=true
	sound.RollOffMinDistance=12
	sound.RollOffMaxDistance=c[5]
	sound.Parent=anchor
	table.insert(sounds,{Island=c[1],Sound=sound})
end
local function update()
	local island=Layout.Enabled() and player:GetAttribute("CurrentIsland")
	local p=palettes[island]
	tint.Enabled=p~=nil
	if p then tint.TintColor=p.Tint tint.Brightness=p.Bright tint.Saturation=p.Saturation end
	for _,entry in ipairs(sounds) do
		local sound=entry.Sound
		if entry.Island==island then
			if not sound.IsPlaying then sound:Play() end
		else
			sound:Stop()
		end
	end
end
player:GetAttributeChangedSignal("CurrentIsland"):Connect(update)
workspace:GetAttributeChangedSignal(Layout.Attribute):Connect(update)
workspace:GetAttributeChangedSignal(Layout.Ready):Connect(update)
update()
