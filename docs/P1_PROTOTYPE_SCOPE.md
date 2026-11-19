# Blade Forest — P1 Limited Island Prototype Scope

**Prepared:** 2026-11-18. **Status:** P1a ONLY explicitly OWNER APPROVED on 2026-11-18; implementation pending Claude verification of dev place. This is not approval for P1b, P1c, P2 or production changes.

## Strict targeting

- **Only:** private `Blade Forest - Island Dev`, place **103379930563763**, universe **10777797608**.
- **Never:** production place **73142469975141**, universe **10777481912**.
- Preserve baseline backup `BladeForest_ORIGINAL_73142469975141_2026-11-18_PRE_ISLANDS.rbxl` and untouched initial dev version. P0 report has checksum.
- Check place/universe identity and editor claim BEFORE ANY save/publish. Stop on mismatch. Review source export on branch `p0/script-export`; do not blindly push to original Studio.

## Proposed first implementation slice (P1a only)

1. **Prototype island registry / classification:** Implement server-side island bounds using a distinct stable IslandId, with legacy Starter vs Pine area behavior retained. Sample tests at x=0, x=3000, x=6000, plus outside bounds. Avoid accidentally treating every x>188 as Crystal Canyon. Keep original Crystal/Frost accessible in dev until migration tests prove compatibility.
2. **Temporary, low-part-count test pads** at/near (3000,0,0) and (6000,0,0), with anchored, non-falling arrival floors and safe marker parts. This is a reversible *blockout*, not terrain construction or detailed decoration. Verify Y coordinates and streaming before placing.
3. **Travel prototype:** Two-way travel to pads in the **same place** using server-validated destinations, an initial cooldown and safe landing. For streaming use correct Roblox API semantics; test client/network behavior rather than assuming the read-only M2 pseudocode is executable. Players cannot bypass locks and cannot travel during combat. For P1a, an authorized Studio-only/admin travel command or minimal test UI is acceptable before building decorative portals.
4. **Preserve old game data:** No destructive migration. New `UnlockedIslands`, `LastIsland`, `IslandProgress` may be implemented only with `DataService.DEFAULT` + reconcile and separate dev test DataStores after explicit approval. Verify old Crystal/Frost accounts grandfather correctly. Keep all old keys; no production DataStore operations.
5. **Safety checks and logs:** record returned travel result, map classification, respawn and rejoin, repeated spam, simultaneous users, latency, falling/streaming, any effects on AutoChop/roll/trees/quests, and cross-island NPC/boss interactions.
6. **No change to commerce** (including game passes, developer product IDs, receipt handling or odds), no asset imports, no deletion/optimization of existing world assets, no release to public.

## Proposed staging after P1a (not authorized yet)

- P1b: validated migration of original Crystal Canyon/Frost Peaks geometry and tree models to the new islands.
- P1c: actual portal art, island-specific NPCs/boss content, unlock quests and economic gates.
- P2: mobile streaming/memory tests and optimization.

## Evidence / exit conditions

- Document exact scripts/objects modified; place and universe IDs; new dev saved version; rollback steps.
- Verify no modifications to production; keep untouched dev baseline.
- Test travel I1→I2→I1 and I1→I3→I1 with separate temporary **test-account bypass only in Studio** if progression gates are not yet implemented. Never release bypass to public.
- Record unit checks for invalid island ID, spam, noclip into locked area, death during travel, streaming timeout, and failed requests.
- Document script export/PR vs Studio state and update `docs/LIVE_HANDOFF.md`, `docs/TASKS.md`, `docs/CHANGELOG.md`.

**Approval:** The owner has explicitly authorized ONLY the P1a prototype described above in private dev place 103379930563763. Claude must verify place identity, save a dev-only rollback checkpoint, implement and test within that scope, report before moving on. No production changes.
