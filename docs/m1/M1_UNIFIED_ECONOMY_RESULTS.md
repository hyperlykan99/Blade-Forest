# M1 — Unified Economy & Progression: Results

_Claude, 2026-11-20 (PST). Branch `m1/unified-economy-progression` (based on `m0.1/foundations-corrections`). Not merged, not published._

| Item | Value |
| --- | --- |
| Place | **Dev only:** `103379930563763` / universe `10777797608`. Every Studio write was preceded by `assert(game.PlaceId == 103379930563763) assert(game.GameId == 10777797608)`. Production `73142469975141` / `10777481912` was **not accessed or modified**. |
| Rollback checkpoint | Dev **v29**, relabelled "M1 PRE-ECONOMY checkpoint (= M0.1 v29 state)" (updateTime unchanged 2026-11-20T12:42:47.246Z). `ServerStorage.M1Backups`: 48 `<Name>_PreM1` ModuleScript copies (attributes OriginalPath / OriginalClass / Checksum, all verified) + `DevProfileSnapshot_p_394034825` (profile JSON 3914:1028722392). |
| Result | Dev **v35** "M1 UNIFIED ECONOMY & PROGRESSION (dev only, not published)…" (Team Create save, Open Cloud `updateTime` 2026-11-21T00:06:47.217Z). v30–v34 were not saved explicitly by Claude (probably Team Create auto-saves during playtests). |
| Paid products | None activated. No receipts, passes or prices changed. |
| Tests | **M1 41/41**, M0.1 64/64, M0 regression 107/107, real-DataStore lock suite 11/11 (single process), plus a single-client live smoke test (§11). |

Checksums below are `length:Adler-32` of the script source, identical in Studio and in the repo (verified for all 26 M1 files plus untouched `ChopEffects` 27331:1017905967 and `TreeKit` 5038:3027397391).

---

## 1. Implemented systems

| Part | What exists now |
| --- | --- |
| **M1.1 Economy engine** | `ReplicatedStorage.Economy` (pure functions, no state) + `ReplicatedStorage.EconomyConfig` (generated). Every Logs / Luck / damage / Souls multiplier, price, reward, rebirth cost, gate, altar and movement value is computed here. Server (DataService.RecalcMultipliers) and client UI call the same functions. |
| **M1.2 Balance** | Progression-tier pricing (8 tiers by best owned weapon Power, capped by island access) replaces BestArea pricing for crates, eggs, Log Packs, Sawmill, rewards, codes and rebirth. New tree Logs ladder. Two permanent Souls sinks. Reproducible simulator in `tools/econsim/`. |
| **M1.3 Walk Speed** | New upgrade `WalkSpeed`, 25 levels, 16 → 24 studs/s, resets on rebirth. Server sets `Humanoid.WalkSpeed` on every spawn and recalc (`DataService.ApplyMovement`). |
| **M1.4 Forest Renewal** | New upgrade `Renewal`, 20 levels, −2 %/level, max −40 % regrow time, resets on rebirth. Personal, server-authoritative, budgeted. |
| **M1.5 Island altars** | Timber Haven / Crystal Wilds / Frostbound Reach altars with distinct cumulative pools, exact odds shown in the Index, player-selectable, guaranteed progression weapon after N rolls. |
| **M1.6 Island gates** | Crystal Wilds and Frostbound requirements staged (`active` / `planned`); unbuilt boss requirement shown but never blocks; existing unlocks grandfathered. |
| **M1.7 AFK integration** | AFK Mode, Auto Chop, Auto Roll, session stats, Battery Saver and the M0.1 safe hop untouched. No AFK penalty. `EconomyTelemetry` measures AFK vs active Logs/h, rolls/h, rares, trees, congestion and server heartbeat. |
| **M1.8 Future-proofing** | Reserved bonus channels that can only feed the existing capped pools; Tech Tree (6 branches × 12 nodes) reserved, not implemented; edition-based permanent index records. |
| **M1.9 Simulator** | `tools/econsim/m1sim.py` + `m1report.py`, 7 player scenarios × 200 h, reading the same `economy_params.json` that generates `EconomyConfig`. Golden values (`golden.py`) are asserted by the in-game tests, so game and model cannot drift. |

### Files

New:

| File | Studio path | Checksum |
| --- | --- | --- |
| `src/shared/Economy.luau` | ReplicatedStorage.Economy | 14311:1316460096 |
| `src/shared/EconomyConfig.luau` (generated, do not hand-edit) | ReplicatedStorage.EconomyConfig | 6888:252679382 |
| `src/server/EconomyTelemetry.luau` | ServerScriptService.EconomyTelemetry | 5568:2419666984 |
| `src/serverstorage/M1Tests.luau` | ServerStorage.M1Tests | 14747:2635000309 |
| `tools/econsim/*` | — | simulator, config generator, golden values, reports |

Changed (before → after):

| File | Before | After | Change |
| --- | --- | --- | --- |
| `src/shared/BladeConfig.luau` | 55586:167717973 | 59230:2212042401 | Requires EconomyConfig (`Config.Economy`); upgrades from config (adds WalkSpeed, Renewal); tree ladder; T/Qa/Qi number suffixes; `GetPriceUnit(who)` accepting a unit, a Player (PriceUnit attribute) or a legacy area id; crate/egg/log-pack/reward/rebirth prices by tier; Codes; `IndexEditions`; Soul upgrades in `SoulShop` + `GetSoulUpgradeCost`; Sawmill rate from config; island required Power from Gates; `AreaIsland`. |
| `src/server/DataService.luau` | 33750:626150713 | 40381:2524911748 | New additive fields (`IndexEditions`, `SoulUpgrades`, `BossKills`, `AltarRolls`, `AltarGuarantee`, `EconomyVersion`); `RecalcMultipliers` via Economy (attributes LogMult, LogMultBase, LogTemp, LuckMult, LuckTemp, BestPower, UnlockedIslands, PriceTier, PriceUnit, Pets, WalkSpeedStat); `ApplyMovement`, `PriceUnit`, `GateContext`, `IslandGate`, `TryUnlockIsland`, `AddBossKill`, `updateIndexEditions`; recalc on EventLogs/EventLuck change; `AddCoins` no longer multiplies by EventLogs separately (strongest temp is inside LogMult); legacy index flags migrated to editions in `prepare()`. |
| `src/server/CombatServer.server.luau` | 21991:1077912845 | 24637:854333739 | Forest Renewal respawn (`respawnDelay` + server token bucket); `ApplyMovement` on spawn; Blade King rewards via `Economy.BossReward` for eligible fighters, `AddBossKill`; chop / boss / heartbeat telemetry. |
| `src/server/ExtrasService.server.luau` | 12732:3387824125 | 13108:159226946 | Egg price by tier; Sawmill by price unit; Treant rewards via `Economy.BossReward`, `AddBossKill("Treant")`, telemetry. |
| `src/server/RollService.server.luau` | — | 5559:288906485 | Rolls use the player's altar (`Economy.RollAltar`), guarantee counter, `Roll("SetAltar", island)` (unlocked islands only), roll telemetry. |
| `src/server/MetaService.server.luau` | — | 12012:2472929737 | Code rewards incl. Logs; tier rebirth cost. |
| `src/server/Progress.luau` | — | 4222:202795260 | Rewards priced by the player's unit. |
| `src/server/TraitService.server.luau` | — | 5859:42095527 | Crate price by tier. |
| `src/server/StoreService.server.luau` | — | 10199:81582006 | Log Pack amount by tier (products still not live). |
| `src/server/SoulService.server.luau` | — | 2580:723279740 | Level-based Soul upgrade purchase. |
| `src/server/TravelService.server.luau` | — | 9732:4232117319 | `TryUnlockIsland` (lists every unmet requirement). |
| `src/server/AreaService.server.luau` | — | 2411:2526158781 | Legacy wedge areas respect island gates (`AreaIsland`). |
| Client: Extras / Index / Store / Meta / Roll / Traits / PvPSoul / AutoChop / AFK / UIController | — | 16065:561929495 / 17443:1408594220 / 11454:2792430064 / 24648:3191251604 / 20085:991771289 / 15490:858316764 / 14334:1507638375 / 13016:1929394645 / 10477:1818816447 / 18099:1265222923 | Prices shown by tier; altar button + exact odds + per-weapon altar label + edition bonus text (Index); Soul upgrade levels (PvPSoul); AutoChop respects island gates and uses the real server Walk Speed; AFK reports state for statistics only; upgrade cards show `Lv x/max`, MAX, next benefit. |

Baseline checksums of every changed file are recorded on its `_PreM1` backup in `ServerStorage.M1Backups` and in the patch generator assertions (each patch refused to apply unless the Studio source matched the M0.1 baseline exactly).

---

## 2. Formulas

`soft(S, C) = C · (1 − e^(−S/C))` — additive category pool S, soft cap C (diminishing, never exceeds C).

**Logs multiplier**

```
LogMultBase = (1 + soft(S_perm, 6)) · (1 + soft(S_pets, 3)) · (1 + soft(0.25·rebirths, 3)) · passes
LogMult     = LogMultBase · min(strongest temporary Logs source, 2)
```
- `S_perm` = trait bonus + index editions + Soul Blessing + future channels. Soft cap +600 %.
- `S_pets` = equipped pets' Logs bonuses. Soft cap +300 %.
- Rebirth: +25 % each, tapering (n=1 ×1.24, n=4 ×1.85, n=8 ×2.46, n=20 ×3.43; old was 1 + 0.25n, uncapped).
- `passes` = advertised game-pass effects **unchanged and outside the pools**: 2× Logs ×2, VIP ×1.1.
- Temporary sources (Log Boost potion ×2, Logs events ×2, PvP ×1.5): the **strongest one** applies, they never stack.

**Luck**

```
Luck = min(50, (1 + soft(S_luck, 4)) · 2xLuck pass · min(strongest temporary luck, 10))
```
- `S_luck` = Lucky Charm (+0.04/level), rebirths (+0.10 each), group (+0.10), pets, index editions, Soul Fortune.
- Permanent luck soft cap ×5; hard cap ×50; strongest temporary source only (Starter ×2, Luck Potion ×3, Mega Luck ×10, luck events).
- Lucky roll ×2 still applies, capped at 50.
- Effective odds: `OneIn_eff = OneIn / luck^γ(rarity)` with γ = 1 for Common–Epic, 0.9 Legendary, 0.75 Mythic, 0.6 Secret, 0.5 Divine; luck only applies to weapons rarer than 1 in 10.

**Prices**

- `Unit(tier)` ≈ 2 minutes of median free-active income at that tier (table in §4).
- Trait Crate = 1.0 Unit; Pet Egg = 1.5 Units; Sawmill 0.35 Units per Soul (÷ hourly rate); Log Packs S/M/L = 3 / 15 / 60 Units; code/gift/daily Logs rewards are expressed in Units.
- Rebirth cost = `max(1,000,000, 15 · 1.15^n · Unit(tier))`.
- Boss Logs = `LogsUnits · Unit(tier) · LogMultBase^0.5 · share` (Blade King 0.35, Treant 1.6); every fighter with ≥ 2 % damage (or the top hitter) is paid. Boss Logs are added raw (no LogMult on top).

**Movement**: `WalkSpeed = 16 + 0.32 · level` (max 24) `+ min(futureMobility, 4)`; `MaxLegitWalkSpeed = 28`.

**Renewal**: `respawn = max(3 s, base · (1 − 0.02 · level))` for Common…Epic trees felled by that player; Legendary/Mythic/Secret always full time.

**Index editions**: per area, Standard set +8 % Luck / +8 % Logs, Mastery (Secret) +2 % / +2 %; Frost Peaks' Divines count as its Standard set with the full +10 % / +10 % (no revocation of the existing bonus); tree index +5 % Logs per area. Records are permanent keys `Weapon/<area>/<Standard|Mastery>/<edition>` and `Tree/<area>/All/<edition>`.

---

## 3. Upgrade configuration

| Upgrade | Levels | Value | First cost | Cost ×/level | Last level | Total to max | Resets on rebirth |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Blades | 5 | 1 → 6 blades | 100 | 18 | 10.50M | 11.12M | yes (unchanged) |
| Speed | 50 | 3 + 0.15/level spin | 30 | 1.28 | 5.38M | 24.57M | yes (unchanged) |
| Damage | 100 | ×1 + 0.1/level | 40 | 1.15 | 40.85M | 313.15M | yes (unchanged) |
| Reach | 40 | 4 + 0.2/level studs | 60 | 1.3 | 1.67M | 7.22M | yes (unchanged) |
| Lucky Charm | 100 | **+0.04 luck pool/level** (was ×+0.05) | **1,500** (was 150) | 1.16 | 3.61B | 26.17B | yes |
| **Walk Speed** (new) | 25 | 16 → 24 studs/s (+0.32) | 400 | 1.42 | 1.81M | 6.11M | yes |
| **Forest Renewal** (new) | 20 | −2 % regrow/level, max −40 % | 2,500 | 1.45 | 2.91M | 9.37M | yes |
| Soul Blessing (new, Souls) | 20 | +0.03 permanent Logs pool/level | 200 Souls | 1.3 | — | — | **no** (permanent) |
| Soul Fortune (new, Souls) | 20 | +0.03 permanent Luck pool/level | 250 Souls | 1.3 | — | — | **no** (permanent) |

The shop shows level, `Lv x/max`, current → next benefit, price, and MAX when maxed (verified live: "Lv 0/25 • 16.0 studs/s → 16.3 studs/s / 400 Logs"; "Lv 0/20 • -0% regrow → -2% regrow / 2,500 Logs").

Walk Speed safety: one server calculator (`Economy.WalkSpeed`), applied by the server on spawn, respawn, recalc and travel; the client never sets it. `MovementGuard` still checks against the server WalkSpeed × 1.35, so an upgraded walker is never flagged and a 2× speed hack still is (E3.11). Auto Chop path scoring uses the real Humanoid speed.

Renewal safety: only trees the player fells; only Common–Epic; 3 s minimum; a server-wide token bucket allows at most 10 accelerated regrowths per second (burst 20), otherwise the normal timer applies, so 20 max-Renewal players cannot flood TreeKit. Trees regrow on the same spots (no layout change, the 620 Crystal Wilds trees are untouched).

---

## 4. Bonus and pricing changes

### Price tiers (replace BestArea)

| Tier | Name | Power ≥ | Highest island counted | Unit | Crate | Egg | Blade King (½ share, LM 1) | Treant (full) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Sapling | 0 | Timber Haven | 750 | 750 | 1.12K | 262 | 1.20K |
| 2 | Pinewood | 40 | Timber Haven | 80K | 80K | 120K | 28K | 128K |
| 3 | Crystal I | 250 | Crystal Wilds | 8M | 8M | 12M | 2.8M | 12.8M |
| 4 | Crystal II | 700 | Crystal Wilds | 12M | 12M | 18M | 4.2M | 19.2M |
| 5 | Frost I | 2,000 | Frostbound | 70M | 70M | 105M | 24.5M | 112M |
| 6 | Frost II | 3,000 | Frostbound | 80M | 80M | 120M | 28M | 128M |
| 7 | Frost III | 4,500 | Frostbound | 100M | 100M | 150M | 35M | 160M |
| 8 | Frost IV | 6,500 | Frostbound | 120M | 120M | 180M | 42M | 192M |

Old crate prices by BestArea: 750 / 25K / 600K / 8M.

### Tree Logs

`Logs = TreeBaseLogs[area] · ladder[rarity]`. Bases: Starter Grove 2, Pine Forest 50, Crystal Canyon 900, Frost Peaks 9,000. Ladder Common…Secret: 1, 2.2, 4.7, 10, 28, 111, 444.

### Souls

New permanent sinks (Soul Blessing, Soul Fortune) without forging or runes. Existing Soul Shop items unchanged. Sawmill now tier-priced.

### Rebirth

Old: `1M · 3^n` (n=2 → 9M, n=8 → 6.56B), bonus +25 % Logs each, uncapped. New: tier-scaled and gentler growth (tier 4: n=2 → 238M, n=8 → 551M; tier 8: n=8 → 5.5B), bonus tapers (§2). Rebirth still resets Logs and the Logs upgrades (existing mechanic kept).

### Maximum builds (simulator §7)

| Build | Old (audit §8) | M1 |
| --- | --- | --- |
| Free max Logs (no temp) | ×106–122 | **×42.9** (×85.9 in a ×2 event) |
| Paid max Logs (no temp) | ×466 (×1,630 with 10 rebirths) | **×99.7** |
| Free max Luck | ×644 | ×4.5 (×45.3 with Mega Luck), hard cap ×50 |

### Dev profile p_394034825 (no progression cliff in multipliers)

LogMult old ×3.47 → M1 ×3.37 (−2.6 %); Luck old ×2.64 → M1 ×2.58 (−2.3 %); live values matched exactly (LogMult 3.37, LuckMult 2.58, tier 4, Unit 12M). Saved Logs, Souls, purchases, collectibles, weapons (22) and weapon Power untouched (E4).

| Item | Old price = minutes of old income | M1 price = minutes of M1 income |
| --- | --- | --- |
| Trait crate | 8.0M = 7.7 min | 12.0M = 11.9 min |
| Pet egg | 12.0M = 11.6 min | 18.0M = 17.8 min |
| Next rebirth (3rd) | 9.0M = 8.7 min | **238M = 236 min** at zero upgrades |

The rebirth line is the one real cliff for this profile: its old 9M was far below any tier-scaled price. Its income at zero upgrades is 60.6M/h; after re-buying the cheap chop upgrades (minutes of play) typical mid-game income is 0.26–1.3B/h, i.e. about 11–55 min. Flagged as owner decision #2 (§10).

### Time-to-afford, typical free-active player (minutes of own median income at that horizon)

| Horizon | Trait crate old → M1 | Pet egg old → M1 |
| --- | --- | --- |
| 0.5 h | 0.30 → 1.54 | 0.44 → 2.30 |
| 2 h | 0.01 → 1.87 | 0.02 → 2.81 |
| 8 h | 0.00 → 3.22 | 0.00 → 4.83 |
| 24 h | 0.00 → 1.81 | 0.00 → 2.71 |
| 72 h | 0.00 → 1.58 | 0.00 → 2.36 |
| 200 h | 0.01 → 1.40 | 0.02 → 2.09 |

Old prices fell to effectively zero within 2 h (BestArea pricing vs uncapped multipliers); M1 keeps them at 1.5–5 min all game.

---

## 5. AFK decisions

- No blanket AFK penalty. AFK Mode, Auto Chop, Auto Roll, session stats, Battery Saver and the M0.1 save-and-release hop are unchanged.
- AFK players earn the same per-tree and per-roll rewards; the gap to active play comes from what AFK cannot do (bosses, gifts collected late, worse purchase timing) — as intended.
- Auto Chop: Walk Speed feeds its path scoring; locked legacy wedge areas are skipped (UnlockedIslands attribute). Live check: 40 s of Auto Chop moved the avatar 159 studs and earned +298K Logs with 0 movement violations and 0 errors.
- Telemetry (`EconomyTelemetry`, statistics only, never affects rewards): per-player Logs/h by source (chop/boss/other), Souls/h, trees/h, rolls/h, rares/h, AFK share; per-server players, trees alive per area, felled/s, renewals granted/refused, heartbeat avg/max ms. Studio: `ServerStorage.DevEconomy:Invoke("Report")`. Live: hourly `Analytics.Custom("EconomyLogsPerHour")` (untested outside Studio).

Simulated AFK / active (free, cumulative Logs, median): 2 h 0.76 · 8 h 0.57 · 24 h 0.49 · 72 h 0.63 · 200 h 0.65 (paid: 0.55–0.68). Target 0.60–0.75 is met at 2 h, 72 h and 200 h but **missed at 8–24 h** (see §10 #1). The 0.5 h value (5.55) is noise from tiny early totals.

---

## 6. Altar pools

| Altar | Pool | Size | Guarantee |
| --- | --- | --- | --- |
| Timber Haven | Starter Grove + Pine Forest weapons | 24 | Crimson Crescent after 2,500 altar rolls if best Power < 250 |
| Crystal Wilds | + Crystal Canyon | 34 | Umbraxe after 20,000 altar rolls if best Power < 2,000 |
| Frostbound Reach | + Frost Peaks (all 38 rollable weapons) | 38 | — |

- All 43 weapon IDs and every owned copy are preserved; non-rollable weapons (Soul Shop / Starter Pack exclusives) are unaffected. Every rollable weapon is still obtainable (E2.3).
- Default altar = highest unlocked island; the player can switch between unlocked islands (Index → "🛕 Altar" button, `Roll("SetAltar", id)`; locked or unknown islands refused).
- Odds: the Index shows for each weapon its base odds and "you: 1 in N" from `Economy.AltarOdds`, the same function the server draws from; odds sum to exactly 1 (E2.4) and 200,000 simulated rolls match them (max |z| 1.67, E2.7). Weapons outside your altar show which altar has them.
- Pools are data (`EconomyConfig.Altars`), so the 120-weapon roster (M2) only adds entries.
- **Paid-random check:** altar rolls are free, so not paid random items. Odds-enhancing passes/potions (2× Luck, Mega Luck) require disclosed odds, which the exact-odds UI provides. Logs-priced crates/eggs become paid random once Log Packs are live; that stays gated by the M0 `Policy` check. No paid route was enabled.

---

## 7. Gate staging

| Island | Requirements (all must be met) | Stage |
| --- | --- | --- |
| Crystal Wilds | Best weapon Power ≥ 250; defeat the Blade King once; chop 600 trees in Starter Grove + Pine Forest | all `active` |
| Frostbound Reach | Power ≥ 2,000; chop 6,000 Crystal Canyon trees | `active` |
|  | Defeat the Crystal Colossus | `planned` — displayed, **never blocks** until the boss exists (flip `Stage` to `active`) |

- Islands already unlocked in a save stay unlocked (grandfathered); the dev profile keeps all three.
- `TryUnlockIsland` lists every unmet requirement; legacy wedge areas inside an island obey the same gate (`AreaIsland`), so the gate cannot be bypassed by walking.
- Boss kills are counted per player (`BossKills`) for eligible fighters only. Tree counts use the existing per-area chop statistics.
- Guaranteed progression weapons are the altar guarantees above. No new bosses were built.

---

## 8. Future-proofing (reserved, not implemented)

- `EconomyConfig.Future.Channels`: Mastery, TechTree, Guild, Runes, TreeBadges, Trait2, Forging, Awakening, Season, Expedition. Each one can only add to an existing capped pool (permanent Logs, pets, permanent Luck, damage-extra, souls-extra); **no future feature gets its own multiplier**.
- Tech Tree: 6 branches (Blade, Forest, Fortune, Explorer, Artisan, Guardian Mastery) × 12 nodes, max 25 % share of a pool. Not built.
- Targets recorded: 120 weapons, 12 traits, 21 pets, 100 Mastery levels; future-island scale ×10 Strength / ×12 Logs / ×12 prices; weapon Power island multipliers 1 / 4 / 16.
- `MobilityExtraMax` = +4 walk speed reserved for Tech mobility.
- Edition-based index records allow future editions without revoking old ones.
- Weapon and tree models and islands unchanged.

---

## 9. Simulator output

Run: `cd tools/econsim && ./run_all.sh 24` (7 scenarios × 24 seeds × 200 h; full report `results/m1/REPORT.txt`). Model estimates for one solo server.

**Median Logs/h (free active)**: 0.5 h 3.1M · 2 h 256M · 8 h 1.30B · 24 h 2.32B · 72 h 3.04B · 200 h 4.30B (old rules: 122M · 2.61B · 13.2B · 20.1B · 25.8B · 35.4B).

| Scenario | Crystal Wilds unlock (p50) | Frostbound unlock (p50) | First Legendary / Mythic / Secret / Divine | Rebirths at 24 h / 200 h |
| --- | --- | --- | --- | --- |
| free new | 22 min | 6.4 h | 55 min / 6.3 h / 67 h / not reached | 8 / 24 |
| free casual | 21 min | 6.4 h | 57 min / 5.8 h / 50 h / not reached | 9 / 25 |
| free active | 34 min | 6.6 h | 55 min / 6.6 h / 66 h / not reached | 10 / 28 |
| free AFK | 26 min | 6.2 h | 43 min / 6.2 h / 48 h / not reached | 6 / 24 |
| paid active | 10 min | 2.5 h | 16 min / 1.8 h / 13 h / not reached | 16 / 36 |
| paid AFK | 8 min | 3.4 h | 28 min / 2.8 h / 20 h / not reached | 12 / 33 |
| whale active | 5 min | 2.2 h | 2 min / 42 min / 11 h / 125 h | 20 / 40 |

Old rules: Crystal 11 min, Frost Power 3.5 h.

- Free vs paid (cumulative Logs): paid/free 5.2× at 2 h → 2.7× at 24 h → 2.3× at 200 h; whale/free 14× → 5.1× → 4.0×. Free players reach every island and all core progression.
- **20-player server (Crystal Wilds supply)**: 620 trees supply ≈ 47.8 trees/s; one mid-game player wants ≈ 23/s. 5 players each get 41 % of solo income, 10 → 21 %, 20 → 10 %. Max Renewal for everyone adds only ~1–2 points under the 10/s budget.
- **Future islands**: at legacy Frost density (1 tree / 150 stud²) Frostbound pays less than Crystal Wilds (FAILS); at 1/60 or denser, island order equals income order. Island 4 at ×12 Logs works at every density.
- Assumptions: player policies in `m1sim.py` (buy upgrades with payback ≤ 2 h; rebirth before luck/pets; eggs only when Logs − egg ≥ ½ rebirth cost; roll at the highest altar); boss participation by mode (AFK 0 %); tree supply solo; paid = 2× Logs + VIP + 2× Luck; whale adds potions. Failures are listed in §10.

---

## 10. Remaining issues and owner decisions

1. **AFK ratio dips below target at 8–24 h** (0.57 / 0.49 vs 0.60–0.75). Cause: AFK players skip bosses (≈ 35–40 % of active income at that stage) and rebirth later. Options: (a) accept; (b) a small AFK boss participation reward; (c) lower boss share. No AFK penalty was added.
2. **Dev profile rebirth cost** 9M → 238M (§4). Options: accept (intended reprice); or soften the first rebirths at Crystal tiers (e.g. cap `n < 4` at tier 3 Unit).
3. **Multiplayer tree supply** is the real ceiling in busy Crystal Wilds servers (§9). Needs server-size / density / instancing decision; Renewal cannot fix it within the CPU budget.
4. **Frostbound density** (audit M8): Frost Peaks pays less than Crystal Wilds. Fix belongs to the Frostbound build (M4b): density ≥ 1/60 or higher Logs.
5. **No Divine for free players by rolling within 200 h.** A deterministic route (forge/crafting, M2/M6) is still required.
6. Logs upgrade costs are absolute: cheap after ~8 h; Lucky Charm and rebirths are the long sinks.
7. Startup in Studio logs "Script timeout" warnings in `MetaController.tagSfx` and `UIStyler.onWorld` while 5,021 breakables stream in. M1 did not touch those functions; most likely pre-existing (unverified on the M0.1 build).
8. **Not tested live** (rule 11): multiplayer, two-player bosses, Blade King / Treant reward payout in play (formula covered by E1.12 only), an actual gate unlock, accelerated Renewal respawns (no Renewal levels bought), altar guarantees, cross-server, real teleport, mobile/iPhone, live Analytics event.
9. Paid products remain inactive; Log Pack amounts are tier-scaled but no product IDs exist.

---

## 11. Tests

| Suite | Result | Notes |
| --- | --- | --- |
| `M1Tests.RunAll()` | **41/41** | E1 formulas vs simulator golden values (12); E2 altars, pools, exact odds, 200k-roll test (10); E3 tiers, gates, Walk Speed, MovementGuard, Renewal, index editions (11); E4 save compatibility on the real dev snapshot, in memory (8). |
| `M01Tests.RunAll()` | 64/64 | M0.1 regression. |
| `M0Tests.RunAll({bk3 profile})` | 107/107 | bk3 read with GetAsync only. |
| `M0Tests.RunDataStore(M0_TestStore)` | 11/11 | Real DataStore, single process (test store only). |

Live single-client smoke test (dev place, one Studio client):
- No server or client script errors (only Roblox CoreGui and startup "Script timeout" warnings, §10 #7).
- Server attributes LogMult 3.37, LuckMult 2.58, BestPower 1834, PriceTier 4, PriceUnit 12M, UnlockedIslands all three. Client GetData exposes no `_WriteSeq` / `_Session`.
- Bought Walk Speed L1: server and client Humanoid 16.32, kept after respawn.
- `SetAltar CrystalWilds` OK; bogus island refused ("Locked"); one roll at the Crystal Wilds altar (Uncommon, auto-sold duplicate); altar set back to Frostbound.
- Bought Soul Blessing L1: Souls 314 → 114, LogMult 3.37 → 3.47.
- Auto Chop 40 s: 159 studs walked, +298K Logs, 0 movement violations; telemetry recorded ≈ 600 trees/h, heartbeat avg 4.6 ms.
- Stop play: session lock released (`_Session` nil), `_WriteSeq` 29.

---

## 12. Save compatibility

- Save format stays **Version 4**; no migration step added. All M1 fields are additive with defaults; existing values are never rewritten (E4.4).
- Legacy `IndexDone` / `TreeIndexDone` flags become permanent edition records in `prepare()`, keeping exactly the old bonus (E4.8).
- Currency, purchases, collectibles, weapon copies/stars/Power, pets, traits, codes and island unlocks are preserved.
- Rollback: restore dev v29, or copy each `ServerStorage.M1Backups.<Name>_PreM1` back over `OriginalPath` and delete Economy, EconomyConfig, EconomyTelemetry and M1Tests. The extra M1 fields in a save are ignored by the v29 code.

**Dev save writes during M1 (account 394034825, dev DataStore only):** Logs 8,836,279 → 9,246,033 (−400 Walk Speed L1, +3 roll auto-sell, +≈410K Auto Chop); Souls 314 → 114 (Soul Blessing L1); `Levels.WalkSpeed` = 1; `SoulUpgrades.SoulBlessing` = 1; `AltarRolls.CrystalWilds` = 1; `Settings.Altar` = FrostboundReach; one roll added (RollNumber 474); `IndexEditions` populated; `_WriteSeq` 23 → 29. `bk3_p_394034825` only read. The `DevProfileSnapshot` in M1Backups holds the pre-M1 copy.

---

## 13. Next dependencies

- Owner decisions §10 #1–#3.
- M2 weapon roster (120 weapons) → add to `EconomyConfig.Altars` pools and odds; deterministic Divine route.
- Crystal Colossus boss → set Frostbound requirement `colossus` Stage to `active`.
- M4b Frostbound build: density / Logs so island order = income order (§9).
- Tech Tree / Mastery / forging / runes: implement only as contributions to the reserved channels.
- Multiplayer validation (bosses, tree supply, Renewal budget) and iPhone, when testing is authorised.
