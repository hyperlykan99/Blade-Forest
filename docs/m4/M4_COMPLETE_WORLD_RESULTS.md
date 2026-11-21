# M4 Complete World Construction

**Private development place** `Blade Forest - Island Dev` · PlaceId `103379930563763` · UniverseId `10777797608`.

**Implementation commit** [`2f50bfbf340b8cd104a083f6c7db308da526158a`](https://github.com/hyperlykan99/Blade-Forest/commit/2f50bfbf340b8cd104a083f6c7db308da526158a) on `m4/complete-world-construction`. Gameplay baseline `fddc1b3ba2cd60abacbadaafff618ae2b6b6a0b0` and the subsequent M3 handoff.

**Saved state** **Roblox dev v52**, returned by Studio’s Team Create save. The cloud update timestamp is `2026-11-21T02:47:44.314Z` (November 20 at 18:47:44 PST). V2 is active for new dev Studio play sessions. The private place was left in Edit mode after the play sessions.

## Timber Haven

The replacement occupies approximately **760 × 640 studs**, centered at **(0, 0, −3000)**. The surveyed footprint contained no spatial-query parts or occupied sampled terrain before construction. The staging package has all eight districts and **1,200 choppable trees**.

| District | X, Z | Trees | Built |
| --- | --- | ---: | --- |
| Haven Village | −24, −3000 | 0 | Four spawn positions, tutorial guide, Haven Lodge, and the existing leaderboards relocated on v2 startup |
| Crafters’ Plaza | 0, −3125 | 0 | Log Market, working upgrade station, and forge workshop shell |
| Collectors’ Row | −144, −3020 | 0 | Weapon Gallery, Pet Sanctuary, Trait Shrine, and Timber altar stations |
| Sapling Woods | 175, −2980 | 300 | StarterGrove plots, including a 30-tree village fringe |
| Pinewood Hollow | 40, −2782 | 450 | PineForest plot, Power 40 route and two Rogue camps |
| Elderpine Ridge | −284, −2847 | 450 | PineForest plot, two Rogue camps and relocated Ancient Treant clearing |
| Kingsfall Arena | −250, −3230 | 0 | Ring arena and relocated Blade King |
| Portal Cliffs | 250, −3230 | 0 | Crystal Wilds and Frostbound prompts, plus two reserved gates |

Home arrival is **(−20, 5, −3000)**. The two legacy area IDs and all 14 StarterGrove and PineForest categories remain available. Architecture includes timber-frame roofs, signposts, trails, waterfall curtains and forest detail. Current tutorial and collection systems are reused.

## Frostbound Reach

The replacement occupies approximately **640 × 560 studs**, centered at **(6000, 0, 0)** inside the existing island registry. The surveyed area contained the Frost placeholder. The editor retains it, and v2 archives that shell during startup. The new island has all eight districts and **830 choppable trees**.

| District | X, Z | Trees | Built |
| --- | --- | ---: | --- |
| Frostgate Outpost | 5750, 0 | 0 | Arrival, Timber and Crystal gates, egg and altar stations, forge annex shell |
| Snowfield | 5880, 120 | 210 | Entry forest with glacier landmarks |
| Glacier Pass | 5900, −140 | 210 | Forest trail and ice-rock features |
| Aurora Basin | 6080, 60 | 210 | Frost forest, aurora and localized snowfall |
| Giant’s Hollow | 6200, 190 | 200 | Forest with rare Frost types and ice obelisks |
| Monarch’s Throne | 6150, −180 | 0 | Frost Monarch arena |
| Heart of Winter Sanctum | 6262, −59 | 0 | Sanctum arena, vault and Winter Key threshold |
| Expedition Gate | 6270, 63 | 0 | Expedition shell and future-island passage near (6270, 218) |

Frost arrival is **(5750, 5, 0)**. All trees retain the `FrostPeaks` area ID. Initial rarity counts are **445 Common, 202 Uncommon, 106 Rare, 51 Epic, 17 Legendary, 7 Mythic and 2 Secret**. The four forest plots use 7.6-stud spacing, about one tree per 58 square studs within the plots. That crosses the M1 simulator's 1-per-60 density threshold. Replacement Frost trees pay **1.35×** the existing Frost Logs value at the same rarity. The multiplier also applies on regrowth, under the existing Renewal cap and server budget. Comparative live Logs/hour was outside this smoke check.

The replicated v2 `Frost_Mythic_1` template uses **5 BaseParts**, down from **370**. Legacy mode retains the original template.

## Crystal Wilds and bosses

All **620/620** Crystal trees match the checked-in dense layout CSV within **0.06 studs**. The Crystal plaza, rim, terrain, paths and camera-fix source remain in place. The Colossus annex is centered at **(3000, 0, −350)**, outside the existing rim. There is a verified prompt from the plaza to **(3000, 5, −384)** and one back to **(2798, 6, −10)** within Crystal Wilds.

| Boss | Implemented | Rewards and progression |
| --- | --- | --- |
| Blade King | Existing encounter moved to Kingsfall in v2. Existing scaling, frenzy and payout remain. | Existing kill credit for Crystal Wilds. V2 first clear adds a Bark Sigil and Crimson Crescent (269 Power) if the player does not already own it. The M1 altar guarantee remains available. |
| Crystal Colossus | Anchored construct with 80,000 base HP, nearby-player scaling, aimed impact circles and a lower-health center strike. | Server damage-share payout, Logs, Souls and 850 Mastery XP. First clear adds a Crystal Sigil and Umbraxe (2,134 Power) if unowned. |
| Frost Monarch | Ice construct with 925,000 base HP, nearby-player scaling, telegraphed ice lanes and a lower-health center strike. | Server damage-share payout, Logs, Souls and 1,250 Mastery XP. First clear adds a Frost Sigil and Frostguard Defender if unowned. A rune pool identifier is reserved for crafting. |
| Heart of Winter | Physical arena, vault and threshold are installed. | Key crafting, live boss, weekly loot and endgame rewards remain in M6. |

The new encounters use the same capped M1 boss-reward engine and the existing persistence path. An eligible contributor needs 2% damage or 12 landed hits. A per-encounter flag rejects repeated payout and a persistent `BossFirstClears` ledger protects first-clear grants. Existing weapon Power, entitlements, index, unlocks, mastery and inventory formats are preserved.

The Frostbound Colossus condition becomes active when the server verifies the Crystal annex and encounter service are available. It still requires 6,000 Crystal chops and 2,000 Power for a new unlock. Existing Frostbound unlocks remain grandfathered.

## Travel and legacy switch

Travel initializes each character from authoritative saved/current island state. It reserves and confirms a landing before committing `CurrentIsland` and `LastIsland`. A failed stream or full arrival retries without replacing the saved island based on character position. Area enforcement pauses during initialization.

`Workspace.BladeWorldLayout` is a **startup switch** with values `legacy` and `v2`. The verified package is stored in `ServerStorage.M4WorldSource`. With v2 active, the server moves legacy breakables, spawns, placeable Map geometry, island placeholders and the original heavy Frost template into `ServerStorage.M4RuntimeLegacyArchive` in the running server. Legacy native Terrain and all original editor assets are retained. Restart with `legacy` to use the original island layouts. Crystal's separate annex is available in either mode. Use the pre-M4 checkpoint for a full gameplay rollback.

## Asset manifest and performance

| Asset | Source | Use |
| --- | --- | --- |
| Island land, cliffs, cottages, camp kits, rings, paths, waymarkers, waterfalls, aurora and signs | Original Studio geometry, [M4Architecture](../../src/serverstorage/M4Architecture.luau) and [M4Layout](../../src/shared/M4Layout.luau) | Staged under `M4WorldSource` |
| 2,030 initial trees and 5-part v2 tree recipes | Original Studio geometry, [M4Construction](../../src/serverstorage/M4Construction.luau) | Seeded plots and regrowth |
| Colossus and Monarch | Original geometry, [M4BossService](../../src/server/M4BossService.server.luau) | Server-spawned encounters |
| [Neighborhood Birds 1](https://create.roblox.com/store/asset/9112835056) | ProSoundEffects, free Creator Store audio, ID `9112835056` | Timber woods |
| [Waterfall Cu 1](https://create.roblox.com/store/asset/9120550180) | ProSoundEffects, free Creator Store audio, ID `9120550180` | Two Timber waterfalls |
| [Snowstorm](https://create.roblox.com/store/asset/551546110) | ZacAttackk, free Creator Store audio, ID `551546110` | Frostbound wind |
| Snowfall sprite | Roblox built-in `rbxasset://textures/particles/sparkles_main.dds` | One localized, capped emitter |

The staged island geometry contains **518 Timber** and **366 Frost** BaseParts apart from trees. Trees add **6,000** and **4,150** BaseParts respectively. No external model scripts were imported. The private Studio build batches measured 5.34 seconds for Timber and 4.18 seconds for Frost, including deliberate yields. These are construction timings, not mobile FPS or server capacity measurements.

## Checks and outstanding work

- Compiled all **19** changed/new Luau sources and matched their Studio digests to Git. The unchanged Crystal camera script digest is `27331:1017905967`. Verified the staged and runtime tree counts and all required tree categories.
- A v2 Studio client rejoined to its saved Crystal island. Travel reached all three registered arrivals and recorded the matching current and saved island after each landing. The 1,834-Power account was correctly refused below the Frost gate. For the Frost landing fixture, temporary server-side Power was set to 2,000 on the already-unlocked dev account and restored along with its prior island. No inventory or unlock was granted by the fixture.
- Drove both Crystal prompts through the Studio client. Observed Blade King in Kingsfall and both new bosses spawning and emitting their attack telegraphs. Both new encounters refused an alive-boss payout. The Frostbound gate fixture required Colossus credit and passed once credit was present. All four placed audio loops reported loaded.
- Legacy-mode smoke boot restored the original Timber and Frost arrivals and **5,021** active legacy-and-Crystal trees. Detached payout fixtures exercised both new bosses, repeated defeat rejection, first-clear deduplication across encounters, contribution thresholds, Mastery XP and preservation of existing purchase fields.
- Positive live defeat payouts, DataStore persistence across a boss clear, sustained multi-client combat, mobile performance and live economy rates remain unverified. A startup `leaderstats` wait warning was observed, followed by a successful profile load and travel. Full forge, expedition, raid and Heart of Winter gameplay belongs to later milestones.

## Rollback

- **Pre-M4 checkpoint.** `ServerStorage.M4Rollback`, with 16 inert source copies and a preserved Frost placeholder. Cloud checkpoint update `2026-11-21T02:23:33.260Z`. The pre-M4 cloud baseline was the M3 save at `2026-11-21T02:11:29.158Z`.
- **Pre-cutover checkpoint.** all staged builds with legacy active. Cloud update `2026-11-21T02:35:28.792Z`.
- For source rollback, restore the modified scripts from the checkpoint or the M3 Git baseline, and disable the M4 package. Original world assets remain in the private Edit DataModel. Preserve profile fields from later saves when reverting.
