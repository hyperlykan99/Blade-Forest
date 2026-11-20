# P1b.2r — Camera visibility fix (Option C on top of Option A) — results

**Status:** implemented and tested on the **dev place only**, one Studio client. Not merged, not published. Awaiting owner review.
**Date:** 2026-11-19 (PST). **Author:** Claude.
**Approval:** "OWNER APPROVAL GRANTED — OPTION C ON TOP OF OPTION A".

## Where things are

| Item | Value |
| --- | --- |
| Dev place | `103379930563763` / universe `10777797608` (PRIVATE), asserted before every Studio write |
| Checkpoint before the fix | **v16** (Studio-reported save of the unmodified v15 state) |
| Saved result | **v18** "P1b.2r camera visibility fix (ChopEffects canopy fade + label tiers)" (Studio-reported; Team Create save). Dev Open Cloud `updateTime` after save: `2026-11-20T05:52:14.927Z` |
| Version gap | Studio returned **v18**, not v17. No Studio save was made by Claude between v16 and v18. v17 is **unexplained** (possibly a Team Create autosave). Owner: please check Version History |
| Production | `73142469975141`: `updateTime` `2026-11-18T15:12:30.520Z`, re-checked via Open Cloud 2026-11-19 21:53 PST. **Unchanged** |
| Branch | `p1b2r/camera-visibility-fix` (from `p1b2r/dense-forest` @ `a893300`) |

## Script changed

Only `src/client/ChopEffects.client.luau` ↔ Studio `StarterPlayer.StarterPlayerScripts.ChopEffects` (LocalScript).

| | Bytes | Adler-32 |
| --- | --- | --- |
| Before | 18,500 | 3640422855 |
| After (repo = Studio) | 27,331 | 1017905967 |

Pre-fix copies: `docs/p1b2r_camera/ChopEffects_PreCameraFix.client.luau.txt` and Studio `ServerStorage.P1bBackups.ChopEffects_PreCameraFix` (Disabled LocalScript).

All other scripts were re-checked after the session and still match their baseline:
WorldServer 14591:830933556, TravelService 9388:3611788483, DataService 19574:676054173, CombatServer 20797:1888490247, BladeConfig 55586:167717973, TreeKit 5038:3027397391, AutoChop 12453:155288051, MetaController 24621:3138427195.

## What the fix does

Section 1 of ChopEffects ("Strength tags") became "Strength tags + canopy visibility":

- **Independent canopy registry.** Trees within 90 studs are registered and dropped beyond 110 studs. Registration works with tags OFF. For each tree it caches the leaf parts (every BasePart except `Hitbox`), the canopy radius and the height band. It re-measures when a tree grows in or changes scale, and it releases references when a tree is removed, chopped or streamed out.
- **Canopy-aware obstruction test** at about 11 Hz (0.09 s). For each tree, it checks the canopy cylinder against two camera rays: camera to head, and camera to hip.
  - If the canopy blocks a ray, it fades to `LocalTransparencyModifier` 0.90.
  - If the canopy is within 3.5 studs of a ray without blocking it, it fades to 0.72.
  - Hysteresis is 0.35 s, with smooth steps of 0.45 up and 0.25 down.
  - The modifier is written only when the value changes.
  - It is client-local only: no `Transparency` or server-replicated changes.
- **Label tiers**, updated every 0.3 s:
  - Tier 1 (Legendary, Mythic, Secret, Divine, mutated): 90 studs, uncapped.
  - Tier 2 (Rare, Epic): 48 studs.
  - Tier 3 (Common, Uncommon): 24 studs, extended to 48 when the tree is locked or was struck in the last 3 s.
  - Caps are 16 labels in compact layouts and 24 otherwise; Tier 1 is uncapped.
  - Any label that would sit over the character is hidden.
  - `BillboardGui.Enabled` is toggled only on change.
- **`Pref_ShowTags`**: when ON, labels follow the tiers; when OFF, all labels are removed. Fading works in both cases. No new setting or menu was added.
- **Diagnostics** are script attributes, refreshed every 2 s: `VisRegistry`, `VisTags`, `VisFaded`, `VisLabelsTier1`, `VisLabelsOrdinary`, `VisLabelsHiddenOverChar`, `VisLabelCap`, `VisFadeMsPerTick`.
- **Unchanged:** shake, falling trees, logs, gates. The Hits handler only records `lastStruck` for the local player's hits.

## Test results (one local Studio client, MacBook; blades OFF except C6)

| Test | Result | Evidence |
| --- | --- | --- |
| C1 Z2 standing and walking | **Pass** | Character fully visible (was a faint silhouette at v15). 14 trees faded. Non-blocking trees stay opaque, with no "tunnel" effect. reg 181, tags 155, labels 10 T1 + 16 ordinary, 2 hidden over character, fade 0.47 ms/tick |
| C2 Z3 standing and walking | **Pass** | Character visible while standing and running toward the camera. reg 182, 14 faded, labels 13 + 16, 1 hidden, 0.52–1.23 ms/tick |
| C3 Z1 and Z4 | **Pass** | Z1: reg 221, 9 faded, labels 10 + 16, 2 hidden. Z4: reg 145, 12 faded, labels 9 + 16, 1 hidden. Character visible in both |
| C4 tags OFF and back ON | **Pass** | OFF: 0 tags and 0 enabled tag GUIs, fading still active (12 faded). ON: labels returned (10 + 16). Tested with a client-local attribute, so the saved preference was not touched |
| C5 caps, Tier 1, hide-over-character, locked | **Pass (compact cap); 24-cap unverified** | Ordinary labels sat at the 16 cap in every zone; Tier 1 labels (e.g. MYTHIC 🔒2,100 locked) were shown beyond the cap. The Studio viewport was 957×532, which counts as compact, so the 24 cap was not exercised |
| C6 regrowth / no leaked references | **Pass** | Blades ON for 4 s chopped 2 trees. After regrowth the registry (150) exactly matched the live tree count within 90 studs. After moving Z3→Z1→Z4→Z2, 0 parts had LTM > 0 beyond 110 studs. In Edit, 0 parts had LTM > 0 |
| C7 Graphics Low / Medium / High | **Pass** | Fading and labels identical across modes (reg 150, 12 faded, 10 + 16 labels); shadows followed the preference. Client-local attribute only |
| C8 performance | **Pass (Studio only)** | Z2 standing 14.6 FPS, walking 14.2–14.6 FPS (worst frame 106–117 ms), against an 8.4 FPS Z2 baseline at v15. Fade pass 0.38–1.23 ms per tick. **MacBook Studio FPS is not representative of iPhone** |
| C9 regressions and console | **Pass with limits** | No ChopEffects errors or warnings. The only console output was the two existing `leaderstats` infinite-yield warnings (AFKController:34, PvPSoulController:156). Strength/lock labels read correctly. Travel UI was not exercised: no travel code was touched, and travel would change the dev save's island |

Screenshots were captured during testing (C1_Z2_walking, C2_Z3_standing, C2_Z3_walking, C3_Z1_standing, C3_Z4_standing, C4_tags_off). They are not committed.

## Trees

In Edit after the session, all **620 / 620** Crystal Wilds trees matched `docs/p1b_tree_spots_crystal_wilds.csv` within 0.06 studs. There were 620 trees in the zone box, 5021 Breakables in total, and `Islands.P1b2rMoved = true`. There were no density, position, count or scale changes.

## Save data (dev DataStore, test account)

| | Before | After |
| --- | --- | --- |
| Logs | 9 | 6,255 |
| Stats.TreesChopped | 3,329 | 3,331 |

The C6 regrowth check needed one 4 s chop, which removed 2 trees as ordinary gameplay. That changed the dev save's Logs and TreesChopped. No reset, restore or manipulation was done. Preferences (`Pref_ShowTags`, `Pref_Graphics`) were changed client-locally only, so the server and save values were not changed.

## Not verified

- iPhone or other touch devices: **not tested**.
- Two-player.
- The non-compact 24-label cap.
- Travel UI.
- The v17 version gap.

## Not done (out of scope)

The following were not done:
- publishing;
- a merge into `main`;
- production changes;
- B1 respawn lighting;
- graphics settings;
- P1b.3 and later phases;
- asset imports.

## Rollback

There are two ways back:
- Studio: copy the source of `ServerStorage.P1bBackups.ChopEffects_PreCameraFix` into `StarterPlayerScripts.ChopEffects` (18500:3640422855).
- Or revert to dev place **v16**.
