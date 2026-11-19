# Blade Forest — P1b Migration Blueprint (P1b.1, planning only)

_Prepared 2026-11-19 by Claude._

**Authorization:** P1b.1 research, read-only inspection and blueprint only. **No construction is authorized.** Owner approval is required before P1b.2.

**Target:** dev place **103379930563763** / universe **10777797608**. **Never** production 73142469975141 / 10777481912.

**Inputs:** `ISLAND_BLUEPRINT.md`, `M2_TECHNICAL_VALIDATION.md`, `P1_PROTOTYPE_SCOPE.md`, `P1A_RESULTS.md`, `LIVE_HANDOFF.md`. Read-only MCP inspection of the dev place on 2026-11-19 00:20–00:40 PST.

**Machine-readable manifest:** `docs/p1b_asset_manifest.json`.

| Tag | Meaning |
|---|---|
| **[MEASURED]** | Read from the dev place during this inspection |
| **[VERIFIED]** | Read from script source |
| **[PROPOSAL]** | Needs owner approval |
| **[ESTIMATE]** | Projection; validate when building |

---

## 0. Baseline verified before planning [MEASURED]
| Item | Value |
|---|---|
| Studio identity | `game.PlaceId` 103379930563763, `game.GameId` 10777797608, Edit mode; no other AI editing (handoff row "None") |
| Build | P1a + M-1, **dev v9**: BladeConfig 55,586 B `3426233414`, DataService 19,574 B `676054173`, TravelService 9,388 B `3611788483` (length:Adler-32). Equal to branch `p1a/m1-arrival-slot-fix` @ `7f925b4` (TravelService) and `p1a/island-prototype` @ `3511a5c` (the other two) |
| Islands | `Workspace.Islands`: TimberHaven (2 pads), CrystalWilds and FrostboundReach test floors; 18 parts, all models Persistent |
| Trees | 4,401 total in `Workspace.Breakables` |
| Production | Not touched by this work |

---

## 1. Inventory of the original areas (both on Island 1 / Timber Haven)

### 1.1 Crystal Canyon (east wedge, x 188–330, |z| < 136) [MEASURED]
| Category | Inventory |
|---|---|
| **Trees** | **400** in `Breakables` (`Area="CrystalCanyon"`). Pivots X 199…298, Z −124…123, Y 0.7…23.4 (some on ledges). Types: Common 215, Uncommon 90, Rare 60, Epic 22, Legendary 8, Mythic 4, Secret 1. **3,188 parts** (2,788 MeshParts), max 16 per tree. **48 Lights, 118 ParticleEmitters**, 23 mutated. Scales: mostly 0.3 (268), 0.4 (80), 0.2 (31), 0.5 (13), plus 0.6–2.6 (8) |
| **Tree templates** (`ReplicatedStorage.TreeModels`) | Crystal_Common_1, Uncommon_1, Rare_1, Epic_1, Legendary_1 (8 parts each), Mythic_1 (3), Secret_1 (16). **0 scripts** in any template |
| **Terrain** (sampled every 8 studs, 770 samples, X 188–360, Z −136–136) | Y 0.9…46.8 (mean 12.3); 62% flat (< 12). Grass 41%, Rock 37%, Basalt 22%, Ground < 1%. No water |
| **Walls / collision** | `Map.AreaWalls.CanyonWalls`: Model, 46 colliding visible parts (x 188–324, z ±132). `Gate_CrystalCanyon`: 5 parts (4 colliding) + `Barrier` (`RequiredPower = 250`, opened client-side by ChopEffects). `Map.Border`: 5 invisible 300-stud walls on the circle near the wedge. `Map.ClimbBlockers`: 49 parts. Total non-tree parts in the region: 105 |
| **NPCs** | Golden Slime zone, **hard-coded** to x 215–305, z ±100 (WorldServer L91), max 4. Slime and Big Slime rings avoid it (`avoidEast`, L71). No camp or boss in the wedge |
| **Other** | Roll altar `Config.Altars.CrystalCanyon = (232, 0, 16)`, range 22 (RollController showcase) |
| **Code dependencies** | `GetAreaAt` legacy rule `x > 188 and |z| < 132`; `Areas.CrystalCanyon` (RequiredPower 250, PowerMult 9); `TraitCrateCost`/egg/log-pack pricing via `BestArea`; weapon index and tree index by area; `TreeTypes.Crystal_*` |

### 1.2 Frost Peaks (west annex, x −660…−345, |z| < 175) [MEASURED]
| Category | Inventory |
|---|---|
| **Trees** | **921** (`Area="FrostPeaks"`). Pivots X −633…−379, Z −152…151, Y 1.7…4.1. Types: Common 511, Uncommon 226, Rare 115, Epic 49, Legendary 15, Mythic 4, Secret 1. **5,606 parts** (3,209 MeshParts); **4 heavy trees** (> 40 parts: the 370-part Mythic). **80 Lights, 211 ParticleEmitters**, 27 mutated. Scales 0.4–1.4, evenly spread |
| **Tree templates** | Frost_Common_1/2/3, Rare_1, Legendary_1, Secret_1 (3 parts each), Uncommon_1, Epic_1 (8), **Mythic_1 (370 parts)** ⚠️. **0 scripts** |
| **Terrain** (2,024 samples, X −690…−345, Z −180…180) | Y −4.0…54.3 (mean 15.6); 56% flat. Snow 71%, Rock 22%, Grass 7% |
| **Walls / collision** | `Gate_FrostPeaks`: 5 parts + `Barrier` (`RequiredPower = 2000`). `Map.Border`: 5 annex walls (x −660, z ±175, x −340 split). `ClimbBlockers`: 3. Total non-tree parts in the region: 13 |
| **NPCs / bosses / altar** | **None** (no slime zone, camp, boss or altar entry) |
| **Code dependencies** | `GetAreaAt` legacy rule `x < −345`; `Areas.FrostPeaks` (RequiredPower 2000, PowerMult 20); pricing via `BestArea`; indexes; `TreeTypes.Frost_*` |

### 1.3 Shared runtime behaviour that makes migration easy [VERIFIED]
- **Trees are data-driven.** A chopped tree regrows at **its own pivot** with a fresh roll from its `Area` (`CombatServer.respawnLater`: `TreeKit.BuildRandom(model.Area or GetAreaAt(pivot), pivot)`). A tree built at a new coordinate with `Area="CrystalCanyon"` becomes a self-sustaining Crystal spot. **No script change is needed for trees.**
- Tree attributes per instance: `Area, TreeType, Template, Rarity, Strength, Health, MaxHealth, Reward, Respawn, IsTree, Kind, TreeName, LeafColor`, all set by `TreeKit.Build`.
- AutoChop (client) scans `Breakables` within **160 studs** and checks the tree's own `Area` Power gate. Island-local by distance.

---

## 2. What can be relocated, cloned or reconstructed [PROPOSAL]
| Asset | Method | Why |
|---|---|---|
| Trees (1,321 legacy) | **Reconstruct** with `TreeKit.Build(typeId, groundCF, scale)` at planned spots on the new island. **Do not clone or move** the legacy instances | Fresh instances carry the correct attributes; legacy areas stay playable until P1b.4; templates are script-free |
| Tree templates | **Reuse in place** (already in ReplicatedStorage). Exception: `Frost_Mythic_1` (370 parts) needs an approved lighter replacement or a count cap | Mobile budget |
| Terrain | **Copy the core plus procedural extension**: `Terrain:CopyRegion` of the legacy core → `PasteRegion` at the island center (voxel-aligned), then a seeded scripted generator extends it to the full footprint, adds a cliff rim and flattens plazas | Keeps the original look; reproducible; versionable as a build script |
| CanyonWalls / gates / Border / ClimbBlockers | **Don't migrate.** New islands are bounded by terrain cliffs plus a few invisible rim walls; access is by portal, not walls | Walls belong to Island 1 geometry |
| Golden Slime zone | **Config move** (P1b.2): a zone on Crystal Wilds instead of the wedge. The legacy zone stays until P1b.4 | Hard-coded coordinates |
| Crystal roll altar | **Config move** (P1b.2): new `Altars` entry for the station cluster on Crystal Wilds | Hard-coded coordinates |
| Gate barriers | **Not migrated**; replaced by portal pads (P1a) and future unlock UI (P1c) | — |
| P1a test floors and EdgeWalls | **Replace** in P1b.2: terrain replaces the floor; EdgeWalls are removed once cliffs exist; ReturnPad moves to the arrival plaza | They'd block the full island |

---

## 3. Crystal Wilds plan — center (3000, 0, 0), footprint 560 × 480 [PROPOSAL]
- **Bounds:** X 2720…3280, Z −240…240. Registry bounds stay 2700…3300 × −300…300 (unchanged).
- **Ground:** base y ≈ 2 (same as Island 1 and the P1a floor). Cliff rim drops to y −60 into the void, outside the footprint by 20–40 studs.

| Zone | Location (world) | Size | Notes |
|---|---|---|---|
| **Arrival plaza** (new anchor) | **(2790, 2, 0)** west edge, facing +X | 40 × 40 flat | Moves `Config.Islands.CrystalWilds.Arrival` from (3000, 5, 0) to **(2790, 5, 0)** (P1b.2 config change). The 9-slot ring (6 studs) fits |
| Return pad | (2775, 2.5, 16) | 8 × 8 | Replaces the P1a center ReturnPad |
| Station cluster (roll altar, egg/market later) | (2850, 2, −40) | 40 × 30 | New `Config.Altars` entry |
| **Canyon core** (pasted legacy terrain) | Centered at (3030, 0, 0) | ~172 × 272 | Basalt and rock ravine, as in the original |
| Tree loop | Ring path around the core | — | ~620 trees (§6) |
| Golden Slime zone | x 3080…3220, z −180…−60 | — | Max 4, as before |
| Future boss arena (P1c) | (3150, 2, −150), radius 48 | Reserved, flat, **no trees** | From M2 |
| Onward portal to Island 3 (P1c art) | (3220, 2, 150) | Reserved | Pad only in P1b |

## 4. Frostbound Reach plan — center (6000, 0, 0), footprint 640 × 560 [PROPOSAL]
- **Bounds:** X 5680…6320, Z −280…280. Registry 5660…6340 × −320…320 (unchanged).

| Zone | Location | Size | Notes |
|---|---|---|---|
| **Arrival plaza** | **(5750, 2, 0)** | 40 × 40 | `Arrival` (6000, 5, 0) → **(5750, 5, 0)** (P1b.3 config change) |
| Return pad | (5735, 2.5, 16) | 8 × 8 | — |
| Station cluster | (5820, 2, −40) | 40 × 30 | Frost has no altar today; adding one is optional and needs approval |
| **Snow-hill core** (pasted legacy terrain) | Centered at (6020, 0, 0) | ~345 × 360 | The original annex shape |
| Tree fields | Around the core | — | ~830 trees (§6) |
| Future boss arena (P1c) | (6150, 2, −180), radius 48 | Reserved | — |
| Sealed Island 4 pad | (6240, 2, 200) | Reserved | — |

## 5. Timber Haven is preserved
- **No change to Island 1 in P1b.2 or P1b.3.** Legacy Crystal Canyon and Frost Peaks stay playable, gated and indexed exactly as now.
- **Island trees use the legacy area IDs** (`Area="CrystalCanyon"` / `"FrostPeaks"`). So tree index, `BestArea`, pricing, Power gates, AreaService and AutoChop all behave the same on the islands as in the old areas.
- Retiring the legacy wedge and annex is a **separate stage (P1b.4)** with its own approval (§10).

---

## 6. Build methodology [PROPOSAL]

### 6.1 Terrain
1. **Snapshot:** before writing, `Terrain:CopyRegion` of the target box (empty today) is stored as `ServerStorage.P1bBackups.<Island>_PreTerrain` (TerrainRegion), and a labelled dev version is saved.
2. **Core paste:** `CopyRegion` of the legacy core, voxel-aligned to 4 studs (Crystal X 188…360, Z −136…136, Y −32…64; Frost X −692…−344, Z −180…180, Y −32…64) → `PasteRegion` at the island center. The legacy source is only **read**.
3. **Procedural extension:** a seeded Luau build script (committed as `tools/p1b_build_terrain.luau`, run only in the dev place, idempotent) does the following:
   - fills the footprint with a base slab (Ground / Snow);
   - blends heights with low-frequency noise (amplitude 6–10 studs) so the core edge meets the base;
   - flattens plazas, the station area, the arena and the paths (±0.5 stud);
   - cuts a cliff rim to y −60;
   - paints materials (Crystal: Grass / Rock / Basalt; Frost: Snow / Rock / Glacier accents).
4. **Collision:** terrain is the floor. Only 4–8 invisible rim walls at cliff edges (copying P1a EdgeWalls semantics) plus `CharacterMaxSlopeAngle` 32 for climb blocking. **No ClimbBlocker spam.**

### 6.2 Arrival anchors
- Arrival anchors sit on flat terrain at y 2, with ±0.5 stud flatness inside a 20-stud radius.
- Keep a small **Persistent** arrival model per island (pad + return pad + marker, under 10 parts). That keeps the V-2 safety (floor always present) while the rest of the island streams normally (`Default` / `Atomic` trees).

### 6.3 Tree placement
- **Seeded Poisson-disc sampling** over the walkable footprint, minus exclusion zones: plaza radius 30, paths 8 studs wide, arena radius 56, stations, portals, slopes > 30°.
- **Spacing:** 7–9 studs (Common / Uncommon), 10–12 (Epic+). Scale ranges match the legacy distributions measured above.
- **Initial rarity mix** = `TreeTypes` weights (55 / 25 / 13 / 5.5 / 1.5 / 0.5 / 0.1). Respawns re-roll anyway. **At least 1 of each type**, so tree-index completion stays possible.
- Every spot is exported to `docs/p1b_tree_spots_<island>.json` (position, scale, typeId, seed) for reproducibility and rollback.
- Trees are placed with `TreeKit.Build(...)` and parented to `Workspace.Breakables` (required by CombatServer and AutoChop), tagged `P1bIsland=<IslandId>` and `P1bStage=<stage>` for audit and removal.

### 6.4 Mobile performance budgets (per island, while standing on it)
| Metric | Budget | Crystal Wilds plan [ESTIMATE] | Frostbound Reach plan [ESTIMATE] |
|---|---|---|---|
| Trees | — | ~620 (1 per ~280 sq studs; legacy canyon is 1 per 62) | ~830 (legacy annex is 1 per 84) |
| Tree BaseParts | ≤ 7,000 | ~4,960 (8 per tree) | ~4,000 if the Mythic is capped or replaced; **~5,400 with four 370-part Mythics** |
| Other BaseParts (pads, rim, stations) | ≤ 300 | ~60 | ~60 |
| Lights | ≤ 40 | ⚠️ ~75 at the legacy ratio (48 per 400) | ⚠️ ~72 (80 per 921) |
| ParticleEmitters | ≤ 150 | ⚠️ ~180 | ~190 ⚠️ |
| Max parts per tree | ≤ 40 | 16 ✅ | **370 ⚠️** |

**Budget decisions needed:**
- **(B1)** Limit glow (Light + particles) to Legendary+ and Shadow/Rainbow mutations on the new islands. That's a **TreeKit visual change** and needs approval.
- **(B2)** Replace or cap `Frost_Mythic_1` (370 parts). A replacement must be a Creator Store asset, checked for scripts.
- **Measure** real counts after each stage and run an iPhone check (now possible on the private dev experience).

---

## 7. Itemized asset migration manifest
Full machine-readable list: `docs/p1b_asset_manifest.json`. Summary:

| # | Source asset (Island 1) | Qty | Action | Target | Stage | Risk |
|---|---|---|---|---|---|---|
| A1 | Crystal trees (`Breakables`, Area CrystalCanyon) | 400 | Keep on I1; **reconstruct** ~620 new | Crystal Wilds | P1b.2 | Low |
| A2 | Crystal templates ×7 | 7 | Reuse (no copy) | — | — | None |
| A3 | Crystal terrain core | 172 × 272 × 96 | CopyRegion → PasteRegion (+ extension) | (3030, 0, 0) | P1b.2 | Medium (voxel alignment) |
| A4 | CanyonWalls / Gate_CrystalCanyon | 46 + 5 | Not migrated | — | P1b.4 decision | — |
| A5 | Border (wedge) / ClimbBlockers (wedge) | 5 / 49 | Not migrated | — | P1b.4 | — |
| A6 | Golden Slime zone | 1 zone | Config move | x 3080…3220, z −180…−60 | P1b.2 | Low |
| A7 | Crystal roll altar | 1 point | Config move | (2850, 0, −40) | P1b.2 | Low |
| B1 | Frost trees | 921 | Keep on I1; **reconstruct** ~830 new | Frostbound Reach | P1b.3 | Low |
| B2 | Frost templates ×9 | 9 | Reuse; **Mythic needs a decision** | — | P1b.3 | Medium (mobile) |
| B3 | Frost terrain core | 348 × 360 × 96 | CopyRegion → PasteRegion (+ extension) | (6020, 0, 0) | P1b.3 | Medium |
| B4 | Gate_FrostPeaks / annex Border / ClimbBlockers | 5 / 5 / 3 | Not migrated | — | P1b.4 | — |
| C1 | P1a CrystalWilds test model (floor, 4 EdgeWalls, marker, label, ReturnPad) | 8 parts | Replace (floor → terrain; pad relocated; EdgeWalls removed after rim walls exist) | Arrival plaza | P1b.2 | Low |
| C2 | P1a FrostboundReach test model | 8 parts | Same | — | P1b.3 | Low |
| C3 | P1a TimberHaven pads | 2 | Keep | — | — | None |
| D1 | `Config.Islands.*.Arrival` | 2 values | Change to the west-edge plazas | — | P1b.2 / .3 | Low (registry) |
| D2 | `Config.Altars` | +1 | Add CrystalWilds entry | — | P1b.2 | Low |
| D3 | WorldServer `SLIME_ZONES` GoldenSlime | 1 | Move or duplicate to Crystal Wilds | — | P1b.2 | Low |

---

## 8. Conflicts and dependencies [VERIFIED code / PROPOSAL resolution]
| System | Conflict | Resolution |
|---|---|---|
| **P1a pads / test floors** | The 160 × 160 ArrivalFloor sits at the island center; the invisible 40-stud **EdgeWalls at ±81** would cut the island into a box | P1b.2 removes EdgeWalls and the floor after terrain and rim walls exist; arrival moves to the west plaza |
| **Island registry** | `Arrival` is at the center today | Config change to the plaza coordinates (D1). Bounds unchanged. `GetAreaAt` island mapping stays legacy-area based |
| **AreaService** | Enforces legacy Power per area on the islands (250 / 2000) | No change in P1b. New unlock rules are P1c |
| **AreaService on Island 1** | Legacy rules (`x > 188`, `x < −345`) keep the wedge and annex gated | Fine through P1b.3. **P1b.4** must decide whether retiring them changes the Island 1 rules (the wedge becomes Portal Ridge, open to all) |
| **WorldServer** | GoldenSlime zone and `avoidEast` are hard-coded to the wedge; `ringPoint` is origin-relative | D3 move; `ringPoint` unchanged for Island 1 |
| **CombatServer** | Respawn uses the tree pivot and `Area` | ✅ Works on islands as-is. The Server Heartbeat scans more trees (+~1,450): measure server frame time |
| **AutoChop** | 160-stud search; relies on tree `Area` gates | ✅ Island-local. Needs walkable navigation on terrain (paths) |
| **ChopEffects** | Barrier visuals read `Map.AreaWalls` | No change (no new walls) |
| **RollController altars** | Config-driven | D2 |
| **Save data** | `BestArea`, `Trees[TreeType]`, `TreeIndexDone[area]`, `IndexDone[area]`, `UnlockedIslands`, `LastIsland` | **No schema change.** Island trees reuse legacy type and area IDs, so indexes and pricing are unchanged. `LastIsland` placement uses the new Arrival automatically |
| **Treant / Blade King / events** | On Island 1 | Unchanged (M-5; P1c) |
| **Streaming** | Persistent arrival models | Keep only the small arrival model Persistent; trees use `Default` streaming |

---

## 9. Staged construction plan (each stage needs approval; dev place only)
| Stage | Scope | Exit checks |
|---|---|---|
| **P1b.2 Crystal Wilds** | Checkpoint version + terrain snapshot → core paste + extension → arrival plaza, return pad, rim walls → remove P1a EdgeWalls and floor → ~620 trees (seeded) → config D1/D2/D3 → measure budgets | Single-client: arrival, travel both ways, chop, tree respawn in place, AutoChop, Golden Slime, altar, index, AreaService gate, rejoin on `LastIsland`; budget table; iPhone check after a dev publish (approval) |
| **P1b.3 Frostbound Reach** | Same pattern; Mythic decision B2; glow decision B1 | Same checks |
| **P1b.4 Legacy retirement on Island 1** | Decide: keep the wedge and annex as an "old forest" or retire them (remove legacy trees, walls, gates; turn the wedge into Portal Ridge); update `GetAreaAt` Island 1 rules | Regression: Starter/Pine unchanged; BestArea/pricing; index |
| **P1b.5 Validation** | Full regression, mobile, two-device (when available), docs | — |

---

## 10. Rollback checklist (per stage)
1. **Before:** confirm IDs; claim the handoff row; Studio `save_place` labelled `P1b.x checkpoint`; record the version.
2. **Terrain:** a `TerrainRegion` snapshot of the target box goes in `ServerStorage.P1bBackups`. To restore: `PasteRegion` the snapshot, or `FillBlock` Air over the box (the target areas are empty today).
3. **Objects:** everything new is tagged `P1bStage` / `P1bIsland`. To remove: delete the tagged instances (an audit script prints counts first).
4. **Config:** the changed lines are on a dev branch. To restore: revert the commit and paste the original sources (checksum-verified).
5. **Full:** Version History → restore the checkpoint; worst case, republish the verified P0 backup (`e050c6c3…6ffd`) **to the dev experience only**.
6. **After:** production `updateTime` check; handoff released.

---

## 11. Open decisions for the owner
1. Approve **P1b.2 Crystal Wilds construction** as specified (terrain copy + extension, ~620 trees, arrival moved to the west plaza).
2. **B1:** limit tree glow (lights and particles) on the new islands. This is a visual TreeKit change.
3. **B2:** cap the Frost Mythic count, or pick an approved lighter Creator Store replacement.
4. Whether Frostbound Reach gets a roll altar.
5. **P1b.4:** keep or retire the legacy Crystal and Frost areas on Island 1 after the islands pass testing.

---

## 12. P1b.2 Crystal Wilds — ACTUAL BUILD RESULTS (2026-11-19, dev place only)

**Status: constructed, single-client tested, saved. Awaiting owner review. NOT published. P1b.3 not started.**

| Item | Value |
|---|---|
| Place | Blade Forest - Island Dev `103379930563763` / universe `10777797608` (IDs asserted before every edit) |
| Checkpoint | Version **9** — "P1b.2 PRE-CRYSTAL-CONSTRUCTION" |
| Result | Version **12** — "P1b.2 Crystal Wilds construction complete" (Open Cloud `updateTime` 2026-11-19T08:35:18Z) |
| Branch | `p1b2/crystal-wilds` @ `0fc997d` (scripts + `tools/p1b2_crystal_wilds/` + tree manifest) |
| Production | `updateTime` 2026-11-18T15:12:30.520Z — **unchanged** (re-checked after the build) |

### 12.1 What was built
- **Terrain** (footprint X 2720–3280, Z −240–240, seed 20261119):
  - Rock/Grass slab.
  - The original Crystal Canyon core was copied with `CopyRegion` (voxels (47,−8,−34)–(90,16,34)) and pasted +2756 studs in X. The core now spans X 2944–3116, Z ±136. **The original canyon is untouched**: a re-sample was identical, with 770 hits.
  - Noise hills with Rock/Basalt patches, 10-wide Ground paths, and flat plaza, station, arena and portal zones.
  - Footprint sample: 4331/4331 hits, Y −13.7…47.1, 92% flat. Outside the footprint: 0 hits.
- **Arrival:**
  - `Workspace.Islands.CrystalWilds_Plaza` (Persistent, 6 parts): 44×2×44 floor with its top at y 2 and centred on (2790,·,0), a ramp from 2 to 4, an arrival marker, a label, and a **ReturnPad** at (2775,2.5,16) (TravelTo=TimberHaven, prompt 0.4 s / 10 studs).
  - All 9 arrival slots raycast to y 2.00 with no blockers.
  - `CrystalWilds_Bounds`: 4 invisible rim walls.
  - The old P1a `CrystalWilds` test model was removed after validation. A backup clone is kept in `ServerStorage.P1bBackups`.
- **Trees:** **620** built with `TreeKit.Build`, parented to `Workspace.Breakables`, with Area=`CrystalCanyon`, P1bIsland=`CrystalWilds` and P1bStage=`P1b.2`. Seed 20261120; dart-throwing with no canopy overlap, slope normal.Y ≥ 0.866, and exclusions for the plaza, ramp, station, arena, portal and paths.
  - By rarity: Common 364, Uncommon 149, Rare 73, Epic 23, Legendary 7, Mythic 3, Secret 1.
  - Mutations: Frozen 14, Golden 11, Shadow 2, Rainbow 1.
  - Manifest: `docs/p1b_tree_spots_crystal_wilds.csv` (620 rows, 22454 bytes, Adler-32 308787882; Studio and Python agree).
- **Backups** (`ServerStorage.P1bBackups`):
  - `CrystalWilds_PreTerrain` (TerrainRegion, voxel min (670,−24,−70), 161×65×141).
  - `CrystalWilds_P1aTestModel`.

### 12.2 Script changes (2 scripts; all others byte-identical)
| Script | Before | After | Change |
|---|---|---|---|
| `BladeConfig` | 55586:3426233414 | **55586:167717973** | Crystal Wilds `Arrival` (3000,5,0) → **(2790,5,0)** |
| `WorldServer` | 13930:2981965952 | **14591:830933556** | Adds a terrain-only RaycastParams and a 2nd `GoldenSlime` zone on Crystal Wilds (X 3080–3220, Z −180…−60, on the terrain surface). It uses the same tag, so it **shares the existing Max = 4 cap** |

Unchanged and verified: TravelService (M-1) 9388:3611788483, DataService 19574:676054173, TreeKit 5038:3027397391, CombatServer 20797:1888490247, AreaService 1737:843202379, AutoChop 12453:155288051. Studio matches `p1b2/crystal-wilds` for all 35 exported scripts. **No DataStore schema, monetization, purchase or progression changes.**

### 12.3 Budgets (new Crystal Wilds content)
| Metric | Budget | Actual |
|---|---|---|
| Tree BaseParts | ≤ 7000 | **4953** (4333 MeshParts) |
| Parts per tree | ≤ 40 | **16** max |
| Other new parts | ≤ 300 | **10** |
| Lights | ≤ 40 | **37** (51 as built; 14 Frozen-mutation lights disabled locally, see below) |
| Particle emitters | ≤ 150 | **135** (136 seen by the client) |

**Light adjustment (localized and reversible; not a TreeKit change).** On the 14 new trees with Mutation=Frozen, the `MutationFX` PointLight was set `Enabled=false` and tagged `P1bLightDisabled=true`. To revert, run `tools/p1b2_crystal_wilds/E_light_budget.luau` with `REVERT = true`.

### 12.4 Tests (one Studio client only; no multi-client; no save resets)
| # | Test | Result |
|---|---|---|
| T1 | Timber Haven → Crystal Wilds travel | ✅ (2790, 5.8, 0), level |
| T3 | Client streaming on CW | ✅ 4953 CW tree parts, **0** Island-1 tree parts cached, floor present |
| T4 | Chop a new tree with real blades | ✅ 1.2 s, Logs +1980 (= 900 × 2.2), index `Crystal_Common` recorded |
| T5 | Tree respawn | ✅ 8 s, same pivot, Area CrystalCanyon (re-rolled to Uncommon) |
| T6 | AutoChop 20 s | ✅ +5940 Logs, stayed on the island |
| T7 | Original canyon tree + `Gate_CrystalCanyon` (250 Power) + 46 CanyonWalls | ✅ intact |
| T7c/T8 | Golden Slimes | ✅ total 4 (original zone 2 + CW zone 2), on the ground |
| T9 | Power gate | ✅ at Power 60: "🔒 Crystal Wilds needs 250 Power"; forced placement pushed back |
| T10 | Reset on CW | ✅ respawn on the plaza |
| T11 | Rejoin with LastIsland | ✅ (2790, 5.8, 0) |
| T12 | Invalid island / combat / cooldown | ✅ all refused with messages |
| T14 | Frost travel regression | ✅ (6000, 5.8, 0) and back |
| — | Return pad (real prompt) | ✅ → Timber Haven (0, 5.8, 22) |
| T15 | Console | ✅ no errors |
| — | Altar | **N/A**: `Config.Altars` is unreferenced and no altar object exists, so none was added |
| — | Two-player | **UNVERIFIED** (multi-client forbidden locally) |
| — | iPhone | **UNVERIFIED**: needs a separately approved private dev publish |

### 12.5 Known limitations / owner decisions
1. **Effects drift on respawn.** Respawned trees are re-rolled by `TreeKit.BuildRandom`, which regenerates effects, and the light-disable applies only to the initial instances.
   - Expected steady state: about 60 lights and 156 emitters, above the 40/150 budgets.
   - Fix options: an approved TreeKit-level glow cap (B1), or about 415 trees for the light budget.
2. **Respawned trees lose `P1bIsland`/`P1bStage`.** Audit and rollback use the island bounds instead (X 2700–3300, |Z| ≤ 300).
3. **Shared Golden Slime cap.** The total is unchanged at 4, so the original zone now averages about 2. A separate cap would need approval.
4. Small terrain details:
   - The arena flat reads about y 6.
   - There is a 2-stud step from the path (y 4) to the copied canyon floor (y 2) at the core's west mouth.
   - The Golden Slime zone overlaps the reserved arena circle.
5. **Server cost:** +620 models and about 4953 parts in memory. Combat uses a spatial query, so there is no per-frame O(trees) cost. Client AutoChop scans `Breakables` (5021 trees) per pick, which is modest.

### 12.6 Rollback
- **Preferred:** Version History → restore **v9** ("P1b.2 PRE-CRYSTAL-CONSTRUCTION"). Then revert `BladeConfig` and `WorldServer` to `7f925b4`, or simply don't merge `p1b2/crystal-wilds`.
- **Manual:** run `tools/p1b2_crystal_wilds/rollback.luau`. It pastes the terrain snapshot, removes Breakables inside the CW bounds, deletes the plaza and bounds, and restores the P1a model.
