# Tasks

Status: `[ ]` todo · `[~]` in progress · `[x]` done. Owner in brackets.

## Repo sync
- [x] Create the repo skeleton, docs and Rojo project. [Claude]
- [ ] Link GitHub to Claude (claude.ai → Settings → Connectors → GitHub) so Claude can push. [Owner]
- [x] Scripts exported from the backup (branch `p0/script-export`). [Claude]
- [ ] Commit `src/` and verify that `rojo serve` round-trips with no diffs. [Claude]

## Security
- [ ] Delete the unused `ServerStorage.*Imports` and `BoardTemplate` folders, or strip their scripts. They contain suspected backdoor modules (see AI_HANDOFF). Waiting for owner approval. [Claude]

## M2 island plan (from M2_TECHNICAL_VALIDATION.md; construction NOT approved)
- [x] Read-only map survey, island placement proposal, streaming and mobile review, system dependency list, 200-seed island simulation. [Claude]
- [ ] Owner decision: island coordinates (I1 at origin reused, I2 (3000,0,0), I3 (6000,0,0)) and the Island 1 zone mapping. [Owner]
- [ ] Owner decision: candidate gates G2 = 600 trees + Power 60 + Blade King; G3 = 6,000 Island-2 trees + Power 500 + Island-2 boss. [Owner + ChatGPT]
- [x] **P0 VERIFIED COMPLETE**: offline backup, private dev place 103379930563763 (universe 10777797608), verified restore, script export to `p0/script-export` (unmerged); owner still to copy backup to external media. [Claude]
- [~] **P1a ONLY APPROVED 2026-11-18** in private dev place 103379930563763: safe island lookup, test pads at x~3000/6000, in-place TravelService prototype, compatible test save fields and checks. Verify place ID before writes; follow `docs/P1_PROTOTYPE_SCOPE.md`. Implementation NOT yet verified. [Claude]
- [ ] **P1b/P1c NOT AUTHORIZED:** actual Crystal/Frost terrain migration, detailed islands, bosses, economic unlock gates, permanent portal art. [Owner]
- [ ] P2 (after approval): mobile streaming tests against the §4.3 budget; Island 1 trim plan (Pine count, lights, 370-part Frost Mythic). [Claude]

## Economy and monetization (proposals from the audit; not approved or implemented)
- [ ] Fix `ProcessReceipt`: grant only after a confirmed save; move to `UpdateAsync` with a session lock or ProfileStore. [Claude, needs approval]
- [ ] Fill in the developer `ProductId`s after creating the products. [Owner, then Claude]
- [ ] Server-side `ArePaidRandomItemsRestricted` gating for Logs-paid crates and eggs, and for purchased free crates. [Claude, needs approval]
- [ ] Rebalance luck stacking and area gates; plan a 5th area and recurring Logs sinks. [ChatGPT to plan]
- [ ] Correct the weapon odds display (rarest-first cascade); remove or implement Pity; fix the FastRoll auto interval. [Claude, needs approval]

## Owner action items
- [ ] Create the 9 developer products in the Creator Dashboard and send Claude the IDs.
- [ ] Put the 5 game passes on sale and set prices.
- [ ] Enable Studio Access to API Services (Game Settings → Security).

## Backlog (for ChatGPT to prioritise)
- [ ] Daily login streak and rewards.
- [ ] Rotating limited-time events (weekend 2× logs, mutation storms).
- [ ] Rebirth/prestige tier beyond Souls.
- [ ] Trading (pets/weapons) with server-side validation.
- [ ] A new area after the current final zone, with its own tree set and boss.
- [ ] Group-only perks and an update-log board in the hub.

## Island world redesign (architecture approved; construction not authorized)
- [x] Approve single-place Starter Island and teleport-connected future-island architecture. [Owner, 2026-11-18]
- [x] Choose one Roblox place with server-validated in-place teleportation (not `TeleportService` for island travel). [Owner]
- [ ] Map current Starter Grove, Pine Forest, Crystal Canyon, and Frost Peaks into the proposed island structure without losing existing unlocks or saves. [Design review]
- [ ] Link island unlocks and content pacing to the economy/monetization audit, especially early-area burn-through, the Frost power wall, and paid/free parity. [ChatGPT planning]
- [x] Record initial island blueprint and migration/rollback requirements in `docs/ISLAND_BLUEPRINT.md`. [ChatGPT]
- [ ] M2: Read-only Studio inventory and measured island layout/blockout; evaluate streaming, mobile memory and portal anchor placements. [Claude/Codex, owner approval before Studio access]
- [ ] M2: Simulate proposed new unlock goals and costs for free/paid users at equal playtime, including unlucky cases. [ChatGPT/Claude]
- [ ] M2: Create old-area migration matrix, asset manifest and test/rollback checklist. [Design review]
- [ ] Owner to approve M2 technical blueprint and separately authorize a reversible build in a fresh development place. [Owner]
