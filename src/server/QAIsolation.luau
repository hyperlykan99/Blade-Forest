-- Test profiles use a separate namespace only in Studio for the authorized development place.
local enabled=game:GetService("RunService"):IsStudio()
	and game.PlaceId==103379930563763 and game.GameId==10777797608
	and workspace:GetAttribute("BladeForestQAProfile")==true
local QA={Enabled=enabled}
local prefix=workspace:GetAttribute("BladeForestQASuite")=="WorldTravel" and "BF_QA_World_" or "BF_QA1_"
function QA.StoreName(name)
	if enabled then return prefix..name end
	return name
end
return table.freeze(QA)
