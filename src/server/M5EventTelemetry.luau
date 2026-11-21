-- Counts only real regional tree chops in the server's current event.
local T={Total=0}
local players={}
local activeIsland
function T.Open(_,island)
	activeIsland=island
	table.clear(players)
	T.Total=0
end
function T.Chop(player,island)
	if activeIsland and island==activeIsland and player:GetAttribute("CurrentIsland")==island then
		T.Total+=1
		players[player.UserId]=(players[player.UserId] or 0)+1
	end
end
function T.Close()
	activeIsland=nil
	return table.clone(players)
end
return T
