# Changelog

Newest first. Place versions refer to Roblox saved versions.

## 2026-11-19 — P1b.2r camera visibility fix, Option C on top of Option A (DEV PLACE ONLY, v18)
- Checkpoint **v16**; result **v18** (v17 unexplained, not saved by Claude). Branch `p1b2r/camera-visibility-fix` (not merged).
- Only the client `ChopEffects` was changed (18500:3640422855 → 27331:1017905967).
  - It now has its own canopy registry, so fading works with tags OFF.
  - A canopy-aware obstruction test runs at about 11 Hz with `LocalTransparencyModifier` 0.90 (blocking) / 0.72 (near) and hysteresis.
  - Labels are tiered (T1 90 studs uncapped; T2 48; T3 24, or 48 when locked or struck), capped at 16 compact / 24, and hidden over the character.
- One Studio client: C1–C9 pass (the 24-label cap and travel UI were not exercised). Z2 Studio FPS is 14.2–14.6, against 8.4 at v15; not representative of iPhone.
- A 4-s chop for the regrowth test changed the dev save (Logs 9→6,255, TreesChopped 3,329→3,331). 620/620 trees are still at their dense spots.
- Not published. Production unchanged (re-checked 21:53 PST). Results: `docs/p1b2r_camera/CAMERA_FIX_RESULTS.md`.

## 2026-11-19 — P1b.2r Crystal Wilds dense-forest redistribution, Option A (DEV PLACE ONLY, v15)
- Checkpoint **v14** "P1b.2r PRE-DENSE-REDISTRIBUTION"; result **v15**. Branch `p1b2r/dense-forest` @ `a893300` (not merged).
- The existing 620 tree instances were moved with `PivotTo` (no rebuild; no attribute, scale or effect changes) into Z1–Z4 (155/155/150/140) plus 4 trail pockets of 5. Nearest-neighbour distance is about 5.2 studs per zone.
- Exact pre-move snapshot and move map stored in `ServerStorage.P1bBackups` and in git. The move is idempotent; the rollback tool's dry run was verified.
- Initial budgets unchanged: 4,953 tree parts, 37 enabled lights, 135 emitters, 10 other parts.
- Studio tests: entry sweep 17–20 trees per revolution (sparse 1); 30-s route 183 trees (sparse 29); respawn stays on the redistributed spot.
- Camera visibility is a partial pass (Z2/Z3 obscured). Studio FPS is about 30% lower inside zones.
- Not published. Production unchanged.

## 2026-11-19 — P1b.2 Crystal Wilds construction (DEV PLACE ONLY, version 12)
- Checkpoint **v9**, result **v12**. Branch `p1b2/crystal-wilds` @ `0fc997d`.
- Terrain: the Crystal Canyon core was copied with CopyRegion and extended to 560×480 (X 2720–3280). The original canyon is untouched.
- Persistent arrival plaza at (2790,·,0), a return pad, and rim walls. The P1a test model was removed (a backup is kept).
- 620 seeded trees (tree-spot manifest committed).
- Light budget met with a localized, reversible disable of 14 Frozen lights.
- `BladeConfig`: Crystal Wilds Arrival → (2790,5,0). `WorldServer`: a 2nd Golden Slime zone (shares the Max 4 cap).
- Single-client tests pass. Two-player and iPhone are unverified. Not published. Production unchanged.

## 2026-11-19 — P1b.1 migration blueprint (docs only)
- Read-only inventory of Crystal Canyon and Frost Peaks.
- Island plans, build methodology, mobile budgets, asset manifest, conflicts, staged plan and rollback.
- No Studio changes.

## 2026-11-19 — Dev v9 published to the PRIVATE dev experience (iPhone testing)
- Studio File → Publish on place 103379930563763.
- The experience stays private. Production unchanged.
- Publish to be confirmed in-game.

## 2026-11-19 — M-1 arrival-slot race fix (DEV PLACE ONLY, version 9)
- TravelService only: slot chosen right before `PivotTo` with no yield in between.
- 2 s per-slot reservation, released on leave or death.
- Preload around the fixed arrival anchor.
- Checkpoint v8 = v7. Production unchanged.

## 2026-11-18 — P1a verification (DEV PLACE ONLY, version 7)
- Fixed: travel now requires the current legacy Power gate.
- Fixed: `CurrentIsland` follows the character's real position.
- Fixed: arrival models are Persistent, and travel aborts if the stream request fails.
- Prompts, death mid-travel and regressions verified.
- Rejoin and 2-player tests are pending owner toggles.

## 2026-11-18 — P1a island prototype (DEV PLACE ONLY, version 5)
- Island registry and island-aware `GetAreaAt`.
- New TravelService (same-place travel: cooldown, combat lock, streaming, respawn).
- Island save fields with grandfathering.
- 18-part test pads at (3000, 0, 0) and (6000, 0, 0).
- Production unchanged. Details in `P1A_RESULTS.md`; code on branch `p1a/island-prototype`.

## 2026-11-18 — P0 verified complete
- Dev experience "Blade Forest - Island Dev" (universe 10777797608, place 103379930563763) is private and isolated, with contents identical to production.
- Backup re-verified.
- Production unchanged.

## 2026-11-18 — P0 isolation and backup (partial)
- Offline backup of the production place saved to the owner's Mac and verified.
- Scripts exported to branch `p0/script-export`.
- Dev experience pending an owner step.
- Production unchanged.

## 2026-11-18 — M2 technical validation (docs only)
- Added `docs/M2_TECHNICAL_VALIDATION.md`, `docs/m2_island_sim.py` and `docs/m2_sim_results.txt`.
- Read-only Studio survey; no Studio, script, terrain, monetization or data changes.

## 2026-11-18 — Economy and monetization audit (docs only)
- Added `docs/ECONOMY_MONETIZATION_AUDIT.md` and the model `docs/economy_sim.py`.
- Read-only; no gameplay, price or script changes.

## 2026-11-18 — Repository setup
- Created the GitHub repo structure: README, docs, Rojo project and `.gitignore`.
- Kept the original `# Blade-Forest` README title.
- No gameplay changes.

## v48 — HUD handoff
- Added an upper-left notification feed (`GameUI.HudNotice`).
- Added StatusRail for timers and potions (`UITheme.AttachToHud`).
- Compact RollBar with 5 buttons.
- Tutorial fixes; removed stale `rollMsg` references.
- Verified on phone layouts.

## v47 — Mobile
- Made mobile dock buttons tiny but tappable (compact scale).

## v46 — Big feature batch
- Pets: 7 pets, eggs, up to 3 equipped, followers.
- Shiny crafting: 5 copies make a Shiny (×1.5 power).
- Sawmill / Log Market: logs to Souls, rate between 0.6 and 1.6, 200 per day cap.
- Ancient Treant world boss: every 20 min, damage-share rewards.
- 18 achievements.
- Reduced Motion setting.
- Tree mutations: Golden, Frozen, Shadow, Rainbow.
- Blade stop toggle; max blade level lowered to 5.
- Climb blocking: slope limit 32°, plus ClimbBlockers.
- NPC camps with Creator Store rigs and default animations.
- Boss HP bar shows only inside the arena; potion status moved to StatusRail.
- Group ID and all game pass IDs set; Starter Pack sold as a pass.
- Mobile hide buttons for each side of the screen.

## Earlier
- Screen shake reduced and made toggleable.
- Spin speed capped at 5.5.
- Index rewards for every weapon.
- Tree index.
- 8 new Mythic/Secret tree types.
- Playtest pass on tutorial steps 9–21.
