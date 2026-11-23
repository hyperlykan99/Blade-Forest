# Teleport validation

Studio Play at private place `103379930563763`, universe `10777797608`, V2 world and the verified Kenney art active. Tests that seed gear, Power or progression use the Studio-only `BF_QA_World_` namespace. The isolated fixture changes prerequisites or places the character beside a prompt. The actual prompt input and travel remote still use the server's normal validation, streaming, landing and state updates. No unlock or cooldown bypass was used for these tests.

## Gate policy

| Island | Power on each entry | Requirements for first unlock |
| --- | ---: | --- |
| Timber Haven | None | None |
| Crystal Wilds | 250 equipped | Blade King credit and 600 trees across Starter Grove and Pine Forest |
| Frostbound Reach | 2,000 equipped | Crystal Colossus credit and 6,000 Crystal Canyon trees |

M4 set `M4ColossusReady=true` in the running build. The Frostbound gate rejected a profile with 2,000 equipped Power and 6,000 chops until Colossus credit was present. Existing permanent unlocks waive historical requirements. Equipped Power is checked on every entry and on rejoin. The existing first-unlock gate also reads best owned Power. Tree positions and registered island bounds were preserved.

The server validates portal proximity, rechecks session transitions, combat, run eligibility and equipped Power after streaming, and records the unlock only after a landing slot is available. `CurrentIsland` and `LastIsland` reflect successful landings. Waypoints within Crystal keep the same saved island. Reserved future gate models have no travel prompt.

## Actual portal inputs

| Entrance | Observed result |
| --- | --- |
| Timber Portal Cliffs to Crystal | E reached Crystal at about `(2790, 5.80, 0)` |
| Timber Portal Cliffs to Frostbound | E reached Frostbound at about `(5750, 3.80, 0)` |
| Crystal plaza to Timber | Holding E for the existing 0.4s prompt returned to Timber at about `(-20, 3.80, -3000)` |
| Crystal plaza to Frostbound | E at the new arch evaluated the gate and unlocked at the exact equipped Power and progression thresholds |
| Frostgate to Crystal | E reached the Crystal plaza independently of the Timber route |
| Frostgate to Timber | E reached the Timber arrival |
| Crystal plaza to Colossus annex | E landed at about `(3000, 4.17, -384)` |
| Colossus annex to Crystal plaza | E returned to `(2798, 5.80, -10)`, leaving Crystal as both current and saved island |

Heights above are sampled after the avatar settles and can differ from the configured pivot. Initial tests used direct client travel requests to isolate gate decisions. The actual entrance tests used Studio E input and verified the resulting server state separately.

## Scenario matrix

| Scenario | Outcome and evidence |
| --- | --- |
| New profile | Denied Crystal at 60 Power. Spawned in Timber with no advanced unlock. |
| Power met, chops missing | Prepared Crystal `599/600` and Frostbound `5999/6000` were both denied with the relevant chop requirement. |
| Power and chops met, boss missing | Prepared no King and no Colossus cases were both denied with the correct boss requirement. |
| Boss and chops met, equipped Power too low | Prepared 249 and 1,999 equipped Power cases denied Crystal and Frostbound. |
| Exactly eligible | Prepared 250 Power, one King and 600 chops unlocked Crystal. Prepared 2,000 Power, one Colossus and 6,000 chops unlocked Frostbound through the new Crystal prompt. |
| Permanent unlock | With a retained Crystal unlock, prepared depleted boss and chop counters were waived. Entry was refused at 249 equipped Power and allowed at 250. |
| Return Timber, travel Crystal/Frostbound both directions | All listed real prompts moved the avatar and the server recorded matching current and saved islands. |
| Rapid repeat | A successful Frostbound trip followed immediately by Timber returned “Wait 2.6s before travelling again.” |
| Two near-simultaneous arrivals | Unverified. The Studio two-client launch returned no result over MCP. A retry reported the previous test still in progress, and the native Studio window inspector could not start. The prepared fixture is in [StudioTravelMultiplayer.server.luau](../../tools/world/StudioTravelMultiplayer.server.luau). |
| Combat | Prepared active combat timestamp returned “You're in combat!” and left the character at the origin. |
| Active Trial and Expedition | Entered real server runs using their ordinary eligibility checks. Travel returned “Exit your run to travel” in both. Existing run exit returned to the correct island. |
| Disconnect while streaming | Unverified. The attempted two-client launch returned no results. The first travel check and the stream-completion path were audited separately. |
| Rejoin | The isolated DataStore acknowledged the save. A fresh Studio Play session reloaded both unlocks and equipped Umbraxe, then spawned at the Frostgate arrival with CurrentIsland and LastIsland both Frostbound. |
| Unavailable destination | A request for the reserved future route returned “Unknown island.” There is no live registered island with an unavailable release state, so that guarded branch had no world entrance to exercise. |
| Crystal annex | Both waypoint prompts landed on their intended platform and kept Crystal as current and saved island. |
| Professional art | All actual prompt tests used the active imported art. The new Crystal portal was placed on a surveyed free section of the plaza away from the arrival ring. |
| Void recovery | A prepared fall at `(6350, -27, 251)` returned to Frostgate without changing saved island or unlock state. |

## Presentation

Island prompts keep Roblox's native input. The nearby status panel reads the player's existing replicated progression snapshot and lists the destination, equipped Power, active boss and chop requirements. It identifies each shortfall and shows the retained unlock when applicable. Studio Play showed the equipped-Power shortfall and the permanent-unlock label beside the portal. I moved the card below and left of the tutorial after the first review showed overlap. [Portal status in Play](PORTAL_STATUS.jpg)

The successful server landing triggers a brief cosmetic glint and ring through the existing graphics, motion, distance and shared VFX limits. A final Medium-graphics Studio test observed the server arrival event and both pooled effects after a real return to Timber. Crystal's existing waypoint prompts keep their own labels.

## Reproducing the remaining two-client check

In the private development place, temporarily install the two fixtures from `tools/world` as server scripts. Set `Workspace.BladeForestQAProfile` to true and `Workspace.BladeForestQASuite` to `WorldTravel` in Edit. Run the two-client test with `StudioTestService:ExecuteMultiplayerTestAsync(2, "WorldTravel2")`. The fixture uses the travel service without bypass flags, checks horizontal slot separation and independent return, and attempts to disconnect the second client after the server marks a trip pending. Remove the fixture scripts and clear both QA attributes before saving.
