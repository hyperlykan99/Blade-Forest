# Current Status

_Last updated: 2026-11-18_

## Live place

- Team Create place `73142469975141`, latest saved version **48** (HUD handoff).
- 34 scripts, about 393 KB of Luau. The full inventory is in `AI_HANDOFF.md`.

## Working and playtested

- Chop loop, blade upgrades (max 5 blades), spin cap, blade stop toggle.
- Weapon rolls, fusing, Shiny crafting, weapon index with rewards and Claim All.
- Tree index with area tabs, mutation counts and a completion bonus.
- 7 tree rarities including Mythic/Secret; about 200 mutated trees seeded.
- Pets (hatch, equip, Equip Best, followers), Log Market, Achievements.
- Ancient Treant world boss with damage-share rewards.
- NPC camps with animated R15 rigs.
- Area boss HP bar shows only inside the arena.
- Settings: Screen Shake and Reduced Motion.
- Mobile compact layout, hide buttons, tiny tappable docks.
- HUD (v48): upper-left notification feed, StatusRail for timers and potions, compact 5-button RollBar.

## Known gaps

- **Developer products are not created.** Creating them through Open Cloud was refused, so the owner must create them in the Creator Dashboard.
- Game passes need to be **put on sale** with prices.
- **Studio API access** must be enabled for DataStores to work in Studio. Until then, leaderboards clear themselves in Studio, which is expected.
- **Repo sync:** the scripts in `src/` must be exported from the place (see `TASKS.md`). Until that happens, the place file is the source of truth.
