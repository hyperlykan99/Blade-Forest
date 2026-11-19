# Blade Forest — M2 Technical Validation

_Prepared 2026-11-18 by Claude._

**Status:** RESEARCH AND PLANNING ONLY. Roblox Studio, scripts, terrain, monetization and player data were **not** modified. Nothing was saved or imported. **No construction is authorized by this document.**

**Inputs:**
- Docs: `LIVE_HANDOFF.md`, `ISLAND_BLUEPRINT.md`, `STARTER_ISLAND_M2.md`, `ECONOMY_MONETIZATION_AUDIT.md`.
- A read-only MCP survey of place `73142469975141`: Edit mode, not running, 34 scripts / 393,047 bytes, unchanged since the last audit.
- Model files: `docs/m2_island_sim.py`, with raw output in `docs/m2_sim_results.txt`.

**Tags used in this report:**

| Tag | Meaning |
|---|---|
| **[MEASURED]** | Read from the live place during this survey |
| **[VERIFIED]** | Read from live script source |
| **[PROPOSAL]** | A new design choice for owner review |
| **[ESTIMATE]** | Simulation output; depends on the assumptions in §6 |

---

## 1. Summary

1. **Keep Island 1 at the world origin and reuse the existing Starter + Pine map [PROPOSAL].**
   - The current central disc (radius 330, about 660 × 660) already holds the spawn plaza, stations, leaderboards, camps, Blade King arena and Treant site, and it fits the draft 640 × 560 footprint.
   - Building Island 1 elsewhere would mean moving 3,080 trees, 4 camps and every origin-relative constant, for no gain.
2. **Place Islands 2 and 3 at (3000, 0, 0) and (6000, 0, 0) [PROPOSAL].** With 3,000 studs between centers (a gap of at least 2,350), only one island is ever within the current `StreamingTargetRadius` of 1,024. Island 4+ slots continue the same grid.
3. **The area system is hard-wired to origin-relative geometry [VERIFIED].**
   - `Config.GetAreaAt(pos)` identifies areas by radius and X/Z thresholds.
   - A player standing on an island at x = 3000 would be classified as **Crystal Canyon** (if |z| < 132) or **Pine Forest** otherwise.
   - That breaks AreaService gating, `BestArea` pricing, AutoChop pathing and NPC rules.
   - **Replacing `GetAreaAt` with an island-registry lookup is the critical-path dependency.**
4. **Today every client loads the whole world [MEASURED].** That's 23,395 BaseParts (16,599 MeshParts), 488 lights and 803 particle emitters, all within an extent of about 1,000 studs, smaller than the 1,024 streaming radius. Splitting into islands reduces what a client loads. Island 1 alone is still about 14,600 parts, above the proposed mobile budget, so it needs trimming either way.
5. **Simulation: checklist gates fix both the D1 burn-through and the D7 wall [ESTIMATE, 200 seeds, equal 45-minute sessions].**
   - The recommended gates are **"600 trees + Power 60 + Blade King"** for Island 2 and **"6,000 Island-2 trees + Power 500 + Island-2 boss"** for Island 3.
   - Results: free players reach Island 2 at **23 min** (p10–p90 22–25) and Island 3 at **3.8 h** (3.5–4.1).
   - Paying players are only **8–15% faster at equal playtime**.
   - A Power-2,000 floor, or a Logs-earned checklist, brings the pay-to-win gap and the long tail back.

---

## 2. Read-only survey of the current map [MEASURED]

### 2.1 World settings
| Setting | Value |
|---|---|
| StreamingEnabled | **true** |
| StreamingMinRadius / TargetRadius | 64 / **1,024** |
| StreamingIntegrityMode | PauseOutsideLoadedArea |
| ModelStreamingMode / StreamOutBehavior | Default / Opportunistic |
| FallenPartsDestroyHeight | −500 |
| Terrain MaxExtents | ±32,000 (engine default; no limit for the planned coordinates) |
| CharacterMaxSlopeAngle | 32 (set earlier for climb blocking) |

### 2.2 Terrain footprint
Terrain exists from about **x −680 to +360** and **z −400 to +360**. Samples every 40 studs: 281 Grass, 81 Rock, 62 Snow (Frost annex), 19 Ground, 10 Basalt. There is **no water** and nothing beyond those bounds; empty void surrounds the map.

```
       x: -840 ......................... 0 ............ +520     (one char = 40 studs; z +440 top → −440 bottom)
  360            .11112223332221111.            ← north rim (hills to y 30–60)
  200     3333333.33211111111111123.            ← Frost annex top edge (x −680…−345)
    0      32111111111111111111111..23          ← flat play area (y < 12), east canyon (x 188–324)
 -200     23333332.23111111111111222.
 -360            .11112223333221111.            ← south rim
 legend: . <2   1 <12   2 <30   3 <60   4 ≥60 studs height
```

### 2.3 Areas
Areas are defined in code by position (`BladeConfig.GetAreaAt`, VERIFIED), not by folders:

| Area | Rule | Approx. bounds | Trees | Tree parts (meshes) | Mutated |
|---|---|---|---|---|---|
| Starter Grove | radius ≤ 130 from origin | disc ∅260 | 848 | 6,792 (5,912) | 34 |
| Pine Forest | everything else in the disc | ring 130–330 | 2,232 | 6,824 (4,458) | 110 |
| Crystal Canyon | x > 188 and \|z\| < 132 | 136 × 264 wedge | 400 | 3,188 (2,788) | 23 |
| Frost Peaks | x < −345 | x −660…−345, z ±175 (315 × 350) | 921 | 5,606 (3,209) | 27 |
| **Total** | | | **4,401** | **22,410 (16,367)** | 194 |

Walls and gates (`Map.AreaWalls`, 144 parts):
- `StarterHedge` at radius 130, with four Pine gates at ±130.
- `CanyonWalls` at x 188–324, with its gate at (188, 0).
- `Gate_FrostPeaks` at (−345, 0).

`Map.Border`: 40 invisible 300-stud-tall walls on the radius-330 circle, plus the annex box out to x = −660.

### 2.4 Spawns, structures, NPCs, bosses
| Object | Position (x, z) | Notes |
|---|---|---|
| SpawnLocations ×4 | (0, ±16), (±16, 0) | Inside `Map.SpawnPlaza` (origin, 64 × 64) |
| Stations: LogMarket, PetEgg | (24, 24), (27, 2) | ProximityPrompt `OpenPanel` |
| TraitCrate | (19, −19) | Plaza |
| Leaderboards ×3 | x −37…−18, z −33…33 | Plaza west |
| Roll altars (Config.Altars) | Starter (−19, −19), Pine (−150, 16), Crystal (232, 16) | Range 22 |
| Camps ×4 (Rogue Lumberjacks) | (±152, ±152) | 504 parts total; Pine ring |
| Blade King arena | **(0, −270)**, radius 48 | `Config.ArenaCenter`; respawn 240 s |
| Ancient Treant (world boss) | **(0, 205)** | `Config.WorldBoss.Position`; every 1,200 s |
| Slime zones (WorldServer) | Slime ring r 142–200, Big Slime r 150–270, Golden Slime x 215–305 / z ±100 | Origin-relative; Golden Slime sits in Crystal Canyon |
| Frost Peaks NPCs | none | No camp, no boss |

### 2.5 Mobile-relevant load
- **Everything is streamed to every client.** The world extent (about 1,000 studs) is under the streaming radius of 1,024.
- Breakables are 4,401 tree models. Heaviest per tree: Frost Mythic **370 parts** (×4) and a Pine outlier with 135. Most trees have 3–8 parts.
- 488 Light objects and 803 ParticleEmitters in Workspace, mostly glows on rare and mutated trees.
- A play-mode mobile frame-rate and memory test was **not** run, because this survey was edit-mode and read-only. It's required in P2 (§8).

---

## 3. Proposed three-island layout [PROPOSAL]

### 3.1 World placement
| Slot | Island | World center (x, y, z) | Usable footprint | Source content |
|---|---|---|---|---|
| 1 | Timber Haven | **(0, 0, 0)** (existing) | X −320…320, Z −280…280 | Starter Grove + Pine Forest, in place |
| 2 | Crystal Wilds | **(3000, 0, 0)** | 560 × 480 (X 2720…3280, Z −240…240) | Crystal Canyon trees, enlarged loop |
| 3 | Frostbound Reach | **(6000, 0, 0)** | 640 × 560 (X 5680…6320, Z −280…280) | Frost Peaks trees + new boss |
| 4 | Future | (9000, 0, 0) | ≤ 640 × 640 | New |
| 5–7 | Future | (0 / 3000 / 6000, 0, 3000) | ≤ 640 × 640 | New |

Why this placement:
- **Separation.** 3,000 between centers leaves at least 2,350 studs between coastlines. That exceeds the 1,024 streaming radius plus a margin, so clients drop the previous island after travel, and the radius could later rise to about 1,500 with islands still isolated.
- **Precision.** Every slot stays within 10,000 studs of the origin, well inside safe physics and float precision.
- **Height.** Ground level is y ≈ 0–30, the same as today. That keeps islands far above `FallenPartsDestroyHeight` (−500) and lets them share the existing tree-height assumptions in CombatServer.
- **Retirement.** The old Crystal Canyon wedge and Frost annex stay untouched until content migration is approved and tested (P3), then are retired. The old canyon wedge becomes Island 1's **Portal Ridge**.

### 3.2 Island 1 zone mapping onto existing geometry
ChatGPT's draft (`STARTER_ISLAND_M2.md`) puts the spawn south at (0, −145) and the boss north-east. On the real map that conflicts with existing assets: the Blade King arena is south at (0, −270), and the spawn plaza and stations are at the origin. **The recommended mapping reuses what exists:**

| Draft zone | Recommended location (world) | Reason |
|---|---|---|
| Welcome spawn + plaza | **(0, 0)** existing SpawnPlaza / stations / leaderboards | No relocation; 4 SpawnLocations already there |
| First-chop / beginner grove | Starter disc, radius 30–130 | 848 low-HP trees already within 10–20 s of spawn |
| Pine woodlands + NPC camps | Ring, radius 130–330 | Existing camps at (±152, ±152) |
| Starter boss clearing | **(0, −270)** existing Blade King arena | Keeps `ArenaCenter` and UI logic |
| Recurring world-boss site | (0, 205) Treant | Unchanged |
| Portal Ridge (Island 2 portal + sealed future pads) | **(240, 0)**, inside the current canyon wedge after Crystal content moves (x 188–324, z ±132) | Visible from the plaza; walls already define the space |

Owner decision needed: accept this mapping or keep the draft layout. The draft layout would require rebuilding Island 1.

### 3.3 Arrival, portal and boss anchors for Islands 2 and 3
| Anchor | Island 2 (world) | Island 3 (world) |
|---|---|---|
| Arrival pad / SpawnLocation | (2780, 0) facing +X | (5740, 0) facing +X |
| Return portal (to Island 1 plaza) | (2770, 30) | (5730, 30) |
| Upgrade / roll / egg station cluster | (2860, 0) | (5830, 0) |
| Boss arena (radius 48) | (3150, −150) | (6150, −180) |
| Onward portal | (3220, 150) to Island 3 | (6240, 200) to sealed Island 4 pad |

### 3.4 Travel times
`StarterPlayer.CharacterWalkSpeed` is 16 studs/s [MEASURED]; scripts only change NPC speeds (13 and 11). That gives:
- Spawn to first trees: about 2 s.
- Plaza to Portal Ridge (240 studs): about 15 s.
- Plaza to the Blade King: about 17 s.

These are inside the draft targets (under 10 s to first tree, under 25 s to the grove). Measure on devices in P2.

---

## 4. Same-place travel, streaming and mobile requirements

### 4.1 Teleport flow [PROPOSAL; uses no TeleportService]
```
Client taps portal or directory ─► RemoteFunction Travel(islandId)
Server:
  1. Player loaded, alive, not mid-travel, 3 s cooldown
  2. islandId in registry, ReleaseState == "available"
  3. Player has unlocked islandId (saved UnlockedIslands, server-evaluated)
  4. Not PvP combat-locked (Config.PvP.CombatLock = 15 s)
  5. player:RequestStreamAroundAsync(anchor.Position, 8)   -- preload the destination
  6. Pick a free slot on the anchor ring (radius 6, 8 slots) → character:PivotTo(slot)
  7. player.RespawnLocation = island SpawnLocation; set attribute CurrentIsland; save LastIsland
  8. Return ok → client fades in (PauseOutsideLoadedArea keeps the client from falling)
```
- **Respawn:** set `Player.RespawnLocation` per island, so deaths respawn on the current island. Today's 4 SpawnLocations are all at the origin.
- **Rejoin:** spawn on the last island if it's still unlocked, otherwise Island 1.
- **AFK return:** AFKService and AFKController use TeleportService to send players to an AFK place and back [VERIFIED]. The return must carry `CurrentIsland` in its teleport data.

### 4.2 Streaming settings to test (P2, dev copy only)
| Item | Recommendation |
|---|---|
| StreamingTargetRadius | Keep 1,024 first. Consider 768 if low-end memory requires it; separation already isolates islands |
| StreamingMinRadius | 64 → **128**, so trees around the arrival pad are guaranteed present |
| Portal / spawn anchor models | `ModelStreamingMode = Persistent` (small part count) |
| Tree models | `Atomic`, so a tree and its hitbox stream together |
| Boss and Treant models | `Atomic` |

### 4.3 Mobile budget per island (targets to validate)
| Metric | Proposed budget | Island 1 now | Island 2 (Crystal now) | Island 3 (Frost now) |
|---|---|---|---|---|
| BaseParts streamed | ≤ 10,000 | ≈14,600 (13,616 trees + ≈1,000 map) ⚠️ | 3,188 + build | 5,606 + build |
| MeshParts | ≤ 7,000 | ≈10,600 ⚠️ | 2,788 | 3,209 |
| Lights | ≤ 60 | ~300 (share of 488) ⚠️ | — | — |
| ParticleEmitters | ≤ 150 | ~500 (share of 803) ⚠️ | — | — |
| Max parts per tree model | ≤ 40 | 135 outlier | 16 | **370** ⚠️ |

Island 1 needs trimming:
- Reduce Pine's 2,232 trees to about 1,400. Spacing allows it, and respawn keeps the density feeling full.
- Remove PointLights from common and mutated trees; keep them on Mythic/Secret only.
- Replace the 370-part Frost Mythic template.

All of this applies only after construction approval.

---

## 5. Systems that need changes [VERIFIED dependencies]

| # | System | Current dependency | Change needed |
|---|---|---|---|
| 1 | **BladeConfig `GetAreaAt`, `StarterRadius`** | Origin radius and X thresholds | **Island registry with bounds.** `GetAreaAt` resolves the island first, then the legacy area inside Island 1 (Starter vs Pine). Used by AreaService, CombatServer, WorldServer and AutoChop |
| 2 | **AreaService** | Power vs `RequiredPower` by position; pushes back to the last safe CFrame; sets `BestArea` on first entry | Validate against `UnlockedIslands`. Pine sub-gate stays power-based. `BestArea` rises on island arrival. Keep the safety net against flying or noclip into locked bounds |
| 3 | **New TravelService** + client portal UI | none | Flow in §4.1; registry-driven destination list showing lock reasons |
| 4 | **DataService** | `BestArea` only | Add `UnlockedIslands`, `LastIsland`, `IslandProgress` (trees per island, boss flags) through `DEFAULT` and `reconcile`. **Grandfather:** BestArea ≥ CrystalCanyon unlocks I2; FrostPeaks unlocks I2 and I3. Never remove legacy keys |
| 5 | **Progress** | Quest stats | Increment per-island tree and boss counters for the gates |
| 6 | **WorldServer** | Slime `ringPoint` around the origin; Golden Slime in the canyon wedge; NPCs never chase into the Starter Grove; Blade King at `ArenaCenter` | Spawn zones per island from the registry; move Golden Slime to Island 2; add an Island 2 boss and an Island 3 NPC/boss (none exist today) |
| 7 | **CombatServer** | Tree respawn uses the tree's `Area` attribute, falling back to `GetAreaAt` | Safe once trees carry `Area`; check the fallback after the registry change |
| 8 | **ExtrasService (Treant)** | Fixed (0, 0, 205); message says "north Pine Forest" | Stays on Island 1, or rotates by registry; decide how a server-wide world boss behaves across islands |
| 9 | **UIController** | Boss HP bar uses distance to `ArenaCenter` | Per-island arena list |
| 10 | **ChopEffects** | Reads `Map.AreaWalls` gates with `RequiredPower` attributes | Show portal-lock state instead of walls for islands |
| 11 | **AutoChop (client)** | Walks to targets where `GetAreaAt` is unlocked | Restrict targets to the current island's bounds |
| 12 | **Config.Altars / RollController** | Altar per legacy area | Altar positions per island |
| 13 | **AFKService / AFKController** | TeleportService round trip | Carry `CurrentIsland` in teleport data |
| 14 | **Pricing keyed by `BestArea`** (crates, eggs, log packs, sawmill, codes, rewards) | Highest area reached | No code change needed. Note: returning to Island 1 keeps Island 3 prices, which is existing behavior |
| 15 | **Stations / leaderboards** | Plaza at the origin | Duplicate the station cluster per island; leaderboards stay on Island 1 |

---

## 6. Updated economy simulation [ESTIMATE]

### 6.1 Model
- **Files:** `docs/m2_island_sim.py`, results in `docs/m2_sim_results.txt`.
- **Verified inputs:** BladeConfig weapon odds (rarest-first cascade), every-10th-roll ×2, upgrades, tree stats per area, mutations, traits, pets, passes.
- **Island mapping:** Island 1 = Starter + Pine trees (Pine needs Power 40 for full damage); Island 2 = Crystal trees; Island 3 = Frost trees.
- **Equal playtime:** every archetype plays 45-minute sessions (one per day) for up to 20 h. **200 seeds**; percentiles p10 / p50 / p90.
- **Archetypes:**
  - Free.
  - Casual: Starter Pack + 2× Logs + Fast Roll, 547 R$.
  - Heavy: all 7 passes, 1,693 R$.
  - Heavy + Mega: also a Mega Luck potion for the whole of every session. Hypothetical, because the products aren't live.
- **Luck variants:**
  - A: current multiplicative stacking.
  - B: paid luck adds instead of multiplying, and total roll luck is capped at 25×.
- **Gate candidates (not approved):**
  - **G2:** 600 trees chopped AND Power ≥ 60 AND Blade King defeated (modelled as +3 min once Power ≥ 60).
  - **G3:** Power floor ∈ {500, 1,000, 2,000} AND a checklist, either **L** (Logs earned on Island 2 ≥ 25 M) or **T** (trees chopped on Island 2 ≥ 6,000).
- **Assumptions:** 1.6 s walk per tree, 1.3 trees in reach, auto-roll all the time, greedy spending, one free 15-minute Luck Potion per session, group joined, no rebirths or events.

### 6.2 Results (minutes or hours of playtime; equal sessions)
**Island 2 (all variants):**
- Free: 22 / **23** / 25 min.
- Casual: 20 / 21 / 22 min.
- Heavy: 19 / 19–20 / 20 min.

The tree checklist sets the pace, so paid boosts barely matter. ✅ This hits the draft target of 20–30 minutes.

**Island 3:**
| Gate 3 | Luck | Free p10/p50/p90 | Casual p50 | Heavy p50 | Heavy+Mega p50 | Free not in 20 h |
|---|---|---|---|---|---|---|
| **T + Power 500** | A | 3.5 / **3.8** / 4.1 h | 3.5 h | 3.3 h | 3.2 h | 0% |
| T + Power 1,000 | A | 3.5 / 4.0 / **7.9** h | 3.5 h | 3.3 h | 3.2 h | 0% |
| T + Power 2,000 | A | 3.6 / 7.6 / **>20** h | 4.7 h | 3.4 h | 3.2 h | **14%** |
| T + Power 2,000 | B (cap) | 3.6 / 7.6 / >20 h | 7.2 h | 6.3 h | 3.3 h | 14% |
| L + Power 500 | A | 4.8 / 5.8 / 6.8 h | **2.9 h** | **2.3 h** | 1.9 h | 0% |
| L + Power 1,000 | A | 4.8 / 5.8 / 7.9 h | 2.9 h | 2.3 h | 1.9 h | 0% |
| L + Power 2,000 | A | 4.8 / 7.6 / >20 h | 4.7 h | 2.7 h | 1.9 h | 14% |

### 6.3 Findings
1. **Use trees chopped (T), not Logs earned (L).** Logs scale with 2× Logs, VIP, traits and pets, so L makes payers 2.0–2.5× faster at equal playtime. T keeps the gap at **8–15%**: a convenience advantage, in line with the blueprint's "no paid skip" rule.
2. **Keep the Power floor attainable: 500 recommended.** 1,000 adds an unlucky tail (free p90 is 7.9 h, versus 4.1 h at 500). 2,000 recreates today's wall: 14% of free players don't reach Island 3 in 20 h of play, and the luck cap doesn't help them.
3. **The luck cap (variant B)** has no effect at floors ≤ 1,000, because the checklist binds. It matters only with a high random floor, where it narrows Heavy vs Free. Keep it on the agenda for weapon chase balance, separately from island gates.
4. **Pacing:** Island 3 at about 3.8 h is about 5 sessions of 45 minutes, so a free player arrives around **D5**. That gives D2–D4 a visible Island 2 checklist rather than a random wall. Island 3 then needs its own long-term goals (bosses, collections, rebirth) to carry D7+.
5. **Starter Pack note:** Founder's Edge (power 60) satisfies G2's Power part at once. The 600-tree checklist still applies, so the comprehension requirement holds.

### 6.4 Model limits
- No rebirths, events, PvP or Souls paths are modelled.
- Boss fights are a 3-minute placeholder.
- Pacing constants are guesses, so absolute times may move ±30%. Relative free-vs-paid comparisons are more reliable than absolute times.
- Calibrate with playtest telemetry: trees per minute by island.

---

## 7. Risks
| Risk | Severity | Mitigation |
|---|---|---|
| `GetAreaAt` misclassifies island coordinates (wrong gate push-back, wrong `BestArea` price tier) | **Critical** | Registry lookup first; unit-test sample points per island |
| Old saves lose access, or get double grants, during migration | High | Grandfather rules (§5 #4); test old, maxed and new accounts in a dev copy; no key removal |
| Mobile memory on Island 1 (≈14.6k parts, 300 lights) | High | Trim per §4.3 before launch; device tests |
| Players fall or stall on arrival because of streaming | Medium | `RequestStreamAroundAsync` before the pivot; MinRadius 128; Persistent anchors |
| Portal spam, or travelling to dodge PvP or bosses | Medium | Cooldown and combat-lock check |
| Server-wide Treant/events while players are spread across islands | Medium | Decide: per-island bosses, or a global boss with a travel prompt |
| AFK teleport returns players to the wrong island | Low | Teleport data carries `CurrentIsland` |
| Suspicious imported scripts reused by accident while building islands | Medium | Asset manifest and script strip before import (AI_HANDOFF rule) |

---

## 8. Recommendations and next steps (all need separate owner approval)
1. **Approve the coordinates (§3.1) and the Island 1 reuse mapping (§3.2)**, or ask for the draft layout instead.
2. **Approve the candidate gates for prototyping:** G2 = 600 trees + Power 60 + Blade King; G3 = 6,000 Island-2 trees + Power 500 + Island-2 boss. Final numbers come after playtest calibration.
3. **P0, on approval:**
   - Create an isolated development copy of the place and back up the live place.
   - Export scripts to `src/` (still waiting on the `.rbxlx`).
4. **P1 (dev copy only):**
   - Island registry and `GetAreaAt` replacement.
   - TravelService.
   - DataService fields with grandfathering.
   - Empty Island 2 and 3 blockouts at the proposed coordinates.
5. **P2:** streaming and mobile tests on low-end iOS and Android, using the §4.3 budget; travel edge-case matrix (death on pad, rejoin, two players, lag, active boss, AFK return).
6. Fold the receipt and save fixes from the economy audit into P1. Any island work touches DataService anyway.

_This document records research only. No Studio changes were made._
