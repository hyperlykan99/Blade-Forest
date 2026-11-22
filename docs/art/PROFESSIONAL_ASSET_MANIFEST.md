# Professional asset manifest

**Status.** Selected and converted locally. Roblox rejected the model and image upload requests at the approved-directory check. No Roblox asset IDs were issued. There are no imported or active assets from this catalog in the private place.

## Verified source archives

| Source | Author and permission | Actual formats and dependencies | SHA-256 of downloaded archive |
| --- | --- | --- | --- |
| [Fantasy Town Kit 2.0](https://kenney.nl/assets/fantasy-town-kit) · [Kenney's OpenGameArt upload](https://opengameart.org/content/fantasy-town-kit) | Kenney. CC0 1.0. Commercial use permitted, confirmed by the archive license and source page. | GLB source modules. Source colormap included in the archive. | `1a7530c09f4d2fa2cdee259876f089334f8b1f27fa86a0c4f54ef86cdd8676ef` |
| [Nature Kit 2.1](https://kenney.nl/assets/nature-kit) · [pinned download mirror](https://github.com/WaviestSun/atelier-packs/releases/tag/packs-2) | Kenney. CC0 1.0. Commercial use permitted, confirmed by the archive license. Mirror hash matched its published pin. | GLB source meshes with modeled flat materials. | `fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d` |
| [Particle Pack](https://kenney.nl/assets/particle-pack) · [Kenney's OpenGameArt upload](https://opengameart.org/content/particle-pack-80-sprites) | Kenney Vleugels. CC0 1.0. Commercial use permitted, confirmed by the archive license. | Individual PNG sprites. Unity samples and other extras were excluded. | `163b839ba7f62f8a420da93a62beaa80013588d5d6b1eb30841e1a553635ad70` |
| [Ultimate Fantasy RTS](https://quaternius.com/packs/ultimatefantasyrts.html) | Quaternius. CC0 1.0 per the creator's kit page. The comparison files came from the creator's official download folder. | `Houses_FirstAge_1_Level3.gltf` and `Dock_FirstAge.gltf`. Embedded geometry, two flat materials each, 1,028 and 388 triangles respectively. | Downloaded as individual glTF files. |

The [CC0 1.0 dedication](https://creativecommons.org/publicdomain/zero/1.0/) applies. License notices accompany the committed files with normalized line endings. The conversion reads static geometry and the color maps. Scripts, animations, example scenes, runtime code and Unity content are excluded. No Creator Store package was selected. Poly Haven's realistic surface treatment was screened out as a poor style fit. The Quaternius files were inspected in the real source-geometry comparison and excluded from the catalog to keep the architecture and props in one coherent family. [Poly Haven license](https://polyhaven.com/license)

## Selected catalog and intended use

The [44-entry catalog](../../assets/art/professional/BladeForestAssetCatalog.json) records the exact source names, triangle counts and bounding dimensions in meters. The [review sheet](../../assets/art/professional/BladeForestStyleReview.json) identifies the 11 assets prepared for the first Studio import. Both GLBs embed one 64 × 64 palette, with no external dependencies and no code. Studio part counts and mesh and texture permissions remain unverified. Each exported entry has a single glTF mesh primitive.

| Category | Selected assets and location |
| --- | --- |
| Trees and vegetation | 14 Timber and seven Frost trees, including distinct oak, stepped pine, mushroom and wide-tiered crown meshes. Uses the current tree IDs and forest slots. `plant_flatTall` and `flower_purpleA` for clearings and the village. |
| Rocks and terrain accents | `rock_largeC`, `cliff_blockSlope_rock` and source-authored tall facets at Portal Cliffs, the brook and the Frost skyline. |
| Buildings, shops and lodge | Cottage, workshop and Records Hall are assemblies of Kenney's authored shutters, arch, doorway and gable modules. Uses the current stations and board locations in Haven Village, Crafters' Plaza, Collectors' Row and Frostgate. |
| Bridges and paths | `bridge_woodRound`, `path_stone`, `path_stoneCircle`. Village brook, frost approach, plaza and arena paving. |
| Fences, props and signage | `fence_planksDouble`, `log_large`, `cart-high`, `lantern`, `stall-green`, `banner-green`. Village edge, shops, forestry and trailheads. Existing signs and prompts retain their functional text. |
| Water and waterfalls | `ground_riverStraight`, `cliff_waterfall_rock`. Brook, cliffs and mineral runoff. |
| Crystal formations | Kenney's `rock_tallF` and `rock_tallA`, adapted in teal and violet as mineral outcrops for the Colossus annex. A more crystalline silhouette remains a candidate for Studio review. |
| Snow and ice | Seven source evergreen meshes with cold palette grading, slate cliff pieces, tinted ruin modules and the Frostgate bridge. The frost palette is baked into the exported asset. |
| Ruins and boss approaches | `wall-broken`, paired segments of `wall-doorway-round` and `wall-wood-doorway-round`, plus stone pavers. Kingsfall, Colossus, Monarch and Sanctum. |
| Ambient, combat and portal VFX | `dirt_02.png` for chips, `slash_01.png` for slivers, `spark_01.png` for glints, `star_04.png` for snow and `smoke_04.png` for dust or shadow. Existing event triggers and budgets are reused. The PNGs are staged alongside their license. |
| UI icons | [Kenney UI Pack Adventure](https://kenney.nl/assets/ui-pack-adventure) is a CC0 candidate for future framing. Excluded from this build pending an in-client fit check. |

## Studio import record

| Prepared batch | Local result | Studio result |
| --- | --- | --- |
| Style review mesh sheet | 11 entries, 3,271 triangles, one embedded palette | Upload denied before asset creation |
| Full environment catalog | 44 entries, 11,553 total triangles, largest entry 1,348 | Awaiting comparison-scene acceptance |
| Five particle PNGs | Authored files selected and retained with their license | First image upload denied before asset creation |

The rejection came from Roblox Studio MCP's folder permission gate. No imported asset script was executed. Any future import belongs in ServerStorage quarantine, with a geometry-only audit and a client fetch check for every dependency before it is moved into the asset bank.
