# M8 — Seasons, collection and final content

| Record | Value |
| --- | --- |
| Branch | `m8/seasons-collection-final-content` |
| Implementation | `2d719aa97093481a719c23f1c625811132b830f9` |
| Baseline | M7 `34ef2e9a101b3a3c8ed40f24c04c5f48666f4c11`, cloud update `2026-11-21T23:19:38.431Z`, numeric version unverified |
| Private development | Place `103379930563763`, universe `10777797608`, M4 v2 world |
| Saved M8 | **v69**, confirmed Team Create receipt. Open Cloud update `2026-11-21T23:37:41.438Z`. |
| Rollback | Cloud checkpoint `2026-11-21T23:25:31.493Z`, numeric version unverified. The final place also keeps 13 inert M7 source copies in `ServerStorage.M8Rollback`, with original paths and classes. |
| Editor | Released in Edit mode |

## First season

**The Verdant Oath** runs from **2026-11-22 00:00 UTC** through **2027-01-17 00:00 UTC**. Claims close **2027-01-24 00:00 UTC**. The season has a forest restoration and warden theme, with 12 free levels and 500 XP per level. Opening the journal shows the current phase, countdown and exact earned rewards. After the season, level, challenge and claim records stay in history and earned titles and auras stay in the existing M7 collection.

| Source | Season XP | Daily source cap |
| --- | ---: | ---: |
| Credited tree chops | 3 per 10 | 51 |
| Daily Contract claim | 55 | 165 |
| Weekly Contract claim | 160 | 320 |
| Ranked Trial completion | 45 | 90 |
| Credited boss victory | 40 | 80 |
| Rewarded Expedition frontier depth | 30 | 90 |

Weekly challenge progress resets at the season-relative UTC week boundary. Eligible unclaimed challenge rewards can be collected through grace. Each week offers 220 chops for 145 XP, five claimed Contracts for 225 XP, two ranked Trials for 170 XP, and one boss credit for 120 XP. Lanterns in the Leaves offers 250 XP for 400 chops in weeks 2–3. Call of the Wardens offers 350 XP for six Contracts in weeks 6–7. Existing forest event scheduling remains in place. M8 adds configurable limited-time challenge windows above the existing activities.

| Level | Free reward |
| ---: | --- |
| 1 | 20 Essence, 40 Mastery XP |
| 2 | 0.25 Logs price units, 8 Souls, 65 Mastery XP |
| 3 | Grove Scout title |
| 4 | 40 Essence, 100 Mastery XP |
| 5 | 0.45 Logs price units, 14 Souls, 130 Mastery XP |
| 6 | Greenlight Mantle aura |
| 7 | 65 Essence, 180 Mastery XP |
| 8 | 0.65 Logs price units, 20 Souls, 225 Mastery XP |
| 9 | Furnacecore Longsword, 90 Essence |
| 10 | Verdant Warden title |
| 11 | 1 Logs price unit, 36 Souls, 350 Mastery XP |
| 12 | Heartwood Halo aura, 180 Essence, 500 Mastery XP |

The M1 price unit comes from the existing progression tier at claim time. Weapons are granted once if unowned and continue to use their original catalog entries. The Gallery shows alternate Season and Collection acquisition routes. There is no paid track or Robux reward.

## Collection edition and milestones

`Foundations01` has a fixed 1,000-point scale and freezes the baseline weapon, pet, tree and region IDs. Category points are capped independently. The edition retains the player's highest score and one-time milestone flags. New content can add an edition without rewriting old IDs or claims.

| Category | Points | Full-credit target |
| --- | ---: | --- |
| Weapon catalog | 370 | 119 of 120 permanent IDs. The optional paid Founder’s Edge can count, and all other weapons can be earned without it. |
| Pet discoveries | 235 | 21 families across 63 normal, Golden and Rainbow forms. Previously held evolved forms imply the earlier forms. |
| Tree discoveries | 90 | All 28 original tree types |
| Tree indexes | 45 | All four regions |
| Boss and raid victories | 85 | Blade King, Crystal Colossus, Frost Monarch, three rotating raids and Heart of Winter |
| Mastery | 65 | Levels 2–100 |
| Titles and auras | 50 | 10 out of the 16 original M7 unlock entries. Seasonal gear is optional. |
| Achievement goals | 60 | 24 of 28 goals. This allows a completion route without guild or party participation. |

| Milestone | Reward |
| ---: | --- |
| 10% | 28 Essence and 65 Mastery XP |
| 25% | 0.5 Logs price units, 16 Souls, 180 Mastery XP |
| 50% | Prism Saber, 100 Essence, 350 Mastery XP |
| 75% | 1.35 Logs price units, 45 Souls, 160 Essence, 650 Mastery XP |
| 100% | Aurora Cleaver, 350 Essence, 750 Mastery XP |

## Achievement catalog

Tier I gives 12 Essence and 40 Mastery XP. Tier II gives 0.25 Logs price units, 8 Souls, 22 Essence and 95 Mastery XP. Tier III gives 0.5 Logs price units, 18 Souls, 42 Essence and 175 Mastery XP. The panel shows category, current progress and claim state. The optional `BadgeId` field is reserved per achievement. No platform badge ID is configured or published.

| Category | Goals and reward tiers |
| --- | --- |
| Chopping | First clearing, 30 chops (I). Timber runner, 1,000 chops (II). Forest keeper, 15,000 chops (III). |
| Rare discoveries | Curious naturalist, 12 tree types (I). Mutation hunter, three mutations (II). An extraordinary roll, recorded rarity of at least 1 in 10,000 (III). |
| Weapons | Full rack, 15 weapons (I). Blade archivist, 60 weapons (II). Living armory, 119 weapons (III). |
| Pets | Critter companion, five families (I). Gilded companion, three evolved forms (II). Forest menagerie, 21 families (III). |
| Bosses | Kingfall, Blade King (I). Monarch’s end, Frost Monarch (II). Winter’s end, Heart of Winter (III). |
| Raids | Answered the horn, a paid raid victory (I). Three banners, all three raid types (III). |
| Trials | Beat the bell, one completion (I). Precision timber, best score 13 (II). |
| Expeditions | Below the snow, depth 3 (I). Into the deep, depth 12 (III). |
| Crafting | From the forge, one craft (I). Awakened steel, three awakened weapons (III). |
| Mastery | Studied the grove, level 15 (I). Master of the woods, level 100 (III). |
| Social | Proud collection, a showcase or vault deposit (I). Never alone, accept a party invitation (II). Guild colors, join a verified guild (II). |

## Onboarding and presentation

New players get a skippable field guide with movement and chopping, Upgrade Shop, rolling, pets, traits, Mastery and Tech Tree, Contracts and Trials, and Portal Cliffs. Common early actions can advance their corresponding step. Later topic cards have Next controls, and Forge guidance is available from Mastery 8. The permanent Guide tab remains available through the Journal. The tutorial uses the original completion flag and never restarts completed historical tutorials. Seen tips persist and use the existing analytics queue.

The compact HUD adds a Seasons tile with one responsive four-tab panel for Season, Collection, Achievements and Guide. It includes progress bars, textual claim states, a live countdown, weapon and pet previews from current templates, and bounded claim feedback using the existing sound and preferences. The guide explains the Heart of Winter seal warning. The new sign at Portal Cliffs and the Seasons and Collection Board use the existing Timber Haven surface. M4 geometry, Crystal camera behavior, and tree positions retain the baseline sources.

## Save and live operations

All M8 ledgers live inside the existing version 4 profile as additive `M8.Schema=1`: season progress and reward history, edition scores, achievement flags, pet discovery history, guide acknowledgements and progression counters. Old inventories and paid receipts stay in their original fields. Each reward check, claim flag and grant occurs on the server in one non-yielding section and uses M0's existing profile writer. The optional platform badge path requires a configured ID and a confirmed profile save. Season level, challenge claims and reward claims emit queued custom events. Season schedules, challenges, events, rewards and cosmetics are configured by ID.

M8 rewards reuse the M1 capped reward calculator and the existing daily Essence cap. If the full amount of Essence cannot fit today, the player can claim the reward after the UTC reset. No extra multiplier or paid product was added. M7 real trade and paid gifting remain disabled.

For source rollback, use the recorded M7 build or restore changed sources from the checkpoint by original path and remove the five new active M8 scripts. Retain the additive `M8` profile fields. The two M8 signs are generated at runtime.

## Economy estimate

Run `python3 tools/econsim/m8sim.py`. The overlay uses the prior M6 economy run, M2 median price units and the actual M8 reward and XP rules. It assumes consistent activity per play day and available claimed challenges. The JSON records each activity assumption and all eight weekly levels.

| Scenario | Final level | Modeled completion |
| --- | ---: | --- |
| New free player, three hours a week and one Daily Contract per session | 8 | Beyond modeled 8 weeks under those fixed activities |
| Free active | 12 | Week 4, 19.5 play hours |
| Paid active using existing progression assumptions | 12 | Week 3, 18 play hours |
| Unattended AFK, tree XP and chop challenge only | 7 | Beyond season under those fixed activities |

A completed season grants 2.35 Logs price units, 78 Souls, 395 Essence and 1,590 Mastery XP. The late-unit estimate is about 259 million free-active Logs, roughly 0.026% of the baseline 200-hour aggregate. Players at an early price tier receive a proportionally smaller grant. Season XP is available from both manual and unattended chops. Contracts and Trial play close the completion gap. Premium cosmetics and a full 120 paid-inclusive catalog are unnecessary for 100%. The model does not estimate a player’s time to 119 weapons, 63 forms or all rare tree discoveries. Those drop-rate tails, beginner completion pace and endgame encounter difficulty need comprehensive balance QA.

## Essential validation and unresolved work

- Studio compiled the 17 changed Luau sources and matched their checksums against Git in the private Edit model. The final save receipt and cloud place timestamp were confirmed.
- A detached legacy v4 profile retained the purchase fixture, original vault slot and existing Trial Tokens. The fixture verified exact UTC start and end, the daily XP caps, the weekly reset, the claims grace period, limited-event rewards and duplicate challenge refusal after save round-trip.
- The detached profile reached 1,000 collection points with all 119 free catalog entries and without Founder's Edge. All 120 catalog entries and 28 tree IDs resolved. The fixture kept all 63 pet discoveries after removing current pet ownership in the copied data. The test verified the centralized reward caps and both disabled flags.
- One Studio client opened the Journal, rendered 15 Season rows and the Collection tab with 14 rows and three model previews, and received the expected rejection for an unknown achievement. The Timber season prompt appeared after the v2 world finished initializing. The smoke ran before the configured season opened, so actual season gameplay and real reward collection were not exercised.
- Studio logged a permission error for existing Silvershore Saber mesh `95027611676885` and Roblox CoreScript timeouts. Journal rendering and the M8 remote checks succeeded in that session. The existing weapon asset and its access permissions were left intact.

Full multi-device play, a timed new-player onboarding pass, deep Expedition and Heart completion, true rarity tails, analytics dashboard delivery, and multi-server persistence remain for comprehensive QA. Trading crash recovery and paid gifting approval stay on the M7 follow-up list. Platform badges await owner-provided IDs.
