# M0.1 Foundations Corrections — Results

| Field | Value |
| --- | --- |
| Date | 2026-11-20 (04:09–04:45 PST) |
| Editor | Claude (single AI editor, one Studio client) |
| Place | **Dev only:** `103379930563763` / universe `10777797608`. Every Studio write was preceded by `assert(game.PlaceId == 103379930563763) assert(game.GameId == 10777797608)`. Production `73142469975141` was not accessed or modified. |
| Checkpoint | Dev **v23**, relabelled "M0.1 PRE-CORRECTIONS (checkpoint = M0 v23 state)" before any change. Script copies are in `ServerStorage.M01Backups` (10 disabled scripts, checksums in §7). |
| Result | Dev **v29**, "M0.1 FOUNDATIONS CORRECTIONS (H2 H3 H1 M1 H6 M5) - dev only, not published" (notes truncated by Roblox). v24–v28 were not saved by Claude explicitly; they are probably Team Create auto-saves during the session (unverified). Dev Open Cloud `updateTime` after the save: 2026-11-20T12:42:47.246Z. |
| Branch | `m0.1/foundations-corrections`, based on `m0/foundations`. Not merged; nothing published. |
| Scope kept | No M1 work, no economy formulas, rewards or tuning changed, 72-node Tech Tree untouched, no planned content added. |

Evidence levels used below: **L** = locally validated in Studio (unit tests with mocks and failure injection, and/or live single-client play against the real dev DataStore). **U** = unverified; needs a real environment (cross-server, real teleports, real purchases, iPhone).

## 1. Summary

| Finding | Fix | Status |
| --- | --- | --- |
| **H2** older overlapping saves could overwrite newer profiles or confirmed purchases | Per-player serialized writer (`ProfileWriter`) and a persistent monotonic `_WriteSeq` fence in `SessionStore.Write` | Implemented, **L** (14 unit + live) |
| **H3** profile lock leaked when a player left during first-time migration or backup | `DataService.Load` checks for departure after `BuildProfile` and releases the lock without writing the profile (`releaseUntouched`) | Implemented, **L** (8 unit) |
| **H1** no server-side movement check for chopping | `MovementGuard`: speed window against the server's Humanoid.WalkSpeed; suspends chopping **credit** only (never kicks or moves anyone); sanctioned teleports and respawns exempt | Implemented, **L** (14 unit + live) |
| **M1** AFK server hop: unconfirmed lock handoff, trusted client stats | Confirmed save-and-release before teleport, resume on failure, minimum interval, sanitised display-only stats | Implemented, **L** for logic and live release/resume; real teleport **U** |
| **H6** playtime gifts reset on every rejoin or hop | Gift progress stored in the profile as a "visit"; rejoin within 30 min resumes it; max 3 paying visits per UTC day | Implemented, **L** (11 unit + live claim and rejoin) |
| **M5** one-touch Treant farming; AFK players elsewhere inflated boss HP | Rewards need ≥2% damage share or ≥12 hits; Treant and Blade King HP count only nearby players | Implemented, **L** (4 unit + live Treant HP); real multi-player **U** |

Tests: **M0.1 suite 64/64**, **M0 regression 107/107**, **real-DataStore lock suite 11/11** (single process). Console: no new errors.

## 2. Changed scripts and exact line references

Line numbers refer to the files on branch `m0.1/foundations-corrections`. Checksums are `length:Adler-32` of the source; the repo file and Studio source match for every entry (re-verified in Edit before saving v29).

### New modules (ServerScriptService)

| File | Checksum | What it does |
| --- | --- | --- |
| `src/server/ProfileWriter.luau` | 4435:3374961470 | FIFO-serialized saves per profile (`Save` L57, `Pending` L42, `Handoff` L93, `Resume` L101). Each write carries `seq = last + 1`. "lost" or "stale" stops the writer. Queue wait is capped at 120 s and a timed-out save does **not** write. |
| `src/server/MovementGuard.luau` | 7021:1019155951 | Movement sanity (`Reset` L65, `Allow` L74, `Check` L105, shared instance L166). 2-s window, tolerance 1.35× server WalkSpeed (minimum 16) plus 10 studs slack. A violation pauses credit 3 s; 5 within 60 s pause it 30 s. Sanctioned teleports are tracked as an origin→destination path (see §5, bug found during testing). |
| `src/server/AFKHandoff.luau` | 3405:1175607087 | `Sanitize` L26 (display-only stats) and `Run` L62 (hop orchestration: interval, release, teleport, resume). |
| `src/server/PlaytimeGifts.luau` | 3307:2973517819 | Visit logic: `Begin` L35, `Tick` L53, `CanClaim` L64, `Claim` L74, `ClaimedList` L82. `RESUME_WINDOW` 1800 s, `MAX_VISITS` 3. |
| `src/server/BossRules.luau` | 2119:3791691843 | `InRange` (Treant 400 studs, Blade King 200 studs) and `Rank` (`MIN_SHARE` 0.02, `MIN_HITS` 12). |

### Patched scripts

| File | Before → after | Changes (line refs) |
| --- | --- | --- |
| `src/server/SessionStore.luau` | 7783:3209818438 → 9048:3466171593 | Header L19–24. `Acquire` L100: reports `info.Seq` (L130) and treats a record holding only `_WriteSeq` as a new profile (L132). `Write(key, data, release, seq)` L154: strips `_WriteSeq` from the payload (L157); refuses `seq < stored` as "stale" (L177–180); stores `_WriteSeq` (L184). |
| `src/server/DataService.luau` | 30390:2507400287 → 33750:626150713 | ProfileWriter require L25; `writers` table L44. DEFAULT gets `Playtime` (L96). Snapshot hides `_WriteSeq` (L129). `releaseUntouched` L694. `Load(player, ss)` L705: H3 departure check after BuildProfile (L737–743, returns "left_during_build"); sets `_WriteSeq` (L745); creates the writer (L747). `SaveNow` L758 ("lost"/"stale" → kick L764–769). `IsActive` L783, `CanPersist` L789, `PendingSaves` L796, `HandoffRelease` L808, `ResumeAfterHandoff` L820. Autosave skips while a save is queued or the writer is released (L880). |
| `src/server/CombatServer.server.luau` | 20797:1888490247 → 21991:1077912845 | Guard and violation reporter L30–40 (`MoveViolations` attribute, throttled warn). `guard:Reset` on spawn L241; `guard:Remove` on leave L277. Treant hit counting `Hits_<UserId>` L363–364. Heartbeat: no credit during an AFK handoff, and credit requires `guard:Check` (L568–570). |
| `src/server/TravelService.server.luau` | 9388:3611788483 → 9596:1823263718 | Guard require L16; `guard:Allow(player, 3, nil, cf.Position, root.Position)` before PivotTo, L114. |
| `src/server/AreaService.server.luau` | 1737:843202379 → 1968:4096101712 | Guard require L10; `guard:Allow(...)` before the push-back PivotTo, L28. |
| `src/server/WorldServer.server.luau` | 14591:830933556 → 15064:1212066197 | BossRules require L9. Blade King HP counts players within 200 studs of ArenaCenter (L327–334); the formula `clamp(8000 + 3000 × n, 8000, 60000)` is unchanged. |
| `src/server/MetaService.server.luau` | 11613:574451345 → 11898:2119943567 | Gifts require L12. `giftState` L30–42 reads `d.Playtime`; `ClaimGift` uses `Gifts.Claim` (L91–97); join `Gifts.Begin` L207; leave sets `LastSeen` L227; minute tick L238; Studio hook L293. Gift rewards (`Progress.Grant`) unchanged. |
| `src/server/ExtrasService.server.luau` | 11953:4230354996 → 12732:3387824125 | BossRules require L19. Treant HP from nearby players' Power (L187–194; `HealthPerPower` and `MinHealth` unchanged). Reward split via `BossRules.Rank` (L232–241); ineligible players get a notice. Reward amounts unchanged. |
| `src/server/AFKService.server.luau` | 1307:72991505 → 2808:85052095 | Rewritten around AFKHandoff (64 lines). No hop in Studio (L45). Stats sanitised (L47); `AFKHandoff.Run` (L48); `TeleportInitFailed` resumes the profile (L54). |

### Test module (ServerStorage, Studio only)

`src/serverstorage/M01Tests.luau` → `ServerStorage.M01Tests`, checksum 27669:4123055364. Run `require(game.ServerStorage.M01Tests).RunAll()` in the Server context. It never runs on its own. It uses a mock DataStore with injectable delays (yielding hooks) and failures.

Unchanged and re-verified: ChopEffects 27331:1017905967 (camera fix), BladeConfig 55586:167717973, TreeKit 5038:3027397391, M0Tests 21328:487727077; 620 Crystal Wilds trees; 5,021 Breakables; all weapons present in the dev save.

## 3. Tests and results

### 3.1 M0.1 unit suite — 64/64 pass (mock stores, failure injection)

| Suite | Result | Covers |
| --- | --- | --- |
| H2 | 14/14 | Older seq refused, newer data kept. Equal-seq retry accepted. Seq-less writes keep the fence. `Acquire` reports Seq. A record with only `_WriteSeq` is new. Overlap test with a 1-s DataStore delay gives order `A-start,B-queued,A-done,B-done` and the final record has the newest data and purchase. Seq strictly increasing. Receipt during a slow in-flight autosave is granted only after its own confirmed write. DataStore down → `NotProcessedYet`, grant kept in memory once. Roblox retry after recovery → Granted, single grant persisted. A late stale snapshot cannot erase purchases. A writer behind the stored seq is fenced. A queue timeout writes nothing and later saves stay ordered. |
| H3 | 8/8 | Leave during the `bk3_` backup write → "left_during_build", lock released at once, original v3 record byte-equal, backup still written, immediate rejoin acquires. Leave during Acquire. New player leaving stays new. Player who stays → v4, lock held. |
| H1 | 14/14 | Walking 16 and upgraded 24: never flagged. Bursty replication (0.6-s bursts): never flagged. 1.3× hack tolerated (documented). 2× and 3× flagged. Unsanctioned 500-stud teleport pauses ~3 s. Island travel and respawn not flagged. Falling 1,200 studs not flagged. 5 teleports/60 s → 30-s pause. New cases: H1.12 teleport applied 4 s late; H1.13 never applied; H1.14 the exact live join revert sequence (destination → spawn → 383 → 832 → destination), with no strike, credit only at the destination, and later teleports still caught. |
| M1 | 13/13 | Handoff = confirmed save and release. No writes after handoff. New server acquires at once. Resume after another server wrote → "conflict", their data kept. Failed teleport → resume and saving continue in sequence. Handoff with DataStore down → not released, lock kept. Orchestration: happy path; release unconfirmed → no teleport; teleport fails → resume; hop within 5 min of joining or of the last hop refused. Sanitising NaN/inf (→ floor), huge (→ cap), bad ids, extra keys and non-table input. |
| H6 | 11/11 | Visit start. 5-min gift once. 10-min gift not early. Rejoin within 30 min resumes progress and claims (old exploit closed). Progress continues across the hop. Break > 30 min → fresh ladder. 4th visit per UTC day pays nothing. Next UTC day resets. Rejoining every 10 min for 3 h pays the 5/10-min gifts once (M0: 18× each). Malformed state is repaired. |
| M5 | 4/4 | Only nearby players scale HP. One-touch (0.8%, 3 hits) not rewarded. Small share with 15 hits still rewarded, best first. A solo player always qualifies. |

One test failed on the first run and was fixed in the **test**, not the code. M1.12 expected `BestOneIn = math.huge` to clamp to the cap, but `Sanitize` deliberately maps every non-finite value to the floor, consistent with NaN and negatives. The test now also checks that a huge *finite* value clamps to 1e10.

### 3.2 Regression

- M0 unit suite `M0Tests.RunAll({bk3 profile})`: **107/107** (locking, migration of 8 fixtures plus the real dev snapshot, receipts, paid-random policy).
- `M0Tests.RunDataStore(M0_TestStore)`: **11/11** on a real DataStore, single process. This is not cross-server evidence.

### 3.3 Live single-client checks (real dev DataStore `BladeForest_v3`, one Studio client)

| Check | Result |
| --- | --- |
| Client `GetData` | v4, no `_WriteSeq`/`_Session`/`_Meta`/`Purchases`/`Analytics` leaked; `SessionStart`/`GiftsClaimed` attributes present (client UI unchanged) |
| 3 concurrent `SaveNow` | All ok, serialized (pending = 3 while saving), `_WriteSeq` 0 → 3, lock kept |
| `HandoffRelease` | Lock released (`_Session` nil, seq 4), `Handoff` attribute set, `IsActive`/`CanPersist` false, a later save refused |
| `ResumeAfterHandoff` | Lock re-acquired, attribute cleared, next save seq 5 (continuous) |
| Unsanctioned 400-stud server PivotTo | Flagged (`MoveViolations` +1; console warning) |
| Island travel TimberHaven ↔ CrystalWilds (2,790 studs each way) | Not flagged |
| Respawn (`LoadCharacter`) | Not flagged |
| Joins / rejoins (5 stop-start cycles) | Before the §5 fix: 1–4 false violations per lagged join. After: 0 on all three joins, including one caught live with the lag pattern (spawn → 1,467 → 2,790) |
| Treant spawn, player 2,798 studs away | MaxHealth 20,000 (the floor; the M0 code would have used all online Power) |
| Treant spawn, player 85 studs away | MaxHealth 550,200 (= Power 1,834 × 300) |
| Both test Treants expired without being killed | No rewards paid; `TreantAlive` false; nothing left in workspace |
| Playtime: `SessionBack 6` → claim gift 1, then 1 again, 2, 99 | 1 paid once; repeat → "Already claimed"; 2 → "Not yet!"; 99 → "?" |
| Rejoin (stop/start play) | Visit resumed: progress ~10 min shown, `GiftsClaimed=1`, re-claim refused |
| Stop play | Lock released every time (`_Session` null, final write seq 23). A read immediately after stop can still see the lock because Studio's BindToClose is asynchronous. |

## 4. Save compatibility

- Additive only: `_WriteSeq` (top-level number, server-only) and `Playtime = { Seconds, Claimed, LastSeen, Day, Visits }`. `Version` stays **4** with no new migration step. v3 records still migrate through the M0 path, and that path's 107 regression tests pass.
- Old records without `_WriteSeq` are treated as seq 0. Writes without a seq (none remain in code) leave the fence unchanged.
- Rolling back to M0 code (v23) is safe: M0 ignores the extra fields; `Playtime` is ignored (gifts fall back to per-server); `_WriteSeq` is carried as an unknown key. After a rollback the fence no longer protects anything until M0.1 is restored.
- `bk3_p_394034825` (pre-M0 backup) is unchanged: Profile JSON 3294:2318875369, byte-identical to the M0 record.

**Dev save changes during M0.1 testing** (ordinary gameplay, nothing reset or edited directly):

| Field | Change |
| --- | --- |
| Logs | 836,279 → **8,836,279**. One 5-minute playtime gift claimed in the live test; the unchanged M0 formula pays `TraitCrateCost[BestArea=FrostPeaks] × 1` = 8,000,000. |
| Playtime | New field (visit 1 of UTC day 20777, gift "1" claimed) |
| `_WriteSeq` | 23 |
| LastIsland | Ended as `TimberHaven` (see §5 bug 2) |

Everything else checked is as before: Version 4, Souls 314, FreeCrates 11, Rebirths 2, 22 weapons, Void equipped. Whether to keep the extra Logs is the owner's call; a pre-M0 copy exists in `bk3_`.

## 5. AFK behaviour (M1) and bugs found

**AFK hop now:**
1. At most one hop per 5 min, and none in the first 5 min after joining.
2. Rewards stop (`Handoff` attribute) and a **confirmed** save releases the lock. If it is not confirmed, nothing happens and the player stays.
3. Teleport; the new server acquires the released lock at once (no 45-s wait).
4. On teleport failure (immediate or via `TeleportInitFailed`) the profile is re-acquired only if no other server wrote since. Otherwise the session ends and is never overwritten.
5. The client's session table is clamped and only shown in the AFK panel; it never affects rewards.

Teleports cannot run in Studio, so steps 3–4 with a real `TeleportAsync` are **U**.

**Bugs found:**

1. **Fixed during M0.1 — H1 false positives on join.** On join or rejoin the client applies the server's island placement late. The server's view of the client-owned character then jumps among the spawn (Timber Haven), interpolated points (383, 832, 1,467 studs) and the destination for up to a few seconds. The first H1 version flagged these jumps (1–4 violations per join; credit paused, no other effect). Fix: a sanctioned teleport is tracked as a path for up to 10 s, during which positions on that path never strike and only the destination earns credit. Regression tests H1.12–H1.14 cover it; re-tested live with 0 violations.
2. **Open (pre-existing, not changed): CurrentIsland follow loop and join lag.** TravelService's once-a-second "follow the character" loop reads those same stale join positions and can set `CurrentIsland` and `LastIsland` to Timber Haven while the character is really on Crystal Wilds. Observed in the logs, and the dev save ended with `LastIsland = TimberHaven`. Impact: the next join may spawn at the hub instead of the last island. This code predates M0.1; fixing it is a gameplay change and is left for owner decision.
3. **Known limitations (by design):**
   - Speed hacks up to ~1.35× WalkSpeed earn credit.
   - Credit pauses ≤10 s after a sanctioned teleport until arrival is seen.
   - The visit cap (3 paying visits per UTC day) is a new gift rule the owner should confirm.
   - Treant reward eligibility (2% or 12 hits) is a new rule; amounts are unchanged.
   - Pre-existing `leaderstats` infinite-yield warnings on first load (documented in M0).

## 6. Outstanding external validations (not claimed)

- Cross-server locking, fencing and AFK handoff with two real servers (the ≥50-cycle test from M0 is still pending).
- A real `TeleportAsync` hop, `TeleportInitFailed` and the reserved-server path.
- Real Robux receipts (all receipt evidence is mock or `NotProcessedYet`-only).
- Two-player Treant and Blade King scaling and reward split in a live server.
- iPhone and other devices (MacBook Studio FPS is not representative).
- Live latency for the movement guard (Studio latency is near zero apart from the join lag above).

## 7. Rollback procedure

Pick the narrowest option:

1. **Whole place:** in the dev place's Version History, restore **v23** ("M0.1 PRE-CORRECTIONS (checkpoint = M0 v23 state)"). Production is unaffected either way.
2. **Scripts only (in Studio Edit):**
   - Copy the sources from `ServerStorage.M01Backups` back over the live scripts: DataService_PreM01 30390:2507400287, SessionStore_PreM01 7783:3209818438, CombatServer_PreM01 20797:1888490247, AFKService_PreM01 1307:72991505, MetaService_PreM01 11613:574451345, ExtrasService_PreM01 11953:4230354996, TravelService_PreM01 9388:3611788483, AreaService_PreM01 1737:843202379, WorldServer_PreM01 14591:830933556, M0Tests_PreM01 21328:487727077.
   - Then delete the five new modules (ProfileWriter, MovementGuard, AFKHandoff, PlaytimeGifts, BossRules) and `ServerStorage.M01Tests`.
   - Verify the checksums against `m0/foundations`.
3. **Git:** `m0/foundations` is untouched. Do not merge `m0.1/foundations-corrections`; or `git revert` its commits.
4. **Saves:** no rollback needed (see §4). The dev Logs can be restored from `bk3_p_394034825` only by owner decision.

## 8. Implementation / validation matrix

| Item | Implemented | Locally validated (L) | Unverified (U) |
| --- | --- | --- | --- |
| H2 serialization + seq fence | Yes | Mock overlap, failure injection, live concurrent saves | Two real servers racing |
| H2 receipts during overlapping saves | Yes | Mock ProcessReceipt with a delayed and failed store | Real Robux purchase |
| H3 leave during migration/backup | Yes | Mock with leave injected mid-backup | Live first-time v3 player leaving |
| H1 movement sanity | Yes | 14 synthetic + live teleport, travel, respawn, joins | Real latency; future WalkSpeed upgrade in play |
| M1 AFK handoff | Yes | Logic + live release/resume | Real teleport and second server |
| H6 playtime gifts | Yes | Unit + live claim and rejoin | Real AFK hop between servers |
| M5 boss rules | Yes | Unit + live Treant HP near/far | Multi-player fight and reward split |

Stop point: M0.1 is complete on the dev place and the branch. **Waiting for owner review.** M1 not started.
