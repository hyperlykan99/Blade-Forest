# Blade Forest — Game Design

## Pitch

Players spin a ring of orbiting blades around their character and walk through a forest that shatters into logs. Logs buy upgrades. Rolls give better weapons. Better weapons unlock harder areas, rarer trees and bosses. It is a "number goes up" simulator with collection layers (weapon index, tree index, pets, achievements) to keep players coming back.

## Core loop

1. **Chop.** Blades orbit the player and damage trees on contact. Felled trees drop logs.
2. **Upgrade.** Spend logs on blade count, spin speed, damage and range.
3. **Roll.** Spend logs to roll for weapons (rarity tiers up to Secret). Duplicates fuse into stars, and 5 copies craft a **Shiny** (×1.5 power).
4. **Progress.** Weapon power unlocks new areas with tougher, more valuable trees.
5. **Collect.** Fill the weapon index and tree index for claimable rewards and permanent bonuses.

## Systems

| System | Summary | Where it lives |
|---|---|---|
| Blades | Orbit count (max level 5), spin speed capped at 5.5 (extra speed is turned into damage), a stop/start toggle | `BladeConfig`, `CombatServer`, `BladeEffects`, `HudExtras` |
| Trees | 7 rarity tiers, including 8 Mythic/Secret types. Respawning, area-gated | `WorldServer`, `TreeKit`, `ReplicatedStorage.TreeModels` |
| Mutations | Golden 1/40 (×3 logs), Frozen 1/70 (×4), Shadow 1/200 (×8), Rainbow 1/800 (×25) | `BladeConfig.Mutations`, `CombatServer` |
| Weapon rolls | Weighted rarity rolls; Fast Roll and Lucky passes | `RollService`, `RollController` |
| Fusing / Shiny | Stars from duplicates; 5 copies make a Shiny | `DataService` (Fuse) |
| Index | Weapon index and tree index, per-entry rewards, Claim All, completion bonus | `MetaService`, `IndexController` |
| Pets | 7 pets, eggs (cost ×1.5 per hatch), up to 3 equipped, follow the player, stat multipliers | `ExtrasService`, `ExtrasController`, `ReplicatedStorage.PetModels` |
| Sawmill / Log Market | Sell logs for Souls at a rate between 0.6 and 1.6, daily cap of 200 | `ExtrasService` |
| Souls | Prestige-style currency for the Soul shop | `SoulService`, `PvPSoulController` |
| Traits | Rollable passive traits | `TraitService`, `TraitsController` |
| Area bosses | Arena bosses; the HP bar shows only inside the arena | `AreaService`, `CombatServer` |
| Ancient Treant (world boss) | Spawns every 20 min and lasts 7 min. HP scales with server power. Rewards are shared by damage dealt | `ExtrasService`, `CombatServer` |
| NPC camps | 4 Rogue Lumberjack camps around the map, plus the Blade King | `WorldServer` |
| PvP | Opt-in toggle | `PvPService` |
| AFK | AFK rewards screen and rejoin | `AFKService`, `AFKController` |
| Achievements | 18 achievements, claimable | `ExtrasService`, `BladeConfig.Achievements` |
| Leaderboards | Global ordered DataStores | `LeaderboardService` |
| Events / potions | Timed boosts shown in the HUD StatusRail | `MetaService`, `HudExtras` |
| Tutorial | First-session guided steps | `TutorialController` |

## Monetisation

- **Game passes:** 2× Luck `2093457053`, 2× Logs `2092761109`, Fast Roll `2094279037`, Lucky Crates `2093577035`, Starter Pack `2094327011`.
- **Developer products:** planned (potions, log packs, rolls). They are not created yet; see `TASKS.md`.
- **Group bonus:** joining group `76836496` gives a bonus.

## Comfort and accessibility

- Screen shake is reduced and has an off switch in Settings.
- A Reduced Motion setting turns off camera effects and roll animations.
- The spin speed cap prevents nausea.
- Mobile uses a compact layout: docks move to the top corners at 0.6 scale, each side can be hidden, and buttons are small but tappable.

## World

- Central hub with the Log Market and Pet Egg stations.
- Areas radiate outward and are gated by power.
- Mountains and barricades can't be climbed: `CharacterMaxSlopeAngle = 32`, plus the `ClimbBlockers` parts.
- Assets come from the Creator Store; we don't make custom models.
