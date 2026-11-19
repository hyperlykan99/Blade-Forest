# Blade Forest — P0 Isolation & Backup Execution Checklist

**Owner approval:** 2026-11-18 — **P0 ONLY**.  
**Status:** AUTHORIZED, **NOT YET VERIFIED COMPLETE**.  
**Authorized activity:** protect the existing game by producing a restorable offline backup, an isolated development copy, a safe copy of source files and verification evidence.  
**Not authorized:** P1 island construction, portal code, island registry, balance changes, DataService schema edits, map edits, import/cleanup of suspicious assets, publishing to or modifying the original place, monetization changes, or touching production player data.

## Ground truth

- Original production/Team Create place ID: **73142469975141**, universe **10777481912**. **Do not save changes to or publish over this place.**
- Source of truth for gameplay remains the original Roblox place until scripts are exported and validated.
- Claude's M2 report records 34 scripts and 393,047 source bytes, an existing central hub at (0,0,0), and origin-dependent area logic. These are **baseline references**, not a guarantee of current Studio content; recheck just before copying.
- GitHub repository `hyperlykan99/Blade-Forest` contains planning docs, not a place-file backup. A Git commit or branch alone is **not** a Roblox place backup.
- Existing Creator Store import folders reportedly contain suspicious scripts. Treat every copy as untrusted until reviewed; **do not execute/import from these folders or delete original assets as part of P0**.

## P0 owner/developer execution steps

### A. Snapshot and offline backup (no source edits)
1. Before opening, confirm the currently selected Roblox experience **and place ID** matches the original, and that the Studio view is in Edit mode. Verify there are no unresolved concurrent edits; do not take over another AI's claimed session.
2. Produce an offline full-place backup using Roblox Studio's **Save to File** capability, preferably both a native `.rbxl` (if supported) and `.rbxlx` copy for text-based export. File format choice is implementation-dependent; verify the saved artifact includes terrain and expected game objects.
3. Name backup with original place ID and timestamp (e.g. `BladeForest_ORIGINAL_73142469975141_2026-11-18_PRE_ISLANDS.rbxlx`), store in a private location outside the live Studio project, and keep a second copy in another protected location.
4. Verify the offline backup can be opened in Studio **without publishing or saving over the original**. Record actual file size, filename/path (private paths need not be published), and SHA-256 hash if accessible.
5. Capture the original saved place/version number, plus baseline counts for scripts, trees, terrain footprint, NPCs, and UI. Any discrepancy from M2 must be documented before proceeding.

### B. Isolated development copy
1. Create a **separate, private Roblox experience/universe** for `Blade Forest — Island Dev`; do not create merely another place under the production universe if shared production data or asset integrations could be affected. If Studio/UI restrictions prevent doing so safely, stop and request the owner's manual step.
2. Populate it from the verified backup using Roblox Studio's **Publish as** workflow, carefully checking the destination before confirming. **Never choose the original production place ID.** If the UI is ambiguous, stop rather than risk overwriting production.
3. Record both the new universe ID and new place ID and confirm they are **different** from the original IDs. Verify the dev experience is private/restricted and not discoverable to public players.
4. Verify development data isolation. Review any hard-coded DataStore names, OrderedDataStore usage, MessagingService, cross-place teleports/AFK targets, group/game-pass/product references, analytics, API keys, webhooks, and automation. A separate universe normally separates Roblox DataStores, but **do not assume every external integration or purchase configuration is isolated**. Disable/restrict dangerous non-test integrations in the *dev copy only* if required, with a record of the exact change.
5. Test opening the dev copy in Studio and inspect asset/script counts. Do not start gameplay-changes or publish anything back to production. Avoid running suspicious imported scripts; address them only under a separately approved security plan.
6. Preserve an untouched initial dev snapshot so any future P1 prototype can be reverted.

### C. Source export (P0 authorized, read/export only)
1. On a verified offline backup or isolated dev copy, export the 34 scripts into the repository `src/` per the existing Rojo project layout; coordinate with Claude's existing blocked `.rbxlx` handoff.
2. Avoid committing `.rbxl`, `.rbxlx`, secrets, credentials, cookies, or unvetted asset scripts to the public GitHub repository. Keep full-place backups private.
3. Check script names/count/content against the recorded inventory and identify which files the Rojo mapping actually covers. Handle sources outside the mapping explicitly. **Do not sync GitHub code into the original Studio place.**
4. Commit exported scripts in a review branch; no forced updates to `main` and no code edits in this phase. Flag suspicious modules for review without executing them.
5. Record commit SHA, counts, excluded files, and whether a no-write verification of round-trip consistency succeeded. If export is blocked, mark P0 partial rather than claiming done.

### D. Verification before P0 sign-off
- [ ] Offline **full-place backup exists** and was reopened safely without changing production.
- [ ] Second backup copy is secured and integrity/size recorded.
- [ ] Original place ID, original universe ID, original saved version, and baseline counts recorded.
- [ ] New dev experience and place IDs recorded; both distinct from production.
- [ ] Dev experience is private and publishing destination has been verified.
- [ ] Dev DataStore and third-party integrations isolated or explicitly documented as blocked.
- [ ] Initial dev snapshot retained.
- [ ] `src/` export reviewed, with exclusions/security issues noted; if blocked, exact recovery action recorded.
- [ ] GitHub `LIVE_HANDOFF.md` and `TASKS.md` updated with verified evidence and next steps.
- [ ] **Original game unchanged.** No P1 scripts, geometry, portals, islands, balance or monetization changes.

## Required completion record

| Field | Verified value |
| --- | --- |
| P0 executing AI / owner | PENDING |
| Original universe / place ID | 10777481912 / 73142469975141 |
| Original saved version at backup | PENDING |
| Offline backup file + format + size | PENDING |
| Backup second copy + checksum | PENDING |
| Backup reopen test | PENDING |
| New dev universe ID | PENDING |
| New dev place ID | PENDING |
| Dev private / access validation | PENDING |
| Dev DataStore/integration isolation validation | PENDING |
| Baseline and dev script/tree counts | PENDING |
| Source export branch / SHA | PENDING |
| Exceptions/blockers | PENDING |
| Production unchanged verified | PENDING |
| Next authorized scope | **P0 only; P1 needs explicit separate approval** |

## Stop conditions

STOP immediately if a publish destination seems to be production, the original is being edited by someone else, a backup cannot be reopened, a dev copy points at production data or risky endpoints, or identity/version checks fail. Report the blocker to the owner rather than trying an unsafe workaround.

**Claude/Codex:** Update `LIVE_HANDOFF.md` before and after your Studio session. Only one AI edits Studio at a time. Do not mark P0 completed until the completion record above contains verified evidence.
