"""M2 weapon roster: the 77 new weapons (single source of truth).

gen_m2.py turns this into:
  * the BladeConfig weapon entries + OneIn values + index edition 2 (src/shared/BladeConfig.luau, M2 block)
  * docs/weapon_manifest.json (all 120 weapons incl. the 43 legacy ones)
  * the Studio model build list (tools/m2/build_list.json)

Fields: Id, Name, Type, Rarity, Area, OneIn, Accent (r,g,b), Particle (None = rarity default),
        F = finalist number in the M2 import montage (model source), Orient = model orientation fix
Areas: StarterGrove/PineForest -> Timber Haven altar, CrystalCanyon -> Crystal Wilds, FrostPeaks -> Frostbound Reach.
Power is NOT stored: it is 5 * OneIn^0.45 like every legacy weapon (one formula, simulator-compatible).
"""

# model sources (Creator Store, free). F -> (asset id, child name or None, creator, asset title)
SOURCES = {
    "RM": (109984325205666, "RabiMaster9", "32 Free Low Poly Fantasy Sword & Weapon Models"),
}
# F numbers 1..32 are children of the RabiMaster9 pack (asset 109984325205666); names resolved in Studio.
SINGLE = {
    33: (85544016354562, "epee_large", "coyote_hybridd", "21 Weapons, Tools & Items - Low Poly RPG Pack"),
    34: (85544016354562, "hache_bataille", "coyote_hybridd", "21 Weapons, Tools & Items - Low Poly RPG Pack"),
    35: (4596657731, "Battle-Axe", "Heahmund", "Nordic Carved Weaponry"),
    36: (4596657731, "Sword", "Heahmund", "Nordic Carved Weaponry"),
    37: (4596657731, "Greatsword", "Heahmund", "Nordic Carved Weaponry"),
    38: (114164136130143, None, "jesperx", "Battle axe with engravings"),
    39: (111938391354722, None, "febrydwip", "Blue Sword Fantasy Low Poly"),
    40: (103249999198428, None, "febrydwip", "Green Sword Fantasy Low Poly"),
    41: (97407267401652, None, "febrydwip", "Blue Mecha Sword Fantasy Low Poly"),
    42: (79233567090868, None, "K3LLo29", "Low Poly Azure Fantasy Sword"),
    43: (84725261554298, None, "KL_JOKER46", "[LOW POLY] Fantasy Iron Sword"),
    44: (5193504025, None, "Airzly", "Crystal Sword"),
    45: (5193470810, None, "Airzly", "Jagged Sword"),
    46: (99319419231103, None, "Aktul_X", "Crystal Fantasy Sword"),
    47: (79913196266344, None, "Wirly_world", "Gothic Greatsword"),
    48: (107204789910711, None, "Wirly_world", "Gothic Scythe"),
    49: (14983425633, None, "Ziresei", "Void Scythe"),
    50: (102732830077707, None, "GreenLightningRBLX", "Groundskeeper Scythe"),
    51: (2019918699, None, "MikuHazard", "Celestial Battle Axe"),
    53: (27782369, None, "Yourius", "The Skull Lord's Battle Axe"),
    55: (11857430591, None, "ImJustCritz", "Crystal Sword"),
    56: (12724420744, None, "OrbiPlay", "Ice Sword"),
    57: (16905154362, None, "Pandebchik Studio", "Ice Sword"),
    58: (8535931563, None, "Dev_Simphony", "Katana Mesh"),
    59: (140237683099823, None, "Amongfse", "Black Katana"),
    60: (13168667185, None, "TealixSwirl", "Winters Greatsword [Mesh]"),
    61: (104922735601845, None, "Udiean27", "white neon fantasy sword"),
    62: (117948646998971, None, "explosibo55", "Illumina"),
    63: (76363890187461, None, "Skywhi7162", "Defender"),
    64: (91274376729622, None, "clansp4 hub", "Cursed Shardblade"),
    65: (16070621258, None, "firegames233 (modeled by Seasly)", "Dark Sword"),
    66: (11300742737, None, "seG1as", "crystal red sword with effect"),
    67: (83223944436703, None, "seG1as", "Blood Scythe Halloween Decor"),
    68: (2506494882, None, "GreenDieno", "Bone Scythe"),
    69: (112775014098679, None, "kris131441", "Scythe"),
    71: (17346131691, None, "Troyonik", "Battle axe"),
    72: (88566817567680, None, "WabbitSlayer78", "Stone_Axe"),
    73: (115423796241260, None, "Al3x_Coo1", "Axe | Топор"),
    74: (132212403247918, None, "dreznik14", "Sapper's Axe"),
    77: (5088853924, None, "noru_xii", "Battle axe"),
    79: (2749777054, None, "Pseudosuper", "Ice Axe"),
    82: (9309773165, None, "kbx_rblx", "Crystal's Scythe"),
    86: (2166057719, None, "XxMlgX15XxX", "Crystal axe"),
    88: (9095853669, None, "IceLord6421", "Crystal Axe"),
    87: (10248346084, None, "RealAndraYas110", "Crystal Axe"),
}

# Orient: "trbl" = tip top-right->bottom-left (tip bottom-left), "brtl" = tip top-left;
# "up" = longest axis is the blade, tip at +Y after fit (default); "down" = tip at -Y;
#         "tlbr" = blade on the box diagonal, tip bottom-right; "bltr" = tip top-right.
R = [
    # ---------------- Timber Haven (15) ----------------
    ("WoodcuttersHatchet", "Woodcutter's Hatchet", "Axe", "Common", "StarterGrove", 5, (190, 150, 100), None, 73, "up"),
    ("RiverRaiderBlade", "River Raider Blade", "Sword", "Common", "StarterGrove", 8, (170, 140, 110), None, 4, "tlbr"),
    ("RiverlordSaber", "Riverlord's Saber", "Sword", "Uncommon", "StarterGrove", 60, (230, 200, 120), None, 12, "tlbr"),
    ("CaptainsGoldguard", "Captain's Goldguard", "Sword", "Uncommon", "StarterGrove", 80, (255, 210, 90), None, 9, "tlbr"),
    ("AshbarkKnightblade", "Ashbark Knightblade", "Sword", "Rare", "PineForest", 400, (220, 140, 90), None, 19, "bltr"),
    ("GroundskeeperScythe", "Groundskeeper's Scythe", "Scythe", "Rare", "PineForest", 600, (160, 190, 140), None, 50, "up"),
    ("FurnacecoreLongsword", "Furnacecore Longsword", "Sword", "Epic", "PineForest", 3000, (255, 150, 60), "Fire", 18, "bltr"),
    ("FlametongueSaber", "Flametongue Saber", "Sword", "Epic", "PineForest", 4000, (255, 110, 40), "Fire", 22, "bltr"),
    ("GildedWarden", "Gilded Warden", "Sword", "Epic", "PineForest", 6000, (255, 220, 110), "Sparkle", 33, "up"),
    ("WildfireGreatsword", "Wildfire Greatsword", "Sword", "Legendary", "PineForest", 30000, (255, 120, 30), "Fire", 21, "bltr"),
    ("KindledRingblade", "Kindled Ringblade", "Sword", "Legendary", "PineForest", 45000, (255, 160, 70), "Fire", 25, "bltr"),
    ("TridentBlaze", "Trident Blaze", "Sword", "Mythic", "PineForest", 300000, (255, 90, 30), "Fire", 28, "bltr"),
    ("Wyrmfang", "Wyrmfang", "Sword", "Mythic", "PineForest", 450000, (255, 70, 40), "Fire", 27, "bltr"),
    ("EmberkingsCrown", "Emberking's Crown", "Sword", "Secret", "PineForest", 2000000, (255, 140, 40), "Fire", 32, "bltr"),
    ("HearthforgeSovereign", "Hearthforge Sovereign", "Sword", "Divine", "PineForest", 12000000, (255, 180, 70), "Fire", 31, "bltr"),
    # ---------------- Crystal Wilds (28) ----------------
    ("ButchersCleaver", "Prospector's Cleaver", "Sword", "Common", "CrystalCanyon", 4, (200, 190, 180), None, 1, "tlbr"),
    ("RopegripCutlass", "Ropegrip Cutlass", "Sword", "Common", "CrystalCanyon", 5, (190, 170, 140), None, 3, "tlbr"),
    ("DeckhandCutlass", "Canyon Deckhand", "Sword", "Common", "CrystalCanyon", 7, (200, 200, 210), None, 5, "tlbr"),
    ("HooktipCutlass", "Hooktip Cutlass", "Sword", "Common", "CrystalCanyon", 8, (210, 200, 190), None, 11, "tlbr"),
    ("ProspectorsBlade", "Quarry Iron Blade", "Sword", "Common", "CrystalCanyon", 9, (200, 200, 205), None, 43, "up"),
    ("SilvershoreSaber", "Silvershore Saber", "Sword", "Uncommon", "CrystalCanyon", 45, (220, 225, 235), None, 2, "tlbr"),
    ("ShellguardCutlass", "Shellguard Cutlass", "Sword", "Uncommon", "CrystalCanyon", 55, (240, 200, 120), None, 6, "tlbr"),
    ("ForkguardCutlass", "Forkguard Cutlass", "Sword", "Uncommon", "CrystalCanyon", 65, (220, 210, 200), None, 8, "tlbr"),
    ("CanyonSickle", "Canyon Sickle", "Scythe", "Uncommon", "CrystalCanyon", 75, (180, 60, 60), None, 67, "up"),
    ("SappersAxe", "Sapper's Axe", "Axe", "Uncommon", "CrystalCanyon", 90, (190, 190, 200), None, 74, "up"),
    ("Flintedge", "Flintedge", "Sword", "Rare", "CrystalCanyon", 300, (160, 150, 150), None, 17, "bltr"),
    ("MagmaveinBlade", "Magmavein Blade", "Sword", "Rare", "CrystalCanyon", 450, (255, 110, 40), None, 20, "bltr"),
    ("CharcoalBrand", "Charcoal Brand", "Sword", "Rare", "CrystalCanyon", 550, (120, 100, 90), None, 30, "bltr"),
    ("JadeleafEdge", "Jadeleaf Edge", "Sword", "Rare", "CrystalCanyon", 800, (90, 230, 120), None, 40, "up"),
    ("AmethystSickle", "Amethyst Sickle", "Scythe", "Rare", "CrystalCanyon", 900, (170, 100, 255), None, 82, "up"),
    ("CraterGreatsword", "Crater Greatsword", "Sword", "Epic", "CrystalCanyon", 2800, (255, 120, 50), "Fire", 23, "bltr"),
    ("Geyserfang", "Geyserfang", "Sword", "Epic", "CrystalCanyon", 4500, (255, 140, 60), "Fire", 26, "bltr"),
    ("MeteorShard", "Meteor Shard", "Sword", "Epic", "CrystalCanyon", 5500, (255, 90, 60), "Fire", 29, "bltr"),
    ("AzureTidecurve", "Azure Tidecurve", "Sword", "Epic", "CrystalCanyon", 8000, (80, 170, 255), "Sparkle", 42, "up"),
    ("GeodeCleaveaxe", "Fuchsia Geode Cleaveaxe", "Axe", "Epic", "CrystalCanyon", 9000, (255, 80, 220), "Sparkle", 87, "up"),
    ("ObsidianGlassblade", "Obsidian Glassblade", "Sword", "Legendary", "CrystalCanyon", 28000, (255, 100, 60), "Fire", 24, "bltr"),
    ("RosequartzFang", "Rosequartz Fang", "Sword", "Legendary", "CrystalCanyon", 40000, (255, 150, 200), "Sparkle", 66, "up"),
    ("OpalineEdge", "Opaline Edge", "Sword", "Legendary", "CrystalCanyon", 60000, (170, 140, 255), "Sparkle", 55, "up"),
    ("GarnetCrystalAxe", "Garnet Crystal Axe", "Axe", "Legendary", "CrystalCanyon", 80000, (220, 40, 60), "Sparkle", 88, "down"),
    ("ObsidianEclipse", "Obsidian Eclipse", "Sword", "Mythic", "CrystalCanyon", 400000, (130, 60, 220), "Void", 65, "trbl"),
    ("GeodeHarvester", "Geode Harvester", "Scythe", "Mythic", "CrystalCanyon", 600000, (230, 40, 50), "Void", 69, "up"),
    ("SkyshardAegisblade", "Skyshard Aegisblade", "Sword", "Secret", "CrystalCanyon", 3000000, (110, 200, 255), "Holy", 46, "tlbr"),
    ("PrismheartRadiance", "Prismheart Radiance", "Sword", "Divine", "CrystalCanyon", 20000000, (200, 120, 255), "Holy", 62, "up"),
    # ---------------- Frostbound Reach (34) ----------------
    ("IcesawBoarder", "Icesaw Boarder", "Sword", "Common", "FrostPeaks", 5, (200, 225, 240), None, 13, "tlbr"),
    ("ShorthiltSaber", "Shorthilt Saber", "Sword", "Common", "FrostPeaks", 6, (210, 220, 230), None, 14, "tlbr"),
    ("GhostshipCutlass", "Ghostship Cutlass", "Sword", "Common", "FrostPeaks", 7, (150, 200, 200), None, 7, "tlbr"),
    ("GlacierWoodsplitter", "Glacier Woodsplitter", "Axe", "Common", "FrostPeaks", 8, (180, 210, 235), None, 34, "up"),
    ("FrostwindKatana", "Frostwind Katana", "Sword", "Common", "FrostPeaks", 9, (200, 215, 230), None, 58, "up"),
    ("HarpoonCutlass", "Harpoon Cutlass", "Sword", "Uncommon", "FrostPeaks", 40, (200, 220, 240), None, 15, "tlbr"),
    ("FrostportOfficer", "Frostport Officer's Sword", "Sword", "Uncommon", "FrostPeaks", 85, (230, 235, 250), None, 16, "tlbr"),
    ("LonghiltBoarder", "Longhilt Boarder", "Sword", "Uncommon", "FrostPeaks", 95, (210, 220, 235), None, 10, "tlbr"),
    ("TundraStoneAxe", "Tundra Stone Axe", "Axe", "Uncommon", "FrostPeaks", 110, (170, 175, 185), None, 72, "up"),
    ("BlackiceKatana", "Blackice Katana", "Sword", "Uncommon", "FrostPeaks", 120, (60, 70, 90), None, 59, "up"),
    ("NorthmanBeardaxe", "Northman Beardaxe", "Axe", "Rare", "FrostPeaks", 350, (170, 190, 210), None, 35, "up"),
    ("FjordSword", "Fjord Sword", "Sword", "Rare", "FrostPeaks", 650, (150, 180, 220), None, 36, "up"),
    ("JaggedFloe", "Jagged Floe", "Sword", "Rare", "FrostPeaks", 750, (160, 220, 255), None, 45, "up"),
    ("FrostwardenBattleaxe", "Frostwarden Battleaxe", "Axe", "Rare", "FrostPeaks", 1100, (150, 200, 240), None, 71, "up"),
    ("SnowcapLabrys", "Snowcap Labrys", "Axe", "Rare", "FrostPeaks", 1200, (220, 235, 255), None, 77, "down"),
    ("NorthmanGreatsword", "Northman Greatsword", "Sword", "Epic", "FrostPeaks", 3200, (140, 180, 230), "Frost", 37, "up"),
    ("RunedFrostaxe", "Runed Frostaxe", "Axe", "Epic", "FrostPeaks", 6500, (120, 200, 255), "Frost", 38, "up"),
    ("SnowlightBlade", "Snowlight Blade", "Sword", "Epic", "FrostPeaks", 7500, (240, 250, 255), "Frost", 61, "tlbr"),
    ("IcicleSpire", "Icicle Spire", "Sword", "Epic", "FrostPeaks", 12000, (150, 230, 255), "Frost", 44, "up"),
    ("RimewireScythe", "Rimewire Scythe", "Scythe", "Epic", "FrostPeaks", 15000, (180, 210, 240), "Frost", 48, "up"),
    ("GlacialSplitter", "Glacial Splitter", "Axe", "Legendary", "FrostPeaks", 55000, (90, 170, 255), "Frost", 79, "up"),
    ("CryoMechblade", "Cryo Mechblade", "Sword", "Legendary", "FrostPeaks", 90000, (80, 160, 255), "Frost", 41, "up"),
    ("FrostspireGreatsword", "Frostspire Greatsword", "Sword", "Legendary", "FrostPeaks", 120000, (200, 220, 240), "Frost", 47, "up"),
    ("IceshardCleaver", "Iceshard Cleaver", "Sword", "Legendary", "FrostPeaks", 150000, (140, 220, 255), "Frost", 56, "up"),
    ("HoarfrostAxe", "Hoarfrost Axe", "Axe", "Legendary", "FrostPeaks", 180000, (200, 215, 235), "Frost", 86, "up"),
    ("FrostskullRavager", "Frostskull Ravager", "Axe", "Mythic", "FrostPeaks", 650000, (130, 200, 255), "Frost", 53, "up"),
    ("GlacierBoneReaper", "Glacier Bone Reaper", "Scythe", "Mythic", "FrostPeaks", 750000, (220, 240, 255), "Frost", 68, "up"),
    ("FrostguardDefender", "Frostguard Defender", "Sword", "Mythic", "FrostPeaks", 850000, (90, 220, 255), "Frost", 63, "up"),
    ("Iceveil", "Iceveil", "Sword", "Mythic", "FrostPeaks", 900000, (90, 160, 255), "Frost", 39, "up"),
    ("Shiverfang", "Shiverfang", "Sword", "Mythic", "FrostPeaks", 950000, (110, 170, 255), "Frost", 64, "bltr"),
    ("AuroraCleaver", "Aurora Cleaver", "Axe", "Secret", "FrostPeaks", 5000000, (100, 220, 255), "Holy", 51, "up"),
    ("RimefrostRequiem", "Rimefrost Requiem", "Sword", "Secret", "FrostPeaks", 8000000, (170, 230, 255), "Holy", 57, "up"),
    ("PolarNightReaper", "Polar Night Reaper", "Scythe", "Secret", "FrostPeaks", 9000000, (90, 60, 200), "Void", 49, "up"),
    ("EternalWinter", "Eternal Winter", "Sword", "Divine", "FrostPeaks", 40000000, (190, 235, 255), "Frost", 60, "up"),
]

KEYS = ("Id", "Name", "Type", "Rarity", "Area", "OneIn", "Accent", "Particle", "F", "Orient")
ROSTER = [dict(zip(KEYS, r)) for r in R]

# Divine Attunement (deterministic, bounded Divine route): one Divine per island altar,
# claimable ONCE per player for Altar Essence (1 per altar roll, daily cap).
ATTUNEMENT = {"TimberHaven": "HearthforgeSovereign", "CrystalWilds": "PrismheartRadiance", "FrostboundReach": "EternalWinter"}

if __name__ == "__main__":
    ids = [r["Id"] for r in ROSTER]
    assert len(ROSTER) == 77, len(ROSTER)
    assert len(set(ids)) == 77
    fs = [r["F"] for r in ROSTER]
    assert len(set(fs)) == 77, "a model is used twice"
    for r in ROSTER:
        assert r["F"] <= 32 or r["F"] in SINGLE, r
    from collections import Counter
    print(Counter((r["Area"], r["Rarity"]) for r in ROSTER))
    print("ok")
