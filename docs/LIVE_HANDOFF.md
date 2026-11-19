# Blade Forest — Live AI Handoff

> **START HERE WHEN SWITCHING BETWEEN CLAUDE AND CODEX.**
> This is a shared, human-readable status page, not a live connection or an automatic lock.
> Last documented snapshot: **2026-11-18**. Status below is from the repository docs, **not an independently verified current Studio inspection**.

## Quick dashboard

| Field | Current recorded value |
| --- | --- |
| Project | Blade Forest |
| Repository | `hyperlykan99/Blade-Forest` (`main`) |
| Roblox place | `73142469975141` (Team Create) |
| Most recent documented place version | **48** (verify before working) |
| Active AI editor | **None recorded** — claim this field before editing |
| Last handoff author / time | **ChatGPT / 2026-11-18** (document setup only) |
| Last confirmed gameplay edit | **Not verified here**; Claude reported no gameplay edits in its repo-setup session |
| Current task | **None claimed** |
| Next action | Receiving AI: read this page and `AI_HANDOFF.md`, inspect the actual Studio place, then state the intended task before editing |
| Code source of truth | **Roblox place** until source scripts are exported and validated into `src/` |
| Documentation source of truth | GitHub `docs/` |
| Working scripts in GitHub? | **Not yet**, per `CURRENT_STATUS.md`; recheck before relying on this |
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

## Current session (claim before editing)

| Item | Entry |
| --- | --- |
| AI | Unclaimed |
| Started (date/time/timezone) | — |
| Task / owner approval | — |
| Studio place ID and saved version checked | — |
| Git branch / starting commit | — |
| Scripts or objects being edited | — |
| Work in progress / unsaved changes | — |
| Tests and results | — |
| Risks / blockers | — |

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
