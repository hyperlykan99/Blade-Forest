# Blade Forest — Economy and Monetization Audit

_Read-only audit by Claude, 2026-11-18. No gameplay, prices or scripts were changed._

**Source:** live Team Create place `73142469975141`, Edit mode. 34 scripts, 393,047 bytes, unchanged since the previous inventory.

**Scripts inspected:** BladeConfig, StoreService, RollService, ExtrasService, CombatServer, DataService, SoulService, TraitService, MetaService, AreaService, TreeKit, and the client StoreController, TraitsController, ExtrasController, RollController and IndexController.

**Model:** `docs/economy_sim.py`. Re-run it after any config change.

## How to read this report

| Tag | Meaning |
|---|---|
| **[VERIFIED]** | Read directly from the live script source or computed exactly from config values |
| **[DERIVED]** | Exact arithmetic on verified values (for example the maximum multiplier stack) |
| **[ESTIMATE]** | From the progression model. Depends on assumed chop pacing, session lengths and spending choices. Treat as direction and order of magnitude, not as forecasts |
| **[UNVERIFIED]** | Not inspected line by line. Confirm before acting |

The Robux prices below are the `Price` fields in BladeConfig, which drive the in-game store labels. They are **not** read from the Creator Dashboard. Whether the passes are on sale, and at what actual price, was not checked.

---

## 1. Executive summary

### Critical (fix before launch or ads)
1. **None of the 9 developer products can be bought [VERIFIED].** Every `ProductId = 0`, so `ProductByProductId` is empty. The store skips the prompt (`if item.ProductId == 0 then return end`). If a receipt did arrive, `ProcessReceipt` would return `NotProcessedYet` forever. Today's Robux revenue is game passes only.
2. **Paid luck stacks multiplicatively without limit, and weapon rolls are free and unlimited [VERIFIED / DERIVED].** The highest reachable luck is about **27,720×**, or about **6,930×** for a free player, before rebirths. Above that, every weapon at or below 1-in-27,720 rolls guaranteed, and the 1-in-100,000,000 Divine drops to about 1 in 3,600 rolls. Paid luck is a 4× multiplier on time-to-gate. With the planned Mega Luck product it becomes roughly 40×. That is the main pay-to-win lever.
3. **Area gates are too easy at the start and too hard at the end [ESTIMATE].**
   - Free players pass the Pine Forest (40 power) and Crystal Canyon (250 power) gates within about **4 minutes**, through free rolls alone.
   - The Frost Peaks gate (2,000 power, roughly a 1-in-600,000 weapon) leaves **about 70% of free players still stuck in Crystal Canyon on day 7**, while every heavy payer reaches it on day 1.
   - Content runs out on D1, then a long plateau follows. That is a classic D1/D7 retention risk.
4. **Once log packs are live, the restricted-region (paid random items) handling is incomplete [VERIFIED code; policy per Roblox docs].**
   - Logs can then be bought with Robux, which makes Logs-paid **Trait Crates** and **Pet Eggs** paid random items.
   - Those must be blocked for players with `ArePaidRandomItemsRestricted`. Today only the Robux store tiles are hidden, and only on the client.

### High
5. **Inflation in Frost Peaks [DERIVED].** No area follows it. Log income reaches millions per minute, and every sink is either one-off (max upgrades, 3 pets) or exponential (rebirth). Log packs scale with area, so the Huge pack is **480,000,000 Logs** in Frost.
6. **The "1 in X" shown for common weapons is wrong [VERIFIED].** The roll checks weapons rarest-first, so the actual odds for common weapons are about **half** the displayed odds. For example, Rusty Sickle shows "1 in 3" but is actually 1 in 6.1, and Wooden shows "1 in 2" but is actually 1 in 3.1. Rolls are free, but paid luck changes them, so Roblox's rule for odds-changing items applies.
7. **Save and receipt robustness [VERIFIED].**
   - Saves use `SetAsync` with no session lock, so data can be overwritten or duplicated across servers.
   - `ProcessReceipt` returns `PurchaseGranted` even if the save fails, so a crash can lose a paid grant.

### Medium
- Dead config misleads anyone reading it: `Pity`, `Areas[].RollCost`, and `Rarities[].Chance` / `GetRollOdds` are never used by the live roll.
- The FastRoll auto-roll interval (0.4 s) is faster than the server allows (0.51 s), so every other call is rejected and the pass delivers less than it advertises.
- Playtime gifts are tracked per session, so they reset when a player rejoins.

---

## 2. Currencies and sources

| Currency | Earned from | Spent on |
|---|---|---|
| **Logs** | Trees (`Reward` attribute × LogMult × event), NPCs, Blade King share (pool 5,000), Treant (crate cost × 3), auto-sell of weapons, daily/quest/gift/code/index rewards, **Robux log packs** | Upgrades, Trait Crates, Pet Eggs, Sawmill, Rebirth |
| **Souls** | NPC drops (Slime 1–5, Big Slime 3–8, Golden Slime 10–20, Bandit 10), PvP kill 15, Blade King pool 200, Treant 40–150, Sawmill (max 200/day), quests, dailies, index | Soul Shop (potions, Soul Trait Crate 150, weapons 250 / 900 / 4,000) |
| **Free Crates** | VIP daily (every 20 h), Starter Pack (3), Robux crate products (1 / 10), quests, gifts, Treant, index (Mythic / Divine) | Trait rolls |
| **Weapon rolls** | **Free**, unlimited; 1.0 s (0.6 s with FastRoll) server cooldown × 0.85 | — |

[VERIFIED] Rebirth (MetaService:186) costs `1,000,000 × 3^n` Logs. It resets **all Logs and all upgrade levels** and keeps weapons, pets, traits and area. Each rebirth gives +25% Logs and +10% Luck, permanently and stacking.

---

## 3. Upgrades [VERIFIED]

Cost = `floor(BaseCost × CostMult^level)`.

| Upgrade | Base → per level | Max level | Cost of last level | Total to max |
|---|---|---|---|---|
| +1 Blade | 1 → +1 (max 6, or 7 with the pass) | 5 | 10,497,600 | 11.1 M |
| Faster Spin | 3.0 → +0.15 (spin capped at 5.5; extra becomes damage) | 50 | 5.38 M | 24.6 M |
| Sharper Blades | ×1.0 → +0.1 | 100 | 40.8 M | 313 M |
| Longer Reach | 4 → +0.2 studs | 40 | 1.67 M | 7.2 M |
| Lucky Charm | ×1.0 → +0.05 (max ×6) | 100 | 361 M | 2.62 B |

Finding: Faster Spin past level 17 (spin 5.55) adds damage, not speed. Combined with Sharper Blades, damage multipliers reach about ×11 × (10.5 / 5.5) ≈ ×21 [DERIVED].

---

## 4. Areas and income [VERIFIED config]

| Area | Gate (Power) | Weapon value mult | Trait crate | Egg | Expected logs per tree* |
|---|---|---|---|---|---|
| Starter Grove | 0 | ×1 | 750 | 1,125 | ≈14 |
| Pine Forest | 40 | ×3 | 25,000 | 37,500 | ≈320 |
| Crystal Canyon | 250 | ×9 | 600,000 | 900,000 | ≈3,400 |
| Frost Peaks | 2,000 | ×20 | 8,000,000 | 12,000,000 | ≈34,000 |

\*[DERIVED] Weighted over the 7 tree rarities (weights 55 / 25 / 13 / 5.5 / 1.5 / 0.5 / 0.1). Includes the expected mutation multiplier of about ×1.16. Mutations (checked rarest first): Rainbow 1/800 ×25, Shadow 1/200 ×8, Frozen 1/70 ×4, Golden 1/40 ×3.

**Power** is the equipped weapon's power × star multiplier (1.15 / 1.35 / 1.6 / 2 / 2.5) × Shiny 1.5 (DataService:335). Weapon power = `round(5 × OneIn^0.45)`. **Power therefore comes only from roll luck. Logs never raise Power directly.** When Power is below a tree's Strength, damage is ×0.1.

Weapons that meet each gate:
- 40: Engraved Axe, 1/100.
- 250: Crimson Crescent, 1/7,000 (Warlord Axe at 1/5,000 gives only 231).
- 2,000: Umbraxe, 1/700,000.
- The exclusives (Founder's Edge 60, Soulbound 120, Soul Harvester 300, Forsaken Axe 1,000) don't reach the Frost gate.

---

## 5. Monetization inventory [VERIFIED]

### 5.1 Game passes (live IDs)
| Pass | ID | Config price | Entitlement (code) |
|---|---|---|---|
| VIP | 2094194984 | 399 | ×1.1 Logs, gold tag, 1 free Trait Crate every 20 h |
| +1 Blade Slot | 2092911060 | 249 | `BonusBlades +1`, above the upgrade cap (6 → 7 blades) |
| 2× Luck | 2093457053 | 299 | Luck ×2, stacks multiplicatively |
| 2× Logs | 2092761109 | 299 | Logs ×2, stacks multiplicatively |
| Fast Roll | 2094279037 | 149 | Roll cooldown 1.0 → 0.6 s; auto-roll 1.1 → 0.4 s (see the bug in §8) |
| Lucky Crates | 2093577035 | 199 | Doubles trait weights for ×1.75 and above. `RandomItem = true`, hidden when restricted |
| Starter Pack (sold as a pass) | 2094327011 | 99 | One time: Founder's Edge (Epic, power 60), StarterLuck ×2 for 30 min, 3 free crates |

Handling: ownership is checked on load with `UserOwnsGamePassAsync` (wrapped in pcall) and on `PromptGamePassPurchaseFinished`. The result becomes a server-only `Pass_<Id>` attribute, followed by `RecalcMultipliers`. Clients cannot change server attributes. The Starter Pack is guarded by the saved `d.StarterPack` flag. **No exploit found.**

### 5.2 Developer products (none purchasable: ProductId = 0)
| Product | Config price | Reward | Random? |
|---|---|---|---|
| Luck Potion | 49 | Luck ×3, 15 min | Odds modifier |
| Mega Luck Potion | 199 | Luck ×10, 15 min | Odds modifier |
| Log Boost | 79 | Logs ×2, 30 min | — |
| Small / Big / Huge Log Pack | 39 / 149 / 499 | Area trait-crate cost × 3 / 15 / 60 (Frost: 24 M / 120 M / 480 M) | Indirect currency |
| Instant Trait Crate | 29 | 1 free crate | **Yes** (`RandomItem`) |
| Trait Crate ×10 | 249 | 10 free crates | **Yes** (`RandomItem`) |

### 5.3 Receipt processing (StoreService:150)
- ✅ Waits for the player to be loaded. Idempotent through saved `d.Purchases[PurchaseId]`. Grant wrapped in pcall; returns `NotProcessedYet` on failure. Purchases are kept out of the client sync.
- ⚠️ It returns `PurchaseGranted` after `pcall(DataService.Save)` whether or not the save succeeded. If the save fails and the server shuts down before the next autosave, the player has paid but loses the reward. Recommendation: return Granted only after a confirmed save.
- ⚠️ DataService saves with `SetAsync` and has no session lock (DS:538). Joining a second server before the first one saves can overwrite or duplicate data, purchase IDs included. Consider `UpdateAsync` with a session lock, or ProfileStore.
- ⚠️ `d.Purchases` grows forever. It's minor, but consider pruning entries older than about 60 days.

### 5.4 Server-side purchase validation of in-game spends
| Handler | Check | Result |
|---|---|---|
| Hatch | Count limited to 1 or 3; `SpendCoins` checks the balance first; 0.2 s rate limit | ✅ |
| Sawmill sell | `0 < frac ≤ 1`, daily cap 200, server-side hourly rate | ✅ |
| Soul Shop | 0.3 s rate limit, ownership check, `SpendSouls` | ✅ |
| Trait crate | Free / Souls / Logs paths each check their balance | ✅ |
| Combat | Blade hits are computed on the server each Heartbeat (`GetBlades`, cooldown, radius), not reported by the client | ✅ No log-farming exploit through hit spoofing |
| Codes | Saved `d.Codes[code]`, one per account | ✅ |
| Playtime gifts | `giftsClaimed` is kept in memory, per session | ⚠️ Resets on rejoin, so gifts can be re-earned every session. Probably intended, but it makes them repeatable sources of luck potions and crates |

---

## 6. Multiplier stacking [VERIFIED formula, DERIVED values]

`RecalcMultipliers` multiplies everything together; nothing is added:

```
Luck = LuckUpgrade(≤6) × Π active boosts (Luck 3, Mega 10, StarterLuck 2) × 2xLuck(2)
       × (1 + 0.1·rebirths) × Group 1.1 × (1 + Σ pet luck, ≤ +1.5) × (1 + 0.1·areas indexed)
Roll luck = Luck × EventLuck (Golden Hour 2 / Blood Moon 5) × 2 on every 10th roll
Logs = Π boosts (LogBoost 2) × 2xLogs 2 × VIP 1.1 × Trait (≤3) × (1+0.25·rebirths) × PvP 1.5
       × (1 + Σ pet logs, ≤ +6) × index (≤1.4) × tree index (≤1.2) × EventLogs (≤2)
```

| Stack | Free maximum | With every paid source | Paid share |
|---|---|---|---|
| Roll luck (0 rebirths) | ≈6,930× | **≈27,720×** | ×4 (×40 counting Mega Luck as paid-only) |
| Log multiplier (0 rebirths) | ≈106× | **≈466×** | ×4.4 |

Consequences of free, unlimited rolls with this much luck [DERIVED]:
- Effective "1 in X" has a floor of 1. At 27,720× luck, everything up to Bloodthorn (1/25,000) becomes guaranteed.
- Frostbound Reaper (1 in 100 M) drops to about 1 in 3,600 rolls, roughly **1 hour** of Fast-Roll auto-rolling.
- Rebirths raise luck without limit (×2 at 10 rebirths), so late game every chase item becomes a certainty. The rarity ladder collapses.

---

## 7. Random-reward odds [VERIFIED]

### 7.1 Weapon roll (free; changed by paid luck)
`RollWeapon` checks the pool from rarest to most common and takes the first hit, with probability 1/eff, where eff = max(OneIn / luck, 1). Weapons with OneIn ≤ 10 ignore luck. Because rarer weapons are checked first, the **actual** odds are lower than displayed. The gap is negligible for rare weapons and large for common ones:

| Weapon | Displayed | Actual (luck 1) |
|---|---|---|
| Iron | 1 in 25 | 1 in 27.3 |
| Woodsman Axe | 1 in 9 | 1 in 10.2 |
| Lumber Hatchet | 1 in 6 | 1 in 7.7 |
| Farmhand Scythe | 1 in 4 | 1 in 6.1 |
| Rusty Sickle | 1 in 3 | 1 in 6.1 |
| Wooden (fallback) | 1 in 2 | 1 in 3.1 |

From Engraved Axe (1/100) upward, the displayed and actual odds agree to within 1.5%. The Index shows "(you: 1 in X)" with luck applied, which helps, but it uses the same simplified formula. The every-10th-roll ×2 and event luck are not shown as the player's true current odds.

### 7.2 Trait crates (paid with Robux, Logs, Souls or free crates)
| Trait | Mult | Logs crate | Logs + Lucky Crates | Soul crate | Soul + Lucky |
|---|---|---|---|---|---|
| Sapling | 1.25 | 50.00% | 40.98% | 0% | 0% |
| Woodcutter | 1.5 | 28.00% | 22.95% | 45.00% | 29.03% |
| Lumberjack | 1.75 | 14.00% | 22.95% | 32.00% | 41.29% |
| Timber Titan | 2 | 6.00% | 9.84% | 15.00% | 19.35% |
| Forest Warden | 2.5 | 1.80% | 2.95% | 7.00% | 9.03% |
| Ancient Root | 3 | 0.20% | 0.33% | 1.00% | 1.29% |

✅ The TRAITS panel shows these percentages (TraitsController:156) and refreshes them when Lucky Crates is owned (line 182). The weights sum to 100.

### 7.3 Pet eggs (Logs; cost = crate cost × 1.5; ×3 hatch available)
Bunny 45% · Cat 30% · Bear 14% · Fox 7% · Penguin 3% · Snow Owl 0.9% · Baby Dragon 0.1%. They sum to 100%. ✅ Shown on each pet card (ExtrasController:142).

### 7.4 Other random rewards
These aren't paid, so no disclosure is required:
- Mutation spawns.
- Events: Golden Hour / Log Rush / Blood Moon, weights 45 / 40 / 15, every 18–30 min.
- Sawmill rate: 0.6–1.6, seeded per hour.

---

## 8. Bugs and inconsistencies (no fixes made)

1. **Dead config [VERIFIED]:**
   - `Config.Pity` (Epic 100, Legendary 1000) is only referenced by a Studio dev hook. **No pity exists in the live roll.** Never advertise one.
   - `Areas[].RollCost` is unused, because rolls are free.
   - `Rarities[].Chance` and `GetRollOdds` aren't called by any client or server code. If anyone ever displays them, the shown odds would be false.
2. **FastRoll auto-roll [VERIFIED values, behavior inferred]:** `FastAutoRollInterval = 0.4` but the server rejects calls closer than 0.6 × 0.85 = 0.51 s. Every other call fails, giving about 0.8 s per roll, so the pass delivers about 1.4× speed instead of the implied 2.75×.
3. **Starter-area Secret [VERIFIED]:** Starbreaker is a Starter Grove weapon but has power 3,008, enough for the Frost gate. Area labels on weapons are cosmetic, since rolls aren't area-limited.
4. **[UNVERIFIED]** Logs rewards defined as `Mult` (daily, quests, codes such as `TIMBER = 10`) probably scale with area crate cost, like log packs do. Progress.Grant was not read line by line.

---

## 9. Progression simulation [ESTIMATE]

**Model:** `docs/economy_sim.py`, median of 25 seeds.

**Assumptions:**
- 1.6 s walk between trees; 1.3 trees in reach.
- Auto-roll the whole time.
- Upgrades and eggs/crates bought greedily.
- Group joined; daily luck potion from free sources.
- No rebirths and no events (both would raise every archetype).

**Sessions:**
- Free: 45 min on D1, then 40 min a day.
- Casual payer (Starter Pack + 2× Logs + Fast Roll, 547 R$): 45 min, then 60 min a day.
- Heavy payer (all 7 passes, 1,693 R$, **plus Mega Luck chained every session**, which assumes products go live): 45 min, then 120 min a day.

| | Free D1 | Free D7 | Casual D1 | Casual D7 | Heavy D1 | Heavy D7 |
|---|---|---|---|---|---|---|
| Area | Crystal | Crystal (72%) | Crystal | Frost (68%) | Frost (100%) | Frost |
| Best weapon (power) | Glacier Fang 315 | Magma Hook 1,562 | Inferno 554 | Starfall Reaper 3,785 | Glacial Edge 8,476 (Divine) | Glacial Edge 8,476 |
| Logs per minute | ≈26 k | ≈93 k | ≈92 k | ≈1.1 M | ≈1.6 M | ≈6.0 M |
| Time to Crystal | ~4 min | — | ~1 min | — | <1 min | — |
| Time to Frost | most not by D7 | — | — | ~2 h of play | ~5 min | — |

### Findings
- **D1:** Starter Grove and Pine Forest are passed in minutes. Their trees, NPCs and Blade King are skipped content, so the first session has no "next goal" ladder after about 5 minutes.
- **D7:** The free player's Logs no longer move them forward, because Power comes only from rolls. Income rises about 3.5× over the week, but the Frost gate depends on luck alone. With about 4.3× luck, about 140,000 rolls are expected (about 43 h of auto-rolling).
- **Pay-to-win:** a heavy payer reaches the end of the content in 5–15 minutes. The gap comes from multiplicative luck, not from the Logs passes. Once Frost is reached nothing is left, so the heavy payer's retention is also at risk.
- **Inflation:** casual D7 income (1.1 M/min) can buy the Huge Log Pack's 480 M in about 7 hours. Once Frost players have maxed upgrades (about 3 B total), Logs have no use except exponential rebirths.

---

## 10. Retention risks

| Risk | Window | Evidence | Severity |
|---|---|---|---|
| Early areas consumed in minutes | D1 | Gates at 40 and 250 reached by free rolls in about 4 min [ESTIMATE] | High |
| Hard wall at Frost gate (luck only) | D3–D7 | About 70% of free players still in Crystal at D7 [ESTIMATE] | High |
| Nothing after Frost Peaks | Payers, D1–D3 | No 5th area; sinks are one-off or exponential [VERIFIED] | High |
| Logs lose meaning late | D7+ | Logs never raise Power; upgrades max out [VERIFIED] | Medium |
| Repeatable session gifts | — | Gifts reset each session [VERIFIED] | Low (could be a feature) |
| Daily streak / quests / Treant / events | — | Present and working [VERIFIED code] | Positive |

---

## 11. Roblox policy compliance (paid random items)

Per Roblox's paid random items guidelines:
- All outcomes and their numerical odds must be shown before purchase.
- The rule also applies to currency bought with Robux.
- Paid odds boosters must explain their effect numerically and show the player's true odds while active.
- Players with `ArePaidRandomItemsRestricted` must not be able to use paid random generators, whether paid with Robux or with Robux-bought currency.

| Item | Paid random today? | Status |
|---|---|---|
| Trait Crate products (29 / 249) | Yes, when live | ✅ Odds shown; ✅ hidden for restricted players (client only) |
| Lucky Crates pass | Odds modifier | ✅ Odds update; ✅ hidden for restricted players |
| Logs-paid Trait Crate | **Becomes one once log packs are live** | ⚠️ Not gated for restricted players |
| Pet eggs (Logs) | **Same** | ✅ Odds shown; ⚠️ not gated |
| Free crates granted by VIP / Starter Pack | Paid indirectly | ⚠️ Not gated for restricted players |
| Weapon rolls (free) + Luck Potion / Mega / 2× Luck | Free roll; paid modifier | ⚠️ Effect stated as "3× Luck", but true odds are shown only per weapon in the Index, use the simplified formula, and are wrong for commons (§7.1) |
| Trading | Not implemented | If added: gate with `IsPaidItemTradingAllowed` |

Recommendations (not applied):
- Check `ArePaidRandomItemsRestricted` on the **server**: in TraitService (Logs path), Hatch, and when spending free crates obtained through purchases.
- Show the true, luck-adjusted weapon odds, computed with the rarest-first cascade, in the altar panel.
- Fill in the Maturity & Compliance questionnaire to match.

---

## 12. Recommendations for ChatGPT to prioritise

Proposals only; none are implemented.

1. Create the 9 developer products and fill in the `ProductId`s. Before that, fix the receipt save confirmation and session locking.
2. **Cap paid luck's effect on gates.** Options:
   - Make luck add up within groups instead of multiplying everything.
   - Cap total roll luck (for example 25–50×).
   - Give Divine/Secret weapons their own lower luck exponent.
   - Add a per-area roll pool.
3. **Rework the gates:** add a Logs or progress requirement alongside Power, such as area unlock costs or tree-index milestones. That makes Logs matter and slows D1 burn-through, and a rising Frost requirement softens the D7 wall.
4. **Add a 5th area** and recurring, scaling Logs sinks (for example star/shiny costs in Logs, pet upgrades) before running ads.
5. Fix the odds display (§7.1). Remove or implement Pity. Fix the FastRoll auto interval.
6. Gate Logs-paid random items for restricted players once log packs go live.

---

_Re-run `python3 docs/economy_sim.py` after config changes. Inputs at the top of the file mirror BladeConfig and must be updated with it._
