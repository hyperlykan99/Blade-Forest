"""Apply the M2 roster (roster.py) to src/shared/BladeConfig.luau and write docs/weapon_manifest.json.

Idempotent: the generated blocks sit between "-- M2:BEGIN <name>" / "-- M2:END <name>" markers.
    python3 tools/m2/gen_m2.py
"""
import json, os, re, sys, zlib
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from roster import ROSTER, SINGLE, ATTUNEMENT  # noqa: E402

CFG = os.path.join(REPO, "src", "shared", "BladeConfig.luau")
ISLAND = {"StarterGrove": "TimberHaven", "PineForest": "TimberHaven", "CrystalCanyon": "CrystalWilds", "FrostPeaks": "FrostboundReach"}
ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine"]


def block(name, body, indent=""):
    return f"{indent}-- M2:BEGIN {name}\n{body}{indent}-- M2:END {name}\n"


def put(text, name, body, anchor, indent="", after=True):
    """insert/replace a marked block; anchor = unique line text to insert after/before"""
    pat = re.compile(rf"[\t ]*-- M2:BEGIN {name}\n.*?-- M2:END {name}\n", re.S)
    blk = block(name, body, indent)
    if pat.search(text):
        return pat.sub(lambda m: blk, text, count=1)
    assert text.count(anchor) == 1, f"anchor not unique: {anchor!r}"
    i = text.index(anchor)
    if after:
        j = text.index("\n", i) + 1
        return text[:j] + blk + text[j:]
    return text[:i] + blk + text[i:]


def weapon_lines():
    out = []
    for r in ROSTER:
        a = r["Accent"]
        p = f', Particle = "{r["Particle"]}"' if r["Particle"] else ""
        out.append(f'\t{{ Id = "{r["Id"]}", Name = "{r["Name"]}", Type = "{r["Type"]}", Rarity = "{r["Rarity"]}", '
                   f'Area = "{r["Area"]}", Scale = 1.0, Accent = Color3.fromRGB({a[0]}, {a[1]}, {a[2]}){p}, Edition = 2 }},\n')
    return "\t-- M2 expansion (77): tools/m2/roster.py is the source; legacy entries above keep their order\n" + "".join(out)


def onein_lines():
    items = [f'{r["Id"]} = {r["OneIn"]}' for r in ROSTER]
    rows = [", ".join(items[i:i + 5]) + "," for i in range(0, len(items), 5)]
    return "".join(f"\t{row}\n" for row in rows)


def editions():
    """index edition 2 per area: Standard = new non-Secret/Divine, Mastery = new Secret + Divine"""
    out = {}
    for r in ROSTER:
        e = out.setdefault(r["Area"], {"Standard": [], "Mastery": []})
        (e["Mastery"] if r["Rarity"] in ("Secret", "Divine") else e["Standard"]).append(r["Id"])
    lines = []
    for area in ["StarterGrove", "PineForest", "CrystalCanyon", "FrostPeaks"]:
        e = out.get(area)
        if not e:
            continue
        parts = []
        if e["Standard"]:
            parts.append("Standard = { " + ", ".join(f'"{x}"' for x in e["Standard"]) + " }")
        if e["Mastery"]:
            parts.append("Mastery = { " + ", ".join(f'"{x}"' for x in e["Mastery"]) + " }")
        lines.append(f"Config.IndexEditions.Weapon.{area}[2] = {{ {', '.join(parts)} }}\n")
    return "-- M2: index edition 2 = the expansion weapons of each area (bonus x EditionScale[2]); edition 1 records stay\n" + "".join(lines)


def main():
    t = open(CFG, encoding="utf-8").read()
    before = t
    # 1) weapon entries: after the last legacy entry (ForsakenAxe line)
    t = put(t, "weapons", weapon_lines(), '{ Id = "ForsakenAxe",     Name = "Forsaken Axe"')
    # 2) OneIn values: after the FrostboundReaper line of Config.OneIn
    t = put(t, "onein", onein_lines(), "GlacialEdge = 15000000, Dragonflame = 25000000, SeraphsLight = 50000000, FrostboundReaper = 100000000,")
    # 3) editions: after the IndexEditions table's closing (TreeIndexBonus comment is right after it)
    t = put(t, "editions", editions(), "-- Completing an area's TREE index: +5% Logs forever (stacks per area)", after=False)
    open(CFG, "w", encoding="utf-8").write(t)
    d = t.encode()
    print("BladeConfig", f"{len(d)}:{zlib.adler32(d)}", "changed" if t != before else "unchanged")

    # manifest of all 120 weapons
    ids_legacy = re.findall(r'\{ Id = "(\w+)",\s+Name = "([^"]+)",\s*Type = "(\w+)",\s*Rarity = "(\w+)",\s*Area = "(\w+)"', before.split("-- M2:BEGIN weapons")[0])
    onein = dict((k, int(v)) for k, v in re.findall(r"(\w+) = (\d+)", t[t.index("Config.OneIn = {"):t.index("Config.RollInterval")]))
    excl = set(re.findall(r'Id = "(\w+)"[^\n]*Exclusive = true', before))
    fixed = dict(re.findall(r'Id = "(\w+)"[^\n]*FixedPower = (\d+)', before))
    soul = dict(re.findall(r'Id = "(\w+)"[^\n]*SoulCost = (\d+)', before))

    def power(i):
        return int(fixed[i]) if i in fixed else int(5 * onein.get(i, 2) ** 0.45 + 0.5)

    def vfx(r):
        return ORDER.index(r)  # 0 Common .. 7 Divine (BladeEffects tiers)
    man = []
    for i, n, ty, ra, ar in ids_legacy:
        src = "SoulShop" if i in soul else ("StarterPack" if i == "FoundersEdge" else ("Starter" if i == "Wooden" else "Altar"))
        man.append(dict(Id=i, Name=n, Type=ty, Rarity=ra, Area=ar, Island=ISLAND[ar], Altar=None if i in excl or i == "Wooden" else ISLAND[ar],
                        OneIn=None if i in excl else onein.get(i), Power=power(i), Edition=1, Source=src, VfxTier=vfx(ra),
                        Model={"Template": f"ReplicatedStorage.BladeModels.{i}", "Origin": "legacy (pre-M2; source not recorded)"}))
    for r in ROSTER:
        F = r["F"]
        if F <= 32:
            aid, creator, title = 109984325205666, "RabiMaster9", "32 Free Low Poly Fantasy Sword & Weapon Models"
            child = "(pack child, see template attribute SourceChild)"
        else:
            aid, child, creator, title = SINGLE[F]
            child = child or ""
        man.append(dict(Id=r["Id"], Name=r["Name"], Type=r["Type"], Rarity=r["Rarity"], Area=r["Area"], Island=ISLAND[r["Area"]],
                        Altar=ISLAND[r["Area"]], OneIn=r["OneIn"], Power=power(r["Id"]), Edition=2,
                        Source="Altar" + (" + Divine Attunement" if r["Id"] in ATTUNEMENT.values() else ""), VfxTier=vfx(r["Rarity"]),
                        Model={"Template": f"ReplicatedStorage.BladeModels.{r['Id']}", "CreatorStoreAssetId": aid, "Child": child,
                               "Creator": creator, "Title": title, "License": "Roblox Creator Store free model (Roblox Terms of Use)",
                               "Scripts": "removed on import (none kept)", "Orientation": r["Orient"]}))
    assert len(man) == 120, len(man)
    assert len({m["Id"] for m in man}) == 120
    out = os.path.join(REPO, "docs", "weapon_manifest.json")
    json.dump({"_doc": "M2: all 120 weapons. Power = 5 x OneIn^0.45 (legacy FixedPower kept). Generated by tools/m2/gen_m2.py.",
               "Weapons": man}, open(out, "w"), indent=1, ensure_ascii=False)
    from collections import Counter
    print("manifest", len(man), dict(Counter(m["Rarity"] for m in man)))


if __name__ == "__main__":
    main()
