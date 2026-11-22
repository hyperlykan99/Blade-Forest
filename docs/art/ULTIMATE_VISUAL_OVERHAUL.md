# Blade Forest — Project Wow Factor

This pass gives the three existing islands different silhouettes, color temperatures and landmarks. Ambient effects stay local and quiet so a rare tree, weapon or encounter can command attention.

| Biome | Art direction and landmarks |
| --- | --- |
| **Timber Haven · Lanternwood** | Warm afternoon light, muted timber roofs, amber lanterns and mounted wayfinding. A carved hammerbeam frames Haven Village. Alder Brook winds past the Records Lodge under a plank footbridge. The lodge has a copper-green canopy, gallery posts and a framed sign. Foxgloves and moss dress the village and mill courtyard. Pinewood Hollow hides a firefly dell, and Elderpine Ridge has a fallen nurse log with shelf mushrooms. Kingsfall has a ring of carved floor marks and watch fires. Gate keystones mark the two active destinations at Portal Cliffs. |
| **Crystal Wilds · Prismglass** | Silvery blue light over the original forest, low crystal outcrops near the encounter entrance, and a split geode around the Colossus annex. Teal and violet mineral faces, a cold mineral cascade and floor inlays draw the eye toward the boss. The Crystal tree positions and camera source were retained. |
| **Frostbound Reach · Crown of Winter** | Blue-hour lighting and a two-ribbon aurora behind the glacier horizon. Amber beacons mark the Frostgate refuge. Tall broken crystals frame Monarch's Throne. The Heart of Winter approach has broken vault ribs, hanging ice, a recessed diamond keystone and pilgrim floor marks. The shrine's sign now states the existing Winter Key and player-count requirements. |

The previous Timber art remains the tree collection. New scenery comes from native Roblox parts and materials. The pass retains the three vetted Timber source models and their six mesh IDs from the [tree manifest](timber-tree-asset-manifest.json). It imports no new Creator Store packages. The foliage glints, powdered ice and impact dust use Roblox's stock sparkles and smoke textures. Alder Brook reuses waterfall audio asset `9120550180` from the M4 build. No new mesh, texture, sound upload or permission change was required.

## Impact, weapons and mutations

- Tree impacts send short wood-chip and leaf bursts in Timber and colder sparks in the other biomes. Falling trees and rare kills share a reusable effect pool. Rare and mutated falls add a brief colored ground pulse for the player who earned the cut. Logs feedback still comes from the existing client and reward systems. Damage numbers have a distance limit and a short per-target interval to avoid covering the forest during sustained chopping.
- All **120 permanent weapon IDs** had a model with renderable parts in Studio. Cleaner trails preserve each weapon's existing authored color and shape. The enhanced detail is limited to the local primary blade. Legendary and later tiers keep recognizable auras, Secret retains iridescence, and Divine uses a warm-edged trail and a slower shimmer. Shiny blades and all three Awakening tiers retain separate visual cues. Nearby characters retain trails and can be seen fighting. Distant weapon effects are culled.
- Golden has warm metallic foliage and gold glints. Frozen keeps ice material and adds cold powder. Shadow uses violet smoke, and Rainbow combines its iridescent foliage with aqua and rose sparkles. The art switch replaces permanent mutation emitters with short pulses on nearby trees. Mutation selection, strength requirements, health, rewards and rune multipliers use the existing rules.
- Blade King, Crystal Colossus, Frost Monarch, Ancient Treant, Crystal Hydra, Frost Giant and Heart of Winter have individual encounter palettes and captions. Their existing server signals drive the phase cues and wind-up and impact effects. The notification card sits out of the combat sightline. Danger disks retain their original positions, radii and damage timing. The original reward and eligibility code remains authoritative.

## Studio verification

All 11 new or modified Luau sources compiled and matched the committed source checksums in the private Edit model.

The private play sessions used the isolated QA profile. Review views covered the village and lodge, approach to the active travel gates, Pinewood Hollow, Elderpine Ridge, Kingsfall, the Crystal forest and Colossus annex, Monarch's Throne and the Sanctum. Before-and-after Studio viewport captures were taken in the session. The village capture showed the change from floating navigation signs to mounted plaques, more restrained timber roof colors and a visible path toward the brook. The combat review exposed an overlapping boss caption and stacked damage numbers. Both were revised. The forward spike at Monarch's Throne was removed and the clear approach was confirmed in the final Play review.

The final startup survey verified **1,200 Timber**, **620 Crystal** and **830 Frostbound** trees and matched the QA Crystal position checksum `620:1325136453` before combat. The **424** new scenery parts were noncolliding, non-touching and non-queryable. The detached mutation fixture verified the four existing health and reward multipliers on Frost Crystal. The real play client observed **30** Timber hits on trees and **30** corresponding falling-tree events. The isolated profile defeated Crystal Colossus, Frost Monarch and Blade King. The client observed their three server Logs reward notifications. The Colossus wind-up disk and Frost Monarch's repositioned phase card were visible in combat.

The live raid rotation and private Heart encounter were not played through to victory in this art pass. The visual cue integration for those encounters was checked in source and compiled. Physical-device performance, long-session rendering and a full multiplayer review remain open.

## Performance

Both benchmark runs used one Studio client, the same **957 × 532** viewport, identical fixed camera poses, Low graphics and Reduced Motion. Each sample began after streaming paused-state cleared and a five-second settle. Frame deltas came from `RenderStepped` for about six seconds. The after run preceded the final damage-number cap and removal of the Monarch approach spike. These samples vary substantially, and the result is a local Studio observation.

| Camera position | FPS before → after | Median frame time before → after | p95 before → after | Reported client memory before → after |
| --- | ---: | ---: | ---: | ---: |
| Haven Village `(-52, 14, -3023)` | 5.0 → 5.7 | 182.0 → 150.6 ms | 416.8 → 340.0 ms | 7,044 → 7,084 MB |
| Crystal Wilds `(2776, 17, -48)` | 6.2 → 5.8 | 150.5 → 157.2 ms | 347.4 → 355.5 ms | 7,064 → 7,081 MB |
| Winter Sanctum `(6262, 18, -12)` | 6.9 → 6.3 | 143.4 → 154.3 ms | 242.3 → 323.4 ms | 7,025 → 7,052 MB |

The effect ceiling is 18 reusable burst markers and three reusable ground pulses per client. Bursts also share a token budget. Blizzard uses the existing weather effect plus the colder local grade, and disables normal snowfall while the Blizzard is active. Low removes the new particle emissions, secondary trails, aurora and post-processing highlights. Reduced Motion omits the moving ground pulses, shake and cinematic fades, with shorter falling-tree styling. New scenery has no dynamic lights and needs no mesh downloads. The slower Frost frame times remain an open performance issue.

## Preservation and rollback

World V2, Timber art v1, the protected Crystal layout, all progression systems, traversal prompts and arrival points stay active. Player saves and inventories are unchanged by the implementation. Studio's isolated QA profile was used for test rewards. Trading and paid gifting remain disabled.

- Repository baseline `art/timber-haven-tree-overhaul` at `ab9d9969abafa6a722a553b586015c6ec33bbea1`, containing Timber implementation `85167c9acecadf205f6f62907839442fdd2a38b3`.
- Checkpoint cloud timestamp `2026-11-22T06:12:52.630Z`. `ServerStorage.UltimateVisualRollback` contains the pre-pass source copies. Clear `Workspace.BladeForestArt` and restart the private Studio session to return to the previous Timber art while retaining v2.
- Implementation commit `56c23ffb1ca70ea15b45457af045a770bf4cdba9` on `art/ultimate-visual-overhaul`.
- Cloud-saved private development **v87** on place `103379930563763`, universe `10777797608`. Studio confirmed the save and Open Cloud reported `2026-11-22T06:37:43.778Z` (10:37 p.m. PST on November 21). `Workspace.UltimateVisualDevBuild` records the implementation SHA. Studio left in Edit mode with the QA switch cleared and the editor released.
