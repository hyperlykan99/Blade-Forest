# Blade Forest — P1b.2r Camera Visibility Review (PROPOSAL)

**Status:** read-only research and design. **Nothing has been implemented.**
- No Roblox Studio objects, scripts, terrain, trees or player data were changed. Nothing was saved or published.
- No existing GitHub docs were modified. The handoff corrections in §10 are **prepared patches only** (`handoff_patches/`). They are not applied.

**Date:** 2026-11-19. **Author:** Claude, for owner review.

**Inputs read:**
- `docs/p1b2r/P1B2R_RESULTS.md`
- `docs/proposals/p1b2_dense_forest/P1B2_DENSE_FOREST_DESIGN.md`
- `LIVE_HANDOFF.md`, `AI_HANDOFF.md`, `CURRENT_STATUS.md`, `CHANGELOG.md`, `TASKS.md` on `main` (`25260c2`), `p1b2r/dense-forest` (`a893300`) and `proposal/p1b2-dense-forest` (`63937f9`)
- `src/client/ChopEffects.client.luau`
- `src/client/MetaController.client.luau`
- `src/server/DataService.luau`
- `src/gui/UIController.client.luau`
- `src/client/UIStyler.client.luau`

**Labels:**

| Label | Meaning |
|---|---|
| **[SOURCE]** | Read in the committed scripts (`p1b2r/dense-forest`) |
| **[MEASURED]** | Measured in Studio during P1b.2 / P1b.2r |
| **[ENGINE]** | Documented Roblox camera-module behaviour |
| **[ESTIMATE]** | Calculation, not tested |
| **[HYPOTHESIS]** | Plausible, needs verification |

**Locked requirements respected:**
- dev v15;
- 620 Crystal Wilds trees in four dense zones (6-stud hex lattice) plus four 5-tree pockets;
- no change to tree positions, density, blade reach, combat, health, rewards, rarity odds, respawn or economy.

---

## 0. Summary

The character becomes a faint silhouette in Z2 Gorge Grove and Z3 North Shardwood for two reasons:
- **Stacked opacity.** The current fade leaves every faded canopy surface 28% opaque, and several stack on the camera line.
- **Labels at body height.** Every tree's Strength/rarity label sits at character torso/head height and keeps a fixed on-screen size.

The fade also has a real bug: **turning "Tree Strength Tags" off disables canopy fading entirely.** The default `Zoom` camera cannot help, because Roblox only treats `CanCollide` parts as camera obstructions and no tree part collides.

**Recommendation: Option C built on Option A.** It is a client-only change to `src/client/ChopEffects.client.luau`:
1. decouple fading from tags;
2. use a canopy-aware line-of-sight test;
3. fade trees on the line more strongly (about 0.9);
4. hide labels on blocking trees or over the character;
5. cap low-tier labels while always keeping rare and mutated labels.

No server, tree, TreeKit, combat or economy changes.

---

## 1. Root-cause analysis (Z2 / Z3 obstruction)

1. **The default camera never avoids trees.** [ENGINE] [MEASURED]
   - `StarterPlayer.DevCameraOcclusionMode = Zoom` [MEASURED]. Roblox's Popper (`PlayerModule.CameraModule.ZoomController.Popper`) uses `canOcclude(part)`, which requires the part to be mostly opaque (`getTotalTransparency(part) < 0.25`), **`part.CanCollide`**, and not part of the character.
   - Every tree part has `CanCollide = false` [MEASURED, P1b.2r §2.2]. So the camera always sits behind, or inside, canopies.
   - All visibility depends on the custom fade in ChopEffects.
2. **Faded canopies still stack.** [SOURCE] [ESTIMATE]
   - The fade sets `LocalTransparencyModifier = 0.72` on every non-Hitbox part of a blocking tree. Leaves are opaque Ice icospheres (transparency 0), so each faded surface stays **28% opaque**.
   - At the measured spacing (nearest neighbour about 5.2 studs, density about 1 tree per 31 st²), a camera-to-character line of about 12.5 studs crosses about **4–5 canopies** (canopy radius about 5.6 × scale), each with several overlapping leaf meshes.
   - Remaining visibility is roughly 0.72^k for k faded surfaces: **27 % at 4, 14 % at 6, 7 % at 8**. This matches the "faint silhouette" in the P1b.2r screenshots.
   - **Why Z1 is clear:** two paths with 13-stud tree-free channels cross Z1, and the camera usually looks along them. Z2 and Z3 have no such channels.
3. **The fade is per whole tree and based on the trunk position.** [SOURCE]
   - A tree is faded when either:
     - its trunk is within 15 studs of the camera (flat, ignoring height), or
     - its trunk is within 9 studs of the camera-to-player line and not more than 6 studs beyond the player.
   - The whole tree then gets the same 0.72, whether or not any leaf crosses the line. Near the player this hazes the entire local forest without producing a clear sightline.
   - The test ignores canopy size, so Legendary, Mythic and Secret canopies (radius 9.7–12.2 [MEASURED]) can reach the line while their trunk is outside 9 studs, and stay **fully opaque**.
4. **Turning tags off turns fading off.** [SOURCE]
   - The fade loop iterates only the `tags` table, and only trees with tags get a `Leaves` list.
   - With `Pref_ShowTags = false`, the sweep calls `removeTag` for every tree. That resets the leaves to 0 and removes them from `tags`.
   - **Canopies then stop fading entirely.** A player who turns tags off to reduce clutter makes visibility worse.
5. **Labels sit at character height and keep a constant pixel size.** [SOURCE] [ESTIMATE]
   - `StrengthTag` is placed at `StudsOffsetWorldSpace = (0, -h/2 + 4.6, 0)`, about 4.6 studs above the tree base. That is the character's torso/head height.
   - `bb.Size` is in offset pixels (78×24 for Common; 100×44, or 150×44 when mutated), so distant labels are as large on screen as near ones.
   - `MaxDistance` is 48 studs for Common, Uncommon and Rare, and 90 for Epic and above.
   - In a dense zone about **140–230 labels** can be active within 48 studs [ESTIMATE]. Labels of trees between the camera and the player are drawn across the character.
6. **Fade lifecycle** [SOURCE]: correct apart from small delays.
   - `removeTag` resets fade state.
   - A felled tree is a destroyed model, and the regrown tree is a new model: it gets a tag on the next 0.4 s sweep and a fade on the next 0.08 s tick, so there is a brief pop of up to about 0.48 s.
   - If a tree's PrimaryPart streams out, the tag and fade go stale, because the sweep skips trees without a `PrimaryPart`. The whole island stays streamed (StreamingTargetRadius 1024 [MEASURED]), so this is minor.
   - When an Adornee is refreshed, `Leaves` is rebuilt without re-applying the current fade state until the next state flip. Minor.
7. **Cost of the current code** [SOURCE]: not the bottleneck.
   - The tag sweep calls `Breakables:GetChildren()` on all 5,021 trees every 0.4 s, with distance checks.
   - The fade loop runs at 12.5 Hz over about 300 tags, doing 2-D math.
   - `LocalTransparencyModifier` is written only on state flips.
   - [HYPOTHESIS] The larger client cost in zones is the hundreds of active BillboardGuis, plus the near-field parts with shadows: 1,368 tree parts within 80 studs in Z2 [MEASURED].
8. **Camera during movement and zoom.**
   - [SOURCE] The fade updates every 0.08 s, about 1.3 studs of travel at WalkSpeed 16. That is adequate.
   - [MEASURED] `CameraMaxZoomDistance = 128`.
   - [HYPOTHESIS] The default zoom (about 12.5 studs) puts the camera at roughly canopy height, so the sightline runs through the canopy band for most of its length. Zooming out raises the camera above some canopies but lengthens the line through the forest.

## 2. Exact source references

`src/client/ChopEffects.client.luau`:

| Lines | What |
|---|---|
| 81–89 | `updateTag`: ⚡ green when Power ≥ Strength, 🔒 red otherwise |
| 91–150 | `makeTag`. 101: pixel `bb.Size`. 102: `MaxDistance` 90 for Order ≥ 4 (Epic and above), else 48. 105: `StudsOffsetWorldSpace` +4.6. 144: `AncestryChanged` cleanup |
| 154 | `TAG_IN, TAG_OUT = 90, 110` |
| 155–161 | `removeTag`: resets `LocalTransparencyModifier` to 0 and destroys the Gui |
| 163–169 | `leavesOf`: all BaseParts except `Hitbox`, so trunks are included |
| 171–201 | 0.4 s sweep. 181–185: `Pref_ShowTags` gates tag creation, and therefore fading. 189: throttle of 40 tags per frame |
| 212–238 | Fade. 212: `FADE = 0.72`. 216: 0.08 s rate. 227: 15-stud near-camera rule. 230: 9-stud line test plus 6-stud margin. 235: applies `LocalTransparencyModifier` |

Other files:
- `src/client/MetaController.client.luau`
  - 124–137 `applyGraphics`: `GlobalShadows = (q == "High")`. Low disables ParticleEmitters and Trails **once** when applied, so emitters on later-respawned trees stay on. Lights are untouched. Medium and High differ only in shadows.
  - 140–143: prefs applied on `Pref_` attribute change.
  - 157 / 161: settings rows "Graphics" and "Tree Strength Tags".
- `src/server/DataService.luau` 65: defaults `Graphics = "High"`, `ShowTags = true`.
- Compact-layout checks:
  - `src/gui/UIController.client.luau` 87: viewport Y < 560, or X < 780, or touch without keyboard.
  - `src/client/UIStyler.client.luau` 28.
- No other script writes `LocalTransparencyModifier`, and the repo has no custom PlayerModule [SOURCE]. A custom PlayerModule in the dev place itself is unverified.

## 3. Comparison of camera visibility approaches

**Option A — Improved canopy fading**
- Keep a nearby-tree fade registry that does not depend on tags.
- Cache each tree's canopy radius from its leaf bounds when it is registered.
- A tree blocks if its distance from the camera-to-head line is at most its canopy radius plus about 1.5, and it lies between camera and character.
- Fade strengths: blocking trees about 0.9; trees within the near-camera radius stay at 0.72; others 0.
- Optional ramp over 2–3 ticks.

**Option B — Local visibility corridor at part level**
- Cache a bounding sphere for each leaf mesh, in local space so it can be re-derived after regrowth scaling.
- About 10–12 times a second, test nearby leaves against a capsule from camera to head (radius about 2.5–3).
- Only intersecting leaf meshes go nearly invisible (about 0.92); the rest of each tree stays opaque.
- Roblox's area and ray queries cannot be used: tree leaves have `CanQuery = false` and only `Hitbox` is queryable [MEASURED]. So this is hand-written math.

**Option C — A (or B) plus label clean-up**
- Fading as in A.
- Hide labels of faded trees and labels overlapping the character on screen.
- Tiered priority and a cap (see §5).

| | A | B | C (on A) |
|---|---|---|---|
| Feasibility | High (one loop) | Medium (custom capsule math; cache refresh on regrowth) | High |
| Mobile cost [ESTIMATE] | About today's | About 1,800 sphere tests at 12 Hz, about 1–2 ms/s | Lower than today (far fewer active labels) |
| Visual quality | Forest kept; visible see-through lane | Best: only real blockers vanish | A's quality plus a clean screen |
| Complexity | Low | Medium | Low–medium |
| Regression risk | Low | Medium (stale caches, regrowth scaling) | Low–medium (label state rules) |

## 4. Recommendation

**Option C on top of A.** It is the smallest safe change that addresses both proven causes: stacked opacity and labels at body height. It also fixes the tags-OFF bug.

It is entirely client-side, in one script, and reversible from git. It needs no server, tree, TreeKit, template, data, combat or economy changes.

**Phasing:**
1. Fade fix: decouple from tags, canopy-aware test, about 0.9 on the line.
2. Label rules (§5).
3. Option B only if A's see-through lane looks too washed-out on larger screens.

## 5. Tree-label clutter redesign (proposal; no UI changed)

Keep the existing `StrengthTag` BillboardGuis. Switch them with `bb.Enabled` instead of destroying and recreating them.

| Tier | Trees | Display | Distance |
|---|---|---|---|
| 1 (never capped) | Legendary, Mythic, Secret, Divine, any mutation | Full label (rarity/mutation and Strength) | 90 (unchanged) |
| 2 | Rare, Epic | Full label | 48 |
| 3 | Common, Uncommon | Compact Strength pill (existing 78×24) | 24; up to 48 when 🔒 too strong; briefly while being hit |

**Rules:**
- **Cap:** at most about 16 tier 2–3 labels on compact screens and about 24 otherwise, highest tier first, then nearest. Use a little hysteresis to avoid popping.
- **Hide over the character:** hide a label while its tree is faded by the fade logic, or while its on-screen position overlaps the character's on-screen box (checked about 3–4 times a second).
- **`Pref_ShowTags`:** keeps its meaning (OFF = no labels). It **no longer disables fading**.
- **Readability:** rare and mutated trees always show their label, every too-strong tree shows 🔒 within 48, and nearby trees show their Strength.
- **Optional, needs owner approval:** raise the label anchor from +4.6 to about +6.5, above head height.

## 6. Phone versus PC

- **Fade:** identical on all devices, because character visibility is gameplay-critical.
- **Label cap:** chosen by the **existing compact-layout check** (screen size, or touch without keyboard), not by an "is this a phone" test. Device type does not predict performance.
- **Graphics setting:** Low may also use the lower label cap.
- **No new settings and no menu changes.**
- **Defaults:**
  - compact or small screens: strong character visibility and minimal labels;
  - larger screens: the same fade with a larger label cap, so the forest appearance is preserved.
- **Optional later:** Option B on larger screens for best visual quality.

## 7. Performance considerations and risks

Nothing here has been implemented or measured.

**Design rules:**
- client-only;
- a nearby-tree registry, with no per-frame scan of the whole forest;
- cached leaf lists and canopy radii;
- writes only on state change;
- 10–12.5 Hz fade, 2.5–4 Hz label pass.

**Expectations:**
- Fewer active BillboardGuis should reduce client cost. Fade math cost stays about the same.
- **No FPS improvement is claimed until it is built and measured.**

**Baselines to compare against** (one Studio client, MacBook) [MEASURED]:
- dense route 8.4 FPS;
- sparse route 11.7;
- Z2 standing 8.4 against open area 12.3;
- Z2 near field 1,368 tree parts within 80 studs;
- server heartbeat 6.0–7.5 ms during entry sweeps.

Server load is unaffected by this proposal.

**Risks:**
- a see-through lane looks odd if the fade is too strong (keep about 0.9, not 1.0);
- label popping at the cap boundary (needs hysteresis);
- stale leaf caches after regrowth (rebuild when the regrown tree is registered);
- [HYPOTHESIS] the Studio FPS drop may come more from near-field parts and shadows than from labels, so labels alone may not recover FPS;
- B1 respawn effect drift is a separate issue and is not addressed here.

## 8. Proposed code-change scope (not written)

- **Single file:** `src/client/ChopEffects.client.luau`, sections 91–238.
  - Fade registry independent of tags.
  - Canopy radius cache.
  - Fade test and strength.
  - Label tiering, cap and overlap hiding.
- **Estimated size:** about 100–150 lines changed.
- **Untouched:** server scripts, TreeKit, tree templates and positions, DataService prefs, the settings UI, combat, economy, `MetaController`.
- **Revert:** restore the file from git. No data migrations.

## 9. Camera visibility and regression test plan (after approval and implementation)

One local Studio client only, followed by iPhone after a separately approved private dev publish.

- **Matrix:**
  - zones Z1, Z2, Z3, Z4;
  - standing and walking;
  - graphics Low, Medium and High;
  - Reach 10 and Reach 40;
  - tags ON and OFF.
- **Checks:**
  - character visible in screenshots;
  - count of enabled labels;
  - every Legendary or above and every mutated tree still labelled;
  - 🔒 shown on too-strong trees within 48;
  - fade-loop time (`os.clock` per tick, logged locally);
  - client FPS against the baselines in §7.
- **Regrowth:** fell trees inside the blocking lane. The regrown tree must fade correctly and its label must return.
- **Regression:**
  - chopping and AutoChop unchanged;
  - gates and other islands' labels unchanged;
  - no console errors.
- **iPhone:** visibility, label legibility and FPS in Z1 and Z2 on High and Low.
- **Save data:** chopping in a playtest writes Logs and stats to the dev save. Prefer blades-off and camera-only playtests unless the owner approves chopping.
- **Reporting:** keep Studio results separate from estimates.

## 10. GitHub handoff discrepancy and proposed corrections (patches prepared, NOT applied)

**Cause.** `p1b2r/dense-forest` was branched from `p1b2/crystal-wilds`, which forked from `main` before the P0 docs commits (common ancestor `026ba31`). So its docs are P0-era:
- `LIVE_HANDOFF.md` shows "Active AI editor: Claude, P0 isolation and backup…";
- no `P1B_MIGRATION_BLUEPRINT.md`;
- older CHANGELOG and TASKS.

`proposal/p1b2-dense-forest` stops at the P1b.2 release (v12). **`main` (`25260c2`) is the most current:**
- P1b.2r complete;
- dev v15 with checkpoint v14;
- editor released;
- production unchanged;
- P1b.3 not authorized.

`AI_HANDOFF.md` is identical on all three branches.

**Stale fields still on `main`:**
- "Most recent documented place version **48**";
- "Script export outstanding";
- "Code source of truth … until exported";
- start-of-session checklist step 2 says to verify **production** place `73142469975141`, which is risky for an editor;
- the "Current session" and "Latest completed handoff" tables date from 2026-11-18;
- `CURRENT_STATUS.md` lists production v48 only and says scripts must still be exported.

**Prepared patches** (in `handoff_patches/`, for owner review; apply with `git apply` only after approval):

| File | Applies to | Changes |
|---|---|---|
| `LIVE_HANDOFF_main.patch` | `main` `docs/LIVE_HANDOFF.md` | Snapshot line; place-version row (dev v15, checkpoint v14, note to confirm v15 in Version History because the cloud timestamp didn't move); code source of truth; scripts-in-GitHub branch lineage; blockers; checklist step 2 (verify the **dev** place); both session tables from verified P1b.2r records. Already-current rows are untouched |
| `LIVE_HANDOFF_p1b2r-branch.patch` | `p1b2r/dense-forest` `docs/LIVE_HANDOFF.md` | Replaces the stale P0 page with the same corrected page |
| `CURRENT_STATUS.patch` | `main` `docs/CURRENT_STATUS.md` | Splits production and dev; records dev v15 and the island state; fixes the repo-sync line; adds the P1b.2r risks |

Not patched, flagged: CHANGELOG and TASKS on `p1b2r/dense-forest`. These resolve if that branch is merged or rebased onto `main`, which needs separate approval.

Key proposed dashboard values (full text in the patches):

```
| Most recent documented place version | Dev: v15 (P1b.2r result; checkpoint v14 "P1b.2r PRE-DENSE-REDISTRIBUTION"), as reported by Studio's save. The dev place's Open Cloud updateTime was 2026-11-19T09:59:41.986Z when last checked; it did not change for the v15 save, so confirm v15 in Version History. Production: documented v48 (HUD handoff); not re-queried. Production updateTime 2026-11-18T15:12:30.520Z |
| Working scripts in GitHub? | Yes, on branches, not main: p0/script-export (34-script baseline) → p1a/island-prototype → p1a/m1-arrival-slot-fix → p1b2/crystal-wilds @ 0fc997d (35 scripts; BladeConfig + WorldServer changed for P1b.2) → p1b2r/dense-forest @ a893300 (no script changes). Pending design branch: proposal/p1b2-dense-forest @ 63937f9 |
| Blockers | Owner decisions pending: P1b.2r camera visibility (Z2/Z3), merge strategy for p1b2r/dense-forest, private dev publish for iPhone, B1 respawn effect/tag drift. Still open: commerce/API setup; suspicious imported scripts. Two-player and iPhone unverified |
Checklist step 2: verify the dev place 103379930563763 / universe 10777797608 (never edit production 73142469975141) …
```

## 11. What was inspected and what remains unverified

**Inspected (read-only):**
- the three branches' latest commits and docs listed above;
- the ChopEffects fade and label code, graphics prefs, default prefs and compact-layout checks;
- Roblox's documented Popper `canOcclude` rule;
- Studio measurements from P1b.2 / P1b.2r: tree hitboxes and `CanCollide`/`CanQuery`, canopy radii, camera occlusion mode `Zoom`, `CameraMaxZoomDistance` 128, streaming radius 1024, the T-D6 screenshots, and the FPS, part and heartbeat figures.

**Unverified:**
- the dev place itself in this session. Studio was closed, so these are unchecked: whether the dev place contains a custom PlayerModule, current leaf transparency states, and v15 in Version History;
- the default camera zoom distance and height;
- the canopy layer counts and label counts (estimates);
- the FPS or visibility effect of any option (nothing implemented);
- iPhone and two-player behaviour.

**Not done (by instruction):** no Studio, script, tree, data, economy or combat changes; no handoff files modified; no merge or publish. P1b.3, P1b.4, P1c, P2 and B1 not started.
