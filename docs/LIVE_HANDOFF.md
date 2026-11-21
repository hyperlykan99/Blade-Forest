# Blade Forest — Live AI Handoff

> **START HERE WHEN SWITCHING BETWEEN CLAUDE AND CODEX.**
> **2026-11-20 PST · Codex M3 implementation.** The private dev place has the 72-node Tech Tree, 100 Mastery levels, 12 traits, 21 pets and Golden/Rainbow evolution. The editor is released. See the [M3 results](m3/M3_CHARACTER_PROGRESSION_RESULTS.md).
> Last documented snapshot: **2026-11-20 16:15 PST** (Claude, end of M1 Unified Economy & Progression). Written on branch `m1/unified-economy-progression` (based on `m0.1/foundations-corrections`; not merged to `main`). **Re-verify Studio before editing.**
> Last documented snapshot: **2026-11-20 04:50 PST** (Claude, end of M0.1 Foundations Corrections). Written on branch `m0.1/foundations-corrections` (based on `m0/foundations`; not merged to `main`). **Re-verify Studio before editing.**

## Quick dashboard

| Field | Current recorded value |
| --- | --- |
| Project | Blade Forest |
| Repository | `hyperlykan99/Blade-Forest` (`main`) |
| Roblox place | **Production:** `73142469975141` / universe `10777481912` (Team Create, group 76836496, PUBLIC). **Dev:** `103379930563763` / universe `10777797608` (PRIVATE, personal) |
| Most recent documented place version | **Dev M3 saved state** · Open Cloud `updateTime` `2026-11-21T02:11:29.158Z`. Team Create reported no unsaved changes. The numeric M3 version is unverified. Last numbered milestone in the handoff: **v45 (M2)**. |
| Active AI editor | **Codex** (owner-authorized M4 world construction) |
| Last handoff author / time | **Codex / 2026-11-20 PST** (M3 Character Progression) |
| Last confirmed gameplay edit | **Dev only:** M3 Tech Tree, mastery, traits and pets. M2’s 120 weapon definitions and 120 BladeModels were observed in the M3 smoke session. |
| Current task | M4 world construction on private dev only. |
| Next action | Review the M3 results and resolve the numeric saved version through Studio Version History. M4 requires a new owner instruction. |
| Code source of truth | **Roblox private dev place and `m3/character-progression`.** The 18 M3 source digests matched implementation commit `fddc1b3ba2cd60abacbadaafff618ae2b6b6a0b0`. The two new pet rosters and all evolution model recipes are source-controlled. |
| Documentation source of truth | GitHub `docs/` |
| Working scripts in GitHub? | **Yes, on branches, not `main`.** `p0/script-export` (34-script baseline) → `p1a/island-prototype` → `p1a/m1-arrival-slot-fix` → `p1b2/crystal-wilds` @ `0fc997d` (35 scripts; BladeConfig + WorldServer changed) → `p1b2r/dense-forest` @ `a893300` (no script changes) → `p1b2r/camera-visibility-fix` (ChopEffects changed). Design branches: `proposal/p1b2-dense-forest` @ `63937f9`, `proposal/p1b2r-camera-visibility` @ `49e6e81` |
| Blockers | Numeric cloud save version unverified. Actual evolved-inventory DataStore persistence, restricted-account policy, mobile and multiplayer remain unverified. Earlier milestone review items remain open. |

## Who is responsible

- **Claude:** primary Studio developer, currently using Roblox Studio MCP. On handoff, save the place, report exact state and update this file.
- **Codex:** fallback Studio developer, also reportedly configured for Roblox Studio MCP. Confirm it can see **this exact place/session** before any changes. For repository code work, follow the branch/PR workflow in `AI_HANDOFF.md`; never assume an unmerged branch is deployed in Studio.
- **ChatGPT:** project planner, reviewer and handoff-document editor. Do not interpret a documentation update as a Roblox code edit.
- **Owner:** decides priorities, grants risky changes and resolves conflicts. Only one AI should edit the Studio place at a time.

## Start-of-session checklist (Claude or Codex)

1. Pull/read the latest `docs/LIVE_HANDOFF.md`, `docs/AI_HANDOFF.md`, `docs/CURRENT_STATUS.md`, `docs/TASKS.md`, and latest commit/PR status.
2. Inspect Roblox Studio: verify the **dev** place `103379930563763` / universe `10777797608` (never edit production `73142469975141`), current saved place version, Edit mode (not Play), and which scripts/objects exist. **MCP access alone does not confirm same session or current content.**
3. Check for unsaved Studio changes and another AI's unfinished edits. If the handoff is stale or conflicting, **ask the owner rather than overwrite**.
4. Before editing, fill `Active AI editor`, `Current task`, and the working time under **Current session**. Commit this documentation update when possible.
5. Observe the safety/architecture rules in `AI_HANDOFF.md`: server-authoritative rewards; compatible DataService saves; Creator Store assets; no secrets or force-push; Edit mode only.
6. Make and test only the approved change. Do **not** edit in parallel with another AI. Do not change live commerce or delete suspect assets without approval.

## End-of-session checklist (required before switching AIs)

1. Stop edits. Save the Roblox place in Studio and confirm the saved version if available; never claim a save that was not confirmed.
2. Update **Current session** and **Latest completed handoff** with what changed, exact script/object paths, tests, failures, warnings, and work left incomplete.
3. Update `CURRENT_STATUS.md` for verified behavior, `CHANGELOG.md` for completed changes, and `TASKS.md` for task status. Update `AI_HANDOFF.md` if architecture or conventions changed.
4. Commit and push doc changes; include the Git commit SHA/link. If push fails, paste the handoff in the chat and explicitly mark it **not synced**.
5. Set `Active AI editor` to **None**, `Current task` to **None claimed**, and give the next AI one specific next action.

## Claude → Codex handoff (2026-11-18 22:20 PST)

- **Studio state:** dev place `Blade Forest - Island Dev` (place 103379930563763 / universe 10777797608, PRIVATE), **Edit mode, saved version 7**. No edits since v7; only playtests ran afterwards. A final `save_place` check timed out on the device and was **not retried**. If Studio shows unsaved changes, they are not Claude's: inspect before saving.
- **Studio API access:** ON for the dev experience (verified working 22:10 PST).
- **Dev test data:** the account 394034825 dev save holds the Void weapon, a Crystal Wilds unlock and `LastIsland = CrystalWilds` (dev DataStore only).
- **Code:** branch `p1a/island-prototype` @ `3511a5c` matches Studio v7 (BladeConfig 55,586 B, DataService 19,574 B, TravelService 7,991 B; checksums in commit messages). Studio-only objects: `Workspace.Islands` (18 parts, Persistent models).
- **Test hooks (Studio only):** `ServerStorage.DevTravel:Invoke(player, islandId, {unlock=,cooldown=,same=})`, `ServerStorage.DevGrant:Invoke(player, "Get"|"Save"|"AddWeapon", ...)`. Note: a command-bar `require(DataService)` returns a separate copy with no players; use DevGrant `Get`.
- **Production:** 73142469975141 untouched; `updateTime` `2026-11-18T15:12:30.520Z` (last checked 22:05 PST).
- **Not authorized:** P1b, gameplay/economy/monetization changes, production edits, asset imports, deleting import folders.

## Claude → next AI handoff (2026-11-20 ~17:40 PST, M2)

- **Studio state:** dev place 103379930563763 / 10777797608, **Edit mode, saved v45**, no play session, profile lock released. One Studio client used.
- **Branch / commit:** `m2/complete-weapon-collection` @ `26360477a615ec6c2c1da1be3d47cb3ef98aa7c5`.
- **What changed:** see `docs/m2/M2_COMPLETE_WEAPON_COLLECTION_RESULTS.md`. Roster lives in `tools/m2/roster.py`; run `python3 tools/m2/gen_m2.py` to regenerate the BladeConfig M2 blocks and `docs/weapon_manifest.json`. Never hand-edit between `-- M2:BEGIN/END` markers.
- **Test hooks (Studio only):** `require(game.ServerStorage.M2Tests).RunAll()` (run suites separately if it times out); M1/M01/M0 tests unchanged.
- **Rollback:** dev v35, or `ServerStorage.M2Backups` (`<Name>_PreM2`, `BladeModels_PreM2`, dev profile snapshot).
- **Production:** not accessed.

## Claude → next AI handoff (2026-11-20 16:15 PST, M1)

- **Studio state:** dev place 103379930563763 / 10777797608, **Edit mode, saved v35**, no play session, profile lock released. Studio instance used: one client only.
- **Commit:** `be23a7c2117ec2d59e31bed13ee091466f7c5370`.
- **What changed:** see `docs/m1/M1_UNIFIED_ECONOMY_RESULTS.md` §1 (26 files, all checksum-matched between Studio and branch `m1/unified-economy-progression`).
- **Economy parameters:** edit `tools/econsim/economy_params.json`, run `python3 tools/econsim/gen_luau.py` to regenerate `src/shared/EconomyConfig.luau`, re-run `tools/econsim/run_all.sh` and `golden.py`, then update `M1Tests` golden values. Never hand-edit EconomyConfig.
- **Test hooks (Studio only):** `require(game.ServerStorage.M1Tests).RunAll()`; `ServerStorage.DevEconomy:Invoke("Report")` (telemetry). Earlier hooks unchanged.
- **Rollback:** dev v29, or `ServerStorage.M1Backups` (`<Name>_PreM1` + `OriginalPath`).
- **Production:** not accessed.

## Current session (claim before editing)

| Item | Entry |
| --- | --- |
| AI | Codex |
| Started (date/time/timezone) | — |
| Task / owner approval | Owner-authorized M3 construction and private save complete. |
| Studio place ID and saved version checked | `103379930563763` / `10777797608`, Edit mode. No unsaved changes. Cloud timestamp `2026-11-21T02:11:29.158Z`; numeric version unverified. |
| Git branch / starting commit | `m3/character-progression`, starting from documentation handoff `a42477e11d81a410b54af71406f7aeb18a98ab47` on completed M2 `ce670488172ae0a39bfff259c47bf6b74578e1d5`. |
| Scripts or objects being edited | None |
| Work in progress / unsaved changes | None reported by Studio. |
| Tests and results | [M3 results](m3/M3_CHARACTER_PROGRESSION_RESULTS.md) covers compilation, detached progression and evolution fixtures, v4 save compatibility, and one-client functional checks. |
| Risks / blockers | See dashboard and M3 results. |

## Codex → next editor (2026-11-20 PST, M3)

- The implementation commit is `fddc1b3ba2cd60abacbadaafff618ae2b6b6a0b0` on `m3/character-progression`. The private place was left in Edit mode.
- The Tech Tree uses `ReplicatedStorage.CharacterProgression`, `ServerScriptService.CharacterProgressionService` and the client Mastery controller. Mastery, node ownership, points and respec use the existing profile writer.
- Pet models are generated by `ServerScriptService.PetModelFactory` from seven unchanged Timber templates and source-controlled Crystal/Frostbound geometry. The saved place loads 63 templates at server startup.
- Rollback is documented M2 v45 or the 11 verified source copies in `ServerStorage.M3Rollback`. The full object and source inventory is in the [M3 results](m3/M3_CHARACTER_PROGRESSION_RESULTS.md).

## Historical camera visibility handoff

| Item | Entry |
| --- | --- |
| From AI | Claude |
| Date | 2026-11-19 (camera fix, about 21:15–22:00 PST) |
| What was completed | Dev place only: client-side camera visibility fix in `ChopEffects`. It adds an independent canopy fade registry, a canopy-aware obstruction test (0.90 blocking / 0.72 near), hysteresis, tiered labels (T1 90 studs uncapped; T2 48; T3 24, or 48 when locked or struck), caps of 16 compact / 24, and hides labels over the character |
| Gameplay changes | Client visuals only (`LocalTransparencyModifier`, BillboardGui enable). No server, data, economy, combat, tree or terrain changes |
| Current Studio version | Dev **v18** (Studio-reported). Checkpoint **v16**. v17 unexplained. Production unchanged (`updateTime` 2026-11-18T15:12:30.520Z, checked 2026-11-19 21:53 PST) |
| Files edited in GitHub | `p1b2r/camera-visibility-fix`: `src/client/ChopEffects.client.luau`, `docs/p1b2r_camera/*`, this page, `CURRENT_STATUS.md`, `CHANGELOG.md`, `TASKS.md` |
| Gameplay files modified | `src/client/ChopEffects.client.luau` only (18500:3640422855 → 27331:1017905967) |
| Tests | One Studio client, C1–C9 passed (limits: 24-label cap and travel UI not exercised). Studio FPS in Z2 14.2–14.6 (was 8.4); MacBook Studio is not representative of iPhone. One 4 s chop for the regrowth test changed the dev save (Logs 9→6,255, TreesChopped 3,329→3,331). 620/620 trees at dense spots. iPhone and two-player **not tested** |
| Commit | See `git log` on `p1b2r/camera-visibility-fix` |
| Incomplete | iPhone validation; two-player; merge decision; B1 effect/tag drift; dense-zone income |
| Next AI instruction | Do not edit Studio until the owner reviews v18. Verify dev v18 and production `updateTime` first. P1b.3 not authorized |

## Known security warning

Claude's `AI_HANDOFF.md` reports **14 suspicious imported ModuleScripts** nested in unused `ServerStorage` import/template folders. Their safety has **not** been independently established here. Do not clone or execute those assets, and do not delete folders without owner approval and a recoverable backup. Review `AI_HANDOFF.md` before using any imported model.

## How to hand off in practice

**Claude reaches its usage limit:** ideally have Claude save and update this page first. If the limit interrupts it, Codex must inspect Studio and GitHub, mark anything uncertain as **unverified**, and avoid overwriting unsaved work.

**Codex takes over:** read both handoff docs, verify the Studio place, claim the session, complete one approved task, playtest/save, and update GitHub before releasing the session.

**Claude returns:** read the latest handoff and Git commits/PRs; inspect the actual Roblox Studio state before resuming.

**ChatGPT plans:** write proposed items to `TASKS.md` only when requested/approved; do not relabel proposals as implemented functionality.

**Note:** This page does not automatically update itself. Each AI needs GitHub write access and must actually commit changes. Exporting scripts is *optional for documentation sync*, but strongly recommended for source review, backup, and safe Git-based editing. While code still lives only in Studio, no GitHub document can prove the current script contents.
