# M3 Character Progression

**Implemented and smoke-tested in the private development place on November 20, 2026 (PST).** M3 includes 72 skills across six branches, 100 Mastery levels, 12 traits, 21 base pets in three egg pools, and 42 Golden and Rainbow variants.

| Item | State |
| --- | --- |
| Private place | `Blade Forest - Island Dev` · place `103379930563763` · universe `10777797608` |
| Saved state | Team Create reported **no unsaved changes** after the final save attempt. Open Cloud returned `2026-11-21T02:11:29.158Z` (Nov 20, 18:11:29 PST). |
| Numeric save version | Unverified. The labelled save request did not return a version receipt. The Edit DataModel still reports `30` and the version-history API was previously restricted. The Studio UI check timed out. Use Roblox Studio **Window → Version History** to resolve the saved version number. |
| M3 implementation commit | [`fddc1b3ba2cd60abacbadaafff618ae2b6b6a0b0`](https://github.com/hyperlykan99/Blade-Forest/commit/fddc1b3ba2cd60abacbadaafff618ae2b6b6a0b0) on `m3/character-progression` |
| M2 baseline | Git `ce670488172ae0a39bfff259c47bf6b74578e1d5` · last documented Roblox M2 save **v45** at `2026-11-21T01:15:19.309Z` |
| Editor | Released in Edit mode after the local test session ended. |

## Tech Tree and Mastery

Mastery begins at level 1. XP to the next level is `floor(110 + 32 × level^1.48)`. Valid tree chops award rarity-weighted XP (3/5/8/13/23/40/75/100) times the island tier (1/2/3), with 4 × tier for a mutation and 30 for the first discovery of a tree type. Eligible Blade King and Treant participation awards 240 and 650 XP respectively. Chops use the same XP rules during active play and Auto Chop. The XP formula is independent of Logs, Luck, spending, and AFK time.

Every even level awards 4 Tech Points. Levels 25, 50, 75 and 100 each award 10 milestone points, for 240 TP across a complete profile. Each level above 1 adds 0.5% into the permanent M1 Logs pool. The HUD displays XP progress and the server sends level-up notifications. The Tech Tree has selectable branches, prerequisite links, node previews and states, capstones and confirmed respec. Respec returns all points spent on known nodes and advances the tree revision to reject stale requests.

Each cell names a node. Its stable ID is its column prefix plus its zero-padded row number. Levels, costs, prerequisites and effect conditions apply to all six nodes on that row.

| # | Mastery | TP | Prerequisites in branch | Bonus active when | Blade | Forest | Fortune | Explorer | Artisan | Guardian |
| ---: | ---: | ---: | --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | 2 | 2 | — | Always | True Edge | Fieldcraft | Fortune Seed | Trail Boots | Carved Collar | Seed Keeper |
| 02 | 6 | 2 | — | Mastery 10+ | Steady Orbit | Seasoned Hands | Lucky Streak | Wayfinder | Fine Stitching | Grove Sentinel |
| 03 | 12 | 2 | — | Crystal Wilds unlocked | Crystal Cleave | Crystal Sap | Facet Finder | Crystal Footing | Crystal Harness | Crystal Nursery |
| 04 | 18 | 2 | 01 | Primary trait equipped | Inscribed Steel | Bark Blessing | Omen Reader | Traveler's Mark | Runed Tag | Ward Seal |
| 05 | 25 | 3 | 02 | Mastery 25+ | Tempered Arc | Canopy Harvest | Silver Lining | Long March | Masterwork Saddle | Lifeweaver |
| 06 | 32 | 3 | 03 | One or more pets equipped | Pack Strike | Pack Haul | Lucky Companion | Scouting Partner | Bonded Leash | Forest Familiar |
| 07 | 40 | 3 | 04 | Frostbound Reach unlocked | Ice Cutter | Winter Timber | Winter Star | Glacier Step | Frostweave | Winter Greenhouse |
| 08 | 48 | 3 | 05 | Two or more pets equipped | Flanking Blades | Timber Caravan | Twinned Charms | Expedition Party | Pack Harness | Grove Patrol |
| 09 | 55 | 5 | 06 | Mastery 50+ | Heartwood Splitter | Old Growth | Gilded Fate | Fleetfoot | Guildwork | Second Spring |
| 10 | 64 | 5 | 07 | Secondary trait equipped | Twin Engraving | Twin Bark Seals | Double Omen | Double Trail Sign | Twin Signatures | Twin Wards |
| 11 | 75 | 5 | 08 | Mastery 75+ | Peerless Edge | Verdant Dominion | Starlit Path | Far Horizon | Heirloom Craft | Elder Warden |
| 12 | 90 | 5 | 09, 10, 11 | Mastery 100 | Crown of Steel ✦ | Heart of the Forest ✦ | Wheel of Fortune ✦ | Worldwalker ✦ | Master Artisan ✦ | Evergreen Covenant ✦ |

Each node contributes the amount below to the existing channel when its condition is met. The Artisan bonus also requires an equipped pet. The tree-damage channel applies only to trees. Guardian shares the existing Renewal cap and server regrowth budget.

| Branch | Economy channel | Tier 1 (01–04) | Tier 2 (05–08) | Tier 3 (09–12) |
| --- | --- | ---: | ---: | ---: |
| Blade Mastery | Capped tree damage pool | +1% | +2% | +3% |
| Forest Mastery | Permanent Logs pool | +2.5% | +5% | +7.5% |
| Fortune Mastery | Permanent Luck pool | +1.8% | +3.6% | +5.4% |
| Explorer Mastery | Capped movement | +0.11 studs/s | +0.22 studs/s | +0.33 studs/s |
| Artisan Mastery | Pet Logs pool | +1.7% | +3.4% | +5.1% |
| Guardian Mastery | Eligible tree regrowth reduction | +0.4 points | +0.8 points | +1.2 points |

## Traits

The six legacy IDs, multipliers and relative weights are retained. Frostbound Reach access unlocks slot two, with its own lock and reroll. A roll matching a trait already equipped in either slot leaves both slots intact. Replacement offers persist with the profile. Crate rolls remain server-authoritative and use the existing paid-random eligibility policy. When Logs packs are enabled, the Souls crate is also gated because the Sawmill converts Logs to Souls. No commerce was enabled for M3.

Odds below are percentages before the eligible Lucky Crates modifier. The UI uses the same weight function as the server and asks the server whether the modifier applies.

| ID | Rarity | Effect | Logs / free crate | Souls crate |
| --- | --- | --- | ---: | ---: |
| Sapling | Common | +25% to the permanent Logs pool | 39.14% | 0.00% |
| Woodcutter | Uncommon | +50% to the permanent Logs pool | 21.92% | 32.85% |
| Lumberjack | Rare | +75% to the permanent Logs pool | 10.96% | 23.36% |
| TimberTitan | Epic | +100% to the permanent Logs pool | 4.70% | 10.95% |
| ForestWarden | Legendary | +150% to the permanent Logs pool | 1.41% | 5.11% |
| AncientRoot | Mythic | +200% to the permanent Logs pool | 0.16% | 0.73% |
| SapSage | Uncommon | +2.5% to the eligible regrowth reduction | 10.18% | 8.76% |
| FortuneBark | Rare | +18% to the permanent Luck pool | 5.48% | 8.03% |
| Trailborn | Rare | +0.55 studs/s within the movement cap | 3.13% | 5.11% |
| Edgekeeper | Epic | +7% to the tree damage pool | 1.88% | 2.92% |
| Beastmaster | Legendary | +25% to the pet Logs pool | 0.78% | 1.46% |
| AuroraSage | Mythic | +32% to the permanent Luck pool | 0.27% | 0.73% |

## Pet roster and asset manifest

The Pets panel selects the egg island and the Normal, Golden, or Rainbow inventory. An island must be unlocked before its egg can be hatched. Each egg uses the existing tier-scaled Logs price and the same seven rarity weights. The Timber egg keeps the original pool and world prompt. Crystal and Frostbound eggs are available from the panel after their island unlocks.

Golden evolution consumes three unequipped normal copies and 50 Souls. Rainbow evolution consumes three unequipped Golden copies and 150 Souls. The corresponding stage keeps the base pet Logs contribution and adds 0.06 or 0.15 to the capped Luck pool. Counts are saved in separate `PetGolden` and `PetRainbow` tables. Equipped normal IDs are preserved, and evolved variants use `_G` and `_R` keys. Auto Equip Best ranks owned copies by Logs + 2 × Luck within existing slot limits (3, or 4 with VIP). Existing client-side follow movement renders nearby equipped pets, including evolved variants.

Fourteen new base pets use original procedural Studio geometry. The source-controlled [roster](../../src/shared/PetRoster.luau) and [model factory](../../src/server/PetModelFactory.luau) generate reproducible models at server startup under `ReplicatedStorage.PetModels`. The seven Timber templates come from the existing place. The factory derives evolved geometry and tints from the corresponding template. The model checks verified 63 nonempty templates with no scripts. The part counts below are Normal / Golden / Rainbow.

| Island | Pet ID | Egg odds | Model source | BaseParts |
| --- | --- | ---: | --- | --- |
| Timber Haven | Bunny | 45% | Existing Studio template | 7 / 8 / 10 |
| Timber Haven | Cat | 30% | Existing Studio template | 10 / 11 / 13 |
| Timber Haven | Bear | 14% | Existing Studio template | 9 / 10 / 12 |
| Timber Haven | Fox | 7% | Existing Studio template | 2 / 3 / 5 |
| Timber Haven | Penguin | 3% | Existing Studio template | 2 / 3 / 5 |
| Timber Haven | Owl | 0.9% | Existing Studio template | 48 / 49 / 51 |
| Timber Haven | Dragon | 0.1% | Existing Studio template | 2 / 3 / 5 |
| Crystal Wilds | QuartzHare | 45% | Original generated geometry | 12 / 13 / 15 |
| Crystal Wilds | GeodeTortoise | 30% | Original generated geometry | 12 / 13 / 15 |
| Crystal Wilds | JadeMantis | 14% | Original generated geometry | 12 / 13 / 15 |
| Crystal Wilds | AmethystBat | 7% | Original generated geometry | 10 / 11 / 13 |
| Crystal Wilds | CitrineRam | 3% | Original generated geometry | 14 / 15 / 17 |
| Crystal Wilds | PrismStag | 0.9% | Original generated geometry | 14 / 15 / 17 |
| Crystal Wilds | CrystalWyvern | 0.1% | Original generated geometry | 12 / 13 / 15 |
| Frostbound Reach | SnowPika | 45% | Original generated geometry | 12 / 13 / 15 |
| Frostbound Reach | FrostSeal | 30% | Original generated geometry | 8 / 9 / 11 |
| Frostbound Reach | GlacierWolf | 14% | Original generated geometry | 12 / 13 / 15 |
| Frostbound Reach | TundraMammoth | 7% | Original generated geometry | 13 / 14 / 16 |
| Frostbound Reach | AuroraRay | 3% | Original generated geometry | 8 / 9 / 11 |
| Frostbound Reach | IcePhoenix | 0.9% | Original generated geometry | 10 / 11 / 13 |
| Frostbound Reach | BorealLindwyrm | 0.1% | Original generated geometry | 12 / 13 / 15 |

## Save compatibility and rollback

M3 uses the existing v4 profile, DataStore key, reconciliation, session locks and writer. The new persistent fields are `Mastery`, `TechTree`, `Trait2`, `Trait2Locked`, `TraitOffer`, `PetGolden` and `PetRainbow`. Existing pet, trait, weapon, purchases, and attunement fields keep their formats. Mutating M3 actions reject a profile in AFK handoff. No manual DataStore edits were used.

`ServerStorage.M3Rollback` contains 11 inert, source-verified copies of the pre-M3 scripts at the completed M2 SHA, with original paths and classes. Team Create reported a checkpoint timestamp of `2026-11-21T01:56:04.005Z` after that backup was created. The M2 rollback reference is the documented v45 save. For a source rollback, restore the 11 original sources from the checkpoint and remove the seven M3-only source instances listed in the implementation commit. Model variants are runtime-generated. Preserve any newer profile data if reverting the place.

## Essential checks

- All **18** M3 Luau sources compiled in Studio and their source and editor digests matched the Git implementation after the save check.
- Detached M3 fixtures verified 72 nodes, six capstones, prerequisites, 100 levels and exactly 240 points, duplicate unlock rejection, exact respec refund and stale respec rejection. They also checked capped pools, trait odds normalization, island egg pools, insufficient currency, equipped-copy protection, exact duplicate consumption and 63 script-free pet models.
- One Studio client loaded a profile and the Mastery HUD. Clicked the Tech Tree tile, opened a 12-node branch with 11 dependency edges, selected an Explorer node and verified its locked preview for level 1. The live client received server rejection for an unknown node, an invalid trait slot and an unknown egg. The server reported 120 weapon definitions and 120 BladeModels.
- A synthetic older v4 profile passed the real profile builder. A JSON round-trip preserved the fixture purchases, owned/equipped legacy collectibles and M2 attunement while retaining new mastery, nodes, pending trait offer and both evolution inventories. The single-client Studio startup log included early `leaderstats` wait warnings, followed by confirmed profile load.
- Positive trait rolls, purchases, paid-random policy responses from a restricted account, and actual DataStore writes with evolved inventory were outside the smoke check. No extended multiplayer, mobile-device profiling, game-balance campaign or M4 work was performed.
