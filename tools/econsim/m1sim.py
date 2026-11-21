"""Blade Forest M1 economy simulator.

Reads the weapon / tree / mutation catalog from src/shared/BladeConfig.luau (bf_config.py)
and EVERY M1 economy rule from economy_params.json (the same file gen_luau.py turns into
src/shared/EconomyConfig.luau, so the game and the model cannot drift apart).

Formulas mirrored from ReplicatedStorage.Economy (M1):
  soft(S, C)   = C * (1 - exp(-S / C))                            additive pool, soft-capped
  LogMult      = (1+soft(S_perm,6)) * (1+soft(S_pet,3)) * (1+soft(0.25n,3)) * Pass * max(temp)
  Luck         = min(50, (1+soft(S_luck,4)) * Pass2x * max(temp) [* 2 every 10th roll])
  EffOneIn     = OneIn / Luck^gamma(rarity)   (OneIn > 10 only)
  Damage       = Power * (1+0.1*DamageLv) * spinOverflow
  WalkSpeed    = 16 + 0.32*WalkSpeedLv  (<= 24)
  Price(item)  = k_item * Unit(tier),  tier = min(PowerTier(best Power), island access)
  Rewards      = Units * Unit(tier)  (gifts, daily, quests, bosses)
  Altars       = pool of the island the player farms (inherits lower islands), rolls-based
                 progression guarantee per altar
  Gates        = island Power + staged requirements (BladeKing kill, tree counts)

Geometry / behaviour assumptions (inherited from the audit simulator, calibrated to the
dev profile: 3,438 Logs/s predicted vs ~3,400 observed):
  A1 density: Crystal Wilds 1 tree / 31 stud^2; other areas 1 / 150 stud^2
  A2 AutoChop: walking at WalkSpeed; 70% of trees alive; harmonic encounter / kill rate
  A3 behaviour (see MODES)
  A4 greedy spending policy (spend())
  A5 per-player efficiency lognormal(0, 0.25)
  A6 one daily login + quest set per 4 played hours
"""
import json, math, os, sys
import numpy as np
from bf_config import load

HERE = os.path.dirname(os.path.abspath(__file__))
P = json.load(open(os.path.join(HERE, "economy_params.json")))
C = load()
TAU = 2 * math.pi
AREA_ORDER = [a["Id"] for a in C["areas"]]
AREA = {a["Id"]: a for a in C["areas"]}
DENSITY = {"StarterGrove": 1 / 150, "PineForest": 1 / 150, "CrystalCanyon": 1 / 31, "FrostPeaks": 1 / 150}
POOLS = P["Pools"]
UPG = {u["Id"]: u for u in P["Upgrades"]}
SOUL = {s["Id"]: s for s in P["SoulUpgrades"]}
ISL_ORDER = P["IslandOrder"]
AREA_ISL = P["AreaIsland"]

# ---------------------------------------------------------------- trees (ladder from params)
for t in C["trees"].values():
    t["Logs"] = math.floor(P["TreeBaseLogs"][t["Area"]] * P["TreeLadder"][t["Rarity"]] + 0.5)
TREES_BY_AREA = {a: [t for t in C["trees"].values() if t["Area"] == a] for a in AREA_ORDER}


def _mut_expect():
    p_none, e_log, e_hp = 1.0, 0.0, 0.0
    for m in reversed(C["mutations"]):
        p = p_none * (1 / m["OneIn"])
        e_log += p * m["LogMult"]; e_hp += p * m["HealthMult"]
        p_none -= p
    return e_log + p_none, e_hp + p_none
MUT_LOG, MUT_HP = _mut_expect()


def _event_avg():
    """time-averaged Logs/Luck from events under STRONGEST-ONLY temp stacking (with base temp)"""
    tw = sum(e["Weight"] for e in C["events"])
    dur = sum(e["Weight"] / tw * e["Seconds"] for e in C["events"])
    gap = sum(C["EventGap"]) / 2
    cyc = gap + dur
    return [(e["Weight"] / tw * e["Seconds"] / cyc, e["Logs"], e["Luck"]) for e in C["events"]], 1 - dur / cyc
EVENT_SLICES, EVENT_NONE = _event_avg()


def soft(S, cap):
    return cap * (1 - math.exp(-S / cap)) if cap > 0 else 0.0


# ---------------------------------------------------------------- weapons / altars
ROLLABLE = {k: w for k, w in C["weapons"].items() if w.get("OneIn") and not w.get("Exclusive") and k != "Wooden"}


def altar_pool(isl):
    a = P["Altars"][isl]
    ids = [k for k, w in ROLLABLE.items() if w["Area"] in a["Areas"]]
    for parent in a["Inherit"]:
        ids += altar_pool(parent)
    return sorted(set(ids), key=lambda k: -ROLLABLE[k]["OneIn"])


ALL_IDS = sorted(ROLLABLE, key=lambda k: -ROLLABLE[k]["OneIn"])
WIDX = {k: i for i, k in enumerate(ALL_IDS)}
ONEIN = np.array([ROLLABLE[k]["OneIn"] for k in ALL_IDS])
POWER = np.array([ROLLABLE[k]["Power"] for k in ALL_IDS], float)
LEN = np.array([ROLLABLE[k]["Length"] for k in ALL_IDS])
GAMMA = np.array([P["LuckGamma"][ROLLABLE[k]["Rarity"]] for k in ALL_IDS])
POOL_MASK = {isl: np.isin(ALL_IDS, altar_pool(isl)) for isl in ISL_ORDER}
STAR = np.array(C["StarMult"])
CUM_FUSE = np.cumsum([0] + C["FuseCost"])
INDEX_WEAPONS = {a: [k for k, w in C["weapons"].items() if w["Area"] == a and not w.get("Exclusive")] for a in AREA_ORDER}


def roll_probs(luck, isl):
    """exact per-roll probability of each weapon (sequential rarest-first algorithm) at an altar"""
    eff = np.where(ONEIN <= P["LuckMinOneIn"], ONEIN, np.maximum(ONEIN / np.maximum(luck, 1) ** GAMMA, 1))
    p_hit = np.where(POOL_MASK[isl], 1 / eff, 0.0)
    survive = np.concatenate([[1.0], np.cumprod(1 - p_hit)[:-1]])
    return p_hit * survive


# ---------------------------------------------------------------- economy formulas
def upg_value(uid, lv):
    u = UPG[uid]; return u["Base"] + u["PerLevel"] * lv


def upg_cost(uid, lv):
    u = UPG[uid]; return math.floor(u["BaseCost"] * u["CostMult"] ** lv)


def soul_upg_cost(su, lv):
    return math.floor(su["BaseCost"] * su["CostMult"] ** lv)


def walk_speed(p):
    m = P["Movement"]
    return min(m["BaseWalkSpeed"] + UPG["WalkSpeed"]["PerLevel"] * p["lv"]["WalkSpeed"], m["RegularMaxWalkSpeed"])


def stats(p):
    L = p["lv"]
    raw_speed = upg_value("Speed", L["Speed"])
    speed = min(raw_speed, C["MaxSpinSpeed"])
    dmg_mult = upg_value("Damage", L["Damage"]) * raw_speed / speed
    blades = upg_value("Blades", L["Blades"]) + (1 if "BladeSlot" in p["passes"] else 0)
    reach = upg_value("Reach", L["Reach"])
    size = 1 + C["BladeSizePerReach"] * L["Reach"]
    return dict(power=p["power"], dmg=p["power"] * dmg_mult, blades=blades, speed=speed, walk=walk_speed(p),
                reach=reach, length=p["wlen"] * size, slack=C["BladeHitRadius"] * size)


def area_rate(st, area, mode, eff=1.0, alive=0.7):
    outer = st["reach"] - 0.5 + st["length"] + st["slack"]
    inner = max(st["reach"] - 0.5 - st["slack"], 0)
    slots = DENSITY[area] * math.pi * (outer ** 2 - inner ** 2)
    hit_rate = st["blades"] * st["speed"] / TAU
    num = den = wsum = 0.0
    for t in TREES_BY_AREA[area]:
        weak = st["power"] < t["Strength"]
        if mode != "idle" and weak:
            continue
        dmg = st["dmg"] * (C["WeakDamageMult"] if weak else 1)
        kill = math.ceil(t["Health"] * MUT_HP / dmg) / hit_rate
        w = t["Weight"]
        den += w * (kill + (t["Respawn"] if mode == "idle" else 0))
        num += w * t["Logs"] * MUT_LOG
        wsum += w
    if wsum == 0:
        return 0.0, 0.0
    lpt = num / wsum
    if mode == "idle":
        trees = slots * wsum / den
    else:
        encounter = DENSITY[area] * st["walk"] * 2 * outer * alive
        trees = 1 / (1 / encounter + (den / wsum) / max(slots, 0.3))
    return trees * eff, trees * lpt * eff


def pass_logs(p):
    m = 1.0
    for k, e in P["PassEffects"].items():
        if k in p["passes"]:
            m *= e.get("Logs", 1)
    return m


def s_perm(p):
    t = p["trait"]
    return ((t["Mult"] - 1) if t else 0) + p["idx_logs"] + p["soul_lv"]["SoulBlessing"] * SOUL["SoulBlessing"]["PerLevel"]


def log_mult(p, temp=1.0):
    pets = sum(x["Logs"] for x in p["pets_eq"])
    return ((1 + soft(s_perm(p), POOLS["PermLogsCap"])) * (1 + soft(pets, POOLS["PetLogsCap"]))
            * (1 + soft(POOLS["RebirthLogsPer"] * p["reb"], POOLS["RebirthLogsCap"])) * pass_logs(p)
            * min(max(temp, 2.0 if p.get("logboost") else 1.0), POOLS["TempLogsMax"]))


def luck(p, temp=1.0):
    S = (UPG["Luck"]["PerLevel"] * p["lv"]["Luck"] + P["Rebirth"]["LuckPer"] * p["reb"] + p["idx_luck"]
         + sum(x["Luck"] for x in p["pets_eq"]) + 0.10 + p["soul_lv"]["SoulFortune"] * SOUL["SoulFortune"]["PerLevel"])
    L = 1 + soft(S, POOLS["PermLuckCap"])
    if "2xLuck" in p["passes"]:
        L *= 2
    t = max(temp, 10.0 if p.get("megaluck") else 1.0, p.get("luckpot", 1.0))
    return min(L * min(t, POOLS["TempLuckMax"]), POOLS["LuckHardCap"])


def avg_log_mult(p):
    """time-average over events (strongest-only)"""
    m = EVENT_NONE * log_mult(p, 1.0)
    for share, lg, _ in EVENT_SLICES:
        m += share * log_mult(p, lg)
    return m


def roll_probs_avg(p, isl):
    pr = EVENT_NONE * _rp(p, 1.0, isl)
    for share, _, lk in EVENT_SLICES:
        pr += share * _rp(p, lk, isl)
    return pr


def _rp(p, temp, isl):
    L = luck(p, temp)
    return 0.9 * roll_probs(L, isl) + 0.1 * roll_probs(min(L * POOLS["LuckyRollMult"], POOLS["LuckHardCap"]), isl)


# ---------------------------------------------------------------- tiers, gates
def island_tier_ok(p, isl):
    return ISL_ORDER.index(isl) <= p["isl_max"]


def price_tier(p):
    best = 1
    for t in P["PriceTiers"]:
        if p["best_power"] >= t["MinPower"] and ISL_ORDER.index(t["MaxIsland"]) <= p["isl_max"]:
            best = t["Tier"]
    return best


def unit(p):
    return P["PriceTiers"][price_tier(p) - 1]["Unit"]


def gate_met(p, isl):
    g = P["Gates"][isl]
    if p["best_power"] < g["Power"]:
        return False
    for r in g["Requirements"]:
        if r["Stage"] != "active":
            continue
        if r["Kind"] == "BossKills" and p["kills"].get(r["Boss"], 0) < r["Count"]:
            return False
        if r["Kind"] == "TreesInAreas" and sum(p["trees"].get(a, 0) for a in r["Areas"]) < r["Count"]:
            return False
    return True


# ---------------------------------------------------------------- players
SCEN = {
    "free":  dict(passes=set()),
    "paid":  dict(passes={"2xLogs", "2xLuck", "VIP", "BladeSlot", "FastRoll"}),
    "whale": dict(passes={"2xLogs", "2xLuck", "VIP", "BladeSlot", "FastRoll"}, megaluck=True, logboost=True),
}
# behaviour: share of time chopping, boss participation, NPC souls/h, efficiency scale
MODES = {
    "active": dict(king=0.6, treant=0.7, npc_souls=30, chop_share=0.92, eff=1.0),
    "casual": dict(king=0.3, treant=0.4, npc_souls=15, chop_share=0.95, eff=0.8),
    "afk":    dict(king=0.0, treant=0.0, npc_souls=0, chop_share=1.0, eff=1.0),
    "new":    dict(king=0.4, treant=0.4, npc_souls=20, chop_share=0.9, eff=0.75),
}


def new_player(rng, scen):
    p = dict(logs=0.0, earned=0.0, souls=0.0, crates=0, reb=0, lv={k: 0 for k in UPG},
             soul_lv={s["Id"]: 0 for s in P["SoulUpgrades"]},
             copies=np.zeros(len(ALL_IDS)), power=5.0, best_power=5.0, wlen=3.0, wid="Wooden", trait=None,
             pets=[], pets_eq=[], idx_logs=0.0, idx_luck=0.0, idx_std=set(), idx_mas=set(), tree_seen=set(), tidx=0,
             passes=set(SCEN[scen]["passes"]), rolls=0.0, soul_weapons=set(), kills={}, trees={}, isl_max=0,
             altar_rolls={i: 0.0 for i in ISL_ORDER}, guaranteed=set(), rarest=2, first={},
             eff=float(np.exp(rng.normal(0, 0.25))), logs_by={"chop": 0.0, "boss": 0.0, "other": 0.0})
    p.update({k: v for k, v in SCEN[scen].items() if k != "passes"})
    if scen in ("paid", "whale"):
        p["soul_weapons"].add("FoundersEdge"); p["crates"] += 3
    p["souls"] += 100; p["crates"] += 1; p["logs"] += P["Codes"]["TIMBER"]["Logs"]
    return p


def refresh_weapon(p):
    pw = POWER * STAR[np.minimum(np.searchsorted(CUM_FUSE, np.maximum(p["copies"] - 1, 0), side="right") - 1, 5)]
    pw = np.where(p["copies"] > 0, pw, 0)
    cand = [(5.0, "Wooden", 3.0)]
    if pw.max() > 0:
        b = int(np.argmax(pw)); cand.append((pw[b], ALL_IDS[b], LEN[b]))
    for wid in p["soul_weapons"]:
        w = C["weapons"][wid]; cand.append((w["Power"], wid, w["Length"]))
    p["power"], p["wid"], p["wlen"] = max(cand)
    p["best_power"] = max(p["best_power"], p["power"])


def allowed_areas(p):
    out = []
    for a in AREA_ORDER:
        isl = AREA_ISL[a]
        if p["power"] >= AREA[a]["RequiredPower"] and ISL_ORDER.index(isl) <= p["isl_max"]:
            out.append(a)
    return out


def area_choice(p, st, mode):
    best, rate = "StarterGrove", (0.0, 0.0)
    for a in allowed_areas(p):
        r = area_rate(st, a, "idle" if mode == "idle" else "active", p["eff"])
        if r[1] > rate[1]:
            best, rate = a, r
    return best, rate


def roll_trait(rng, souls_crate=False):
    key = "SoulWeight" if souls_crate else "Weight"
    w = np.array([t[key] for t in C["traits"]]); w = w / w.sum()
    return C["traits"][rng.choice(len(w), p=w)]


def roll_pet(rng):
    w = np.array([x["Weight"] for x in C["pets"]]); w = w / w.sum()
    return C["pets"][rng.choice(len(w), p=w)]


def equip_best_pets(p):
    slots = int(C["MaxPetsEquipped"]) + (1 if "VIP" in p["passes"] else 0)
    p["pets_eq"] = sorted(p["pets"], key=lambda x: -(x["Logs"] + 2 * x["Luck"]))[:slots]


def income(p, st=None):
    st = st or stats(p)
    a, (ts, bs) = area_choice(p, st, "active")
    return a, ts, bs * avg_log_mult(p)


def spend(p, rng):
    """A4 greedy spending policy (M1 prices)."""
    for _ in range(300):
        u = unit(p)
        crate = P["Prices"]["TraitCrate"] * u
        egg = P["Prices"]["PetEgg"] * u
        cur = p["trait"]["Mult"] if p["trait"] else 1
        if p["crates"] > 0 and cur < 3:
            p["crates"] -= 1; t = roll_trait(rng)
            if t["Mult"] > cur: p["trait"] = t
            continue
        if p["souls"] >= C["SoulCrateCost"] + 50 and cur < 2.5:
            p["souls"] -= C["SoulCrateCost"]; t = roll_trait(rng, True)
            if t["Mult"] > cur: p["trait"] = t
            continue
        if cur < 2.5 and p["logs"] >= 4 * crate:
            p["logs"] -= crate; t = roll_trait(rng)
            if t["Mult"] > cur: p["trait"] = t
            continue
        bought = False
        for wid, w in C["SoulShopWeapons"].items():
            if wid not in p["soul_weapons"] and p["souls"] >= w["SoulCost"] + 40 and w["Power"] > p["power"]:
                p["souls"] -= w["SoulCost"]; p["soul_weapons"].add(wid); refresh_weapon(p); bought = True
        if bought: continue
        for su in P["SoulUpgrades"]:
            lv = p["soul_lv"][su["Id"]]
            if lv < su["MaxLevel"] and p["souls"] >= soul_upg_cost(su, lv) + 150:
                p["souls"] -= soul_upg_cost(su, lv); p["soul_lv"][su["Id"]] += 1; bought = True
        if bought: continue
        # chop upgrades by ROI (WalkSpeed included)
        base = income(p)[2] + 1e-9
        best, best_roi, best_cost = None, 0, 0
        for uid in ("Blades", "Speed", "Damage", "Reach", "WalkSpeed"):
            lv = p["lv"][uid]
            if lv >= UPG[uid]["MaxLevel"]: continue
            cost = upg_cost(uid, lv)
            p["lv"][uid] += 1
            gain = income(p)[2] - base
            p["lv"][uid] -= 1
            # ignore upgrades that take longer than PAYBACK_H hours to pay back (players stop buying them)
            if gain > 0 and cost / gain <= PAYBACK_H * 3600 and gain / cost > best_roi:
                best, best_roi, best_cost = uid, gain / cost, cost
        lc = upg_cost("Luck", p["lv"]["Luck"]) if p["lv"]["Luck"] < UPG["Luck"]["MaxLevel"] else math.inf
        rc_ = upg_cost("Renewal", p["lv"]["Renewal"]) if p["lv"]["Renewal"] < UPG["Renewal"]["MaxLevel"] else math.inf
        if best and p["logs"] >= best_cost and (best_cost <= lc or p["logs"] >= best_cost + lc):
            p["logs"] -= best_cost; p["lv"][best] += 1; continue
        # rebirth once chop upgrades stop paying back (or Logs pile up): before luck / pets
        rc = rebirth_cost(p["reb"], p)
        if p["logs"] >= rc and (best is None or best_cost > 0.5 * rc or p["logs"] >= 3 * rc):
            p["logs"] = 0; p["reb"] += 1
            for k in UPG:
                if UPG[k]["Resets"]: p["lv"][k] = 0
            continue
        if best is None and p["logs"] < rc and p["logs"] >= 0.25 * rc and lc > 0.05 * rc:
            break  # saving up for the next rebirth
        if p["logs"] >= lc and (best is None or lc <= 0.5 * best_cost):
            p["logs"] -= lc; p["lv"]["Luck"] += 1; continue
        if p["logs"] >= 3 * rc_ and best is None:
            p["logs"] -= rc_; p["lv"]["Renewal"] += 1; continue
        pet_bonus = sum(x["Logs"] for x in p["pets_eq"])
        if p["logs"] >= 5 * egg and pet_bonus < 6 and p["logs"] - egg >= 0.5 * rebirth_cost(p["reb"], p):
            p["logs"] -= egg; p["pets"].append(roll_pet(rng)); equip_best_pets(p); continue
        break


def boss_scale(p):
    """boss Logs grow with permanent progress (base LogMult, no temp boosts), dampened"""
    return log_mult(p, 1.0) ** P["Bosses"].get("LogMultExponent", 0)


def rebirth_cost(n, p=None):
    r = P["Rebirth"]; u = unit(p) if p else P["PriceTiers"][1]["Unit"]
    return max(r["MinCost"], math.floor(r["Units"] * r["Growth"] ** n * u))


def update_index(p):
    # weapon index editions: Standard (<= Mythic) and Mastery (Secret/Divine); sticky.
    # M2: edition 1 = the M1 sets, edition 2 = the expansion weapons (bonus x EditionScale[2])
    for a in AREA_ORDER:
        update_edition(p, a, [i for i in INDEX_WEAPONS[a] if int(C["weapons"][i].get("Edition", 1)) == 1], "")
        update_edition(p, a, [i for i in INDEX_WEAPONS[a] if int(C["weapons"][i].get("Edition", 1)) == 2], "#2")
    I = P["Index"]
    es2 = I.get("EditionScale", [1, 0.5])[1]
    def w(k): return es2 if k.endswith("#2") else 1.0
    full = sum(w(k) for k in p["idx_std"] if k.startswith("FrostPeaks") and not k.endswith("#2"))
    sl = sum(w(k) for k in p["idx_std"]); ml = sum(w(k) for k in p["idx_mas"])
    p["idx_luck"] = sl * I["WeaponStandard"]["Luck"] + (ml + full) * I["WeaponMastery"]["Luck"]
    p["idx_logs"] = sl * I["WeaponStandard"]["Logs"] + (ml + full) * I["WeaponMastery"]["Logs"] + p["tidx"] * I["Tree"]["Logs"]


def update_edition(p, a, ids, tag):
    if not ids:
        return
    if True:
        std = [i for i in ids if C["weapons"][i]["Rarity"] not in ("Secret", "Divine")]
        mas = [i for i in ids if C["weapons"][i]["Rarity"] in ("Secret", "Divine")]
        if not std:  # Frost Peaks: its Divines are the standard set, worth Standard + Mastery
            std, mas = mas, []
        def owned(i): return i == "Wooden" or (i in WIDX and p["copies"][WIDX[i]] > 0)
        k = a + tag
        if std and k not in p["idx_std"] and all(owned(i) for i in std): p["idx_std"].add(k)
        if mas and k not in p["idx_mas"] and all(owned(i) for i in mas): p["idx_mas"].add(k)


RARE_TIERS = ("Legendary", "Mythic", "Secret", "Divine")
PAYBACK_H = 2.0  # A4: an upgrade is bought only if it pays back within this many hours of chopping


def simulate(scen, mode, hours, n_agents=40, seed=1, checkpoints=(0.5, 2, 8, 24, 72, 200)):
    rng = np.random.default_rng(seed)
    M = MODES[mode]
    out = {h: [] for h in checkpoints if h <= hours}
    for _ in range(n_agents):
        p = new_player(rng, scen)
        p["eff"] *= M["eff"]
        refresh_weapon(p)
        t, cps, last_daily, next_treant, next_king = 0.0, list(out.keys()), -1e9, 300.0, 120.0
        roll_int = (C["FastRollInterval"] if "FastRoll" in p["passes"] else C["AutoRollInterval"])
        while cps:
            dt = 30.0 if t < 7200 else (120.0 if t < 86400 else 300.0)
            st = stats(p)
            area, ts, inc = income(p, st)
            isl = AREA_ISL[area]
            u = unit(p)
            chop = inc * M["chop_share"] * dt
            gain = chop
            p["logs_by"]["chop"] += chop
            n_trees = ts * M["chop_share"] * dt
            p["trees"][area] = p["trees"].get(area, 0) + n_trees
            # tree index (sticky)
            elig = [x for x in TREES_BY_AREA[area] if p["power"] >= x["Strength"]]
            wtot = sum(y["Weight"] for y in TREES_BY_AREA[area])
            for x in elig:
                if x["Id"] not in p["tree_seen"] and rng.random() < 1 - (1 - x["Weight"] / wtot) ** n_trees:
                    p["tree_seen"].add(x["Id"])
            p["tidx"] = sum(all(x["Id"] in p["tree_seen"] for x in TREES_BY_AREA[a_]) for a_ in AREA_ORDER)
            # rolls at the island altar (auto-roll in every mode)
            n_rolls = dt / roll_int
            isl = ISL_ORDER[p["isl_max"]]  # altar = highest unlocked island (AltarRule)
            pr = roll_probs_avg(p, isl)
            hits = rng.poisson(n_rolls * pr)
            p["altar_rolls"][isl] += n_rolls
            g = P["Altars"][isl]["Guarantee"]
            if g and isl not in p["guaranteed"] and p["best_power"] < g["UntilPower"] and p["altar_rolls"][isl] >= g["Rolls"]:
                hits[WIDX[g["Weapon"]]] += 1; p["guaranteed"].add(isl)
            if hits.any():
                p["copies"] += hits
                for i in np.nonzero(hits)[0]:
                    r = ROLLABLE[ALL_IDS[i]]["Rarity"]
                    if r in RARE_TIERS and r not in p["first"]:
                        p["first"][r] = t / 3600
                p["rarest"] = max(p["rarest"], float(ONEIN[hits > 0].max()))
                update_index(p)
                refresh_weapon(p)
            else:
                update_index(p)
            p["rolls"] += n_rolls
            # bosses + NPC souls (activity-specific rewards)
            p["souls"] += M["npc_souls"] * dt / 3600
            if t >= next_king:
                next_king += 240
                if rng.random() < M["king"] and p["power"] >= 40:
                    b = P["Bosses"]["BladeKing"]; r = b["LogsUnits"] * u * boss_scale(p)
                    gain += r; p["logs_by"]["boss"] += r; p["souls"] += b["Souls"]
                    p["kills"]["BladeKing"] = p["kills"].get("BladeKing", 0) + 1
            if t >= next_treant:
                next_treant += C["WorldBoss"]["Every"]
                if rng.random() < M["treant"]:
                    b = P["Bosses"]["Treant"]; r = b["LogsUnits"] * u * boss_scale(p)
                    gain += r; p["logs_by"]["boss"] += r; p["souls"] += b["Souls"] + 20; p["crates"] += b["Crates"]
            if "VIP" in p["passes"] and t - p.get("_vip", -1e9) >= C["VIPDailyCrateHours"] * 3600:
                p["_vip"] = t; p["crates"] += 1
            if t - last_daily >= 4 * 3600:  # A6 daily login + quests (claimed on return also for AFK)
                last_daily = t
                r = 2 * u
                p["souls"] += 80; p["crates"] += 1; gain += r; p["logs_by"]["other"] += r
            # gates: AFK players return briefly to kill the King once when it is the only missing step (assumption A7)
            for i_, isl_ in enumerate(ISL_ORDER[1:], start=1):
                if p["isl_max"] == i_ - 1:
                    if mode == "afk" and p["kills"].get("BladeKing", 0) == 0:
                        gp = dict(p); gp["kills"] = {"BladeKing": 1}
                        if gate_met(gp, isl_): p["kills"]["BladeKing"] = 1
                    if gate_met(p, isl_):
                        p["isl_max"] = i_; p["t_" + isl_] = t / 3600
            for a_ in AREA_ORDER:
                if a_ in allowed_areas(p) and ("ta_" + a_) not in p:
                    p["ta_" + a_] = t / 3600
            p["logs"] += gain; p["earned"] += gain
            spend(p, rng)
            t += dt
            while cps and t >= cps[0] * 3600:
                h = cps.pop(0)
                st = stats(p)
                ar, ts_, inc_ = income(p, st)
                out[h].append(dict(
                    earned=p["earned"], income=inc_ * 3600, power=p["power"], weapon=p["wid"], area=ar, reb=p["reb"],
                    logmult=avg_log_mult(p), luck=luck(p), blades=st["blades"], walk=st["walk"],
                    lv=dict(p["lv"]), trait=p["trait"]["Id"] if p["trait"] else "-", pets=sum(x["Logs"] for x in p["pets_eq"]),
                    rolls=p["rolls"], rarest=p["rarest"], souls=p["souls"], souls_earned_h=0, trees_s=ts_,
                    t_cw=p.get("t_CrystalWilds", 1e9), t_fr=p.get("t_FrostboundReach", 1e9),
                    t_pine=p.get("ta_PineForest", 1e9), first=dict(p["first"]), tier=price_tier(p), unit=unit(p),
                    logs_by=dict(p["logs_by"]), soul_lv=dict(p["soul_lv"]), idx=len(p["idx_std"]), tidx=p["tidx"]))
    return out


def pct(v, q):
    return float(np.percentile(v, q))


def summarize(out):
    rows = []
    for h, lst in out.items():
        if not lst: continue
        def tri(k, f=None): return [pct([(f(x) if f else x[k]) for x in lst], q) for q in (10, 50, 90)]
        areas = {}
        for x in lst: areas[x["area"]] = areas.get(x["area"], 0) + 1 / len(lst)
        firsts = {r: tri(None, lambda x, r=r: x["first"].get(r, 1e9)) for r in RARE_TIERS}
        rows.append(dict(h=h, earned=tri("earned"), income=tri("income"), power=tri("power"), reb=tri("reb"),
                         logmult=tri("logmult"), luck=tri("luck"), souls=tri("souls"), walk=tri("walk"),
                         t_cw=tri("t_cw"), t_fr=tri("t_fr"), t_pine=tri("t_pine"), tier=tri("tier"), unit=tri("unit"),
                         first=firsts, area_mix=areas, trees_s=tri("trees_s"), idx=tri("idx"), tidx=tri("tidx"),
                         boss_share=tri(None, lambda x: x["logs_by"]["boss"] / max(x["earned"], 1)),
                         lv={k: tri(None, lambda x, k=k: x["lv"][k]) for k in UPG},
                         soul_lv={k: tri(None, lambda x, k=k: x["soul_lv"][k]) for k in x_keys(lst)}))
    return rows


def x_keys(lst):
    return list(lst[0]["soul_lv"].keys())


if __name__ == "__main__":
    scen = sys.argv[1] if len(sys.argv) > 1 else "free"
    mode = sys.argv[2] if len(sys.argv) > 2 else "active"
    hours = float(sys.argv[3]) if len(sys.argv) > 3 else 24
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 40
    res = summarize(simulate(scen, mode, hours, n))
    os.makedirs(os.path.join(HERE, "results", "m1"), exist_ok=True)
    json.dump(res, open(os.path.join(HERE, "results", "m1", f"res_{scen}_{mode}.json"), "w"), indent=1, default=float)
    for r in res:
        print(f"{r['h']:>5}h earned {r['earned'][1]:.3g} inc/h {r['income'][1]:.3g} pow {r['power'][1]:.0f} reb {r['reb'][1]:.0f}"
              f" lm {r['logmult'][1]:.1f} luck {r['luck'][1]:.1f} tier {r['tier'][1]:.0f} walk {r['walk'][1]:.1f}"
              f" tCW {r['t_cw'][1]:.2f} tFR {r['t_fr'][1]:.2f} boss {r['boss_share'][1]:.2f} souls {r['souls'][1]:.0f}"
              f" mix {{{', '.join(f'{k[:5]}:{v:.2f}' for k, v in r['area_mix'].items())}}}")
