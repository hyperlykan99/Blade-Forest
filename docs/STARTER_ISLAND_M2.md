# Blade Forest — M2 Starter Island Layout & First-Session Progression

**Prepared:** 2026-11-18 by ChatGPT  
**Status:** DRAFT FOR OWNER REVIEW — design only, no construction, no code or live data changes.  
**Parent direction (approved):** `docs/ISLAND_BLUEPRINT.md` — single Roblox place with teleport-connected islands.  
**Basis:** `docs/ECONOMY_MONETIZATION_AUDIT.md` (Claude's code-derived economy numbers and 25-seed estimates), `docs/GAME_DESIGN.md`.  
**Caution:** All coordinates, dimensions, layouts, counts, time goals and suggested unlock conditions below are *new design proposals*, NOT measurements or verified current game values.

## M2.1 Starter Island (working name Timber Haven): proposed 640 x 560 stud blockout

**Coordinate frame:** island-local origin `(0,0)` at central village plaza, +Z = north, +X = east. Positions below are horizontal (X,Z), with Y to be decided from terrain. The proposed bounds are X=-320..320 and Z=-280..280; coast and water outside the walkable area. **Do not paste these coordinates into the current Studio place.** First inspect its origin/terrain and choose safe world-space offsets.

### Top-down spatial zoning (schematic, not scale drawing)

```text
                             NORTH (+Z)
          +-----------------------------------------------------+
          |   PINE FOREST: mid-starter zone (+0,+195)            |
          |   tougher trees / small NPC camp / index milestone  |
          |                [first boss clearing]                 |
          |                        ||                           |
          |    GROVE WEST          ||       PORTAL RIDGE         |
          |    (-210,+50)          ||       (+215,+95)            |
          |  beginner tree loops  ||  [Island 2 portal, locked]  |
          |                        ||       [Future pad, sealed]  |
          |                    VILLAGE PLAZA (0,0)              |
          |  [Upgrades] [Roll] [Pet/Traits] [Index] [Market]      |
          |                        ||                           |
          |                 WELCOME SPAWN (0,-145)               |
          |                 FIRST CHOP (0,-95)                   |
          |             safe onboarding / visible trees         |
          +-----------------------------------------------------+
                             SOUTH (-Z)
```

### Zone specification

| Zone | Local center (X,Z) | Suggested usable footprint | Main function | Design checks |
| --- | --- | --- | --- | --- |
| Spawn & first chop | (0,-145) | 120 x 95 studs | start safely and hit first trees within 30s | No collision blockers; clear route; safe respawn |
| Beginner grove | (-205,+45) | 190 x 180 | 2-3 easy chopping loops, mutation discovery | Tree respawns and orbit blade clearance |
| Village plaza | (0,0) | 160 x 140 | upgrades, *free* roll altar, index, shop navigation, social meet-up | No tutorial UI overload; mobile sign legibility |
| Pine woodlands | (0,+190) | 240 x 135 | harder starter trees, repeatable challenge, NPC camp | Visible escalation without luck-only gate |
| Starter boss clearing | (+95,+205) | 95 x 90 | first boss introduction / milestone | Safe arena and no random combat spillover |
| Portal ridge | (+220,+70) | 120 x 145 | Island 2 portal and future locked expansion pads | Destination preview; unlock status and return routes |
| Coast / scenery | around outer edge | varies | character, landmarks, buffers | No giant dense unoptimized Creator Store models |

**Pathing guidelines (targets to prototype):** spawn-to-first-tree < 10 seconds of normal movement; spawn-to-upgrade within 20 seconds; plaza-to-beginner-grove < 25 seconds; portal-visible-from-plaza; loops return to an obvious landmark. Measure with actual Roblox avatars and device testing. Avoid unavoidable long walks; allow quick return to hub.

### Stations and when to teach them
- **Mandatory at entry:** chop, Logs, first upgrade, a first *free* weapon roll.
- **Progressive discovery:** weapon index, tree mutations, pets/traits, NPC camps, boss. Reveal prompts contextually rather than all in one tutorial queue.
- **Always accessible:** settings and accessibility, travel destinations, return to plaza.
- **No pop-up Robux purchase requirements**, no misleading roll costs, no high-pressure prompts during first quest.

## M2.2 First-session progression test plan

These are *target windows*, not enforced cooldowns, guaranteed outcomes or retention measurements.

| Elapsed time | Desired experience | Key event / observable metric | Fail condition |
| --- | --- | --- | --- |
| 0:00–0:30 | Spawn with a visible tree and active blades | first_tree_chopped | Players wander or cannot chop |
| 0:30–1:30 | Buy impactful first upgrade | first_upgrade | Affordability or UX confusion |
| 1:30–5:00 | Free roll + choose useful weapon | first_weapon_roll, equip | One roll mandatory to pass; false roll costs |
| 5:00–10:00 | See mutation / reveal Pine woodlands milestone | first_mutation_seen, pine_access | Reaching all zones in 4 min without meaningful interaction |
| 10:00–20:00 | Pet / index progress and starter challenge | first_pet / index_reward / boss_visit | Too many panels or dead time |
| 20:00–30:00 | First boss or collection checkpoint, unlock Island 2 | island2_unlocked, portal_used | Long RNG-only power wall or instant paid bypass |
| Return on D1 | New achievable objective and clear saved progress | next_day_return + meaningful milestone | One-time tutorial repeats; rewards disappear |

**Important caveat:** New players can progress quickly; never require 30 minutes of waiting. The proposed time window is a design benchmark for organic play.

### Island 2 unlock *candidate* (not implemented)
Use server-verified **three kinds of achievements** rather than a very rare single roll:
1. Complete a small first-island progression checklist (chop and upgrade; track persistently).
2. Reach a reachable combat/power floor through normal weapon progression **or an alternative deterministic path** (e.g., guaranteed craft or quest reward).
3. Finish a starter challenge / boss or equivalent solo-friendly milestone.

No exact weapon power, Logs price, quest count or boss HP approved. Compute thresholds in the simulator and test solo/free players before selecting. A paid starter pack must not bypass required gameplay comprehension. Previously unlocked old accounts must be migrated/grandfathered carefully.

## M2.3 Economy risks and validation gates

Claude's audit of current implementation reports:
- Starter Grove -> Pine/Crystal gates at 40/250 Power can be reached in ~4 min under the modeled scenario.
- Current Frost gate at 2,000 Power depends heavily on rare rolls; ~70% of modeled free players fail to reach Frost by D7.
- Rolls are **free**; weapon power does not increase from spending Logs on blade upgrades.
- Multiplicative luck stacking leads to excessive paid acceleration.
- Developer-product IDs are all zero, and receipt/data persistence and restricted paid-random-item flows require fixes before commerce activation.

Therefore test the new candidate gate with:
- Free and paid characters at **equal session lengths**, plus short-session and unlucky-roll variants.
- Time to first meaningful purchase, first area completion, Island 2/3 unlock, and stalls >10 minutes without incremental progress.
- Logs source/sink ratio by island and by 1st/7th day; avoid making luck the only way to travel.
- Paid boost impact: convenience is fine, but no island access sold exclusively for Robux.
- Test total-progress distribution across at least 100+ simulation seeds rather than trusting a 25-seed median. Report p10/p50/p90 and variation under low playtime.

## M2.4 Other islands (design interface only)

| Island | Existing area (provisional) | Travel pattern | Content goals |
| --- | --- | --- | --- |
| 1 Timber Haven | Starter Grove + Pine Forest | home spawn, Island 2 portal and return plaza | onboarding, first challenge |
| 2 Crystal Wilds | Crystal Canyon | inbound pad, home portal, Island 3 portal | midgame collections, boss, useful Log sinks |
| 3 Frostbound Reach | Frost Peaks | inbound pad, home portal, future expansion pads | multi-session goals, premium-neutral progression |
| 4+ TBD | New areas | registry-driven portals | add content without migrating older areas repeatedly |

**Island data contract (proposal):** stable IslandId; display name; release state (locked/available/coming soon); mapped legacy area IDs; spawn and return anchors; tree pool; quest/objective set; boss; unlock evaluator; performance budget. Unlocks checked server-side; no automatic grant for clients teleporting into forbidden bounds. Same Roblox place means character re-positioning, not `TeleportService`.

## M2.5 Read-only Studio survey still required (no construction)

Have Claude or Codex, when free, read-only inspect:
- Current island/map bounding boxes, current terrain and region coordinates, spawn(s), shop stations, tree and NPC placement.
- Exact current area IDs, spawn/return paths, current world layout and legacy quests/index references.
- Model/part count and memory heavy imports, streaming settings and mobile behavior.
- Current data schema and migration keys; no saving or writes.
- Exact scripts for area unlock validation and teleport re-entry edge cases.

The measurements should replace **proposed** coordinates above only after inspection; do not claim these are current Roblox world coordinates.

## M2.6 Asset / migration / QA acceptance checks

- Creator Store asset candidates need an asset ID, license/usage check, script audit, part count, performance notes, owner approval prior to import. Previously reported suspicious imported scripts must not be cloned/executed.
- Old players preserve Logs, Souls, weapons, pets, traits, rebirths, indexes, and purchased entitlements.
- Existing zones map to stable legacy area IDs, not blindly renumbered island indexes.
- Round trip portal test: respawn, death near arrival pad, fast repeated interactions, two users simultaneously, network lag, streaming delay, mobile low-memory, boss active, reconnect.
- Rollback: snapshot old place, run changes in a separate development copy only after a separate explicit construction approval.

## M2.7 Decision gate

**Design review required:** approve/revise zone layout, target travel times and milestones; request read-only physical survey and calibrated simulation; then approve a measured technical blockout. **No Studio construction, new assets or code edits authorized by this file.**
