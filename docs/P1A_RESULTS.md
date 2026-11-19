# Blade Forest — P1a Island Prototype Results

_2026-11-18, Claude. Owner-approved P1a only. P1b/P1c/P2 are **not** started._

## Target and identity
| | |
|---|---|
| Place edited | **Blade Forest - Island Dev**, place **103379930563763**, universe **10777797608** (PRIVATE, personal owner). `game.PlaceId` and `game.GameId` were asserted inside every write command |
| Saved version | **Dev place version 7** (current: "P1a verification fixes - travel power check, island sync, persistent arrival pads"). Version 5 = initial P1a; version 6 = a Team Create autosave |
| Production | Place 73142469975141 / universe 10777481912: **not modified**. `updateTime` still `2026-11-18T15:12:30.520Z` after P1a |
| Rollback checkpoint | Before writing, `save_place` reported "no unsaved changes", so the cloud version matched the untouched P0 baseline. A version label could not be added (the first save call errored); see Rollback |

## Changes in Studio (dev place only)
| Item | Change | Size |
|---|---|---|
| `ReplicatedStorage.BladeConfig` | Added the `Config.Islands` registry (3 islands with stable IDs, bounds, arrival points, legacy area mapping), plus `IslandById`, `HomeIsland`, `TravelCooldown = 3`, `GetIslandAt(pos)` and `GetIslandRequiredPower(isl)`. `GetAreaAt` checks the island first; the legacy logic is unchanged | 53,433 → 55,586 B |
| `ServerScriptService.DataService` | Added `UnlockedIslands = {TimberHaven=true}`, `LastIsland = "TimberHaven"` and `IslandProgress = {}` to `DEFAULT` (filled in by `reconcile`). Added grandfathering after reconcile: BestArea Crystal Canyon unlocks Crystal Wilds; Frost Peaks unlocks both. **It only ever adds.** No keys deleted or renamed | 18,797 → 19,574 B |
| `ServerScriptService.TravelService` (new; revised in verification, **7,991 B**) | Server-authoritative same-place travel. `Remotes.Travel` RemoteFunction is created at runtime. ProximityPrompt pads with a `TravelTo` attribute. Respawn and rejoin placement. Studio-only `ServerStorage.DevTravel` hook (created only when `RunService:IsStudio()`) | 7,009 B |
| `Workspace.Islands` (new folder, 18 basic Parts) | `TimberHaven`: 2 neon travel pads at (−12, 2.5, −26) and (12, 2.5, −26) beside the spawn plaza. `CrystalWilds` at (3000, 0, 0) and `FrostboundReach` at (6000, 0, 0): each has a 160×4×160 anchored arrival floor (top y = 2), 4 invisible edge walls, a neon arrival marker, a billboard label and a return pad. All three island models now use `ModelStreamingMode = Persistent` (changed from Atomic during verification) | 18 parts |

Unchanged: all other 31 scripts, every existing map object, the Crystal Canyon wedge and Frost annex, commerce, odds, economy, assets and the import folders.

**GitHub:** branch **`p1a/island-prototype`** (commits `0f0e3b6` + `3511a5c`, based on `p0/script-export`). The three changed scripts are checksum-identical to Studio. Workspace objects exist only in Studio.

## Unlock rule (P1a)
**Travel requires the player's current Power ≥ the legacy gate of the island's mapped area** (since verification; this matches what AreaService enforces). The unlock is then recorded in `UnlockedIslands` for future P1c gates and UI. Gates: Crystal Wilds 250 (Crystal Canyon), Frostbound Reach 2,000 (Frost Peaks). This is deliberately the existing area gate, so **no economy change**. The M2 checklist gates are P1c work and need approval.

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


---

## Verification round (2026-11-18 21:30–22:30 PST)

Dev place 103379930563763 only. One Studio solo playtest client; rejection, prompt and travel tests used the real client paths.

### Defects found and fixed (dev place v7, branch `3511a5c`)
| # | Defect | Fix |
|---|---|---|
| V-1 | **Saved unlock vs. legacy gate conflict.** A player with a saved `UnlockedIslands.CrystalWilds` but Power below 250 could travel, then AreaService bounced them back to Island 1 while `CurrentIsland` still said CrystalWilds | Travel now also requires the current legacy Power gate (same rule as AreaService). A server loop syncs `CurrentIsland`/`LastIsland` from the character's actual position once a second |
| V-2 | **Arrival without streaming = fall into the void.** A character placed on an unstreamed island fell from y 5 to −520 before the floor arrived (0.46 s). `PauseOutsideLoadedArea` did not prevent it | Island models are now **Persistent** (arrival floors always on every client; 18 parts total). Travel is **aborted** with "Couldn't load … try again" if `RequestStreamAroundAsync` errors |

### Results
| # | Test | Result |
|---|---|---|
| **1. Persistence** | Rejoin with saved `UnlockedIslands` / `LastIsland` | ⚠️ **Blocked, not run.** Studio API access is off for the dev experience (`StudioAccessToApisNotAllowed`, session `_NoSave`). The toggle is in Experience Settings → Security, which runs as a separate process that Claude can't operate in background mode. **Partial evidence:** live island fields are present in the save table and returned by `GetData`; their JSON round trip (the DataStore format) is lossless (`{"UnlockedIslands":{…},"LastIsland":"TimberHaven","IslandProgress":[]}`); load-time grandfathering is unit-tested (G1–G6); rejoin placement code is the same path as respawn (T16 ✅) |
| **2. Two players** | Simultaneous travel and arrival-slot spreading | ⚠️ **Blocked, not run.** "Server and Clients" started a 0-client server; the client-count field and **Test → Add Clients** can't be operated in background mode. Single-player arrival slot 0 is verified; ring slots 1–8 are untested |
| **3. ProximityPrompts** | P2: Island 1 pad (real `InputHoldBegin/End`) → Crystal Wilds | ✅ server `PromptTriggered`; landed (3000, 5.8, 0) |
| | P3: Crystal Wilds ReturnPad → home | ✅ (0, 5.8, 22) |
| | P4: locked pads at Power 60, including a saved unlock (V-1 case) | ✅ after fix: no move; "🔒 Frostbound Reach needs 2000 Power"; `CurrentIsland` correct |
| | Note | The first press within about 1 s of arriving at a pad didn't register: the client hadn't shown the prompt yet (`PromptShown` fired later). This is a harness-timing artefact; with a 3 s wait both presses registered. Real players can only press a shown prompt |
| **4. Death during travel** | D1: kill the character while the server waits in `RequestStreamAroundAsync` | ✅ travel returned "Character changed during travel"; `CurrentIsland` stayed TimberHaven; respawned at the normal I1 spawn |
| | D2: next travel right after | ✅ succeeded (not stuck "Already travelling") |
| **Streaming failure** | S1 (before fix): arrival with no stream request | ❌ fell to y −520 (V-2) |
| | S2 (after fix) | ✅ floors present on the client from spawn; landed and stayed at y 5.0–5.8 |
| **Post-fix travel matrix** | invalid id; I1→I2→I1; I1→I3→I1; spam ×4 | ✅ all as expected (spam: 4/4 rejected within cooldown) |
| **5. Regressions** | R1 chopping (8 s Starter Grove) | ✅ +42 Logs |
| | R2 weapon rolls ×3 | ✅ Iron, Wooden, Woodsman Axe |
| | R3 upgrade Damage | ✅ level 0 → 1 |
| | R4 Sawmill info | ✅ rate 1.3 |
| | R5 pet hatch | ✅ correctly refused: "Need 12.0M Logs". Price is from `BestArea` = Frost Peaks, raised by the earlier I3 test trip, same as entering the old Frost area |
| | R6 Claim Index All / R7 Claim Daily | ✅ "Nothing to claim" / streak 1 |
| | R8 GetData | ✅ includes the island fields |
| | R9 NPCs | ✅ 24 slime-family NPCs, Blade King present, 4 camps |
| | R10 Treant (DevExtras) | ✅ spawned at (0, 2, 205) |
| | R11 multipliers | ✅ LogMult 2.2, LuckMult 4.4, Power and area attributes normal |
| | Console | ✅ no game-script errors |

### Still unverified
- **Rejoin persistence** (needs Studio API access on the **dev** experience, or a private live dev-server test).
- **Two-player** simultaneous travel and slot spreading (needs the client count set to 2 in Studio's test toolbar, or two live clients).
- Real network latency, mobile devices, and a genuine `RequestStreamAroundAsync` timeout.

### Owner steps to finish verification (dev experience only)
1. Studio (Island Dev window) → **File → Experience Settings → Security → Enable Studio Access to API Services → Save.**
2. In the Studio toolbar, set the test mode to **Server & Clients** and the client count to **2**, and press **Start**. Then tell Claude, who drives both clients over MCP.

### Final-test attempt (2026-11-18 21:50 PST)
- **Studio API access check: ❌ not active for the dev place.** A playtest in place 103379930563763 made a direct `DataStoreService:GetDataStore("BladeForest_v3"):GetAsync(...)`, which returned `502: API Services rejected request … Error code: 7 … Studio access…`. The session loaded with `_NoSave = true`. **The persistence test (1) was not run**, because no save can be written or read yet.
- **Two-player test (2): not run.** It needs the owner to start Server & Clients with 2 clients (the toolbar control doesn't accept background input).
- Production `updateTime` re-checked: unchanged (see the handoff).

### Final-test attempt 2 (2026-11-18 ~22:00 PST, after the owner reported reopening the place)
- **Studio API access: ❌ still rejected** in place 103379930563763 (`502 … Error code: 7 … Studio access to APIs`; the session loaded with `_NoSave = true`). **Persistence test not run.**
- **2-client session: not detected.** MCP saw only the dev place in Edit mode (no Play server or client DataModels), so the two-player test was not run.
- Production `updateTime` unchanged (`2026-11-18T15:12:30.520Z`).

### Final-test attempt 3 (2026-11-18 ~22:10 PST, place reopened; Studio instance `b6c1…`)
- **Studio API access: ✅ active** in place 103379930563763 (direct `GetAsync` on `BladeForest_v3` succeeded; session loaded with `_NoSave = nil`).
- **Persistence and rejoin: ✅ PASS** (dev DataStore, test account 394034825):
  1. Session 1: granted the Void weapon to the dev save (Power 1,834) and travelled to Crystal Wilds through the real `Remotes.Travel` → landed at (3000, 5.8, 0).
  2. Explicit `DataService.Save`, then a raw `GetAsync` read back: `{"UnlockedIslands":{"TimberHaven":true,"CrystalWilds":true},"LastIsland":"CrystalWilds","IslandProgress":[],"Equipped":"Void","BestArea":"CrystalCanyon"}`.
  3. Stopped the playtest (leave), started a new one (rejoin): loaded `Unlocked={CrystalWilds, TimberHaven}`, `LastIsland = CrystalWilds`, Power 1834. **The player was placed on Crystal Wilds at (3000, 5.8, 0)**, stable for 2+ s; `CurrentIsland` = CrystalWilds, `CurrentArea` = CrystalCanyon.
  - Note: the dev test account's save now holds the Void weapon and a Crystal unlock (dev data only).
- **Two-player test: ⏳ not run.** No Server & Clients session was running (MCP saw only the dev place in Edit mode).
- Production `updateTime` unchanged (`2026-11-18T15:12:30.520Z`).

### Two-player attempt (2026-11-18 ~22:10 PST)
- **Not run: no 2-client session was running.** MCP listed only the dev place in Edit mode (instance `b6c1…`). The Island Dev toolbar showed test mode **"Server & …"** with the **client count at 0** and the session not started (Play enabled, Stop disabled).
- Production `updateTime` unchanged (`2026-11-18T15:12:30.520Z`, checked 22:05 PST).

### Status at handoff to Codex (2026-11-18 22:20 PST)
| Area | Status |
|---|---|
| Registry / classification | ✅ |
| Travel I1↔I2, I1↔I3; invalid, locked, spam, cooldown, combat lock | ✅ |
| ProximityPrompt pads (real input) | ✅ |
| Death mid-travel; respawn on island | ✅ |
| Streaming failure (V-2 fixed: Persistent arrival models + abort) | ✅ |
| Unlock vs. legacy gate (V-1 fixed) | ✅ |
| Grandfathering (unit) | ✅ |
| **Persistence and rejoin (dev DataStore)** | ✅ |
| Regressions (chop, roll, upgrade, sawmill, egg pricing, index, daily, NPCs, Blade King, Treant) | ✅ |
| **2-player simultaneous travel / arrival spacing / independent states** | ⏳ **NOT RUN** (no 2-client session was running) |

### Codex: remaining test (dev place only)
1. Owner: in the Island Dev toolbar set mode **Server & Clients**, client count **2**, press **Play ▶**.
2. Server: confirm 2 players, `Loaded`. Set Power for both as a transient attribute (`SetAttribute("Power", 2500)`) or use the dev save.
3. From both clients **at the same time**, `Remotes.Travel:InvokeServer("CrystalWilds")` → expect both `true`, positions ≥ 3 studs apart (slot 0 at (3000, 5, 0) and a ring slot 6 studs away), both stable on the floor.
4. Independent states: send client A to `FrostboundReach` and keep B on `CrystalWilds`; check each `CurrentIsland` attribute and that A's cooldown doesn't affect B.
5. Both `TimberHaven` → both at or near (0, 5, 22), not stacked.
6. Record results here and in `LIVE_HANDOFF.md`; release the editor row.
