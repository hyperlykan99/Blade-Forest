# P1b.2r — Crystal Wilds Dense-Forest Redistribution (Option A): Results

**Status:** done in the dev place and saved as **v15**. **Not published.** Production is unchanged. P1b.3 and B1 have not started. Awaiting owner review.

**Date:** 2026-11-19 (about 01:50–03:00 PST). **Branch:** `p1b2r/dense-forest`.

| Item | Value |
|---|---|
| Place | Blade Forest - Island Dev, 103379930563763 / 10777797608. IDs asserted before every write |
| Baseline verified | Dev v12: 8 key scripts checksum-matched, 620 tagged Crystal Wilds trees, terrain backup intact, no newer work on any branch, no stabilization fix present |
| **Rollback checkpoint** | **v14 "P1b.2r PRE-DENSE-REDISTRIBUTION"** (the save took v14; v13 was not created by this session) |
| **Result** | **v15 "P1b.2r dense forest redistribution (Option A, 620 trees moved)"** |
| Production | `updateTime` 2026-11-18T15:12:30.520Z, unchanged |

Labels used below:
- **[STUDIO]** results measured in Roblox Studio (one local client, MacBook);
- **[SIM]** earlier offline estimates, shown only for comparison.

---

## 1. What was done
1. **Dry run (read-only):**
   - 620 trees inside the Crystal Wilds bounds, all at their v12 source spots.
   - Each matched exactly one manifest row; largest offset 0.070 studs, tolerance 0.15.
   - Source spots are ≥ 7.03 studs apart, so matching is unambiguous.
   - No row was matched twice or left unmatched.
   - Rotations matched to 0.00°, and no tree was tilted.
   - Totals matched the manifest: 364/149/73/23/7/3/1 by rarity; mutations Frozen 14, Golden 11, Shadow 2, Rainbow 1.
   - All 620 destinations re-raycast OK: ground within 0.005, slope ≤ 30°, no objects, every keep-out and path channel clear.
2. **Backups written before the checkpoint:**
   - the move map (`P1b2r_MoveMap`);
   - an exact snapshot of all 620 pivots and attributes (`P1b2r_PreMoveSnapshot`);
   - copies of both in git (`docs/p1b2r/`), verified byte-for-byte against Studio.
3. **Archive:** the v12 sparse manifest was preserved as `docs/p1b_tree_spots_crystal_wilds_v12_sparse.csv`.
4. **Move:** `tools/p1b2r_dense_redistribution/move.luau`. `PivotTo` on the existing instances only, keeping each tree's exact rotation; 620 moved and verified. **A second run returned `NO-OP` (idempotent).**
5. **Promotion:** the dense manifest became the working manifest `docs/p1b_tree_spots_crystal_wilds.csv` (same 7-column format; 620 rows; 22,335 bytes; Adler-32 1456250753), after Studio confirmed every tree within 0.01 studs of its manifest spot.

## 2. Placement statistics [STUDIO, measured after the move]

| Zone | Trees | Mean nearest neighbour | Minimum |
|---|---|---|---|
| Z1 Arrival Thicket | 155 | **5.23** | 4.25 |
| Z2 Gorge Grove | 155 | **5.20** | 4.38 |
| Z3 North Shardwood | 150 | **5.17** | 4.14 |
| Z4 South Hollow | 140 | **5.19** | 4.39 |
| P1 / P2 / P3 / P4 pockets | 5 each | 3.70 / 4.13 / 4.01 / 3.75 | 3.35–3.81 |
| **Total** | **620** (before 620; all trees in the place 5,021 before and after) | | |

**Placement checks:**
- **Ground fit:** the largest pivot-to-terrain offset is 0.005 studs; hitboxes are exactly on their trees (XZ offset 0.000) and their bases sit on the ground (0.005). Nothing floats or sinks.
- **Keep-outs:** 0 trees within the plaza (+8), return pad, ramp, station clearing, boss arena r64, portal r20, Golden Slime zone or path channels (< 6.5 studs).
- **Attributes:** all gameplay attributes, scales, part counts and effects are unchanged per tree. Rarity, health, strength, reward, respawn, mutation and the P1b tags were checked against the snapshot. `LeafColor` (Color3) can't be stored in the JSON snapshot; it wasn't touched.
- **Other islands:** Island-1 areas unchanged (Starter 848, Pine 2,232, Frost Peaks 921, Crystal Canyon 1,020 including Crystal Wilds).

## 3. Mobile budgets [STUDIO, initial state]

| Metric | Budget | Before | After |
|---|---|---|---|
| Tree BaseParts (Crystal Wilds) | ≤ 7,000 | 4,953 | **4,953** |
| Max BaseParts per tree | ≤ 40 | 16 | **16** |
| Other new BaseParts | ≤ 300 | 10 | **10** |
| Enabled lights | ≤ 40 | 37 | **37** (14 Frozen lights still disabled) |
| Particle emitters (all enabled) | ≤ 150 | 135 | **135** |

**These are initial counts only.** Respawns re-roll trees and rebuild their effects (§5, risk 2). The budget is not permanently guaranteed.

## 4. Gameplay tests (one local Studio client; no multi-client; no save resets)

| Test | Result [STUDIO] | Target | Sparse v12 [STUDIO] | [SIM] |
|---|---|---|---|---|
| **T-D1** Plaza → Z1, entry profile | **First contact after 1.64 s** (player at x 2827 on the path) | < 3 s | — | — |
| **T-D2** Entry sweep in Z2, distinct trees in the first revolution | **18 / 20 / 17** (3 spots) | ≥ 8 | 1 | 13.7 |
| **T-D2** Midgame sweep in Z2 | **34 / 24 / 21** (3 spots; 2nd and 3rd partly regrowing) | ≥ 15 | 3 | 22.6 |
| **T-D3** 30-s route, entry profile | **183 contacted, 53 felled, 110,187 Logs** | ≥ 120 | 29 contacted, 12 felled, 24,948 Logs | 185 / 53 |
| **T-D4** Fell and regrow | **107 felled, 107 regrew at the exact redistributed spot** (Y exact). 0 kept P1b tags; 73 rerolled to a different rarity. All 620 still on manifest spots | Same spot | — | — |
| **T-D5** AutoChop 60 s, real account setup (Void, Reach 27, 5 blades) | **Started in Z1:** 328 contacted, 322 felled, 2.88M Logs. **Started in Z2:** 157 / 150 / 2.97M. Never stuck (~670 studs walked); moves between zones chasing the best logs/sec | Works, no stuck | — | — |
| **T-D6** Camera / visibility, all four zones | **PARTIAL.** Z1: character clearly visible. Z4: visible but partly veiled. **Z2 and Z3: heavily obscured.** Near canopies render translucent, but the character is only a faint silhouette and rarity labels clutter the view. Movement unaffected (no collision). Camera occlusion mode is `Zoom` | Visible | — | — |
| **T-D7** Performance (Studio, MacBook, server and client in one process) | **Client FPS:** route 8.4 (sparse 11.7); standing in Z2 8.4 against 12.3 in an open area (about −30%); 95th-percentile frame 181 ms. **Near field in Z2 (80 studs):** 1,368 tree parts, 34 emitters, 12 lights. **Server heartbeat:** 6.0–7.5 ms during entry sweeps against about 1.2–1.4 ms sparse; 3.1 ms average on the 30-s walk (sparse 2.1). **Network receive Kbps:** not readable from the command bar (0) | Measure | — | — |
| **T-D8** Features | Trees within plaza / return pad / station / arena / portal / slime zone: **0 / 0 / 0 / 0 / 0 / 0**. Golden Slimes 4 total, 2 in the Crystal Wilds zone. Plaza 6 parts and rim walls 4 intact | Clear | — | — |
| **T-D9** Regression | Crystal Wilds → Timber Haven OK. At Power 60: "🔒 Crystal Wilds needs 250 Power". Timber Haven → Crystal Wilds arrives at (2790, 5.8, 0). Frostbound Reach (6000, 5.8, 0) and back OK. **Rejoin** spawns at (2790, 5.8, 0), level | Pass | — | — |
| **T-D10** Console | No errors | None | — | — |

Profiles used:
- **Entry:** Glacier Fang, Reach 10, 3 blades, Speed 10, Damage 30.
- **Midgame:** Void Reaper, Reach 20, 5 blades, Speed 20, Damage 60.

Profiles were applied as transient player attributes during the playtest and never written to saves.

### Economics observed [STUDIO]
- **Same 30-s route with the entry profile:** 110,187 Logs against 24,948 sparse, **4.4×**.
- **AutoChop with the real account setup:** about **2.9M Logs per minute**. There is no sparse AutoChop baseline (not measured).

**Test data on the dev account's save.** Chopping during the playtests went through the normal DataService save. Across both playtests:
- Logs 11,708,313 → 21,222,510 (+9.51M);
- TreesChopped 1,012 → 2,464;
- tree-index entries unchanged (7).

No save was edited, reset or restored.

## 5. Remaining risks
1. **Camera visibility in Z2 and Z3 (T-D6 partial).** Options needing an owner decision, none applied: wider spacing in Z2/Z3 (7-stud lattice), smaller scale for interior trees, removing a lane, or camera/label settings (script changes).
2. **Respawn effects and tag drift** (separate issue; **B1 not implemented**). Confirmed live: regrown trees lose `P1bIsland`/`P1bStage` and reroll rarity and effects. The light and emitter counts in §3 are initial; the steady-state expectation is about 60 lights / 155 emitters island-wide, now concentrated in the zones.
3. **Performance.** Studio FPS drops about 30% inside the dense zones on this MacBook, and server heartbeat rises with many simultaneous hits. **iPhone and multi-player behaviour remain unverified.** They need a separately approved private dev publish.
4. **Economy:** chopping income in Crystal Wilds is about 4× the sparse layout (§4).
5. The Z2 / Z4 link uses the canyon's south mouth (a 2-stud step). AutoChop roams across all zones (search radius 160).

## 6. Rollback
- **Preferred:** Studio Version History → restore **v14** "P1b.2r PRE-DENSE-REDISTRIBUTION".
- **In place:** `tools/p1b2r_dense_redistribution/rollback.luau` with `DRY_RUN = false`, in Edit mode, then save. Its dry run was verified after the move: 620 trees mapped to their exact snapshot pivots, rotations identical.
- **Git:** to restore the sparse manifest, rename `docs/p1b_tree_spots_crystal_wilds_v12_sparse.csv` back to `docs/p1b_tree_spots_crystal_wilds.csv`.
- **No script changes** were made, so there are no script reverts.
