# Timber Haven tree and visual overhaul

The source changes branch from QA commit `0903e765cde5e43481906e0ba10705f5a159b558`. They apply to the staged v2 Timber Haven layout in private development place `103379930563763`, universe `10777797608`. Production place `73142469975141` was outside the work.

## Tree audit

Timber's 14 starting types previously shared five-part M4 models. Each model had one trunk, one hitbox and three rounded canopy parts. Color and size carried most of the rarity information. The new visuals retain those trunk and hitbox dimensions and give the crown its own silhouette.

| Biome and tree ID | Existing model | Classification and visual decision |
| --- | --- | --- |
| Sapling Woods · `Grove_Common` Sapling | M4 Grove Common | **REPLACE** with a small leafy birch silhouette |
| Sapling Woods · `Grove_Uncommon` Blossom Tree | M4 Grove Uncommon | **REPLACE** with a taller yellow-green broadleaf |
| Sapling Woods · `Grove_Rare` Autumn Maple | M4 Grove Rare | **UPGRADE** with a wider amber crown |
| Sapling Woods · `Grove_Epic` Ruby Maple | M4 Grove Epic | **UPGRADE** with a taller red crown |
| Sapling Woods · `Grove_Legendary` Golden Oak | M4 Grove Legendary | **SPECIAL** · native forked oak with a layered gold crown |
| Sapling Woods · `Grove_Mythic` Sakura Spirit | M4 Grove Mythic | **SPECIAL** · curved branches and a pink canopy |
| Sapling Woods · `Grove_Secret` Rainbow Tree | M4 Grove Secret | **SPECIAL** · swept violet crown with gold accents |
| Pinewood Hollow / Elderpine Ridge · `Pine_Common` Spruce | M4 Pine Common | **REPLACE** with a dark, faceted spruce |
| Pinewood Hollow / Elderpine Ridge · `Pine_Uncommon` Tall Pine | M4 Pine Uncommon | **REPLACE** with an upright green pine |
| Pinewood Hollow / Elderpine Ridge · `Pine_Rare` Frost Spruce | M4 Pine Rare | **UPGRADE** with a taller blue-green faceted crown |
| Pinewood Hollow / Elderpine Ridge · `Pine_Epic` Ember Pine | M4 Pine Epic | **UPGRADE** with a russet crown |
| Pinewood Hollow / Elderpine Ridge · `Pine_Legendary` Golden Pine | M4 Pine Legendary | **SPECIAL** · tall gold pine with its own proportions |
| Pinewood Hollow / Elderpine Ridge · `Pine_Mythic` Giant Mushroom | M4 Pine Mythic | **SPECIAL** · native tiered mushroom caps and a crooked stalk |
| Pinewood Hollow / Elderpine Ridge · `Pine_Secret` Moonlit Bonsai | M4 Pine Secret | **SPECIAL** · a 22-stud design with exposed roots and sweeping boughs |

Crystal's models already have a distinct crystalline silhouette. Most sampled templates carry seven mesh surfaces. The Secret tree has the largest model and is a candidate for future profiling. Frost's five-part staged forms are already compact. Their repeated silhouettes are a visual limitation, and their icy tints and top-tier materials continue to signal rarity. The art switch affects neither biome.

| Biome and tree | Existing model or runtime template | Classification and observation |
| --- | --- | --- |
| Crystal Wilds · Frost Crystal | `Crystal_Common_1` | **KEEP** · 8 parts, 7 mesh surfaces |
| Crystal Wilds · Amethyst Tree | `Crystal_Uncommon_1` | **KEEP** · 8 parts, 7 mesh surfaces |
| Crystal Wilds · Rose Quartz | `Crystal_Rare_1` | **KEEP** · 8 parts, 7 mesh surfaces |
| Crystal Wilds · Prism Tree | `Crystal_Epic_1` | **KEEP** · 8 parts, 7 mesh surfaces |
| Crystal Wilds · Sun Crystal | `Crystal_Legendary_1` | **SPECIAL** · 8 parts, 7 mesh surfaces |
| Crystal Wilds · Sky Crystal | `Crystal_Mythic_1` | **SPECIAL** · 3 parts, 2 mesh surfaces |
| Crystal Wilds · Crystal Heart Tree | `Crystal_Secret_1` | **SPECIAL** · 16 parts, 15 mesh surfaces |
| Frostbound Reach · Snow Spruce | `Frost_Common` / `M4SnowTree` | **KEEP** · compact snow-blue canopy |
| Frostbound Reach · Glacier Pine | `Frost_Uncommon` / `M4SnowTree` | **KEEP** · blue canopy |
| Frostbound Reach · Frostwood | `Frost_Rare` / `M4SnowTree` | **KEEP** · brighter ice-blue character |
| Frostbound Reach · Aurora Tree | `Frost_Epic` / `M4SnowTree` | **KEEP** · violet canopy |
| Frostbound Reach · Starfrost Tree | `Frost_Legendary` / `M4SnowTree` | **SPECIAL** · cyan and ice accents |
| Frostbound Reach · Frostleaf Tree | `Frost_Mythic` / `Frost_Mythic_1` | **SPECIAL** · previously optimized falling template |
| Frostbound Reach · Ancient Frost Giant | `Frost_Secret` / `M4SnowTree` | **SPECIAL** · pale ice silhouette |

## Creator Store manifest

| Creator Store listing | Creator | Retained geometry |
| --- | --- | --- |
| [Low Poly Pine Tree Forest Nature Set](https://create.roblox.com/store/asset/139324793394505) | CraftCyberCrystal461 | `PineTall`. Crown `2919523288`, bark `2919522588` |
| [Low-Poly Pine Tree Evergreen Forest Snow Trees 3D](https://create.roblox.com/store/asset/117892238103747) | Zofazike71 | `PineFaceted`. Crown `2852007441`, bark `2852007373` |
| [Three Trees Realistic Forest Nature Pine Low Poly](https://create.roblox.com/store/asset/122491881731754) | Neonneed5891 | `Broadleaf`, birch only. Crown `7489974238`, bark `7196346050` |
| [Maple Tree](https://create.roblox.com/store/asset/138817556746532) | cube3D | Rejected. Retained no instances. |

The imports were quarantined in ServerStorage. Each retained tree used only two mesh parts with their children and texture references stripped. The source packages included scripts, modules, constraints or unrelated interface objects. Those instances were excluded from the retained models. The [geometry manifest](timber-tree-asset-manifest.json) records the retained mesh IDs, pivots and dimensions. Native trees cover special silhouettes and provide a fallback when a sanitized template is unavailable.

## Paths and Records Lodge

The placement plan uses the boundaries of the nine existing packed trails. It keeps trunks at least 9.5 studs beyond the road edges, spreads near-neighbors 5.55 studs apart and keeps activity around the village, plaza, Collectors' Row and arena approaches open. The original four forest plot folders and tree slots remain in the editor. The runtime reuses those models, retaining their seeds, type IDs, collision and chopping hitboxes, health, strength, rewards and respawn timing. A small offset varies the standing grid, and blocked trees move into the nearby forest within their original progression area.

Haven Records Lodge gives all three existing boards a shared south-facing orientation. The faces are about 20.7 studs wide, with centers 23 studs apart at X −15, 8 and 31 along Z −2928.1. The pavilion has a slate forecourt and roof, timber posts, amber accents and six noninteractive village and plaza trees. Board models, identifiers, SurfaceGuis and row templates stay under `Workspace.Map.Leaderboards` for the existing service.

## Tree mutations

**Implemented gameplay.** `TreeKit.BuildRandom` rolls mutations for Crystal and legacy trees. The staged Timber and Frost forests start with authored trees, then roll mutations on regrowth through `M4Construction.Regrow`. Golden, Frozen, Shadow and Rainbow change appearance, health and Logs rewards. Timber and Frost retain the existing rule that only Shadow and Rainbow keep ambient mutation emitters on regrowth. The one-in-40, one-in-70, one-in-200 and one-in-800 checks run rarest first. These are the per-roll thresholds. The save records mutation discoveries and chop statistics. The Mutation Logs rune applies to actual mutated targets through the capped Economy Logs channel. The art switch preserves that logic and uses the existing mutation appearance function on the replacement crown.

## Validation and performance observations

- Studio compiled all four changed or added Luau modules and matched their source checksums to the implementation commit. An initial runtime error in the native tree constructor was corrected before the successful play session. An art preflight failure falls back to the previous v2 art.
- The isolated Studio server loaded **300 Starter Grove**, **900 Pine Forest**, **620 Crystal Wilds** and **830 Frost Peaks** trees. Timber preserved all 14 starting type counts, original hitboxes and trunk collision. Initial Timber health, strength, rarity, Logs rewards and respawn timing matched the existing definitions. Crystal's sorted position checksum matched the QA reference `620:1325136453`. Frost's tree and reward code was untouched.
- **263** original Timber tree centers sat within the new road buffer. **276** slots required replanting after applying all filters. The closest tree center ended up **9.52 studs** from a packed trail. None of the new trees' measured part bounds overlapped those trails.
- All six retained Creator Store mesh IDs loaded in Edit and in the Studio play client. The running Timber forest held **4,920 tree BaseParts** versus **6,000** in the previous five-part models. The new total includes **2,354 MeshParts**. These are instance counts. Desktop FPS, mobile frame time, and streaming performance were outside this pass.
- All three leaderboard faces pointed south, were nonblocking, and displayed populated first rows through the existing refresh service in the isolated Studio session. All six landscaping trees were present.
- A detached regrowth check used the real M4 regrow path. It picked a Timber type, received the matching art and falling template, and kept its queryable hitbox. Applying each of the four mutations changed the foliage material and returned the existing Logs multiplier. A player-driven chop and cross-server leaderboard update were outside this pass.

Visual notes above describe the changes, including the small broadleaf grove, the taller blue-green and ember pines, the native Moonlit Bonsai and the slate-and-timber Records Lodge. Crystal Heart's heavier model and Frost's repeated canopy forms are noted in the audit. A physical-device look and performance review remain open under QA.

## Save and rollback

- Private place `103379930563763`, universe `10777797608`. Team Create reported no unsaved changes after saving. Open Cloud confirmed the private place update at **2026-11-22T06:02:10.093Z** (November 21 at 10:02 p.m. PST). The numeric version of the final save was unverified. Studio stayed in Edit mode with the QA profile switch cleared and the editor released.
- Rollback checkpoint **v76**. `ServerStorage.TimberArtRollback` holds the QA v75 copies of `ServerScriptService.M4WorldRuntime` and `ServerStorage.M4Construction`. To revert the art only, clear `Workspace.BladeTimberArt` and restart a private session. The staged v2 editor world retains its original models and positions.
- Implementation commit `85167c9acecadf205f6f62907839442fdd2a38b3`, recorded in `Workspace.TimberArtDevBuild`. Branch `art/timber-haven-tree-overhaul`. Production was untouched and the private build was saved without publishing.
