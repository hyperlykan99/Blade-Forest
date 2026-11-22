# Blade Forest visual style bible

## Art direction

Blade Forest is a woodland trade route that climbs from working villages into mineral country and an abandoned alpine kingdom. The landscape and buildings share low-poly facets, matte materials, readable silhouettes and human-scale entrances. At a distance, each biome should have a memorable skyline. At ground level, the next path and interaction should be obvious.

Use **Kenney Fantasy Town Kit 2.0** and **Kenney Nature Kit 2.1** as one primary design family. They agree on silhouette simplicity, flat color surfaces and modular scale. Kenney's Particle Pack supplies complementary graphic accents. The Kenney family was selected after comparing actual Kenney and Quaternius geometry. Quaternius's Fantasy RTS house and dock are useful references. The selected Kenney kit has a more consistent match across open shop façades, trees, paths, landscaping, bridges and water. [Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit) · [Nature Kit](https://kenney.nl/assets/nature-kit) · [Particle Pack](https://kenney.nl/assets/particle-pack) · [Ultimate Fantasy RTS](https://quaternius.com/packs/ultimatefantasyrts.html)

## Shared visual language

| Element | Direction |
| --- | --- |
| Architecture | Shuttered timber walls, sloping gables, readable arches and open counters. Use the same floor and window rhythms in villages, outposts and ruins. Worn stone plinths ground buildings in the terrain. |
| Vegetation | Rounded broadleaf in beginner areas, stepped conifers in the midgame, wide and irregular crowns for special trees. Distinguish a top-tier tree by its silhouette and crown structure. |
| Surface response | Matte albedo, low reflectivity and broad color blocks. Keep source surface detail where supported. Keep bright accents on small focal details. |
| Color | Timber uses cedar, moss and ochre. Crystal adds cool graphite, pale teal and dusty violet. Frost shifts to slate blue, cold gray and weathered wood. Amber identifies places of shelter and service across the three islands. |
| Scale and light | Read buildings from character height. Raise the skyline around protected perimeters. Keep gates, boss telegraphs and path intersections open. Use stable light and contrast to direct attention. |
| Interface | Keep existing controls. Use physical, short signs at the approach and readable text over decorative iconography. Preserve text contrast and large touch targets. |
| VFX | Dry chips and slivers for everyday chopping. A faceted glint for rarity, a steady pale shape for cold, a soft muted puff for shadow. Preserve clear warning areas and use restrained trails to keep weapon silhouettes visible. |

## Site composition

- **Haven Village** opens on a view of the Records Lodge and brook. The cottage front and market stalls frame the entry path. One bridge and a few props establish the village scale. Crafters' Plaza and Collectors' Row reuse the same shop modules and garden forms. The eight Timber districts each retain their existing functional roles.
- **Sapling Woods** reads as a low broadleaf edge. **Pinewood Hollow** uses layered conifer heights and a quieter palette. **Elderpine Ridge** uses larger silhouettes, older logs and a few recognizable top-tier trees. Keep the existing tree-free buffers, and place accents at trailheads or in clearings.
- **Kingsfall** uses low ruined walls and a clear combat floor. **Portal Cliffs** uses related arch profiles to frame travel prompts. The Records Lodge uses the existing board models and rows.
- **Crystal Wilds** keeps the protected grove. Place geology and ruins around the Colossus annex perimeter and low at the approach. Use matte mineral accents and preserve the camera sightline through the forest.
- **Frostbound Reach** uses cool recolors of the common tree family, layered authored slopes and broken ribs around the Monarch and Sanctum approaches. Keep the party entry, boss sightline and refuge routes clear.

## Technical limits

One mesh primitive per catalog entry. Reuse the catalog palette and its Woodland grade for repeated meshes. Reuse the same asset IDs for repeated vegetation. Keep current authoritative hitboxes and routes. Stage the real models together at player height before placement. Review shape and scale, texture availability, clipping, collisions, path access, falling animation and visual readability in the Roblox client. The imported player-height comparison is the in-engine reference. [Studio comparison](KENNEY_STUDIO_COMPARISON.jpg)
