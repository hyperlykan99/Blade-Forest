"""Parse the balance numbers straight out of src/shared/BladeConfig.luau.

Everything the simulator uses comes from the real config file, so a config
change is picked up by re-running the simulator. Only behavioural/geometry
assumptions live in sim.py (and are labelled there).
"""
import re, math, pathlib, os

# BladeConfig.luau to read. Default: the repo checkout this folder lives in
# (docs/audits/sims -> repo root). The audit used m0/foundations @ 75f5985;
# `main` has no src/, so point BF_CONFIG at that file when running from main.
_DEFAULT = pathlib.Path(__file__).resolve().parents[3] / "src" / "shared" / "BladeConfig.luau"
SRC = pathlib.Path(os.environ.get("BF_CONFIG", str(_DEFAULT)))


def _num(s):
    return float(s)


def _fields(line):
    out = {}
    for k, v in re.findall(r'(\w+)\s*=\s*("[^"]*"|-?[\d.]+(?:e\d+)?|true|false)', line):
        if v.startswith('"'):
            out[k] = v.strip('"')
        elif v in ("true", "false"):
            out[k] = v == "true"
        else:
            out[k] = _num(v)
    return out


def _block(text, start_pat, end_pat=r"\n}"):
    i = re.search(start_pat, text).end()
    j = text.index(end_pat.replace("\\n", "\n"), i)
    return text[i:j]


def load():
    t = SRC.read_text()
    C = {}
    # rarities
    C["rarities"] = {}
    for line in _block(t, r"Config\.Rarities = \{").splitlines():
        f = _fields(line)
        if "Id" in f:
            C["rarities"][f["Id"]] = f
    # areas
    C["areas"] = []
    for line in _block(t, r"Config\.Areas = \{").splitlines():
        f = _fields(line)
        if "Id" in f:
            C["areas"].append(f)
    # trees
    C["trees"] = {}
    for line in _block(t, r"Config\.TreeTypes = \{").splitlines():
        m = re.match(r"\s*(\w+)\s*=\s*\{(.*)\}", line)
        if m:
            f = _fields(m.group(2))
            f["Id"] = m.group(1)
            C["trees"][m.group(1)] = f
    # mutations
    C["mutations"] = []
    for line in _block(t, r"Config\.Mutations = \{").splitlines():
        f = _fields(line)
        if "Id" in f:
            C["mutations"].append(f)
    # weapons
    C["weapons"] = {}
    for line in _block(t, r"local W = \{").splitlines():
        f = _fields(line)
        if "Id" in f and "Rarity" in f:
            C["weapons"][f["Id"]] = f
    one = _block(t, r"Config\.OneIn = \{")
    for k, v in re.findall(r"(\w+)\s*=\s*([\d.]+)", one):
        C["weapons"][k]["OneIn"] = float(v)
    for w in C["weapons"].values():
        w["Power"] = w.get("FixedPower") or math.floor(5 * w.get("OneIn", 2) ** 0.45 + 0.5)
        w["Length"] = C["rarities"][w["Rarity"]]["Length"]
    # scalars
    def scal(name):
        return float(re.search(rf"Config\.{name}\s*=\s*([\d.]+)", t).group(1))
    for n in ["WeakDamageMult", "MaxStar", "ShinyCopies", "ShinyMult", "RollInterval", "FastRollInterval",
              "LuckyRollEvery", "AutoRollInterval", "FastAutoRollInterval", "BladeHitRadius", "BladeHitCooldown",
              "BladeSizePerReach", "MaxSpinSpeed", "SoulCrateCost", "MaxPetsEquipped", "PetEggMult",
              "VIPDailyCrateHours", "GroupLuck", "BossRewardPool", "BossSoulPool"]:
        C[n] = scal(n)
    C["FuseCost"] = [int(x) for x in re.search(r"Config\.FuseCost = \{([^}]*)\}", t).group(1).split(",")]
    sm = re.search(r"Config\.StarMult = \{([^}]*)\}", t).group(1)
    C["StarMult"] = [1.0] + [float(x) for x in re.findall(r"(?<![\[\w])([\d.]+)(?!\])", sm.split(",", 1)[1])]
    C["upgrades"] = {}
    for line in _block(t, r"Config\.Upgrades = \{").splitlines():
        f = _fields(line)
        if "Id" in f:
            C["upgrades"][f["Id"]] = f
    C["IndexBonus"] = _fields(re.search(r"Config\.IndexBonus = \{([^}]*)\}", t).group(1))
    C["TreeIndexBonus"] = _fields(re.search(r"Config\.TreeIndexBonus = \{([^}]*)\}", t).group(1))
    C["boosts"] = {}
    for line in _block(t, r"Config\.Boosts = \{").splitlines():
        m = re.match(r"\s*(\w+)\s*=\s*\{(.*)\}", line)
        if m:
            C["boosts"][m.group(1)] = _fields(m.group(2))
    C["traits"] = [f for f in map(_fields, _block(t, r"Config\.Traits = \{").splitlines()) if "Id" in f]
    C["TraitCrateCost"] = _fields(re.search(r"Config\.TraitCrateCost = \{([^}]*)\}", t).group(1))
    C["pets"] = [f for f in map(_fields, _block(t, r"Config\.Pets = \{").splitlines()) if "Id" in f]
    C["Rebirth"] = _fields(re.search(r"Config\.Rebirth = \{([^}]*)\}", t).group(1))
    C["events"] = [f for f in map(_fields, _block(t, r"Config\.Events = \{").splitlines()) if "Id" in f]
    g = re.search(r"Config\.EventGap = \{\s*(\d+),\s*(\d+)", t)
    C["EventGap"] = (float(g.group(1)), float(g.group(2)))
    C["Sawmill"] = _fields(_block(t, r"Config\.Sawmill = \{"))
    C["WorldBoss"] = _fields(_block(t, r"Config\.WorldBoss = \{"))
    C["PvP"] = _fields(_block(t, r"Config\.PvP = \{"))
    C["passes"] = [f for f in map(_fields, _block(t, r"Config\.GamePasses = \{").splitlines()) if "Id" in f]
    C["products"] = [f for f in map(_fields, _block(t, r"Config\.DevProducts = \{").splitlines()) if "Id" in f]
    C["SoulShopWeapons"] = {k: v for k, v in C["weapons"].items() if v.get("SoulCost")}
    return C


if __name__ == "__main__":
    C = load()
    print(len(C["weapons"]), "weapons;", len(C["trees"]), "tree types;", len(C["traits"]), "traits;", len(C["pets"]), "pets")
    print("StarMult", C["StarMult"], "FuseCost", C["FuseCost"])
    print({k: (v["BaseCost"], v["CostMult"], v["MaxLevel"]) for k, v in C["upgrades"].items()})
    print("events", [(e["Id"], e["Luck"], e["Logs"], e["Seconds"], e["Weight"]) for e in C["events"]], C["EventGap"])
    print("rebirth", C["Rebirth"], "crate", C["TraitCrateCost"])
    print("WorldBoss", C["WorldBoss"])
