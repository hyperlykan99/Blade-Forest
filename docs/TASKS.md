# Tasks

Status: `[ ]` todo · `[~]` in progress · `[x]` done. Owner in brackets.

## Repo sync
- [x] Create the repo skeleton, docs and Rojo project. [Claude]
- [ ] Link GitHub to Claude (claude.ai → Settings → Connectors → GitHub) so Claude can push. [Owner]
- [ ] Save the place locally as `BladeForest.rbxl`, then run `rojo syncback --input BladeForest.rbxl` to fill `src/`. [Owner or Claude, once a local folder is connected]
- [ ] Commit `src/` and verify that `rojo serve` round-trips with no diffs. [Claude]

## Security
- [ ] Delete the unused `ServerStorage.*Imports` and `BoardTemplate` folders, or strip their scripts. They contain suspected backdoor modules (see AI_HANDOFF). Waiting for owner approval. [Claude]

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
