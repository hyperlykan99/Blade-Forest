# M6 — Deep Progression and Endgame

| Record | Value |
| --- | --- |
| Private development | Place `103379930563763`, universe `10777797608` |
| M5 gameplay baseline | `baa5ba0cc109f88456889259308be6936e9226aa`, cloud update `2026-11-21T03:15:54.138Z`. Numeric M5 version unverified. |
| M6 implementation | `47fcd18b689cf7590d923e8dff8d37dcbb62b27a` on `m6/forging-runes-raids-endgame` |
| M6 cloud save | **v60**, Studio Team Create save receipt, cloud timestamp `2026-11-21T04:41:09.178Z` |
| M6 rollback | Private cloud checkpoint timestamp `2026-11-21T04:32:07.577Z`. `ServerStorage.M6Rollback` holds 14 inert source copies with original paths and classes. |
| World and editor | Timber Haven, Crystal Wilds and Frostbound Reach retain the M4 v2 layout. Studio is in Edit mode and the AI editor is released. |

The installed M6 work covers Forge, three Awakening stages, 20 runes, three world raids, the Heart of Winter and extensions to Trials and Expeditions. The gameplay implementation commit is stored on the private place as `Workspace.M6DevBuild`. Its 17 scripts matched Git by checksum. The smoke checks below record the verified behavior and remaining play checks.

## Forge, materials and weapon commissions

Forge interactions work from the Forge Workshop in Crafters’ Plaza and Forge Annex in Frostgate Outpost. The HUD entry shows discovered and locked recipes, eligibility, balances, costs, output, and selection previews. The server checks the character is alive, on the current island, near the counter, outside isolated activities, and owns all ingredients. Successful operations update the player’s existing locked profile in a single non-yielding section. Request revisions, an in-flight guard, and server throttling protect retries. A repeat commission for an owned weapon leaves all ingredients in inventory. Salvage accepts 1–10 eligible spare copies per request and up to 48 per UTC day. Favorites, exclusive weapons and the representative cannot be salvaged. The material grant per copy is 1–4 based on rarity, plus 3–24 existing Altar Essence.

| Commission | Unlock | Existing output | Costs |
| --- | --- | --- | --- |
| Hearthsteel | Timber, Mastery 8 | Furnacecore Longsword | 42 Bark, 650 Altar Essence, 120 Souls |
| Prismatic | Crystal, Mastery 19 | Prism Saber | 30 Bark, 60 Crystal Shards, 2,400 Essence, 280 Souls |
| Glacier | Frostbound, Mastery 30 | Frostspire Greatsword | 45 Crystal Shards, 65 Frost Cores, 2 Expedition Cores, 5,200 Essence, 520 Souls |
| Aurora | Frostbound, Mastery 50 | Aurora Cleaver | 55 Crystal Shards, 100 Frost Cores, 14 Expedition Cores, 25,000 Essence, 1,800 Souls |
| Sovereign | Frostbound, Mastery 70 | Hearthforge Sovereign | 160 Bark, 80 Crystal Shards, 80 Frost Cores, 3 Trial Seals, 100,000 Essence, 2,600 Souls |
| Radiance | Frostbound, Mastery 85 | Prismheart Radiance | 160 Crystal Shards, 95 Frost Cores, 24 Expedition Cores, 5 Trial Seals, 100,000 Essence, 3,400 Souls |
| Winter Key | Frostbound, Mastery 1 | One Winter Key | One Bark Sigil, one Crystal Sigil and one Frost Sigil |
| Bronze Trial | Timber, best score 4 | Ashbark Knightblade | 45 Trial Tokens |
| Silver Trial | Crystal, best score 8 | Canyon Sickle | 85 Trial Tokens, 1 Trial Seal |
| Gold Trial | Frostbound, best score 13 | Iceveil | 140 Trial Tokens, 2 Trial Seals |

Each island grants one local material per 12 credited chops, up to 80 per island per UTC day. Progression bosses retain their existing sigil sources. M6 raids also grant their regional sigil. Expedition Cores and Trial Seals use the established M5 IDs and ledgers. The Trial shop still exchanges 18 Tokens for a Seal under its weekly limit. Existing Altar Essence sources stay available to Forge customers.

## Awakening and runes

An owned five-star weapon with an eligible catalog entry advances one stage at a time. Current catalog eligibility starts at Epic rarity. Each stage unlocks one rune socket. The equipped weapon's total Power multipliers are applied once.

| Stage | Power | Island required | Costs | Equipped appearance |
| --- | ---: | --- | --- | --- |
| I | ×1.2 | Timber | 35 Bark, 15 Crystal Shards, 1,500 Essence, 175 Souls | Edge aura |
| II | ×1.4 | Crystal | 40 Crystal Shards, 25 Frost Cores, 4,500 Essence, 450 Souls | Enhanced trail and ring |
| III | ×1.6 | Frostbound | 55 Frost Cores, 8 Expedition Cores, 10,000 Essence, 950 Souls | Two rings and animated aura |

| Rune | Channel | Etched | Refined | Radiant | Ancient | Raw cap per equipped weapon |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Harvest | Logs | 3.5% | 6.5% | 10% | 15% | 30% |
| Edge | Tree damage | 2.5% | 4.5% | 7.5% | 11% | 22% |
| Spirit | Combat Souls | 2.5% | 4.5% | 7.5% | 11% | 22% |
| Fortune | Permanent Luck | 4% | 7.5% | 11% | 16% | 32% |
| Mutation | Mutated-tree Logs | 4.5% | 8% | 12.5% | 18% | 36% |

Etched crafting costs 8 Bark and 85 Souls. Refined costs 12 Crystal Shards and 175 Souls. Radiant costs 20 Frost Cores and 350 Souls. Ancient costs 30 Frost Cores, 5 Expedition Cores and 725 Souls. Refined and above consume three loose runes of the previous rarity and same type. Reroll consumes a loose rune and grants one of the other four types at the same rarity. Its costs are 30/60/120/240 Souls and a third of the crafting materials rounded up. Existing paid-random eligibility applies to rerolls that spend Souls. Socket replacement returns the displaced rune to inventory, and unequipping changes the active bonuses without changing ownership. The bonuses join the existing M1/M3 channels and their soft and hard limits. Mutation contributes only on mutated trees. Gallery previews and Power sorting include Awakening and the acquisition metadata lists the alternate routes.

## World raids

A UTC 20-minute slot rotates Ancient Treant, Crystal Hydra and Frost Giant. The first seven minutes are the spawn window. The boss appears when eligible players approach the arena. Initial HP scales by 34% per additional nearby eligible player, up to seven additions. Attacks, participation and timers are server-owned.

| Raid | Power gate / solo HP | Arena | Attacks | First eligible reward |
| --- | --- | --- | --- | --- |
| Ancient Treant | 40 / 55,000 | Timber `(-286, 0, -3078)` | Targeted root eruption and scattered root circles | Wildfire Greatsword |
| Crystal Hydra | 250 / 245,000 | Crystal annex `(3124, 0, -350)`, across the bridge from the Colossus arena | Rotating three-lane blasts | Skyshard Aegisblade |
| Frost Giant | 2,000 / 1,350,000 | Frostbound `(6072, 0, 219)` | Broad ice impacts on the target and arena centre | Glacial Splitter |

Existing server blade overlaps, movement sanity and hit cooldown determine damage. Reward eligibility uses at least 2% damage or 12 hits, recent participation and the current encounter or island. The persistent ledger limits each raid slot to one paid clear per player and three paid raid clears per UTC day. An eligible paid raid credits 0.62 M1 Price Units in Logs, 48–64 base Souls, 640 Mastery XP, 10–15 regional materials, a regional Sigil, and an Etched rune in Timber or Refined rune in Crystal or Frostbound. Damage share affects Souls and material amounts. The three progression bosses retain their own scripts and credits.

## Heart of Winter

The M4 Winter Key Threshold opens an eight-second local gathering window for up to four eligible players, including solo. Entry requires Frostbound unlocked, 2,000 Power, a Winter Key, and standing at the sanctum out of travel or active combat restrictions. The encounter streams a leased arena and runs for up to nine minutes after gathering. It has 1,750,000 solo HP, plus 48% per additional fighter. The battlefield and boss use original procedural Studio geometry.

- Phase I has delayed frost strikes on player positions and the centre.
- At 67% HP, Phase II shields the Heart until players break three Winter Seals. Rotating ice lanes add movement pressure.
- At 31% HP, Phase III moves the Heart around the ring and adds four faster, harder-hitting lanes.
- An eligible paid victory spends one Winter Key. Disconnect, death, timeout and retreat preserve the key. Attempt membership and health expire with the server encounter. Rejoining loads the last authoritative island and retains the unspent key. A successful clear displays Victory and returns survivors to Frostbound through the existing travel path.
- The first eligible clear each UTC week pays 1.75 M1 Price Units in Logs, 100–116 base Souls, 1,400 Mastery XP, 24–29 Frost Cores and one Ancient rune. It grants the existing Eternal Winter weapon once if unowned.
- Other paid clears grant 0.48 Price Units, 35–51 base Souls, 500 Mastery XP, 7–12 Frost Cores and a Radiant rune. The daily budget is three paid clears. The weekly reward is honored if a new UTC week opens after the daily budget was already used.
- M0/M0.1 profile sessions serialize reward writes. Week and reward are in the same profile update. The final encounter retains a local gathering flow for future party integration.

## Catalog and saves

All 120 permanent IDs remain unchanged. This milestone adds 13 alternate acquisition routes on existing IDs, including the three Trial commissions. Ownership, Stars, Shiny, favorites, original acquisition history, Gallery entries, Altar rolls and Divine Attunement retain their original IDs and representation. The Trial best value seeds from the existing weekly best if available. Completed M5 depths retain existing records and rewards. A paid weekly-frontier clear every third depth adds a rune, at Refined from depth 3, Radiant from 9 and Ancient from 15. From depth 8, the first tree in the wave is tougher. The existing six-per-day Expedition payout budget applies.

The profile uses additive `M6.Schema=1` and the reserved `WeaponItems` map inside the current v4 profile. The first awakening creates one stable GUID for the stack representative. Item records hold the weapon ID, stage, string-keyed sockets and bound/trade-locked flags. The original stack owns counts, Stars, Shiny and acquisition history. Salvage reduces spare copies only. No live profiles were rewritten for migration or testing. New source routes, wallets, day limits, weekly credit and the new Trial best are in the same existing serialized profile. A source rollback should retain these keys and use the source checkpoint.

The six-tab Workshop UI has Forge, Salvage, Awaken, Runes, Raids and Trials. It uses the existing HUD, scrollable panel, recipe previews, material and rune counts, selected weapon and sockets, and result notifications. Raid timers and boss health use the status rail and the encounter UI. Forge success animates local VFX. Awakening and forge effects use the existing motion and graphics preferences. No external asset IDs or paid products were added.

## Economy projection

Reproduce with `python3 tools/econsim/m6sim.py --output tools/econsim/results/m6/M6_ISSUANCE_200H.json`. The 200-play-hour model adds M6 to M5's median-anchored M1/M2 economy. It uses four hours/day for active play and eight for AFK, with one assumed successful raid per active day solo or two cooperatively. The co-op player contributes 38%. Timing depends on assumed Mastery and five-star availability. The model compares fixed-price issuance and time displaced from chopping. Rune uplift is a sensitivity, based on 7% effective extra Logs on 35% of baseline income.

| Scenario | First Forge / first crafted rune | Awakening I/II/III | First Winter Key | Natural and crafted runes | Net Logs vs M5 / with rune sensitivity |
| --- | --- | --- | --- | ---: | ---: |
| Free active solo | 4h / 8h | 28h / 32h / 68h | 24h | 81 | −3.30% / −0.85% |
| Free active co-op | 4h / 8h | 28h / 36h / 56h | 24h | 131 | −4.44% / −1.99% |
| Paid active solo | 4h / 8h | 24h / 28h / 64h | 24h | 82 | −3.90% / −1.45% |
| Free and paid unattended AFK | — | — | — | 0 | 0% / 0% |

The model projects about 14,000 combined Bark, Crystal Shards and Frost Cores for a free active solo player, against 575 spent by the modeled forge/awakening purchase plan. Most of the late-game spending is concentrated in existing Essence and Souls. The free solo plan spent 49,250 Essence and 4,380 Souls. It reached four of the six weapon commissions by 200h. The paid solo estimate reached five. AFK retains tree earnings and earned 2,000 local materials in the assumed fixed late-game route. The high material surplus, active Logs opportunity cost and Divine commission Essence bottleneck are open balance issues. The JSON includes source and sink totals, modeled raid and Heart clears, and affordability by commission. The projection cannot establish actual time to full collection or win probability.

## Validation and outstanding work

- Studio compiled and then read back all 17 changed sources against the local checksums. The private place identity and Edit mode were checked again immediately before the save. The M4 v2 switch was verified during the play smoke.
- A detached synthetic v4 profile survived JSON round-trips with purchase receipt, existing Trial Tokens and score, stable awakened GUID, three stages, Stars, Shiny, acquisition count and sockets intact. Favorite salvage was refused, spare salvage reduced the exact quantity, insufficient Sigils were rejected, paid Trial commission replay preserved Tokens, and a socketed rune could be returned and rerolled without duplicating it. All 120 weapon IDs and 13 new routes resolved.
- Studio Play registered both Forge prompts, the Winter Key Threshold and Hydra annex. The Forge HUD tile opened the panel with eight content rows. Forge read succeeded and a crafting request away from a workshop was refused. The server/client log samples showed no errors during these probes. The 20-minute rotation, seven-minute window and bounded boss Souls math were checked with fixture calls.
- A complete raid or Heart victory, player combat balance, long-session reward behavior, cross-server weekly payout reload, and multiplayer/mobile layout remain unverified. The test used a single Studio client, and used detached data for inventory requests. Numeric M5 version and the numeric rollback checkpoint version remain unverified.
- Recovery uses the timestamped private checkpoint or the source copies. To revert source only, restore the changed files by `OriginalPath` from `ServerStorage.M6Rollback`, remove the seven new M6 scripts from the active tree, and resume the M5 implementation. Keep the inert checkpoint and saved profile fields.
