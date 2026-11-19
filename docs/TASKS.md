# Tasks

Status: `[ ]` todo · `[~]` in progress · `[x]` done. Owner in brackets.

## Repo sync
- [x] Create the repo skeleton, docs and Rojo project. [Claude]
- [ ] Link GitHub to Claude (claude.ai → Settings → Connectors → GitHub) so Claude can push. [Owner]
- [ ] Save the place locally as `BladeForest.rbxl`, then run `rojo syncback --input BladeForest.rbxl` to fill `src/`. [Owner or Claude, once a local folder is connected]
- [ ] Commit `src/` and verify that `rojo serve` round-trips with no diffs. [Claude]

## Security
- [ ] Delete the unused `ServerStorage.*Imports` and `BoardTemplate` folders, or strip their scripts. They contain suspected backdoor modules (see AI_HANDOFF). Waiting for owner approval. [Claude]

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

## Proposed island map redesign (design only; no Studio changes approved)
- [ ] Design a Starter Island and teleport-based progression to other islands; future updates add more islands. [ChatGPT planning / Owner review]
- [ ] Decide same-place island travel versus multi-place `TeleportService` travel after evaluating load times, mobile performance, shared bosses, and persistence. [Design review]
- [ ] Map current Starter Grove, Pine Forest, Crystal Canyon, and Frost Peaks into the proposed island structure without losing existing unlocks or saves. [Design review]
- [ ] Link island unlocks and content pacing to the economy/monetization audit, especially early-area burn-through, the Frost power wall, and paid/free parity. [ChatGPT planning]
- [ ] Produce island blueprint, future-island template, migration/rollback plan, and playtest checklist **before requesting any construction**. [Owner approval required]
