# Blade Forest — P1a Island Prototype Results

_2026-11-18, Claude. Owner-approved P1a only. P1b/P1c/P2 are **not** started._

## Target and identity
| | |
|---|---|
| Place edited | **Blade Forest - Island Dev**, place **103379930563763**, universe **10777797608** (PRIVATE, personal owner). `game.PlaceId` and `game.GameId` were asserted inside every write command |
| Saved version | **Dev place version 5** ("P1a island prototype - registry, TravelService, test pads"; Team Create) |
| Production | Place 73142469975141 / universe 10777481912: **not modified**. `updateTime` still `2026-11-18T15:12:30.520Z` after P1a |
| Rollback checkpoint | Before writing, `save_place` reported "no unsaved changes", so the cloud version matched the untouched P0 baseline. A version label could not be added (the first save call errored); see Rollback |

## Changes in Studio (dev place only)
| Item | Change | Size |
|---|---|---|
| `ReplicatedStorage.BladeConfig` | Added the `Config.Islands` registry (3 islands with stable IDs, bounds, arrival points, legacy area mapping), plus `IslandById`, `HomeIsland`, `TravelCooldown = 3`, `GetIslandAt(pos)` and `GetIslandRequiredPower(isl)`. `GetAreaAt` checks the island first; the legacy logic is unchanged | 53,433 → 55,586 B |
| `ServerScriptService.DataService` | Added `UnlockedIslands = {TimberHaven=true}`, `LastIsland = "TimberHaven"` and `IslandProgress = {}` to `DEFAULT` (filled in by `reconcile`). Added grandfathering after reconcile: BestArea Crystal Canyon unlocks Crystal Wilds; Frost Peaks unlocks both. **It only ever adds.** No keys deleted or renamed | 18,797 → 19,574 B |
| `ServerScriptService.TravelService` (new) | Server-authoritative same-place travel. `Remotes.Travel` RemoteFunction is created at runtime. ProximityPrompt pads with a `TravelTo` attribute. Respawn and rejoin placement. Studio-only `ServerStorage.DevTravel` hook (created only when `RunService:IsStudio()`) | 7,009 B |
| `Workspace.Islands` (new folder, 18 basic Parts) | `TimberHaven`: 2 neon travel pads at (−12, 2.5, −26) and (12, 2.5, −26) beside the spawn plaza. `CrystalWilds` at (3000, 0, 0) and `FrostboundReach` at (6000, 0, 0): each has a 160×4×160 anchored arrival floor (top y = 2), 4 invisible edge walls, a neon arrival marker, a billboard label and a return pad. Island models use `ModelStreamingMode = Atomic` | 18 parts |

Unchanged: all other 31 scripts, every existing map object, the Crystal Canyon wedge and Frost annex, commerce, odds, economy, assets and the import folders.

**GitHub:** branch **`p1a/island-prototype`** (commit `0f0e3b6`, based on `p0/script-export`). The three changed scripts are checksum-identical to Studio. Workspace objects exist only in Studio.

## Unlock rule (P1a)
An island is unlocked if it is saved in `UnlockedIslands`, **or** the player's Power ≥ the legacy gate of its mapped area: Crystal Wilds 250 (Crystal Canyon), Frostbound Reach 2,000 (Frost Peaks). This is deliberately the existing area gate, so **no economy change**. The M2 checklist gates are P1c work and need approval.

## Tests
Studio playtest, dev place, 1 player (hyperlykan99). Rejection tests used the real client `Remotes.Travel` remote.

| # | Test | Result |
|---|---|---|
| U1 | Classification at 12 sample points (legacy areas on Island 1, test islands, void) | ✅ 12/12 |
| T1–T3 | Invalid id `"Atlantis"`, number, nil | ✅ "Unknown island" / "Bad destination", no movement |
| T4–T5 | Locked Crystal Wilds / Frostbound Reach at Power 60 | ✅ "🔒 … needs 250 / 2000 Power" |
| T6 | Travel to the island you're already on | ✅ rejected |
| T7b | Server-forced noclip onto locked Island 2 (Power 60) | ✅ AreaService returned the player to the last safe spot in about 0.3 s |
| T8 | I1 → I2 (Power temporarily set to 2500 as a transient attribute) | ✅ 0.38 s, landed at (3000, 5, 0), stable after 2 s; area = Crystal Canyon |
| T9 | Streaming at I2 | ✅ I2 floor present on the client before arrival; I3 not streamed |
| T10 | Spam: 5 rapid requests | ✅ 1 allowed, then "Wait 2.8s / 2.4s / 0.7s", then "already on …" |
| T11 | I2 → I1 | ✅ (0, 5, 22) |
| T13–T14 | I1 → I3 → I1 | ✅ (6000, 5, 0), area = Frost Peaks; back to (0, 5, 22). About 1,750 Island 1 tree parts streamed out while on I3 (Opportunistic) |
| T15 | Travel while combat-locked (`CombatUntil` in the future) | ✅ "You're in combat!" |
| T16 | Death on I2, then respawn | ✅ respawned on I2 at (3000, 5, 0) after 6.2 s |
| G1–G6 | Grandfathering on 6 save shapes (Starter, Pine, Crystal, Frost, invalid BestArea / LastIsland, existing unlock) | ✅ all as expected; nothing removed |
| R1 | Chopping after travel (Starter Grove, 8 s) | ✅ +118 Logs |
| R2 | Weapon rolls | ✅ 3/3 returned weapons |
| R3 | Upgrade (Faster Spin) | ✅ level 0 → 1, Logs deducted |
| C1 | Console errors from game scripts | ✅ none (only the expected `StudioAccessToApisNotAllowed` DataStore notices) |

### Not verified (needs follow-up)
- **Rejoin / persistence of `LastIsland` and `UnlockedIslands`:** Studio API access is **off** for the dev experience, so DataStores neither load nor save in Studio (the session ran with `_NoSave`). To test: enable *Game Settings → Security → Enable Studio Access to API Services* on the **dev** experience only (owner decision), or test in a private live dev server.
- **Multiple simultaneous players:** the arrival-slot ring is implemented but untested (MCP drives a single client). Use Studio *Test → Clients and Servers (2+)*.
- **Real latency / mobile devices / streaming timeout path:** only Studio local. The timeout path (`RequestStreamAroundAsync` failing) is wrapped in pcall but not forced.
- **Death mid-travel**, NPC chase across islands, Treant and Blade King while away: not exercised. The code handles a character change during travel.
- **Travel pads via ProximityPrompt:** wired to the same `travel()` function but not physically triggered in the test (the remote and DevTravel were used).

## Known limitations (by design for P1a)
- The test islands reuse legacy areas: Crystal Wilds reports `CrystalCanyon` and Frostbound Reach reports `FrostPeaks`. Arriving there raises `BestArea` exactly as entering the old areas does.
- Outside all island bounds, `GetAreaAt` falls back to the legacy rules. That's harmless in the void, and edge walls keep players on the floors.
- AreaService keeps its legacy "push back to last safe spot" behaviour. If a player's Power drops while on Island 2/3 (for example by equipping a weaker weapon), they're held at their last safe spot, as in the old Crystal and Frost areas.
- No client UI beyond prompts and notifications. No portal art. No new gates.

## Rollback
1. **Fastest, any time:** in Studio (dev place), *File → Version History* → restore the latest version saved **before 2026-11-19 05:20 UTC** (21:20 PST). That is the published P0 baseline; P1a is version 5.
2. **Manual:** delete `Workspace.Islands` and `ServerScriptService.TravelService`; restore `BladeConfig` and `DataService` from branch `p0/script-export` (`bb354a6`). Saved `UnlockedIslands` / `LastIsland` / `IslandProgress` keys are harmless extra fields if left in saves.
3. **Full:** republish the verified backup `BladeForest_ORIGINAL_73142469975141_2026-11-18_PRE_ISLANDS.rbxl` (SHA-256 `e050c6c3…6ffd`) **to the dev experience only**.
