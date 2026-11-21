# Current Status

_Last updated: 2026-11-20 16:15 PST (branch `m1/unified-economy-progression`; owner review)_

**M1 (dev v35):** unified Economy engine, tier pricing, Walk Speed and Forest Renewal upgrades, Soul upgrades, island altars with exact odds, staged island gates and economy telemetry are live on the dev place only. Single-client verified; multiplayer, bosses in play and gate unlocks not yet verified. See `docs/m1/M1_UNIFIED_ECONOMY_RESULTS.md`.

## Live place

- **Production** (Team Create) `73142469975141`: documented v48 (HUD handoff); unchanged since the P0 baseline (`updateTime` 2026-11-18T15:12:30.520Z, re-checked 2026-11-19 21:53 PST).
- **Dev** `103379930563763` / `10777797608` (PRIVATE): **v35** (M1 Unified Economy; checkpoint v29). Previously **v29** (M0.1 Foundations Corrections; checkpoint v23; v24–v28 probably auto-saves). The dev save is format v4 with session locking (M0) plus serialized, sequence-fenced writes and profile-stored playtime gifts (M0.1; see `docs/m0/M01_FOUNDATIONS_CORRECTIONS_RESULTS.md`). Islands prototype: Timber Haven hub, Crystal Wilds (P1b.2 terrain, plaza, return pad; 620 trees in four dense zones after P1b.2r), Frostbound Reach (P1a placeholder). 35 scripts; BladeConfig and WorldServer (P1b.2) and the client ChopEffects (camera fix) differ from production.

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
- **Repo sync:** scripts are exported and checksum-matched on branches (`p0/script-export` baseline, latest `p1b2r/camera-visibility-fix`). None are merged to `main` yet.
- **Dev Crystal Wilds (P1b.2r):** camera visibility fixed on dev v18 (client canopy fade + tiered labels; one Studio client, C1–C9 passed; Studio Z2 FPS 14.2–14.6 vs 8.4 before). Respawned trees lose P1b tags and reroll effects (B1). iPhone and two-player testing are unverified.
