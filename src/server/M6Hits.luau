-- Encounter targets are registered server-side. Remote clients never submit damage.
local Hits={}
local handlers=setmetatable({},{__mode="k"})
function Hits.Register(target,fn) handlers[target]=fn end
function Hits.Remove(target) handlers[target]=nil end
function Hits.Deal(player,target,damage)
	local fn=handlers[target]
	if not fn then return false end
	if player and type(damage)=="number" and damage==damage and damage>0 then
		fn(player,math.min(damage,1e9))
	end
	return true
end
return Hits
