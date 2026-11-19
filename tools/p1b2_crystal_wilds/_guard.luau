-- Shared guard: paste at the top of every P1b.2 tool script (Studio command bar, Edit mode).
-- Aborts unless this is the authorized PRIVATE development place.
local AUTH_PLACE, AUTH_GAME = 103379930563763, 10777797608
assert(game.PlaceId == AUTH_PLACE and game.GameId == AUTH_GAME,
	("ABORT: PlaceId %d / GameId %d is not Blade Forest - Island Dev"):format(game.PlaceId, game.GameId))
assert(not game:GetService("RunService"):IsRunning(), "ABORT: run in Edit mode, not during a playtest")
