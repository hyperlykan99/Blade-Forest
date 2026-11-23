# World edges and teleport integration

Private place `103379930563763` in universe `10777797608`. The v98 professional art remains the foreground in all three islands. This update adds a Woodland Valley around Timber, a mineral canyon outside the Crystal forest and annexes, and an alpine skyline around Frostbound. It reuses the nine verified Kenney mesh assets named in the [horizon design and asset manifest](INFINITE_HORIZON_DESIGN.md). No new asset IDs were required.

See the [teleport matrix](TELEPORT_VALIDATION.md) for actual client prompt input, server gate decisions, exact prepared thresholds, arrival positions and save checks.

## Evidence and structural checks

The eight functional entrances include both directions between Crystal and Frostbound and the two Colossus waypoints. Future gates remained decorative. All 45 center and perimeter arrival samples across the three islands and two waypoints had a collidable floor below, within 3–5 studs of their configured pivots. The imported landscape uses zero active decorative physics. Decorative scenery is anchored and normally does not collide, touch, query or cast shadows. Four reachable rim rocks have collision. The exterior recovery test used the authorized movement guard and returned the player to Frostgate.

The final Play build contained **124** horizon MeshParts, down from **159** in the first installed revision. They reuse nine source meshes and represent 11,550 source triangles across all three biomes, before Roblox LOD or occlusion. The scenery pack adds no textures. The active foreground retained the professional art bank. Both the final Play server and Edit-mode comparison found all 620 protected Crystal slots in the committed layout with a maximum horizontal difference of about 0.0001 studs. The other runtime counts were 300 Starter Grove, 900 Pine Forest and 830 Frost Peaks. The Crystal camera source was unchanged. Captures use actual Studio views.

## Performance

Before and after samples use a 957 × 532 logical viewport, Low graphics, Reduced Motion, fixed camera locations, a five-second settling period and about six seconds of RenderStepped sampling. The local Studio sessions may differ in workload. Frame times report observed wall time rather than rendering in production. Live draw-call counters and physical phone measurements were unavailable.

The initial 159-mesh installation was slower at all three viewpoints. In the same Play session, hiding the horizon increased five-second-sample rates from about 5.1 to 6.2 FPS in the Village, 5.0 to 6.3 FPS in Crystal, and 6.0 to 7.4 FPS in the Sanctum. That test retained meshes in the game process and cannot determine the memory cost of loading them fresh. The final composition consolidates the skyline arcs and uses fewer individual pine and mineral silhouettes.

| View | FPS before → final | P50 ms before → final | P95 ms before → final | Client MB before → final | Final resident horizon meshes / centers in frame |
| --- | ---: | ---: | ---: | ---: | ---: |
| Haven Village `(-52,14,-3023)` | 7.7 → 6.5 | 134.4 → 142.1 | 203.7 → 246.8 | 7,493 → 7,667 | 45 / 10 |
| Crystal Wilds `(2776,17,-48)` | 6.8 → 6.4 | 148.8 → 151.8 | 232.2 → 245.0 | 7,509 → 7,664 | 40 / 16 |
| Winter Sanctum `(6262,18,-12)` | 7.5 → 7.5 | 131.9 → 137.3 | 214.9 → 214.6 | 7,496 → 7,656 | 39 / 9 |

Streamed residency differed by region. The final client held 39–45 of the 124 horizon meshes at the sample points, and `GameplayPaused` was false after settling. Projected centers are a visibility proxy, before occlusion tests, and do not represent draw calls. Final performance recovered relative to the first horizon pass but still trails v98 at the Village and Crystal. Simultaneous arrivals, a confirmed streaming-time disconnect, and physical-device performance remain open. The normal camera can still see between the low-poly ridges looking directly over a few basin edges.

## Studio views

| Location | Before | After |
| --- | --- | --- |
| Timber Haven village | [Matched view](VILLAGE_BEFORE.jpg) | [Woodland Valley](VILLAGE_AFTER.jpg) |
| Crystal Wilds approach | [Matched view](CRYSTAL_BEFORE.jpg) | [Grand Crystal Canyon](CRYSTAL_AFTER.jpg) |
| Heart of Winter approach | [Matched view](SANCTUM_BEFORE.jpg) | [Alpine Wilderness](SANCTUM_AFTER.jpg) |

The Timber and Crystal pairs use Play captures with the horizon hidden for the before framing. The Sanctum before image was captured from the pre-change Studio build. The shots use the fixed benchmark camera positions. The [15-view district sweep](STUDIO_DISTRICT_REVIEW.jpg) uses the normal gameplay camera. It covers spawn, Haven Village, Sapling Woods, Pinewood Hollow, Elderpine Ridge, Kingsfall, Portal Cliffs, Crystal arrival and forest, Colossus annex, Frostgate, Snowfield, Aurora Basin, Monarch’s Throne and the Sanctum. The densest protected canopies and the existing Colossus pillars can fill the view at some close camera angles.

## Save and rollback

- Implementation commit `429f541e199a4cf85f4ecd618b6afaae4c876caf` on `world/teleports-and-infinite-horizons`.
- Studio confirmed the private rollback checkpoint **v99** before implementation edits, with original sources in `ServerStorage.WorldHorizonRollback`. Set `Workspace.BladeForestHorizons` to absent in Edit and restart to restore the baseline scenery. Restore **v99** to roll back both travel and the world update.
- Studio reported private cloud save **v105**. Open Cloud confirmed the update at `2026-11-23T00:40:15.182Z`. Studio was released in Edit mode with both QA attributes cleared and both test fixtures removed. The production place was untouched. The place was never published and trading, gifting and commerce stayed disabled.
