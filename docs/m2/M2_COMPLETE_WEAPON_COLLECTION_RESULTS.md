# M2 — Complete Weapon Collection: Results

**Status: M2 feature-complete on the DEV place only.** Not published, not merged, monetization untouched. Production place 73142469975141 was not opened, read or written.

| Item | Value |
| --- | --- |
| Dev place | 103379930563763 / Universe 10777797608 |
| Rollback checkpoint | **v35**, relabelled "M2 PRE-WEAPONS checkpoint (= M1 v35 state)" |
| Final dev version | **v45** "M2 COMPLETE WEAPON COLLECTION (dev only, not published)", Open Cloud updateTime 2026-11-21T01:15:19.309Z |
| Branch | `m2/complete-weapon-collection` (cut from `m1/unified-economy-progression` @ 0ac6802), pushed, not merged |
| Commit | see §12 |
| In-Studio backups | `ServerStorage.M2Backups`: 47 `<Script>_PreM2` copies, `BladeModels_PreM2` (all 43 original models), `DevProfileSnapshot_p_394034825` |

## 1. What was delivered

- **120 distinct weapons**: the 43 originals with IDs, ownership, stars, copies, Shiny and Power untouched, plus **77 new** weapons, all `Edition = 2`.
- Every weapon has an ID, name, type, island/altar, rarity, Power, odds (`OneIn`), 3D model template, VFX tier, gallery entry, acquisition text and future-system flags. Equip, fusion, stars and Shiny reuse the existing code paths with no special cases.
- Machine-readable manifest: `docs/weapon_manifest.json` (120 entries, including model source, creator, license, part count and status). Roster source: `tools/m2/roster.py`; generator: `tools/m2/gen_m2.py`, which writes marked `-- M2:BEGIN` blocks into `BladeConfig.luau`.
- **Source of truth stays M1**: altar pools and odds come from `BladeConfig` and `EconomyConfig` (generated from `tools/econsim/economy_params.json`). No IDs were renumbered.

## 2. Roster, rarity distribution and Power

Power for new weapons uses the legacy formula `Power = 5 · OneIn^0.45`, so new weapons slot between the existing ones without inflating the top end. No original weapon's Power changed. Altar pools are cumulative: Timber Haven 39 rollable, Crystal Wilds 77, Frostbound Reach 115. The other 5 are non-altar weapons (starter, crate and event).

### Rarity distribution (all 120 / new 77)

| Rarity | TimberHaven | CrystalWilds | FrostboundReach | Total (new) |
|---|---|---|---|---|
| Common | 7 (2) | 5 (5) | 5 (5) | 17 (12) |
| Uncommon | 7 (2) | 5 (5) | 5 (5) | 17 (12) |
| Rare | 7 (2) | 5 (5) | 5 (5) | 17 (12) |
| Epic | 9 (3) | 6 (5) | 5 (5) | 20 (13) |
| Legendary | 6 (2) | 6 (4) | 5 (5) | 17 (11) |
| Mythic | 3 (2) | 7 (2) | 5 (5) | 15 (9) |
| Secret | 3 (1) | 4 (1) | 3 (3) | 10 (5) |
| Divine | 1 (1) | 1 (1) | 5 (1) | 7 (3) |
| **Total** | 43 (15) | 39 (28) | 38 (34) | 120 (77) |

### The 77 new weapons

| # | Id | Name | Type | Rarity | Island / area | 1 in | Power | VFX | Source asset (creator) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | WoodcuttersHatchet | Woodcutter's Hatchet | Axe | Common | TimberHaven / StarterGrove | 5 | 10 | 0 | 115423796241260 (Al3x_Coo1) |
| 2 | RiverRaiderBlade | River Raider Blade | Sword | Common | TimberHaven / StarterGrove | 8 | 13 | 0 | 109984325205666 / 03_Rusty_Plunger_Sword (RabiMaster9) |
| 3 | RiverlordSaber | Riverlord's Saber | Sword | Uncommon | TimberHaven / StarterGrove | 60 | 32 | 1 | 109984325205666 / 14_Treasure_Island_Ceremonial_Sword (RabiMaster9) |
| 4 | CaptainsGoldguard | Captain's Goldguard | Sword | Uncommon | TimberHaven / StarterGrove | 80 | 36 | 1 | 109984325205666 / 02_Captain_Gold_Guard_Sword (RabiMaster9) |
| 5 | AshbarkKnightblade | Ashbark Knightblade | Sword | Rare | TimberHaven / PineForest | 400 | 74 | 2 | 109984325205666 / Ash_Knight_Sword (RabiMaster9) |
| 6 | GroundskeeperScythe | Groundskeeper's Scythe | Scythe | Rare | TimberHaven / PineForest | 600 | 89 | 2 | 102732830077707 (GreenLightningRBLX) |
| 7 | FurnacecoreLongsword | Furnacecore Longsword | Sword | Epic | TimberHaven / PineForest | 3,000 | 184 | 3 | 109984325205666 / Furnace_Core_Longsword (RabiMaster9) |
| 8 | FlametongueSaber | Flametongue Saber | Sword | Epic | TimberHaven / PineForest | 4,000 | 209 | 3 | 109984325205666 / Flame_Tongue_Curved_Sword (RabiMaster9) |
| 9 | GildedWarden | Gilded Warden | Sword | Epic | TimberHaven / PineForest | 6,000 | 251 | 3 | 85544016354562 / epee_large (coyote_hybridd) |
| 10 | WildfireGreatsword | Wildfire Greatsword | Sword | Legendary | TimberHaven / PineForest | 30,000 | 517 | 4 | 109984325205666 / Flame_Wave_Greatsword (RabiMaster9) |
| 11 | KindledRingblade | Kindled Ringblade | Sword | Legendary | TimberHaven / PineForest | 45,000 | 621 | 4 | 109984325205666 / Fire_Ring_Guard_Sword (RabiMaster9) |
| 12 | TridentBlaze | Trident Blaze | Sword | Mythic | TimberHaven / PineForest | 300,000 | 1,458 | 5 | 109984325205666 / Triple_Flame_Sword (RabiMaster9) |
| 13 | Wyrmfang | Wyrmfang | Sword | Mythic | TimberHaven / PineForest | 450,000 | 1,750 | 5 | 109984325205666 / Fire_Dragon_Fang_Sword (RabiMaster9) |
| 14 | EmberkingsCrown | Emberking's Crown | Sword | Secret | TimberHaven / PineForest | 2,000,000 | 3,423 | 6 | 109984325205666 / Flame_King_Crown_Sword (RabiMaster9) |
| 15 | HearthforgeSovereign | Hearthforge Sovereign | Sword | Divine | TimberHaven / PineForest | 12,000,000 | 7,667 | 7 | 109984325205666 / Forge_God_Hammer_Sword (RabiMaster9) |
| 16 | ButchersCleaver | Prospector's Cleaver | Sword | Common | CrystalWilds / CrystalCanyon | 4 | 9 | 0 | 109984325205666 / 05_Meat_Cleaver_Curved_Sword (RabiMaster9) |
| 17 | RopegripCutlass | Ropegrip Cutlass | Sword | Common | CrystalWilds / CrystalCanyon | 5 | 10 | 0 | 109984325205666 / 09_Rope_Wrapped_Raider_Sword (RabiMaster9) |
| 18 | DeckhandCutlass | Canyon Deckhand | Sword | Common | CrystalWilds / CrystalCanyon | 7 | 12 | 0 | 109984325205666 / 01_Deckhand_Cutlass (RabiMaster9) |
| 19 | HooktipCutlass | Hooktip Cutlass | Sword | Common | CrystalWilds / CrystalCanyon | 8 | 13 | 0 | 109984325205666 / 06_Hooktip_Cutlass (RabiMaster9) |
| 20 | ProspectorsBlade | Quarry Iron Blade | Sword | Common | CrystalWilds / CrystalCanyon | 9 | 13 | 0 | 84725261554298 (KL_JOKER46) |
| 21 | SilvershoreSaber | Silvershore Saber | Sword | Uncommon | CrystalWilds / CrystalCanyon | 45 | 28 | 1 | 109984325205666 / 16_Admiral_Silver_Sword (RabiMaster9) |
| 22 | ShellguardCutlass | Shellguard Cutlass | Sword | Uncommon | CrystalWilds / CrystalCanyon | 55 | 30 | 1 | 109984325205666 / 08_Shell_Guard_Cutlass (RabiMaster9) |
| 23 | ForkguardCutlass | Forkguard Cutlass | Sword | Uncommon | CrystalWilds / CrystalCanyon | 65 | 33 | 1 | 109984325205666 / 10_Forked_Knuckleguard_Sword (RabiMaster9) |
| 24 | CanyonSickle | Canyon Sickle | Scythe | Uncommon | CrystalWilds / CrystalCanyon | 75 | 35 | 1 | 83223944436703 (seG1as) |
| 25 | SappersAxe | Sapper's Axe | Axe | Uncommon | CrystalWilds / CrystalCanyon | 90 | 38 | 1 | 132212403247918 (dreznik14) |
| 26 | Flintedge | Flintedge | Sword | Rare | CrystalWilds / CrystalCanyon | 300 | 65 | 2 | 109984325205666 / Flint_Sword (RabiMaster9) |
| 27 | MagmaveinBlade | Magmavein Blade | Sword | Rare | CrystalWilds / CrystalCanyon | 450 | 78 | 2 | 109984325205666 / Lava_Straight_Sword (RabiMaster9) |
| 28 | CharcoalBrand | Charcoal Brand | Sword | Rare | CrystalWilds / CrystalCanyon | 550 | 86 | 2 | 109984325205666 / Charcoal_Burner_Sword (RabiMaster9) |
| 29 | JadeleafEdge | Jadeleaf Edge | Sword | Rare | CrystalWilds / CrystalCanyon | 800 | 101 | 2 | 103249999198428 (febrydwip) |
| 30 | AmethystSickle | Amethyst Sickle | Scythe | Rare | CrystalWilds / CrystalCanyon | 900 | 107 | 2 | 9309773165 (kbx_rblx) |
| 31 | CraterGreatsword | Crater Greatsword | Sword | Epic | CrystalWilds / CrystalCanyon | 2,800 | 178 | 3 | 109984325205666 / Crater_Greatsword (RabiMaster9) |
| 32 | Geyserfang | Geyserfang | Sword | Epic | CrystalWilds / CrystalCanyon | 4,500 | 220 | 3 | 109984325205666 / Erupting_Vent_Sword (RabiMaster9) |
| 33 | MeteorShard | Meteor Shard | Sword | Epic | CrystalWilds / CrystalCanyon | 5,500 | 241 | 3 | 109984325205666 / Meteoric_Scorching_Sword (RabiMaster9) |
| 34 | AzureTidecurve | Azure Tidecurve | Sword | Epic | CrystalWilds / CrystalCanyon | 8,000 | 285 | 3 | 79233567090868 (K3LLo29) |
| 35 | GeodeCleaveaxe | Fuchsia Geode Cleaveaxe | Axe | Epic | CrystalWilds / CrystalCanyon | 9,000 | 301 | 3 | 10248346084 (RealAndraYas110) |
| 36 | ObsidianGlassblade | Obsidian Glassblade | Sword | Legendary | CrystalWilds / CrystalCanyon | 28,000 | 501 | 4 | 109984325205666 / Volcanic_Glass_Sword (RabiMaster9) |
| 37 | RosequartzFang | Rosequartz Fang | Sword | Legendary | CrystalWilds / CrystalCanyon | 40,000 | 589 | 4 | 11300742737 (seG1as) |
| 38 | OpalineEdge | Opaline Edge | Sword | Legendary | CrystalWilds / CrystalCanyon | 60,000 | 707 | 4 | 11857430591 (ImJustCritz) |
| 39 | GarnetCrystalAxe | Garnet Crystal Axe | Axe | Legendary | CrystalWilds / CrystalCanyon | 80,000 | 804 | 4 | 9095853669 (IceLord6421) |
| 40 | ObsidianEclipse | Obsidian Eclipse | Sword | Mythic | CrystalWilds / CrystalCanyon | 400,000 | 1,659 | 5 | 16070621258 (firegames233 (modeled by Seasly)) |
| 41 | GeodeHarvester | Geode Harvester | Scythe | Mythic | CrystalWilds / CrystalCanyon | 600,000 | 1,991 | 5 | 112775014098679 (kris131441) |
| 42 | SkyshardAegisblade | Skyshard Aegisblade | Sword | Secret | CrystalWilds / CrystalCanyon | 3,000,000 | 4,108 | 6 | 99319419231103 (Aktul_X) |
| 43 | PrismheartRadiance | Prismheart Radiance | Sword | Divine | CrystalWilds / CrystalCanyon | 20,000,000 | 9,648 | 7 | 117948646998971 (explosibo55) |
| 44 | IcesawBoarder | Icesaw Boarder | Sword | Common | FrostboundReach / FrostPeaks | 5 | 10 | 0 | 109984325205666 / 07_Sawback_Boarding_Sword (RabiMaster9) |
| 45 | ShorthiltSaber | Shorthilt Saber | Sword | Common | FrostboundReach / FrostPeaks | 6 | 11 | 0 | 109984325205666 / 11_Short_Hilt_Pirate_Sword (RabiMaster9) |
| 46 | GhostshipCutlass | Ghostship Cutlass | Sword | Common | FrostboundReach / FrostPeaks | 7 | 12 | 0 | 109984325205666 / 15_Ghost_Ship_Perforated_Sword (RabiMaster9) |
| 47 | GlacierWoodsplitter | Glacier Woodsplitter | Axe | Common | FrostboundReach / FrostPeaks | 8 | 13 | 0 | 85544016354562 / hache_bataille (coyote_hybridd) |
| 48 | FrostwindKatana | Frostwind Katana | Sword | Common | FrostboundReach / FrostPeaks | 9 | 13 | 0 | 8535931563 (Dev_Simphony) |
| 49 | HarpoonCutlass | Harpoon Cutlass | Sword | Uncommon | FrostboundReach / FrostPeaks | 40 | 26 | 1 | 109984325205666 / 13_Harpoon_Tip_Curved_Sword (RabiMaster9) |
| 50 | FrostportOfficer | Frostport Officer's Sword | Sword | Uncommon | FrostboundReach / FrostPeaks | 85 | 37 | 1 | 109984325205666 / 04_Naval_Officer_Sword (RabiMaster9) |
| 51 | LonghiltBoarder | Longhilt Boarder | Sword | Uncommon | FrostboundReach / FrostPeaks | 95 | 39 | 1 | 109984325205666 / 12_Long_Hilt_Boarding_Sword (RabiMaster9) |
| 52 | TundraStoneAxe | Tundra Stone Axe | Axe | Uncommon | FrostboundReach / FrostPeaks | 110 | 41 | 1 | 88566817567680 (WabbitSlayer78) |
| 53 | BlackiceKatana | Blackice Katana | Sword | Uncommon | FrostboundReach / FrostPeaks | 120 | 43 | 1 | 140237683099823 (Amongfse) |
| 54 | NorthmanBeardaxe | Northman Beardaxe | Axe | Rare | FrostboundReach / FrostPeaks | 350 | 70 | 2 | 4596657731 / Battle-Axe (Heahmund) |
| 55 | FjordSword | Fjord Sword | Sword | Rare | FrostboundReach / FrostPeaks | 650 | 92 | 2 | 4596657731 / Sword (Heahmund) |
| 56 | JaggedFloe | Jagged Floe | Sword | Rare | FrostboundReach / FrostPeaks | 750 | 98 | 2 | 5193470810 (Airzly) |
| 57 | FrostwardenBattleaxe | Frostwarden Battleaxe | Axe | Rare | FrostboundReach / FrostPeaks | 1,100 | 117 | 2 | 17346131691 (Troyonik) |
| 58 | SnowcapLabrys | Snowcap Labrys | Axe | Rare | FrostboundReach / FrostPeaks | 1,200 | 122 | 2 | 5088853924 (noru_xii) |
| 59 | NorthmanGreatsword | Northman Greatsword | Sword | Epic | FrostboundReach / FrostPeaks | 3,200 | 189 | 3 | 4596657731 / Greatsword (Heahmund) |
| 60 | RunedFrostaxe | Runed Frostaxe | Axe | Epic | FrostboundReach / FrostPeaks | 6,500 | 260 | 3 | 114164136130143 (jesperx) |
| 61 | SnowlightBlade | Snowlight Blade | Sword | Epic | FrostboundReach / FrostPeaks | 7,500 | 277 | 3 | 104922735601845 (Udiean27) |
| 62 | IcicleSpire | Icicle Spire | Sword | Epic | FrostboundReach / FrostPeaks | 12,000 | 342 | 3 | 5193504025 (Airzly) |
| 63 | RimewireScythe | Rimewire Scythe | Scythe | Epic | FrostboundReach / FrostPeaks | 15,000 | 379 | 3 | 107204789910711 (Wirly_world) |
| 64 | GlacialSplitter | Glacial Splitter | Axe | Legendary | FrostboundReach / FrostPeaks | 55,000 | 679 | 4 | 2749777054 (Pseudosuper) |
| 65 | CryoMechblade | Cryo Mechblade | Sword | Legendary | FrostboundReach / FrostPeaks | 90,000 | 848 | 4 | 97407267401652 (febrydwip) |
| 66 | FrostspireGreatsword | Frostspire Greatsword | Sword | Legendary | FrostboundReach / FrostPeaks | 120,000 | 965 | 4 | 79913196266344 (Wirly_world) |
| 67 | IceshardCleaver | Iceshard Cleaver | Sword | Legendary | FrostboundReach / FrostPeaks | 150,000 | 1,067 | 4 | 12724420744 (OrbiPlay) |
| 68 | HoarfrostAxe | Hoarfrost Axe | Axe | Legendary | FrostboundReach / FrostPeaks | 180,000 | 1,158 | 4 | 2166057719 (XxMlgX15XxX) |
| 69 | FrostskullRavager | Frostskull Ravager | Axe | Mythic | FrostboundReach / FrostPeaks | 650,000 | 2,064 | 5 | 27782369 (Yourius) |
| 70 | GlacierBoneReaper | Glacier Bone Reaper | Scythe | Mythic | FrostboundReach / FrostPeaks | 750,000 | 2,202 | 5 | 2506494882 (GreenDieno) |
| 71 | FrostguardDefender | Frostguard Defender | Sword | Mythic | FrostboundReach / FrostPeaks | 850,000 | 2,329 | 5 | 76363890187461 (Skywhi7162) |
| 72 | Iceveil | Iceveil | Sword | Mythic | FrostboundReach / FrostPeaks | 900,000 | 2,390 | 5 | 111938391354722 (febrydwip) |
| 73 | Shiverfang | Shiverfang | Sword | Mythic | FrostboundReach / FrostPeaks | 950,000 | 2,449 | 5 | 91274376729622 (clansp4 hub) |
| 74 | AuroraCleaver | Aurora Cleaver | Axe | Secret | FrostboundReach / FrostPeaks | 5,000,000 | 5,170 | 6 | 2019918699 (MikuHazard) |
| 75 | RimefrostRequiem | Rimefrost Requiem | Sword | Secret | FrostboundReach / FrostPeaks | 8,000,000 | 6,388 | 6 | 16905154362 (Pandebchik Studio) |
| 76 | PolarNightReaper | Polar Night Reaper | Scythe | Secret | FrostboundReach / FrostPeaks | 9,000,000 | 6,736 | 6 | 14983425633 (Ziresei) |
| 77 | EternalWinter | Eternal Winter | Sword | Divine | FrostboundReach / FrostPeaks | 40,000,000 | 13,179 | 7 | 13168667185 (TealixSwirl) |



## 3. Odds before and after (per roll, luck ×1; full tables at luck ×1 and ×10 were checked in testing)

| Altar | Rarity | M1 | M2 |
| --- | --- | --- | --- |
| Timber Haven | Legendary | 8.86e-5 | 1.44e-4 |
| Timber Haven | Mythic | 4.0e-6 | 9.56e-6 |
| Timber Haven | Secret | 1.07e-6 | 1.57e-6 |
| Timber Haven | Divine | 0 | 8.33e-8 |
| Crystal Wilds | Legendary | 1.13e-4 | 2.58e-4 |
| Crystal Wilds | Mythic | 1.13e-5 | 2.10e-5 |
| Crystal Wilds | Divine | 0 | 1.33e-7 |
| Frostbound Reach | Legendary | 1.13e-4 | 3.08e-4 |
| Frostbound Reach | Mythic | 1.13e-5 | 2.72e-5 |
| Frostbound Reach | Divine | 1.37e-7 | 2.95e-7 |

- The UI (Index, Gallery detail) and the server both call `Economy.WeaponOdds(weaponId, luck)`, so they show identical odds. Test W3 checks that each pool sums to 1 and matches across sides.
- M1 guarantees (progression weapons) still fire; every original weapon is still obtainable from its altar.
- **Owner decision:** adding more weapons per rarity raises the chance of hitting *some* Legendary/Mythic (each one keeps its own 1-in-X). If you want rare rarities to stay as rare as in M1, raise the new weapons' `OneIn` in `tools/m2/roster.py` and regenerate.

## 4. Deterministic Divine path (Divine Attunement)

- Every altar roll gives **1 Altar Essence**, capped at **25,000 per UTC day** (no limitless AFK).
- **100,000 Essence** attunes one island and grants its Divine once: Timber Haven → Hearthforge Sovereign, Crystal Wilds → Prismheart Radiance, Frostbound Reach → Eternal Winter. At the cap this takes at least 4 days, about 31 h of rolling.
- The server is authoritative: `DataService.AddEssence` / `DataService.Attune`, using `Roll("Attune", island)`. Bogus islands, insufficient essence and repeat claims are rejected.
- Forge recipes and crafting are deferred to M6. Only the interfaces exist (see §8).

## 5. 3D models and asset/license manifest

**All 77 new models are imported Creator Store free models.** Per standing owner direction, no custom models were made. Each template stores `SourceAssetId`, `SourceChild`, `SourceCreator` and `SourceTitle` as attributes, and the same data is in `weapon_manifest.json`.

- **Licenses:** Roblox Creator Store free models, used under the Roblox Terms of Use.
- **Import safety:** imported into a ServerStorage quarantine, and **all scripts and non-visual objects were stripped** before use. An allow-list strip was later run across every BladeModel. No packages or require-by-ID were imported.
- **Normalization:** SpecialMeshes were converted to MeshParts. Each template was fitted to length 4, with the tip along −Z and the pivot at the origin.
- **Creators:** 32 models come from RabiMaster9's sword pack (109984325205666). The remainder come from about 40 other creators, including coyote_hybridd, Heahmund, febrydwip, seG1as, Airzly, TealixSwirl and IceLord6421 (full list per weapon in the table above and the manifest).
- **Excluded on purpose:** a "Fantasy Swords Pack" that re-uploads other creators' work, a Unity/Synty conversion pack, IP clones (licensed game and anime weapons) and a scythe resembling a RWBY weapon.
- **LihFolk vault:** **not accessed.** No vault assets were inspected or used.
- **Status:** every new model is a *production candidate*. Each was visually inspected in Studio lineups and in the gallery. Triangle counts cannot be read from Luau, so they have **not** been verified. None is labelled final.

**Built / optimized / missing**
- Built (imported and normalized): **77 / 77**. Missing: **0**.
- Silhouettes: high rarities use distinct meshes, not recolors. Where two weapons share a source pack, they use different children of that pack.
- Optimized (the look was kept; primitives were merged per material so neon is preserved):
- Wooden: 13 -> 2 parts (primitive parts merged per material; look unchanged)
- GlacierFang: 19 -> 5 parts (primitive parts merged per material; look unchanged)
- SunsteelSword: 144 -> 12 parts (primitive parts merged per material; look unchanged)
- PrismSaber: 16 -> 6 parts (primitive parts merged per material; look unchanged)
- FoundersEdge: 59 -> 9 parts (primitive parts merged per material; look unchanged)
- Also removed: 7 PointLights and 38 non-visual objects; 11 Tool and 4 Accessory wrappers were unwrapped; 8 unbounded emitters were capped.
- The BladeModels folder holds 120 models and about 300 parts in total.
- **Still above 8 parts** (all-mesh, so they cannot be merged in Studio): BonewhiteReaper 41, SoulboundBlade 15, WarlordAxe 13, SunsteelSword 12, ForsakenAxe 11, FoundersEdge 9. Test W2 exempts these.

## 6. VFX and reveals

- `BladeEffects` VFX tiers 0–7 (VfxTier = rarity order − 1): glow, trails, particles and a Divine pulsing aura (held steady under Reduced Motion).
- **Budgets:**
  - full effects on blade 1;
  - particles on blades 2–3 for the local player only;
  - other players see blade 1 effects only;
  - Graphics "Low" shows trails only;
  - at most 1 PointLight per wielder.
- **Reveals** (`RollController`): Legendary 1.5 s ring, Mythic 2.5 s beam, Secret 3 s with extra rings, Divine 4 s with letterbox and title.
- **Announcements:** Mythic, Secret and Divine to the server; Secret and Divine globally. The legacy 1-in-X thresholds still apply.

## 7. Gallery

- New `GalleryController` with a 🗡️ GALLERY dock tile. It covers all 120 weapons by island and rarity, with locked silhouettes for unowned weapons.
- **Detail view:** rotatable 3D viewport, owned count, stars and Shiny, Power, acquisition text and exact odds.
- **Controls:**
  - filters for island, rarity and owned, plus sorting;
  - Favorite, Equip and Auto Equip;
  - "Collected N / 120" counter;
  - Essence line and Attune button.
- The roster is data-driven, so future weapons appear automatically. M1 index editions are kept: edition 2 holds each area's new weapons, with its bonus scaled ×0.5 (`Index.EditionScale`).
- **Favorites** block auto-sell and max-star overflow selling (up to 999 copies kept), and block future salvage and trade. Auto-fuse is still allowed.

## 8. Future-system interfaces (data only, no gameplay)

Every weapon has `Future = {Forgeable, RuneSlots, MaxAwakening, Tradeable, Vaultable, SeasonVariantOf, GuildReward}`, together with `Config.WeaponFuture` and `EconomyConfig.WeaponFuture` (`PowerCeilingMult` 6), so new islands can add weapons without breaking the curve. **No Tech Tree** and no forging, rune or trading gameplay were built.

## 9. Changes to original weapons

- IDs, names, rarity, OneIn, Power, ownership, stars, copies and Shiny are **unchanged**. Tests W1 and W4 compare them against the pre-M2 snapshot.
- Each original weapon gained metadata fields (Edition 1, Island, Altar, Source, VfxTier, Future).
- Model-only changes: the 5 part-count optimizations above, plus removed lights, emitters and wrappers. The pre-M2 originals are kept in `BladeModels_PreM2`.

## 10. Validation

| Suite | Result |
| --- | --- |
| M2Tests (new: W1 roster/IDs, W2 models, W3 odds, W4 legacy preservation, W5 essence/attune, W6 favorites/gallery data) | **46/46** |
| M1Tests (goldens updated for pools 39/77/115) | 41/41 |
| M01Tests | 64/64 |
| M0Tests (bk3 profile) | 107/107 |

**Single-client playtest:** 0 server errors and 0 client errors.
- Essence accrues 1 per roll.
- Favorite on an owned weapon succeeds; a bogus ID is rejected ("Not owned").
- Attune without enough Essence is rejected ("Need 100.0K Altar Essence"); an unknown island is rejected.
- The gallery renders "Collected 25 / 120".
- Mythic (Void) effects: 5 instances across 2 blades, 1 light.

**Simulator** (`tools/econsim/results/m2/`, 12 seeds; M1 results kept in `results/m1/`):
- Crystal Wilds unlock p50, free player: 13–23 min (M1: 21–34). Frostbound unlock is unchanged at about 6.3 h.
- Free player, first Legendary: 30–46 min. First Mythic: 3–5.9 h. First Secret: 23–40 h. Divine is reached via Attunement.
- AFK/active Logs ratio 0.43–0.61; paid/free at 200 h: 2.44.

**Dev save changes from testing:**
- 3 weapons gained from test rolls (25 owned).
- A test favorite was set and then reverted.
- Essence counters advanced.
- Logs 9,246,033 and Souls 114 unchanged; session lock released.

**Not tested:**
- multiplayer and cross-server;
- iPhone/mobile;
- the Attunement *success* path live (it needs 100k Essence; covered by unit test W5);
- favorite sell protection in a live session (unit tested);
- the Divine reveal live.

## 11. Outstanding work and owner decisions

1. Decide whether new weapons' `OneIn` should be raised to keep M1 rarity pacing (§3).
2. Review the 77 models in Studio and swap any you dislike. Each one is a single entry in `tools/m2/roster.py` (`SINGLE` map) followed by a re-import.
3. Verify triangle counts and mobile performance on a real iPhone.
4. Six legacy all-mesh models remain above 8 parts (§5).
5. Variety gaps: few dual-blade or greatsword looks; there is no dual-blade weapon type.
6. Forge recipes and crafting (M6); runes, awakening, trading and vaults are interfaces only.
7. Merge and publish decisions belong to the owner.

## 12. Git

- Branch `m2/complete-weapon-collection`, pushed, not merged.
- M2 commit: `26360477a615ec6c2c1da1be3d47cb3ef98aa7c5`.
