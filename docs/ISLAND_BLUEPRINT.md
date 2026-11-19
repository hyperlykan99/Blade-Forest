# Blade Forest — Approved Single-Place Island Blueprint (Design v0.1)

**Owner decision:** 2026-11-18. Approved design direction: a single Roblox place with multiple teleport-connected islands, starting with a Starter Island and adding islands in future updates.

**Status:** Design direction approved. Exact island count, names, timing, prices, geometry, asset choices and construction are **not yet separately approved**. Do not modify Roblox Studio, live data, monetization, or scripts based solely on this document.

**Baseline:** Roblox place `73142469975141`. Sources: `GAME_DESIGN.md`, `ECONOMY_MONETIZATION_AUDIT.md`, `AI_HANDOFF.md`, `LIVE_HANDOFF.md`.

## 1. World architecture (approved)

- **One place, one server session:** Every island exists in the same Roblox place, spatially separated. Teleport pads or a portal directory relocate the character to a validated destination within this place; **do not use TeleportService for intra-world travel**.
- Stay in same multiplayer server with existing inventory, Logs, Souls, bosses and UI; support safe round trips to previously unlocked islands.
- Maintain a central destination list/registry rather than hard-coding 3 or 4 areas. Future additions should only need island configuration + content + tests.
- Check unlock access on the **server** for every teleport request. Apply destination cooldown, safe landing zone and obstruction checks; handle streaming delay and mobile rendering. No free bypass of progression gates.
- Make Starter Island playable immediately with no paid requirement. Never require a game pass or paid rare roll to reach content.

## 2. Initial launch concept — proposed, not final

**Working island count:** Three polished islands at initial release, future Island 4+ appended. Working names are not final.

| Island | Theme / function | Provisional reuse of existing areas | Player-facing anchor |
| --- | --- | --- | --- |
| 1 — Timber Haven | Friendly green starter forestry village; first upgrades, beginner trees, clear tutorial, hub/portals | Starter Grove + Pine Forest | Timber village, central portal plaza and first boss |
| 2 — Crystal Wilds | Colorful crystalline forest; stronger trees, pet/trait progression and repeatable objectives | Crystal Canyon | Crystal arch and themed boss |
| 3 — Frostbound Reach | Frozen advanced forestry; rare collections, long-term goals, boss encounters | Frost Peaks | Frozen gate and endgame activities |
| 4+ | Future update islands, progressively harder and visually distinct | New content, not a silent replacement of saves | New portals and content slots |

**No physical terrain measurements are approved yet.** Conceptually arrange islands with generous separation and streamable asset budgets, not continuous bridges. Portal travel is the connection.

### Starter Island layout zones
1. **Welcome spawn**: safe landing, immediate sight line to starter trees, minimal tutorial overlay.
2. **First chop grove**: fast initial action/rewards without teleport prompts.
3. **Upgrade and roll plaza**: upgrades and weapons; the current roll is free, so do not show fake Log costs.
4. **Pet / trait / index stations**: unlock introduction progressively; don't swamp first-time players with every menu.
5. **Boss / challenge clearing**: first meaningful challenge and return goal.
6. **Portal hub**: clear locked/unlocked destinations, requirements, preview, and a return portal.

### Island 2 and 3 composition
- Arrival pad; clear travel-back station; tree loop; upgrade/reward station or shortcut; distinct boss arena; collectible milestones; portal onward.
- The owner should later approve visual mockups, asset choices and exact dimensions. Existing Creator Store assets must be inspected and checked for foreign scripts before use.

## 3. Provisional pacing, not verified economy values

Use the existing code audit as the baseline, not as a final economy. The audit reports that early gates (40 and 250 Power) can be passed in about four minutes, but the 2,000 Power Frost gate traps most modeled free players for a week while heavily paying players reach Frost in minutes. **These are estimates based on a 25-seed simulation, not observed retention.**

| Milestone | Initial design target | Test condition |
| --- | --- | --- |
| First tree chopped | 0–30 seconds | New player with no paid boosts |
| First meaningful blade upgrade | 30–90 seconds | Free player |
| First weapon roll / discovery | 2–5 minutes | Free player |
| First island meaningful completion and portal to Island 2 | Roughly 20–30 minutes | Casual free player (target to validate, not hard time gate) |
| Island 2 / Island 3 progression | Extend through several sessions with measurable incremental milestones | No random-only hard wall; paying users cannot skip all content |
| Week-one goal | Useful collections, bosses, Souls/rebirths and recurring activities remain | Measure D1/D7 with real cohorts after launch |

**Design principle:** area unlock = transparent combination of gameplay milestones and attainable power; do not gate progress solely on a highly improbable weapon roll. Consider island-level quests or boss completion + attainable Power threshold. Confirm exact formula after economy simulation; no final numeric thresholds are approved.

**Currency design:** Logs must retain sinks (upgrades, pets/traits, future optional progression), Souls remain prestige resource; revisit multipliers and luck stacking so neither paid nor free players trivialize islands. Preserve nonpaying access, avoid inflated unlock prices intended to pressure purchases. Add new sinks only after modeling earnings over time.

**Monetization blocker:** do not activate new developer products or paid-random rewards until robust receipt persistence, server-side restrictions, and transparent odds are addressed and tested. Actual store prices must be verified in Creator Dashboard.

## 4. Player data migration / backwards compatibility

Current saved state and all item ownerships should be treated as durable. Preserve original area IDs/weapon and index identifiers while mapping their **presentation** into islands. Before changes:
- Inventory existing DataService save keys, area-unlock flags, spawn points, quest location references, portals, NPCs, TreeModels, bosses, events and client UI.
- Draft explicit old-area-to-new-island mapping and test old saves, maxed accounts, brand-new accounts, purchases and cross-server rejoins.
- Do not delete/remap old player fields or reset Logs, Souls, weapons, pets, traits, purchased entitlements or achievements.
- Use a feature flag/isolated development copy and a recoverable backup so existing map and saves are not overwritten. Plan rollback before enabling island travel.

## 5. Performance / Roblox architecture

- Single-place islands avoid cross-place loads but **all geometry may burden clients unless streaming and optimization are verified**.
- Plan a high-priority spawn area and safe character relocation with `StreamingEnabled` tested at representative mobile memory and network conditions.
- Do not rely on the client to authorize travel. Decide consistent handling of boss timers and events across islands in one server.
- Teleport UX: preview destination; show unlock reasons; avoid spam; allow return; deal with missing streamed terrain or avatar collision.
- Future island registry fields (concept only): `IslandId`, `DisplayName`, `WorldFolder`, `SpawnAnchor`, `UnlockCondition`, `MinSuggestedPower`, `TreePool`, `BossId`, `Theme`, `ReleaseState`.
- Validate server-visible destinations and no sensitive admin/debug hooks reachable by clients.

## 6. Phase gate / deliverables

**Next milestone: M2 — Technical and economic feasibility specification. Still no construction.**
1. Site audit: inventory current area coordinates/objects, scripts and dependencies without editing Studio.
2. Proposed top-down measured island blockout (dimensions, approximate separation, portal positions, spawn locations and performance budget).
3. Detailed economy simulation for the proposed island gates: free/paid at equal playtime, unlucky cases, D1/D7 pathways. Check model assumptions and seed variance.
4. Map migration and regression test matrix; rollback/backup approach.
5. Template for Island 4+ and a validated teleport flowchart.
6. Asset manifest of candidate Creator Store assets with provenance, script audit and owner approval before import.

**Not authorized at this stage:** changing scripts, existing geometry, map, user data, monetization, asset imports, Studio building, or launching experiments.

**Owner review next:** approve the measured M2 blockout and progression targets; then separately authorize a reversible pilot in an isolated development place.

## 7. Recommended staged implementation only after separate authorization

- P0: Back up / isolate development place and test old saves.
- P1: Build basic empty island layouts and server-validated teleport prototype; no old map destruction.
- P2: Validate traversal, streaming, mobile performance and return paths.
- P3: Migrate one starter-area content loop while preserving legacy area IDs.
- P4: Stage next two islands and rebalance progression using simulation and small playtests.
- P5: Retention instrumentation, security/commerce validation, staged QA and launch decision.

**Reminder:** This file is an approved *direction* and proposed blueprint. It is not evidence that any build work has been performed.
