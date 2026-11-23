# Issue #1 — Premium visual makeover: M0 baseline and M1 first slice

**Author:** Claude · **Date:** 2026-11-23 (PST night of 22 → 23 Nov) · **Branch:** `art/claude-premium-makeover`
**Place:** private dev `103379930563763` / universe `10777797608` only. Production `73142469975141` was **not opened or changed** (Open Cloud `updateTime` still `2026-11-18T15:12:30.520Z`).

| Save | Meaning |
|---|---|
| **v107** | Rollback checkpoint taken before any edit. v106 (cloud update `2026-11-23T00:57:54Z`) was an undocumented save after Codex's recorded v105. |
| **v113** | M1 slice saved. Studio confirmed a Team Create cloud save; the version label was rejected by text moderation, so the version has no title. |

## 1. Status in one paragraph

M1 is **partially delivered**. The no-upload parts are built, tested and saved: living terrain ground, carved earth paths and cobbled plazas, a golden-hour lighting grade, a premium station-interaction card, the "Haven Guild" UI palette and an animated Trail Guide NPC. The part that would change the look most, **replacing the Kenney trees and station buildings with the approved Style A (KayKit) art, is blocked on upload batch M1-A**. KayKit is not on the Creator Store, so it must be uploaded to the owner's account first, and the issue requires separate approval for that. Everything new is behind a single switch and can be turned off.

## 2. M0 — verified baseline

- Studio instance: `Blade Forest - Island Dev`, Edit mode, Team Create. No other AI held the editor (the handoff showed it released).
- Docs read: `LIVE_HANDOFF.md`, `AI_HANDOFF.md`, `GAME_DESIGN.md`, `ISLAND_BLUEPRINT.md`, plus the newest branch handoffs (`world/teleports-and-infinite-horizons` v105, `art/professional-asset-rebuild` v98, `art/ultimate-visual-overhaul` v87).
- The world is built at **server start** by `ServerScriptService.M4WorldRuntime` from `ServerStorage.M4WorldSource`, behind Workspace attributes. The makeover follows the same pattern.
- Timber Haven: 760 × 640 plateau, top at y = 0. Districts: Haven Village, Crafters' Plaza, Collectors' Row, Sapling Woods, Pinewood Hollow, Elderpine Ridge, Kingsfall Arena, Portal Cliffs. 61 trail parts, 14 station foundations, 6 station prompts (`OpenPanel`).

### Worst visual defects found (before)

| # | Defect | Evidence |
|---|---|---|
| D1 | One flat plastic "Grass" slab for the whole island; no ground variation | [BEFORE_AERIAL_VILLAGE](BEFORE_AERIAL_VILLAGE.jpg) |
| D2 | Paths are flat brown strips floating on the slab | [BEFORE_MATCHED_CRAFTERS](BEFORE_MATCHED_CRAFTERS.jpg) |
| D3 | Trees are a lime/tan Kenney mix that reads as placeholder; conflicts with the approved Style A | [BEFORE_SAPLING_WOODS](BEFORE_SAPLING_WOODS.jpg) |
| D4 | Station buildings are near-identical Kenney cottages with candy pink/teal roofs; counters are hidden inside the shells | [BEFORE_SPAWN_PLAYER](BEFORE_SPAWN_PLAYER.jpg) |
| D5 | Flat midday lighting, no colour script | [BEFORE_MATCHED_VILLAGE](BEFORE_MATCHED_VILLAGE.jpg) |
| D6 | NPCs: every bandit is the same plaid avatar; the Blade King is a stock pirate-skeleton rig; no hub keepers at all | [NPC_AUDIT_BANDIT_BLADEKING](NPC_AUDIT_BANDIT_BLADEKING.jpg) |
| D7 | The Upgrades panel overlaps the currency pill, the Mastery bar and the RollBar; its buttons are still hard-coded lime | [AFTER_STATION_OPENED](AFTER_STATION_OPENED.jpg) (pre-existing, not changed in M1) |
| D8 | Station prompts use Roblox's default grey prompt | — |

## 3. Look-and-feel bible (Timber Haven)

- **Mood:** late-afternoon storybook forest village. Warm key light, cool blue-violet shadow fill, soft haze that hides the island edge.
- **Shape language:** Style A (KayKit chunky flat). Rounded silhouettes, readable at 40 studs, no thin details. Style B (Quaternius textured) only in separate themed zones (#9). Kenney is limited to props until it is recoloured or approved.
- **Ground:** short leafy lawn everywhere players act; tall wind-blown meadow grass only at edges and meadows, never on paths, around stations or inside choppable groves (gameplay readability first).
- **Paths:** worn earth with a darker wheel-rut centre and soft grass shoulders. Cobble only at village hearts and under building pads.
- **Palette:** grass `#709842`, meadow `#7CA446`, earth `#927450`, rut `#6E5840`, cobble `#928A7C`; UI walnut `#70482B` (dark `#382316`), emerald `#46AC60`, gold `#FFC854`, cream `#FFF6E4`.
- **UI:** one panel at a time (existing rule). Walnut cards with a thin gold edge, a cream key chip, a gold small-caps title and a cream action verb. World-space cards are depth-tested so they belong to the scene. Reduced Motion removes the pop and press bounce.
- **NPCs:** every hub role gets a keeper with a nameplate (name in gold, role below), an idle animation, and turn-to-face plus wave when a player approaches. No physics and no collisions; script-free rigs only.
- **Performance budget:** no new lights except one small NPC lantern light, no particles in M1, terrain instead of parts.

## 4. What M1 changed (all private dev, all behind `Workspace.BladeHavenMakeover = "m1"`)

| Object / script | Change | Source in repo |
|---|---|---|
| `ServerStorage.HavenMakeover` (new ModuleScript) | Terrain lawn (LeafyGrass) 0.4 studs above the plateau, 140 meadow-grass patches outside keep-clear zones, 61 trails converted to earth/rut paths, 19 pads (foundations, rivers, pavers, bridge), 2 cobbled plazas, flat Kenney ground meshes lifted 0.42, Ranger Wren NPC, 6 station prompts switched to the custom card | `src/serverstorage/HavenMakeover.luau` |
| `ServerScriptService.M4WorldRuntime` | 5-line pcall hook at the end, gated by the flag | `src/server/M4WorldRuntime.luau` |
| `StarterPlayerScripts.HavenStationCards` (new LocalScript) | Station interaction card (keyboard, gamepad and touch; hold-fill; press feedback; Reduced Motion aware). Falls back to the default prompt if anything errors | `src/client/HavenStationCards.client.luau` |
| `StarterPlayerScripts.ForestPresentation` | Timber Haven golden-hour grade (flag only). Other islands are untouched | `src/client/ForestPresentation.client.luau` |
| `ReplicatedStorage.UITheme` | "Haven Guild" palette for the existing keys (flag only). No layout or binding change | `src/shared/UITheme.luau` |
| `Workspace.Terrain.Decoration` | Turned on (animated grass renders only on the Grass material, which exists only in the meadow patches) | — |
| `ServerStorage.HavenMakeoverRollback` | Pre-edit copies of `M4WorldRuntime`, `ForestPresentation` and `UITheme`, with their original paths | — |
| `ServerStorage.HavenMakeoverQuarantine` | Empty. The 3 Creator Store candidates were deleted, see §7 | — |

All 5 scripts in Studio match the repo files byte for byte (length and a rolling hash, checked after the save).

## 5. Before / after (same camera, Studio Play)

| View | Before | After |
|---|---|---|
| Arrival, player camera | [BEFORE_MATCHED_VILLAGE](BEFORE_MATCHED_VILLAGE.jpg) | [AFTER_MATCHED_VILLAGE](AFTER_MATCHED_VILLAGE.jpg) |
| Crafters' Plaza from above | [BEFORE_MATCHED_CRAFTERS](BEFORE_MATCHED_CRAFTERS.jpg) | [AFTER_MATCHED_CRAFTERS](AFTER_MATCHED_CRAFTERS.jpg) |
| Village overview | [BEFORE_AERIAL_VILLAGE](BEFORE_AERIAL_VILLAGE.jpg) | [AFTER_AERIAL_VILLAGE](AFTER_AERIAL_VILLAGE.jpg) |
| Station interaction | default prompt | [AFTER_STATION_CARD](AFTER_STATION_CARD.jpg) |
| Trail Guide | no keeper | [AFTER_NPC_RANGER_WREN](AFTER_NPC_RANGER_WREN.jpg) |

## 6. Tests (Studio Play, one client, owner dev profile)

| Test | Result |
|---|---|
| Startup with the flag on | `HavenMakeover` applied: Trails 61, Pads 19, MeadowTufts 140, Prompts 6, NPC spawned. No errors from the module |
| Startup with the flag off | Identical to v107 (no `HavenMakeover` folder; old visuals) |
| Chop loop, Sapling Woods | Walked a 5-point loop for 21 s: **Logs +1,008**, grove trees 264 → 247 felled, **247 → 252 regrown** after 20 s |
| Station interaction | Card appears at the Upgrade Hall counter; pressing **E** opened the Upgrades panel |
| NPC | Feet on the ground (bottom y = 0.40); idle and wave tracks playing; turns to face the player |
| Terrain readability | No meadow grass on paths, plazas, pads or forest plots (keep-clear rules) |
| Travel | `DevTravel` to Timber Haven; `CurrentIsland` = TimberHaven; lighting switched to the new grade |
| FPS, arrival, Studio, 957 × 532 | **Before 14.4 fps** (median 67.1 ms, p95 85.2 ms, 5,103 MB) → **after 14.1 fps** (median 66.9 ms, p95 92.1 ms, 5,127 MB). Within noise. Studio is a slow baseline, not a device measurement |

**Not tested:** physical iPhone/Android, gamepad, two clients, the touch path of the card (code path present, not exercised on a device), and the Studio Device Simulator.

## 7. Asset sources and licences

- **Terrain, lighting, UI:** built in engine. No assets.
- **Ranger Wren:** `ServerStorage.NPCModels.RogueLumberjack` (existing script-free R15 rig; its shirt and pants were removed and the parts recoloured). The lantern is the existing uploaded Kenney `ProfessionalArtAssets.Lantern` (CC0, see `docs/art/PROFESSIONAL_ASSET_MANIFEST.md`). Animations are Roblox stock R15 idle `507766388` and wave `507770239`.
- **Creator Store candidates rejected:**
  - `133018947900385` "Park Ranger" contained the known backdoor pattern (`OriginalPosition.Runtime.RuntimeInput…ScreenBuilder`).
  - `127600453910354` and `119979604721760` (cube3D) are procedural generators that render "OOF!" placeholders.
  - All three were inserted sandboxed into the quarantine folder and then **deleted**. None reached Workspace.

## 8. Initial asset picks from the vault (Style A, CC0, local paths verified in `HEX-Forge-Master-Vault/collections/blade-forest-shortlist.csv`)

| Role | short_id · name |
|---|---|
| Choppable trees | `a4a3072d5e20` Tree_1_A · `f33c03e79d74` Tree_1_B · `f33e293a089d` Tree_2_A · `ad470c400603` Tree_2_C · `e2a97ef2677e` Tree_2_E · `1b2b2e90e499` Tree_3_A · `5eb7d2c7028c` Tree_4_A |
| Chopped state | `c90a41e78cf4` Tree_Bare_1_A · `4486ca8127ac` Tree_Bare_2_B · `510c75dd0f39` tree_single_A_cut · `25b6f0830285` trees_A_cut |
| Undergrowth / rocks | `208520ceed31` Bush_1_E · `86df089c5ede` Bush_3_A · `4f284dccfda5` Grass_2_C (single-sided) · `4f163642914e` Rock_1_J (cliff) · `4337604abbf0` Rock_3_K |
| Stations | `d6be04f2adef` market (Log Market) · `7d965075dbd6` blacksmith (Forge Workshop) · `ae022406de00` lumbermill (Upgrade Hall) · `275a50521f39` tavern (Village Records) · `babba4cf0762` tower A (Trail Guide) · `c3ba4792d246` home A (Haven Lodge) · `9f1fb649d89e` well (plaza centrepiece) |
| Props / rewards | `737a3af41d59` fence_wood · `d72ac01f2d9b` resource_lumber · `ce24860bc28c` Wood_Log_Stack · `9c89a1591700` barrel · `5cd4fb4ff5dd` crate_A_big · `cdf778581e89` wheelbarrow |

KayKit hexagon buildings are about 3–6 studs tall at import scale, so they will be scaled roughly ×5 to fit the existing 20 × 16 station footprints.

## 9. Upload batch M1-A (awaiting owner approval; nothing has been uploaded)

Three private Model assets on the owner's account (user 394034825), each one GLB packed from the CC0 vault files with one shared texture:

| # | Asset name | Contents | Textures |
|---|---|---|---|
| A | `BF_StyleA_Forest` | 14 trees, 6 bare trees, 8 bushes, 12 rocks and cliff pieces, 4 grass tufts (44 meshes) | 1 (`forest_texture.png`) |
| B | `BF_StyleA_Village` | 11 blue-roof buildings, 5 fences, bridges and stages, 16 props, 4 chopped stumps (36 meshes) | 1 (`hexagons_medieval.png`) |
| C | `BF_StyleA_Resources` | 10 logs, planks and reward pieces | 1 (`resource_bits_texture.png`) |

Free and not public. Each will be inspected after upload (no scripts, triangles, scale, pivot), placed only through `HavenMakeover`, and recorded with its real asset ID.

## 10. Work queue

1. **After M1-A approval:** upload, then swap Timber Haven tree visuals (keep the existing hitbox and trunk collider, as the v98 Kenney swap did); replace the 14 station shells with KayKit buildings plus counter dressing; add path-side props and chopped-state stumps. Re-capture the before/after set.
2. Edge pass: KayKit cliff rocks along the plateau rim, soften the basalt shelf, and frame the Portal Cliffs ridge.
3. Keepers for each existing station role (Log Market, Upgrade Hall, Forge, Gallery, Pets, Traits, Altar), using the Ranger Wren pattern.
4. UI: fix the D7 overlap (the panel must clear the top bar and RollBar); restyle the RollBar and currency pills to the walnut/gold system; replace the hard-coded lime buttons.
5. Retire the old "INTERACT" counter billboards once every counter has a card.
6. Device pass: Studio Device Simulator (iPhone SE / 15 / iPad), touch on the card, then a physical phone when the owner can.

## 11. Rollback

- **Fast:** clear `Workspace.BladeHavenMakeover` in Edit and start a new session. The world returns to the v105/v107 look; the new scripts become no-ops.
- **Script level:** copy the sources from `ServerStorage.HavenMakeoverRollback` back to their `OriginalPath` attributes, then delete `ServerStorage.HavenMakeover` and `StarterPlayerScripts.HavenStationCards`.
- **Full:** revert the private place to **v107** in version history. `Terrain.Decoration` was set at edit time and is reverted by v107 or by turning it off.
