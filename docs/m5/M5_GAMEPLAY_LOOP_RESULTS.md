# M5 Gameplay Loop Results

M5 implements the island quest chains, selectable Contracts, solo Chopping Trials, playable Endless Expeditions, and the regional forest events on the private v2 development world.

| Item | Recorded state |
| --- | --- |
| Private place | Blade Forest - Island Dev · PlaceId `103379930563763` · UniverseId `10777797608` |
| Saved build | Team Create reports no unsaved changes. Open Cloud update `2026-11-21T03:15:54.138Z` (Nov 20, 19:15:54 PST). The numeric M5 save version is unverified. No numbered receipt was returned, and the Studio Version History UI timed out. |
| Base | M4 gameplay `2f50bfbf340b8cd104a083f6c7db308da526158a`, plus its handoff. The v52 cloud timestamp was `2026-11-21T02:47:44.314Z`. |
| Source | [`baa5ba0cc109f88456889259308be6936e9226aa`](https://github.com/hyperlykan99/Blade-Forest/commit/baa5ba0cc109f88456889259308be6936e9226aa) includes the final Studio sources on `m5/contracts-trials-expeditions-events`. |
| Rollback | `ServerStorage.M5Rollback` contains 10 checksum-verified pre-M5 source copies. The checkpoint cloud timestamp is `2026-11-21T02:53:37.982Z`. The last numbered pre-M5 baseline is v52. |
| Editor | Released in Roblox Studio Edit mode. |

## Island quests

Steps are ordered within each island. Existing tree counts, mutation finds, weapon Power, traits, pet ownership, boss credits and island unlocks count where the objective permits. Visits and landmarks are recorded from real server-confirmed movement. Quests are claimed once. Step rewards are `0.18 + 0.055 × step` M1 Price Units, `3 + step` Souls, and `25 + 12 × step` Mastery XP, using central bounded reward logic.

| Island | Step | Quest | Requirement |
| --- | ---: | --- | --- |
| Timber Haven | 1 | Welcome to Haven | Arrive in Timber Haven |
| Timber Haven | 2 | First timber | Chop 12 Timber Haven trees |
| Timber Haven | 3 | Learn the grove | Discover 3 Starter Grove tree types |
| Timber Haven | 4 | A sharper edge | Own a weapon with at least 40 Power |
| Timber Haven | 5 | Down the forest trail | Visit Pinewood Hollow |
| Timber Haven | 6 | A companion joins | Own a pet |
| Timber Haven | 7 | A mark of your own | Equip a primary trait |
| Timber Haven | 8 | The hollow harvest | Chop 250 Timber Haven trees |
| Timber Haven | 9 | Kingsfall champion | Defeat Blade King with eligible participation |
| Timber Haven | 10 | Beyond the cliffs | Unlock Crystal Wilds |
| Crystal Wilds | 1 | Through the crystal gate | Arrive in Crystal Wilds |
| Crystal Wilds | 2 | Crystalwood | Chop 100 Crystal Wilds trees |
| Crystal Wilds | 3 | Canyon survey | Discover 4 Crystal Canyon tree types |
| Crystal Wilds | 4 | The wilds lookout | Visit the Crystal Wilds plaza |
| Crystal Wilds | 5 | Light in the canopy | Chop 5 mutated trees anywhere |
| Crystal Wilds | 6 | Crystal companion | Own a Crystal Wilds pet |
| Crystal Wilds | 7 | A thousand edges | Own a weapon with at least 1,000 Power |
| Crystal Wilds | 8 | The Colossus trial | Defeat Crystal Colossus with eligible participation |
| Crystal Wilds | 9 | Crystal quartermaster | Chop 3,000 Crystal trees |
| Crystal Wilds | 10 | Open Frostgate | Unlock Frostbound Reach |
| Frostbound Reach | 1 | Beyond Frostgate | Arrive in Frostbound Reach |
| Frostbound Reach | 2 | Winter timber | Chop 100 Frost trees |
| Frostbound Reach | 3 | Through the flurries | Visit Aurora Basin |
| Frostbound Reach | 4 | The frost field guide | Discover 4 Frost Peaks tree types |
| Frostbound Reach | 5 | Twin marks | Equip different traits in both slots |
| Frostbound Reach | 6 | Winter companion | Own a Frostbound Reach pet |
| Frostbound Reach | 7 | Beneath the ice | Finish expedition depth 2 in any week |
| Frostbound Reach | 8 | The crown breaks | Defeat Frost Monarch with eligible participation |
| Frostbound Reach | 9 | The winter harvest | Chop 1,800 Frost trees |
| Frostbound Reach | 10 | Master of the Reach | Discover all 7 Frost Peaks tree types |

## Contracts

Each UTC day offers **five**, with up to **three** selected. Each UTC Monday week offers **four**, with up to **two** selected. The offer list is deterministic per player and period. Selection captures the objective starting total and freezes the island tier and M1 price unit for the period. Earned progress stays on the profile and completion is server-checked from cumulative gameplay counters. Past-period and duplicate claims are rejected. Route objectives require two unlocked islands and use per-island arrival credit spaced at least four minutes apart.

Claim all three daily selections to advance the daily streak and earn an extra **0.35 Price Units** once per day. Missing a day breaks the streak. Mastery **15** unlocks one daily reroll. Mastery **30** unlocks one weekly reroll. A reroll replaces only an unselected offer. Existing fixed quests and historical claims remain available alongside Contracts.

Goals are shown for the Timber / Crystal / Frost island tiers. Each Logs value is a multiplier of the frozen M1 Price Unit.

| Period | Objective | Trigger | Tier goals | Logs units | Souls |
| --- | --- | --- | --- | ---: | ---: |
| Daily | Timber work | Trees · current island | 45 / 75 / 95 | 0.43 | 4 |
| Daily | Home grove | Trees · TimberHaven island | 35 / 75 / 120 | 0.36 | 3 |
| Daily | Altar practice | Rolls | 50 / 85 / 120 | 0.4 | 4 |
| Daily | Forest effort | Chops | 65 / 95 / 125 | 0.48 | 4 |
| Daily | Companion care | Pets | 1 / 1 / 2 | 0.36 | 4 |
| Daily | Explore the routes | Visits | 1 / 2 / 2 | 0.28 | 3 |
| Daily | The long trail | Chops | 100 / 150 / 200 | 0.6 | 6 |
| Daily | Boss challenger | Bosses | 1 / 1 / 1 | 0.57 | 8 |
| Daily | Timed harvest | TrialFinishes | 1 / 1 / 1 | 0.32 | 4 |
| Weekly | Weekly timber | Trees · current island | 420 / 650 / 850 | 1.25 | 14 |
| Weekly | Altar circuit | Rolls | 380 / 700 / 1000 | 1.15 | 14 |
| Weekly | Island champions | Bosses | 3 / 4 / 5 | 1.5 | 22 |
| Weekly | Forest sweep | Chops | 650 / 975 / 1350 | 1.45 | 18 |
| Weekly | Companion keeper | Pets | 5 / 7 / 9 | 1.05 | 12 |
| Weekly | Island routes | Visits | 5 / 8 / 10 | 0.88 | 11 |
| Weekly | Trial practice | TrialFinishes | 3 / 4 / 5 | 1.05 | 13 |

## Chopping Trials

Trials reserve a separate **108 × 108 stud** solo arena. Arena centers are 170 studs apart. A run starts the authoritative 60-second timer after admission, streaming and landing. It standardizes walk speed to 18 studs/s, two blades, 4.6 spin speed, 4 damage, 6.5 reach and 4.2 blade length. Timber / Crystal / Frost trial trees have 4 / 6 / 8 HP. A tree is worth one point and respawns after 1.6 seconds. The existing blade orbit, hitbox, hit cooldown and movement checks still determine the hit. The arena lease, target ownership and deadline are validated on the server. Auto Chop and AFK hopping are disabled while an activity is active.

| Rank | Timber | Crystal | Frost | Tokens |
| --- | ---: | ---: | ---: | ---: |
| Bronze | 4 | 4 | 4 | 2 |
| Silver | 8 | 8 | 7 | 4 |
| Gold | 13 | 12 | 11 | 6 |
| Platinum | 19 | 17 | 16 | 9 |
| Diamond | 26 | 23 | 21 | 12 |

Ranked finishes pay up to **24 Tokens per UTC day**. Early exit or death forfeits the unfinished Trial. The weekly best and leaderboard reset on Monday UTC. Each weekly reward shop line can be used twice. A Timber Cache costs 12 Tokens for 0.5 Price Units, a Soul Cache costs 14 for 15 Souls, and a Trial Seal costs 18 for one reserve crafting material. The three Trial weapon rewards are an outstanding catalog allocation. The existing **120 weapon IDs** remain intact.

## Endless Expeditions

Enter at Frostbound's physical gate at **(6270, 0, 52)**. The server checks the island, gate radius, progress, player state and Power. Runs start solo at depth 1, using the existing Frost tree families and server blade combat. The party interface advertises capacity one for M7 extension. Depths contain four to twelve trees. Tree health starts at 23,000, grows 11.5% per depth through depth 121, then continues on a slower linear curve to limit exponential growth.

The lifecycle is **loading → active depth → depth clear → descend or exit**. Death, disconnect, expiry at 15 minutes and voluntary exit clean up the leased arena. Leaving a run preserves its last completed depth and rewarded frontier. A reconnect recovers to the normal saved island. Arena coordinates are never written into the travel record. Only a new weekly personal depth can reward, up to **six depth awards per UTC day**. Depths cleared after the cap still count for ranking. Replaying an already-cleared depth in that week stays ineligible for another reward.

| Reward | Rule for eligible depth `d` |
| --- | --- |
| Logs | `0.22 + 0.035 × min(d, 18)` M1 Price Units |
| Souls | `6 + min(d, 18)` |
| Mastery XP | `55 + 5 × min(d, 30)` |
| Material | One `ExpeditionFrostCore`, with one additional Core every fifth depth |

Both leaderboards use week-scoped OrderedDataStores with a server-local fallback. A best value is submitted globally following a confirmed profile save, and existing bests loaded on join can repair a failed leaderboard write. The profile retains an all-time depth and weekly Trials / depth bests.

## Forest events

The regional cycle uses UTC epoch-aligned 20-minute slots. The listed event begins two minutes into its slot. The remainder is cooldown. Meteor Grove rotates through the three forest islands. Existing global events keep their original schedule and UI visibility.

| Regional event | Location | Duration | Cooldown within slot | Logs | Luck |
| --- | --- | ---: | ---: | ---: | ---: |
| Crystal Bloom | Crystal Wilds | 7 min | 13 min | ×1.25 | ×1.45 |
| Blizzard | Frostbound Reach | 6 min | 14 min | ×1.42 | ×1.10 |
| Meteor Grove | Rotating Timber / Crystal / Frost | 5 min | 15 min | ×1.35 | ×1.55 |

Bonuses apply only in the affected island outside runs. Each channel chooses the stronger eligible regional or global boost, then uses the existing M1 temporary-pool caps and boost checks. Local tints and one bounded emitter clean up automatically. Performance preferences control particles. The server records regional tree participation and sends the existing analytics integration a per-player event total at closing. Events reuse tree positions and Forest Renewal.

## UI and persistence

The Adventures tile opens Story, Contracts, Trials, Expeditions and Events on a single theme panel. It includes objective state, reward previews, rank and shop information, weekly boards, gate guidance, and cooldowns. The existing status rail gets one contextual countdown chip. Layouts use width-relative controls and scroll regions. Physical Expedition entry attaches to the staged Frostbound gate on server startup. No imported asset scripts or commerce products were added.

A single additive `M5` profile structure stores story claims, historical visits, selected contracts and their starting counters, streak, Tokens, materials, weekly bests and the daily payout ledger. M0 locking and the serialized ProfileWriter are unchanged. No active run is serialized. A reward and its claim ledger are mutated together before a normal profile sync. M5 currency amounts pass through `Economy.M5Reward` with bounded transaction and source limits.

## Economy projection

The existing M1 simulator was rerun in paired M4/M5 arms for **72 played hours**, with two seeded agents per arm in each scenario. Both arms use v2 forest density and the M4 boss gate. The model assumes four played hours per calendar day for active players and eight for AFK players. The active arm attempts two Trials daily and Expeditions after Frostbound unlock. The model charges the corresponding forest chopping time. It uses approximate boss participation, contract completion, and Story milestones.

The 72-hour M5 values below are medians. Logged Trial and Expedition amounts are **net of estimated displaced chopping**. All Logs entries use billions.

| Scenario | M4 total | M5 total | Contract Logs | Trial net | Expedition net | Event Logs | M5 Souls | Tokens earned | Best depth |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| free active | 460.59 | 362.02 | 2.20 | -2.15 | -3.29 | 10.24 | 707.5 | 212 | 3.5 |
| free afk | 216.05 | 330.79 | 0.42 | 0.00 | 0.00 | 11.87 | 311 | 0 | 0 |
| paid active | 1954.82 | 1578.20 | 2.62 | -11.88 | -24.92 | 53.26 | 740.5 | 214 | 5 |
| paid afk | 1390.92 | 1892.21 | 0.54 | 0.00 | 0.00 | 69.25 | 320 | 0 | 0 |

The small paired sample varies substantially once weapon rolls and rebirth timing feed back into income. In that sample, free active / paid active reached Frostbound at about **1.74 / 1.60 h**, with median end Power **3,281 / 5,888**. Free AFK / paid AFK reached Frostbound at about **10.39 / 8.12 h**, with end Power **4,972 / 9,624**. The active scenarios earned more direct M5 Souls, Tokens and materials. In two scenarios the simulated AFK Logs advantage increased. These are signals to validate with a larger cohort.

For a **200-hour issuance estimate**, a separate projection holds weapon progression to the checked-in M2 medians and overlays M5 source and opportunity-cost assumptions. Its net Logs uplift is **+3.03% free active**, **+4.09% free AFK**, **+1.99% paid active**, and **+3.90% paid AFK**. The regional schedule adds about **2%** to time-weighted raw temporary Luck exposure before individual boost overrides. Treat this as an issuance estimate. Market inflation and replicated long-run progression need live data.

Hard recurring limits include **2.00 Price Units/day** from daily Contracts with streak, **2.95 Units/week** from weekly Contracts, **1.00 Unit/week** from the Trial Logs shop line, and **at most 5.10 Units/day** from rewarded expedition depths. Story rewards are one-time. Each item still uses its bounded M1 Price Unit and channel.

[Paired 72-hour output](../../tools/econsim/results/m5/M5_PAIRED_72H.json) · [Anchored 200-hour output](../../tools/econsim/results/m5/M5_ISSUANCE_200H.json) · [Simulation runner](../../tools/econsim/m5sim.py)

## Validation and outstanding work

- Compiled all **20** changed and new Luau files and matched final Studio source digests to Git. The v2 package and the existing Crystal camera script were verified. The camera source digest remained `27331:1017905967`.
- Used the real profile builder with a detached v4 fixture. The JSON round trip preserved existing purchases, weapon and pet inventory, Mastery, boss credit and attunement, and retained new Contract, quest, Token, shop and depth fields.
- Fixtures verified 30 chain definitions, five daily/four weekly offers, three/two selections, Mastery reroll, UTC rollover, daily streak, bounded payouts, and duplicate claim rejection. Separate payout fixtures verified Trial replay protection, the daily Token cap, the six expedition awards per day, and personal depth retention after the cap.
- In one private Studio client, opened the Adventures dock tile and five-offer Contracts panel. The server refused an out-of-period claim, a forged Trial score and premature descent. A Trial started with the 60-second timer and fixed 18-stud/s walk speed. An ordinary blade hit scored a tree. Exiting cleaned up the arena and returned to the original Crystal arrival.
- The physical Frostbound prompt entered a depth-one arena containing four trees and returned to Frostbound on exit. The fixture account already had Frostbound unlocked and temporarily received a runtime Power adjustment to exercise the existing entry check. Its original Power and Crystal arrival were restored. The server reported zero leased arenas after return.
- The weekly Trial board read succeeded against the global store and returned an empty ranking. Regional schedule fixtures covered all three event IDs, and the live server exposed the next event. Studio produced early startup wait warnings and Roblox CoreGui video-module errors. The feature remotes, profile and UI subsequently loaded. The final client bounds its Adventures startup wait to 30 seconds.
- Positive live 60-second payout, complete-depth reward writes, reconnect persistence, real cross-server ranking writes, multi-client slot isolation, live event telemetry delivery and mobile performance remain unverified. Trial weapons remain a future allocation decision within the 120-ID catalog.

Rollback the private world to v52 through Version History for an exact M4 place restore. For a source rollback, restore the 10 checkpointed scripts and remove the M5-only source instances from the implementation commit. Preserve accumulated profile data during a rollback.
