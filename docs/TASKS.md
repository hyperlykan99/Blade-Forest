# Tasks

Status: `[ ]` todo · `[~]` in progress · `[x]` done. Owner in brackets.

## Repo sync
- [x] Create the repo skeleton, docs and Rojo project. [Claude]
- [ ] Link GitHub to Claude (claude.ai → Settings → Connectors → GitHub) so Claude can push. [Owner]
- [x] Scripts exported from the backup (branch `p0/script-export`). [Claude]
- [ ] Commit `src/` and verify that `rojo serve` round-trips with no diffs. [Claude]

## M0 Foundations (dev v23, branch `m0/foundations`)
- [x] Session-locked persistence, v4 migration plus backup, receipts, paid-random policy, analytics baseline. [Claude]
- [ ] Owner review of `docs/m0/M0_FOUNDATIONS_RESULTS.md`. [Owner]
- [ ] Real cross-server lock test (≥50 cycles on two live servers). [Owner/Claude]
- [ ] Server-side purchase gate before any product goes live. [Claude, after approval]
- [ ] iPhone and two-device validation. [Owner]

## M0.1 Foundations Corrections (dev v29, branch `m0.1/foundations-corrections`)
- [x] H2 serialized writes + write-sequence fence; H3 migration lock leak; H1 movement sanity; M1 AFK handoff; H6 playtime gifts in profile; M5 boss scaling/minimum contribution. [Claude]
- [ ] Owner review of `docs/m0/M01_FOUNDATIONS_CORRECTIONS_RESULTS.md` (incl. the visit cap and the Treant eligibility rule). [Owner]
- [ ] Decide on the pre-existing CurrentIsland/LastIsland join-lag bug (results §5). [Owner]
- [ ] Real two-server validation: lock/fence races, AFK teleport hop, Treant/King with 2+ players. [Owner/Claude]
- [ ] Real receipt test once products exist. [Owner/Claude]

## Security
- [x] Quarantine the malicious scripts in `ServerStorage.*Imports` / `BoardTemplate` (M0-E, dev v23): 37 roots destroyed, 53 disabled, models kept. Manifest in `docs/m0/M0_SECURITY_MANIFEST.tsv`. [Claude]
- [ ] Decide whether to delete the now-inert import folders entirely. [Owner]

## M2 island plan (from M2_TECHNICAL_VALIDATION.md; construction NOT approved)
- [x] Read-only map survey, island placement proposal, streaming and mobile review, system dependency list, 200-seed island simulation. [Claude]
- [ ] Owner decision: island coordinates (I1 at origin reused, I2 (3000,0,0), I3 (6000,0,0)) and the Island 1 zone mapping. [Owner]
- [ ] Owner decision: candidate gates G2 = 600 trees + Power 60 + Blade King; G3 = 6,000 Island-2 trees + Power 500 + Island-2 boss. [Owner + ChatGPT]
- [x] **P0 VERIFIED COMPLETE**: offline backup, private dev place 103379930563763 (universe 10777797608), verified restore, script export to `p0/script-export` (unmerged); owner still to copy backup to external media. [Claude]
- [~] **P1a ONLY APPROVED 2026-11-18** in private dev place 103379930563763: safe island lookup, test pads at x~3000/6000, in-place TravelService prototype, compatible test save fields and checks. Verify place ID before writes; follow `docs/P1_PROTOTYPE_SCOPE.md`. Implementation NOT yet verified. [Claude]
- [x] **P1b.2 Crystal Wilds construction** — built in dev v12, single-client tested ([Claude], 2026-11-19). See `P1B_MIGRATION_BLUEPRINT.md` §12.
- [x] **P1b.2r dense-forest redistribution (Option A)**: dev v15, single-client tested ([Claude], 2026-11-19). See `docs/p1b2r/P1B2R_RESULTS.md` on `p1b2r/dense-forest`.
- [x] **P1b.2r camera visibility fix (Option C on Option A)**: dev v18, one Studio client, C1–C9 passed ([Claude], 2026-11-19). See `docs/p1b2r_camera/CAMERA_FIX_RESULTS.md` on `p1b2r/camera-visibility-fix`.
- [ ] **Owner review of P1b.2r + camera fix**: review v18 visuals, ~4x Crystal Wilds income, merge `p1b2r/dense-forest` and `p1b2r/camera-visibility-fix`; iPhone and two-player still unverified. [Owner]
- [ ] **Owner review of P1b.2**: effects drift on respawn (B1 glow cap?), shared Golden Slime cap, altar N/A, merge `p1b2/crystal-wilds`. [Owner]
- [ ] Private dev publish of v12 for an iPhone check (needs separate approval). Two-player test still unverified. [Owner]
- [ ] **P1b.3 / P1b.4 / P1c NOT AUTHORIZED:** actual Crystal/Frost terrain migration, detailed islands, bosses, economic unlock gates, permanent portal art. [Owner]
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
