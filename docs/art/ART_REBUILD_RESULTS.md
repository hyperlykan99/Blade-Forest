# Blade Forest — Professional Asset Rebuild results

The private place runs the imported Kenney Fantasy Town and Nature assets with the professional-art switch enabled. See the [visual style bible](BLADE_FOREST_VISUAL_STYLE_BIBLE.md), [source and license manifest](PROFESSIONAL_ASSET_MANIFEST.md), and [Roblox asset IDs](../../assets/art/professional/STUDIO_ASSET_IDS.json).

## Import and integration

The exact approved directory was the workspace’s `work/art-intake` folder. The 11-mesh comparison was reviewed at player camera height before importing the full 44-mesh catalog. The cottage, bridge, trees and props shared consistent faceted outlines and readable proportions. Both model packages were inspected in private ServerStorage quarantine. All 44 catalog meshes, their shared atlas, the Timber atlas and the five VFX images fetched successfully in Studio. The packages contained no scripts. The temporary comparison scene was removed. The safe runtime mesh bank and raw quarantine are retained in ServerStorage.

| Area | Installed art and Studio Play observations |
| --- | --- |
| Haven Village and Records Lodge | Kenney gables and shuttered façades, an entry arch, a brook crossing, and a Records Hall backdrop. All three leaderboard faces displayed populated rows. The walk-up lanes remain open. |
| Crafters’ Plaza and Collectors’ Row | Station shells use the same window and roof proportions, with open storefronts over existing service foundations. Restored mounted wayfinding where oversized signs obscured façades. |
| Sapling Woods, Pinewood Hollow and Elderpine Ridge | 14 Timber variants across 1,200 slots. Rounded broadleaf, multiple conifers, branching crowns and a mushroom silhouette. The custom Woodland grade darkens the canopy palette and is confined to Timber meshes. Imported trunks and crowns use the existing tree base position. |
| Kingsfall Arena and Portal Cliffs | Ruins and paving frame the combat floor, and catalog arches dress two approaches. Blade King reached the victory state in the isolated Play client. |
| Crystal Wilds | Imported mineral formations near arrival and around the Colossus annex. The protected Crystal forest uses its existing trees and camera code. Colossus spawned in the Play client. |
| Frostbound Reach | Seven evergreen silhouettes across 830 slots, authored shells at Frostgate, frozen slopes and a bridge, and imported arches and mineral accents at Monarch’s Throne and Heart of Winter. Frost Monarch spawned and its existing telegraphs were visible. Player-height spot checks also covered Snowfield, Glacier Pass, Aurora Basin, Giant’s Hollow and Expedition Gate. |

The Play server kept `300 StarterGrove + 900 PineForest + 620 CrystalCanyon + 830 FrostPeaks`. Crystal’s position signature stayed `620:1325136453`. All 2,030 Timber and Frostbound trees used the imported fall templates and retained their original queryable hitbox and collidable trunk. Initial rarity, health, strength, regrowth and Logs values matched the existing configuration. Timber’s minimum measured tree-center clearance from main roads was 9.52 studs. The imported canopy bounds had zero measured main-road intrusions. New scenery meshes do not collide, touch, or participate in spatial queries.

The isolated Play client recorded 38 tree hits, 38 imported falls, 19 matched regrowths before the sample ended and zero missing fall templates. The client fetched all five sprite IDs successfully and used the leaf, glint and dust sprites in its active effects pool.

Existing tree-hit, falling-tree and encounter events still drive the cosmetic client. Five licensed sprites are assigned to the existing distance-gated effect pool. Low graphics suppresses the cosmetic bursts. Reduced Motion reduces emission and suppresses optional motion. Weapon models, tree rules and mutation probabilities and rewards use their existing sources.

## Studio evidence

| View | Actual Studio capture |
| --- | --- |
| Imported comparison | [Player-height staging scene](KENNEY_STUDIO_COMPARISON.jpg) |
| Timber Haven | [Village](KENNEY_PLAY_HAVEN.jpg) · [Woodland canopy](KENNEY_PLAY_WOODLAND.jpg) · [Records Lodge](KENNEY_PLAY_LODGE.jpg) |
| Crystal Wilds | [Protected approach](KENNEY_PLAY_CRYSTAL.jpg) · [Colossus encounter](KENNEY_PLAY_COLOSSUS.jpg) |
| Frostbound Reach | [Frostgate](KENNEY_PLAY_FROSTGATE.jpg) · [Heart of Winter approach](KENNEY_PLAY_SANCTUM.jpg) |

The old build was measured before a matched screenshot set was captured. The comparison and Play captures above show actual imported Studio assets. The [local catalog render](Blade-Forest-Kenney-Style-Review.png) remains separate.

## Performance

One isolated Studio client, a 957 × 532 logical viewport, Low graphics, Reduced Motion, matched fixed camera positions and a five-second streaming settle. Samples were approximately six seconds per location. The after measurements include the imported geometry and mounted wayfinding and precede the final texture-only Woodland grade.

| Camera | FPS before → after | Median ms | p95 ms | Client MB |
| --- | ---: | ---: | ---: | ---: |
| Haven Village `(-52, 14, -3023)` | 6.6 → 7.3 | 143.1 → 132.5 | 232.2 → 224.3 | 7,127 → 8,320 |
| Crystal Wilds `(2776, 17, -48)` | 8.4 → 6.8 | 92.1 → 143.6 | 220.8 → 216.5 | 7,124 → 8,307 |
| Winter Sanctum `(6262, 18, -12)` | 8.6 → 8.3 | 117.4 → 125.3 | 171.5 → 215.9 | 7,118 → 8,298 |

Studio performance remains poor. The session measured higher client memory at all three locations, and Crystal and the Sanctum had lower average FPS. The samples do not isolate the asset cost from the Studio process’s other allocations. Physical mobile performance remains unverified.

## Remaining visual and gameplay checks

Some large legacy terrain and arena surfaces remain visible, especially at Kingsfall, along Crystal’s arena ring and against the Frost skyline. Shared shop modules are still visually repetitive from some angles. Dense Frost canopies and legacy slabs can obstruct low camera angles. Crystal received a perimeter treatment. Full boss-model redesign, walking every route, complete travel prompt traversal, prolonged play and physical mobile tests remain open.

## Save, commit and rollback

- Private place `103379930563763`, universe `10777797608`. Studio confirmed private cloud save **v98**. Roblox reported cloud update `2026-11-22T23:37:17.200Z`. The editor was released in Edit mode with the isolated QA switch cleared.
- Implementation `862bb5b50b09a1df04aa5eebffd9564db4694c64` on `art/professional-asset-rebuild`.
- Clear the startup attribute `Workspace.BladeForestAssetArt` in Edit and start a fresh private session to return to the previous art. For complete restoration, use the private cloud checkpoint at `2026-11-22T06:49:28.114Z`. Six baseline source copies are retained in `ServerStorage.ProfessionalArtRollback` against the v87 art implementation.
- Production stayed untouched and the place was never published. Trading and paid gifting stayed disabled. QA instrumentation ran against the isolated Studio profile.
