# Changelog

Newest first. Place versions refer to Roblox saved versions.

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
