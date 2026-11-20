# M0 Foundations — Results (DEV PLACE ONLY)

_Author: Claude · 2026-11-20 03:30 PST · branch `m0/foundations` · owner review required. Nothing is merged or published._

## 1. Versions and checkpoint

| Item | Value |
| --- | --- |
| Place | Dev `103379930563763` / universe `10777797608` (asserted before every Studio write) |
| Starting version | **v18**. A save with no changes relabelled it **"M0 PRE-FOUNDATIONS"**; this is the rollback checkpoint. |
| Offline copy | File > Download a Copy → `~/Documents/BladeForest_IslandDev_v18_M0_PRE_FOUNDATIONS`. The dialog closed without error; the file's existence is not verified because that folder is not connected. |
| Script backups in Studio | `ServerStorage.M0Backups`: DataService_PreM0, StoreService_PreM0, TraitService_PreM0 and ExtrasService_PreM0. All are disabled and match the originals by checksum. |
| Result version | **v23** "M0 FOUNDATIONS (…)". Saved through Team Create; the notes were truncated by Studio. |
| v17 (unexplained) | Not resolved. Studio has no version-history UI, and the built-in browser is not signed in to Roblox. Dev `updateTime` was still the v18 time (05:52:14Z) when the session started. **Owner: please check Version History.** |
| v19–v22 (new finding) | The save returned v23, not v19. Claude made no explicit saves between v18 and v23, so v19–v22 are probably Team Create auto-saves of this same editing session. Not verified: please confirm in Version History. Dev `updateTime` after the save: 2026-11-20T11:22:18.739Z. |
| Production | **Not touched.** No production writes. Re-reading production `updateTime` this session was blocked by the permission classifier, so it was **not re-verified** (last check 2026-11-19 21:53 PST: 2026-11-18T15:12:30.520Z). |
| Publish | **None.** |

## 2. Scripts changed (Studio = repo, verified by length:Adler-32)

| Script | Type | Before | After |
| --- | --- | --- | --- |
| ServerScriptService.SessionStore | ModuleScript (new) | — | 7783:3209818438 |
| ServerScriptService.SaveMigrations | ModuleScript (new) | — | 3183:2423986931 |
| ServerScriptService.PaidRandomPolicy | ModuleScript (new) | — | 4687:1835212535 |
| ServerScriptService.ReceiptProcessor | ModuleScript (new) | — | 3476:3116857810 |
| ServerScriptService.Analytics | ModuleScript (new) | — | 11417:1592676899 |
| ServerScriptService.AnalyticsBoot | Script (new) | — | 290:877684522 |
| ServerScriptService.DataService | ModuleScript | 19574:676054173 | 30390:2507400287 |
| ServerScriptService.StoreService | Script | 7939:183368817 | 10179:3054948545 |
| ServerScriptService.TraitService | Script | 5344:554018198 | 5839:1833782450 |
| ServerScriptService.ExtrasService | Script | 11734:2674314332 | 11953:4230354996 (+3 lines: egg policy gate) |
| ServerStorage.M0Tests | ModuleScript (new, test harness, never runs by itself) | — | 21328:487727077 |

**Unchanged and re-verified after M0:**
- ChopEffects (camera fix) 27331:1017905967, BladeConfig, CombatServer, WorldServer, TravelService, MetaService, Progress, RollService, TreeKit and AutoChop.
- Crystal Wilds trees: **620** (by `P1bIsland` attribute); Breakables: 5021.
- No changes to tree positions, island layouts, blade damage or hits, weapon odds, luck or Logs multipliers, NPCs, gates, pets, traits, bosses or VFX.

## 3. Architecture decision: session locking

**Chosen design:** a custom `UpdateAsync` session lock, stored inside the existing record as `_Session {Id, Job, Place, Lease}`.
- Lease is 300 s; autosave every 60 s refreshes it.
- Acquire is retried 15× at 3 s intervals.
- I/O is retried 4× with backoff of 1, 2, 4 and 8 s.

**Why it is safe to choose without stopping:**
- It keeps the same DataStore and key (`BladeForest_v3` / `p_<UserId>`) and the same shape.
- v4 only **adds** fields, and v3 code ignores `_Session`.
- Rollback = restore the v18 scripts. Nothing is irreversible, so the instruction's STOP condition (an architecture choice that changes the save system or risks an irreversible migration) was not triggered.

| | Custom UpdateAsync lock (chosen) | ProfileStore / ProfileService |
| --- | --- | --- |
| Save format | Unchanged key; additive fields | Wraps data in its own metadata format, so a migration of key and shape is needed |
| Third-party code | None | Requires importing an external module. Network installs are off, and the source can't be verified here (forbidden: "unverified … module") |
| Reversibility | Remove the scripts; v3 reads v4 records | Harder; the profile format changes |
| Maturity | New; locally tested only | Battle-tested at scale |
| Risk | Our own bugs; needs real cross-server testing | Integration/migration risk |

**Behaviour:**
- **Locked by a live session:** load is refused and the player is kicked with a clear message. Writes from a stale session return `lost`; that server stops saving and kicks the player.
- **Lease expired (crashed server):** another session takes over.
- **DataStore outage, corrupt record or migration failure:** fail closed. The player is kicked and **no default profile is ever written over existing data**.
- **Shutdown:** BindToClose releases all profiles in parallel, bounded at 25 s. It also waits for releases already started by PlayerRemoving.

## 4. Migration v3 → v4

**Code:**
- `SaveMigrations.CURRENT = 4`, with numbered steps.
- `Migrate` works on a deep copy and never mutates its input. It is idempotent: `_Meta.Applied["4"]` is set, and `_Meta.MigratedFrom` is recorded.

**Fields added (approved list only):**
- `WeaponItems` (empty).
- `RetiredWeapons`: catalog-missing weapons are parked here, never deleted.
- `CrateOrigins {Earned, Paid, Legacy}`: existing crates become Legacy.
- `Analytics {Onboard, Prog, Legacy=true}`.
- `Collections` (empty).
- `_Meta`.

**Backup:**
- Before the first migration, the untouched record is written once (WriteOnce) to `bk3_p_<UserId>`.
- It is then read back and compared before the migrated profile can load. If the backup can't be written or read, the load is refused.

**Real dev profile (`p_394034825`, the only profile; authorized dev data):**

| | Before (v3) | After (v4) |
| --- | --- | --- |
| JSON length:adler | 3294:2318875369 | 3822 bytes at the end of test 1 |
| Weapons | 22 | 22 (0 retired) |
| Logs / Souls | 6,255 / 314 | 6,255 / 314 at migration |
| FreeCrates | 11 | 11 (Legacy 11) |
| Purchases | 0 | 0 |
| `bk3_p_394034825` | — | **3294:2318875369, byte-identical to the pre-migration record**; unchanged after two sessions |
| SaveFormat attribute | — | `migrated` on first load, `current` on second load |

- The live profile differed from the original **only** in `Stats.PlaySeconds` and `Quests.Daily` (the normal day rollover).
- The second load did not re-migrate and did not overwrite the backup.

**Ordinary gameplay writes to the dev save (documented, not reverted):**
- During the T8 smoke test the character was teleported next to a Crystal Wilds tree and left there for about 4 minutes while tests ran.
- Auto-chopping took TreesChopped from 3,331 to 3,419 and **Logs from 6,255 to 836,279**.
- This is ordinary gameplay, but it is larger than intended. The pre-M0 state is preserved in `bk3_p_394034825`. Claude did not reset or edit the save; whether to roll it back is the owner's call.

**Other DataStore keys written:**
- `bk3_p_394034825` (the backup).
- Throwaway keys `m0t_*` in DataStore **`M0_TestStore`**, a test-only store, never the game store.

## 5. Receipts (M0-C)

**Flow:**
- Snapshot the profile.
- Grant the product and record `Purchases[PurchaseId]` **in the same document**.
- `SaveNow` must be confirmed before returning `PurchaseGranted`. Otherwise return `NotProcessedYet`; grant and record stay together in memory, so a retry cannot grant twice.
- If the grant throws, the snapshot is restored.

**Other rules:**
- Unknown product, player absent, profile not loaded or owned elsewhere, or an unsaved Studio profile all return `NotProcessedYet`.
- **Purchase ids are never pruned** (permanent dedupe, as the owner corrected).

**Recovery method for unresolved receipts:**
- Roblox re-delivers any receipt that was not granted. Because the id and the grant are saved atomically, the retry is idempotent.
- `ReceiptProcessor.pending()` (Studio: `ServerStorage.DevStore:Invoke(p,"Unconfirmed")`) lists receipts granted in memory whose save was not yet confirmed; they are re-saved on the next attempt.

**Commerce safety:**
- No product IDs were invented or created, no commerce was activated, and no real or simulated Robux purchase was made.
- End-to-end, only synthetic receipts with **unknown** product ids were sent through the real `ProcessReceipt`. Result: `NotProcessedYet`, and no purchase record was written (0 → 0).

## 6. Paid random items (M0-D)

**Classification of pathways by currency origin (server-side):**

| Entry point | Paid input? | Restricted player |
| --- | --- | --- |
| Free Trait Crate (TraitService "Free") | Crates from Robux packs, Starter Pack or VIP daily = Paid; quests, achievements, codes and Treant = Earned; owned before v4 = Legacy (treated as paid) | Earned crates only. Paid and Legacy crates are **kept, not removed** (message: "Only Trait Crates earned in-game can be opened on your account.") |
| Trait Crate with Logs / Pet Egg with Logs | Paid **only if** Logs are Robux-purchasable. Today every log pack has ProductId = 0, so they are not | Allowed now; blocked automatically once any log pack goes live |
| Trait Crate with Souls | Souls cannot be bought | Allowed |
| Lucky Crates pass (odds modifier) | Paid | Effect disabled for restricted players (odds themselves unchanged) |
| Weapon rolls (paid luck boosts) | Out of scope (M1); odds and luck untouched | Documented gap |

**Failure handling:**
- If PolicyService fails, the player is treated as restricted (fail closed).
- Results are cached for 600 s on success and 60 s on failure.

**Known gaps (to close before commerce goes live):**
- The client can still open a product prompt. A server-side purchase gate is needed before any product is activated.
- Pass sales can't be blocked server-side.
- Weapon-roll luck boosts are left for M1.

## 7. Security (M0-E)

Full manifest: `docs/m0/M0_SECURITY_MANIFEST.tsv` (path, class, length, adler, family, markers, disposition).

**Scan:**
- 153 non-game scripts, all in `ServerStorage` import folders. Inspected read-only; nothing was executed.
- The game clones only from `NPCModels`, `TreeModels`, `BladeModels` and `PetModels`, so these scripts were not executable in play unless copied.

**Actions:**
- **Destroyed: 37 malicious root scripts (95 script instances including children).** Families:
  - LightConfig / EasyConfiguration / Type (MarketplaceService);
  - TextureConfiguration (including the Cyrillic homoglyph "Pаckаgе" and self-nesting chains);
  - Runtime / ScreenBuilder;
  - CoreValidation (non-ASCII obfuscation, Kick, string.char);
  - "DO NOT DELETE.Material" plus Credits;
  - EffectBuilder;
  - the 14030-byte qPerfectionWeld variant.
- **Disabled: 53 benign but unused scripts** (Animate, boss and NPC scripts, sword scripts, the standard qPerfectionWeld, …). One ModuleScript (`ItemConfig`) was left inert; it is never required.
- **Not touched:** `P1bBackups.ChopEffects_PreCameraFix` (our own backup).
- **No models, meshes, parts or textures were deleted.** No malicious source was exported, copied to a backup location or sent anywhere. The originals exist only in dev version v18.

**Verification:**
- 57 scripts remain in import folders: 0 enabled, 0 matching malicious patterns.
- 0 hits in active containers.

## 8. Analytics (M0-F)

**APIs** (signatures checked against create.roblox.com docs):
- LogOnboardingFunnelStepEvent, LogProgressionCompleteEvent, LogEconomyEvent and LogCustomEvent.
- No PII: only product config keys and counts.

**Event coverage:**
- **Onboarding steps 1–8:** session, first tree, first upgrade, first weapon, first egg, first trait, first boss encounter, first island unlock. New players only; legacy players are flagged and skipped so the funnel is not polluted.
- **Progression:** Islands, Areas, WeaponTier, Bosses. Milestones a legacy player already reached are seeded silently.
- **Economy:** Logs and Souls sources and sinks, aggregated per player every 60 s.
- **Custom events:** receipt outcomes, save failures and session events.

**Delivery:**
- Global budget of 20 events/s, queue capped at 500 (excess dropped and counted).
- Each send is wrapped in `pcall`, so a failure never reaches gameplay.

**Local results (Studio, single client; simulated, NOT dashboard-verified):**
- Economy events fired. Studio printed "LogEconomyEvent event fired."; examples: `Logs_Source` 234,919 and then 247,411 per 60 s window.
- With analytics disabled, the next flush counted `failed=1` while chopping and the profile stayed active.
- **Dashboard ingestion, funnels and D1/D7 retention are not claimed.**

## 9. Test matrix

Legend: **I** = Implemented · **L** = Locally validated (Studio, one client) · **E** = Externally verified · **P** = Blocked / pending

| Test | Result | Status |
| --- | --- | --- |
| T1 baseline: 35 scripts checksum-match the repo; 620 trees; checkpoint v18 | Pass | L |
| T2 migration: 8 fixtures (new, v3, rare, high, paid, old/missing + Coins + retired id, invalid, real dev snapshot), idempotence, input not mutated, backup written once and not overwritten, interrupted step fails closed, backup outage refuses load | 73/73 pass (2nd run; the 1st run's single failure was a harness bug, fixed) | L |
| T2 real dev profile migrated in play; backup byte-identical | Pass | L |
| T3 locking, mock store (T3.1–T3.15: duplicate refused, lease refresh, stale takeover, stale write rejected, release, retries, outage, corrupt, 50 simulated handoffs) | 15/15 | L (logic only) |
| T3 locking on a real DataStore (`M0_TestStore`), single process | 11/11 | L |
| T3 live: second session against the owner's in-use profile → `locked`; its write → `lost`; record unchanged | Pass | L |
| T3 lock released on stop (`_Session` nil, twice) | Pass | L |
| **T3 50 real cross-server cycles** | **Not run.** The mock and single-process runs are not a substitute | **P** |
| T4 receipts T4.1–T4.13 (synthetic, injected dependencies) | 13/13 | L |
| T4 real ProcessReceipt with unknown product → NotProcessedYet, nothing written | Pass | L |
| T4 live Robux receipts / duplicate re-delivery by Roblox | Not run (no products active; not authorized) | P |
| T5 pure (crate origins, Logs-paid classification) | 6/6 | L |
| T5 end-to-end: restricted and policy-failure free-crate roll refused with message, crates kept (11 Legacy) | Pass | L |
| T5 real PolicyService on a restricted account | Not run | P |
| T6 security: manifest, quarantine, 0 remaining, active containers clean | Pass | L |
| T7 analytics events fire; disabled-service isolation | Pass (Studio) | L |
| T7 dashboard ingestion | Not checked | P |
| T8 smoke: load, data sync (no Purchases/_Meta/_Session/Analytics leaked to client), multipliers, chopping, autosave, release | Pass | L |
| T8 smoke: rolls, trait, pets, travel and camera-fade not exercised in this session (scripts unchanged and checksum-verified) | Not exercised | P |
| T9 before/after comparison of ≥5 profiles | 8 profiles: **1 real dev profile, 7 synthetic** | L |
| T10 iPhone / two-device multiplayer | Not run | P |

## 10. Observations and blockers

1. **First-load latency.** Client scripts log `Infinite yield possible on leaderstats` (AFKController, PvPSoulController): the profile load (UpdateAsync, plus the backup on first load) took more than 5 s in Studio. They recover once leaderstats appears. Live latency is unmeasured.
2. **Test-harness caveat.** Code run from the MCP or command bar uses a separate module cache. `require(DataService)` there creates a second instance, which re-binds `GetData.OnServerInvoke` with an empty profile table. This affects tests only, but in a playtest run `M0Tests` **after** any client checks. Studio-only `DevGrant`, `DevStore` and `DevAnalytics` bindables are used for cross-cache inspection.
3. **Edge case.** If a brand-new player leaves while loading, the release writes `{}`. Their next join migrates that empty record, with a trivial backup. This is harmless but worth tidying later.
4. **Pending owner actions:**
   - real cross-server lock test (≥50 cycles, two live servers);
   - private dev publish if wanted for iPhone/2-device testing;
   - a server-side purchase gate before any commerce goes live;
   - decide whether to keep or roll back the extra dev Logs;
   - confirm v17 and v19–v22 in Version History.

## 11. Git

- Branch `m0/foundations`, based on `p1b2r/camera-visibility-fix` @ `d222d98`.
- Not merged into `main`; no force-push.
- Commit SHA: see the push report / branch head.
