# Infinite horizon design

The horizon uses the private place's verified Kenney Nature Kit and Fantasy Town mesh bank. It extends the three biomes outward with matte sculpted relief. The islands retain their original playable footprint, tree slots, arrival anchors and fog settings. The entire distant scene is created once at startup. Restore the previous composition by clearing `Workspace.BladeForestHorizons` and restarting the server.

| View | Foreground | Mid-distance | Skyline |
| --- | --- | --- | --- |
| Timber Haven | Existing village and forests, with authored stone at selected corners | Moss-green slopes, a wooded outflow and a waterfall in the southeast gorge | A low valley opening between layered muted green ridges |
| Crystal Wilds | Original crystal grove, plaza and camera, with a new outward route adjacent to the plaza | Graphite terraces and mineral faces set back from the Colossus and Hydra annexes | Blue-gray canyon relief with an open view through the low points |
| Frostbound Reach | Existing Frostgate and arena paths with selected ice-rock rim outcrops | Cold slate shelves, a frozen cascade, and a distant ruined watch | Overlapping pale alpine ridges and high glacier silhouettes |

Background models use anchored meshes with collision, touch, queries, and shadows disabled. Four isolated edge rocks retain collision and no touch. Arrival floors, physical boundaries and combat telegraphs use their existing sources. Exterior fall recovery runs inside the existing server area loop and returns the character to the registered island's arrival without changing saved island state. Travel, handoff and private run participants are excluded from recovery. No new lights, particles, textures or active scenery scripts were installed.

## Assets

All meshes came from the verified private catalog model `108287874035412`. The horizon uses the original mesh topology and graded matte colors with no texture downloads. The imported meshes appeared on the original [Kenney project pages](https://kenney.nl/assets/nature-kit) and [Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit). The source assets were offered under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). See the [professional asset manifest](../art/PROFESSIONAL_ASSET_MANIFEST.md) for the source archives and licenses.

| Runtime asset | Source usage |
| --- | --- |
| Cliff and Boulder | Irregular relief, slopes and edge rock |
| Spruce | Small groups of distant tree silhouettes |
| CrystalSpine | A few mineral faces outside gameplay |
| Waterfall and River | Timber outflow and glacier continuation |
| RuinedWall | Alpine landmark |
| GateArch and Pavers | New Frostbound entrance on the Crystal plaza |

Source names, triangles and matching uploaded Roblox mesh IDs are in the [catalog](../../assets/art/professional/BladeForestAssetCatalog.json) and [Roblox asset IDs](../../assets/art/professional/STUDIO_ASSET_IDS.json).
