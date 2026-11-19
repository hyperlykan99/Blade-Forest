# Blade Forest — Live AI Handoff

> **START HERE WHEN SWITCHING BETWEEN CLAUDE AND CODEX.**
> This is a shared, human-readable status page, not a live connection or an automatic lock.
> Last documented snapshot: **2026-11-18**. Status below is from the repository docs, **not an independently verified current Studio inspection**.

## Quick dashboard

| Field | Current recorded value |
| --- | --- |
| Project | Blade Forest |
| Repository | `hyperlykan99/Blade-Forest` (`main`) |
| Roblox place | **Production:** `73142469975141` / universe `10777481912` (Team Create, group 76836496, PUBLIC). **Dev:** `103379930563763` / universe `10777797608` (PRIVATE, personal) |
| Most recent documented place version | **48** (verify before working) |
| Active AI editor | **Claude**: **P1b.2 Crystal Wilds construction** (owner-approved), dev place 103379930563763 only (claimed 2026-11-19 00:30 PST) |
| Last handoff author / time | **Claude / 2026-11-19 ~00:45 PST** (P1b.1 blueprint) |
| Last confirmed gameplay edit | **Dev place only:** v9 (M-1, TravelService). Production: none since the P0 baseline (`updateTime` 15:12:30Z, re-checked 2026-11-19 00:25 PST) |
| Current task | **P1b.1 blueprint delivered** (`docs/P1B_MIGRATION_BLUEPRINT.md` + `docs/p1b_asset_manifest.json`). Dev place v9 verified (P1a + M-1). **No construction done** |
| Next action | Owner: review the blueprint §11 decisions (P1b.2 approval, B1 glow cap, B2 Frost Mythic, altar, P1b.4). **P1b.2 construction NOT authorized until explicit approval.** iPhone solo check of dev v9 still pending |
| Code source of truth | **Roblox place** until source scripts are exported and validated into `src/` |
| Documentation source of truth | GitHub `docs/` |
| Working scripts in GitHub? | **Yes, on branch `p0/script-export`** (34 scripts, checksum-verified). Not yet merged to `main` |
| Blockers | Script export outstanding; owner-managed commerce/API setup; suspicious unused imported scripts awaiting review |

## Who is responsible

- **Claude:** primary Studio developer, currently using Roblox Studio MCP. On handoff, save the place, report exact state and update this file.
- **Codex:** fallback Studio developer, also reportedly configured for Roblox Studio MCP. Confirm it can see **this exact place/session** before any changes. For repository code work, follow the branch/PR workflow in `AI_HANDOFF.md`; never assume an unmerged branch is deployed in Studio.
- **ChatGPT:** project planner, reviewer and handoff-document editor. Do not interpret a documentation update as a Roblox code edit.
- **Owner:** decides priorities, grants risky changes and resolves conflicts. Only one AI should edit the Studio place at a time.

## Start-of-session checklist (Claude or Codex)

1. Pull/read the latest `docs/LIVE_HANDOFF.md`, `docs/AI_HANDOFF.md`, `docs/CURRENT_STATUS.md`, `docs/TASKS.md`, and latest commit/PR status.
2. Inspect Roblox Studio: verify place ID `73142469975141`, current saved place version, Edit mode (not Play), and which scripts/objects exist. **MCP access alone does not confirm same session or current content.**
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

## Current session (claim before editing)

| Item | Entry |
| --- | --- |
| AI | Claude |
| Started (date/time/timezone) | 2026-11-18 19:05 America/Los_Angeles |
| Task / owner approval | Script export (approved, waiting on file); economy and monetization audit, read-only (approved 2026-11-18, completed) |
| Studio place ID and saved version checked | Place `73142469975141` / universe `10777481912` confirmed; Edit mode, not running. Saved version not re-queried (last documented: 48). 34 scripts / 393,047 bytes, identical to Claude's previous inventory, so no code changes since |
| Git branch / starting commit | `main` @ `e1c0b5d` |
| Scripts or objects being edited | None in Studio (export only reads) |
| Work in progress / unsaved changes | None from Claude |
| Tests and results | Studio state re-checked 2026-11-18 (Edit mode, 34 scripts / 393,047 B unchanged). M2: read-only survey of map, terrain, streaming, trees, NPCs, bosses and spawns; island sim `docs/m2_island_sim.py` (200 seeds × 4 archetypes × 2 luck variants × 6 gates). No Studio writes and no saves |
| Risks / blockers | Export needs the owner to attach an `.rbxlx` (Mac folder access denied). Audit found: all 9 dev products have `ProductId = 0` (none purchasable); `SetAsync` without session lock; paid-random gating gaps once log packs go live. See the report |

## Latest completed handoff

| Item | Entry |
| --- | --- |
| From AI | Claude (repo setup; summarized by ChatGPT) |
| Date | 2026-11-18 |
| What was completed | Repo skeleton, docs, Rojo configuration, regular Git push |
| Gameplay changes | None reported in that session |
| Current Studio version | 48 **as documented**, not freshly checked |
| Files edited in GitHub | `README.md`, `docs/GAME_DESIGN.md`, `docs/CURRENT_STATUS.md`, `docs/CHANGELOG.md`, `docs/AI_HANDOFF.md`, `docs/TASKS.md`, Rojo setup, `.gitignore` |
| Gameplay files modified | None reported in repo setup |
| Tests | Git push reported successful; no new gameplay tests reported |
| Commit | Check latest `main` commit in GitHub; not recorded here |
| Incomplete | 34 Luau scripts still need safe export to `src/` if source-file handoff is desired |
| Next AI instruction | Verify Studio state/version; do not assume this snapshot reflects later edits |

## Known security warning

Claude's `AI_HANDOFF.md` reports **14 suspicious imported ModuleScripts** nested in unused `ServerStorage` import/template folders. Their safety has **not** been independently established here. Do not clone or execute those assets, and do not delete folders without owner approval and a recoverable backup. Review `AI_HANDOFF.md` before using any imported model.

## How to hand off in practice

**Claude reaches its usage limit:** ideally have Claude save and update this page first. If the limit interrupts it, Codex must inspect Studio and GitHub, mark anything uncertain as **unverified**, and avoid overwriting unsaved work.

**Codex takes over:** read both handoff docs, verify the Studio place, claim the session, complete one approved task, playtest/save, and update GitHub before releasing the session.

**Claude returns:** read the latest handoff and Git commits/PRs; inspect the actual Roblox Studio state before resuming.

**ChatGPT plans:** write proposed items to `TASKS.md` only when requested/approved; do not relabel proposals as implemented functionality.

**Note:** This page does not automatically update itself. Each AI needs GitHub write access and must actually commit changes. Exporting scripts is *optional for documentation sync*, but strongly recommended for source review, backup, and safe Git-based editing. While code still lives only in Studio, no GitHub document can prove the current script contents.
