"""Blade Forest economy simulator (read-only audit, 2026-11-20).

Formulas taken from the real game code (cited as file:line in the report):
  * damage per hit = Power x StarMult x Shiny x (1 + 0.1*Damage) x (rawSpeed / min(rawSpeed, 5.5))   BladeConfig.GetStats
  * a blade hits a given tree once per revolution (0.4 s per-blade cooldown < revolution time)       CombatServer.processWielder
  * weak damage x0.1 when Power < tree Strength                                                     CombatServer:515
  * reward = tree Logs x mutation LogMult x LogMult x EventLogs; last hitter gets it all              CombatServer:368, DataService.AddCoins
  * tree respawns after Respawn s with a freshly weighted type + mutation roll                        CombatServer.respawnLater, TreeKit
  * free rolls; weapon w hits with chance luck/OneIn (OneIn>10), rarest first, every 10th roll x2    BladeConfig.RollWeapon, RollService
  * LogMult / Luck stacking exactly as DataService.RecalcMultipliers
  * upgrade cost = BaseCost x CostMult^level; rebirth = 1e6 x 3^n, resets Logs + upgrades            BladeConfig, MetaService
MODEL ASSUMPTIONS (not in code; labelled in the report):
  A1 forest density (trees per stud^2): Crystal Wilds dense zones 1/31 (P1b.2r measured NN ~5.2 studs);
     other areas 1/150 (estimate for the original map, 5,021 breakables).
  A2 AutoChop: walking 16 studs/s, blades sweep a band 2*outer wide, 70% of trees alive; harmonic
     combination of encounter-limited and kill-time-limited rates.
  A3 behaviour: Active = AutoChop + auto-roll + Treant 50% + NPC souls 30/h + claims;
     AFK = AutoChop + auto-roll, no Treant/NPC/gifts; Idle = standing still (no AutoChop).
  A4 spending policy: greedy ROI on chop upgrades, Luck when cheap, trait crates/eggs when affordable
     with margin, rebirth when Logs >= cost and (upgrades maxed or Logs >= 3x cost).
  A5 per-player efficiency factor ~ lognormal(0, 0.25) on chop income (route/skill/server crowding).
  A6 long horizons: 1 daily login + daily quests per 4 played hours.
"""
import math, sys, json, os
import numpy as np
from bf_config import load

C = load()
TAU = 2 * math.pi
AREA_ORDER = [a["Id"] for a in C["areas"]]
AREA = {a["Id"]: a for a in C["areas"]}
DENSITY = {"StarterGrove": 1 / 150, "PineForest": 1 / 150, "CrystalCanyon": 1 / 31, "FrostPeaks": 1 / 150}

# --- mutations: expected LogMult and HealthMult (rolled rarest first) ---
def _mut_expect():
    p_none, e_log, e_hp = 1.0, 0.0, 0.0
    for m in reversed(C["mutations"]):
        p = p_none * (1 / m["OneIn"])
        e_log += p * m["LogMult"]; e_hp += p * m["HealthMult"]
        p_none -= p
    return e_log + p_none, e_hp + p_none
MUT_LOG, MUT_HP = _mut_expect()

TREES_BY_AREA = {a: [t for t in C["trees"].values() if t["Area"] == a] for a in AREA_ORDER}

# --- events: time-averaged multipliers ---
def _event_avg():
    tw = sum(e["Weight"] for e in C["events"])
    dur = sum(e["Weight"] / tw * e["Seconds"] for e in C["events"])
    gap = sum(C["EventGap"]) / 2
    extra_logs = sum(e["Weight"] / tw * e["Seconds"] * (e["Logs"] - 1) for e in C["events"])
    extra_luck = sum(e["Weight"] / tw * e["Seconds"] * (e["Luck"] - 1) for e in C["events"])
    cyc = gap + dur
    return 1 + extra_logs / cyc, 1 + extra_luck / cyc
EVENT_LOGS, EVENT_LUCK = _event_avg()

# --- weapons for rolling (rarest first, as Config.RollPool) ---
ROLL = sorted([w for w in C["weapons"].values() if w.get("OneIn") and not w.get("Exclusive") and w["Id"] != "Wooden"],
              key=lambda w: -w["OneIn"])
ROLL_ONEIN = np.array([w["OneIn"] for w in ROLL])
ROLL_IDS = [w["Id"] for w in ROLL]
WIDX = {w: i for i, w in enumerate(ROLL_IDS)}
ROLL_POWER = np.array([w["Power"] for w in ROLL], dtype=float)
ROLL_LEN = np.array([w["Length"] for w in ROLL])
CUM_FUSE = np.cumsum([0] + C["FuseCost"])  # copies needed for star s (spares beyond the first)
STAR = np.array(C["StarMult"])
AREA_WEAPONS = {a: [w["Id"] for w in C["weapons"].values() if w["Area"] == a and not w.get("Exclusive")] for a in AREA_ORDER}


def roll_probs(luck):
    """per-roll probability of each weapon in ROLL order (exact sequential formula)."""
    eff = np.where(ROLL_ONEIN <= 10, ROLL_ONEIN, np.maximum(ROLL_ONEIN / max(luck, 1), 1))
    p_hit = 1 / eff
    survive = np.concatenate([[1.0], np.cumprod(1 - p_hit)[:-1]])
    return p_hit * survive


def upg_cost(uid, lvl):
    u = C["upgrades"][uid]
    return math.floor(u["BaseCost"] * u["CostMult"] ** lvl)


def stats(p):
    """blade stats from a player dict, as BladeConfig.GetStats."""
    L = p["lv"]
    raw_speed = 3 + 0.15 * L["Speed"]
    speed = min(raw_speed, C["MaxSpinSpeed"])
    dmg_mult = (1 + 0.1 * L["Damage"]) * raw_speed / speed
    blades = 1 + L["Blades"] + (1 if "BladeSlot" in p["passes"] else 0)
    reach = 4 + 0.2 * L["Reach"]
    size = 1 + C["BladeSizePerReach"] * L["Reach"]
    return dict(power=p["power"], dmg=p["power"] * dmg_mult, blades=blades, speed=speed,
                reach=reach, length=p["wlen"] * size, slack=C["BladeHitRadius"] * size)


def area_rate(st, area, mode, eff=1.0):
    """(trees/s, base logs/s before LogMult) in an area for a mode: 'active' (AutoChop) or 'idle'."""
    outer = st["reach"] - 0.5 + st["length"] + st["slack"]
    inner = max(st["reach"] - 0.5 - st["slack"], 0)
    slots = DENSITY[area] * math.pi * (outer ** 2 - inner ** 2)
    hit_rate = st["blades"] * st["speed"] / TAU  # hits per second on each tree in reach
    num = den = wsum = 0.0
    for t in TREES_BY_AREA[area]:
        weak = st["power"] < t["Strength"]
        if mode == "active" and weak:
            continue  # AutoChop.pickTarget skips trees above your Power
        dmg = st["dmg"] * (C["WeakDamageMult"] if weak else 1)
        kill = math.ceil(t["Health"] * MUT_HP / dmg) / hit_rate
        w = t["Weight"]
        if mode == "idle":
            den += w * (kill + t["Respawn"])
        else:
            den += w * kill
        num += w * t["Logs"] * MUT_LOG
        wsum += w
    if wsum == 0:
        return 0.0, 0.0
    logs_per_tree = num / wsum
    if mode == "idle":
        trees = slots * wsum / den
    else:
        encounter = DENSITY[area] * 16 * 2 * outer * 0.7          # A2
        kill_avg = den / wsum
        trees = 1 / (1 / encounter + kill_avg / max(slots, 0.3))
    return trees * eff, trees * logs_per_tree * eff


def log_mult(p, pvp=False):
    m = 1.0
    t = p["trait"]
    m *= t["Mult"] if t else 1
    if "2xLogs" in p["passes"]: m *= 2
    if "VIP" in p["passes"]: m *= 1.1
    if p.get("logboost"): m *= 2
    m *= 1 + C["Rebirth"]["LogsPer"] * p["reb"]
    if pvp: m *= C["PvP"]["LogMult"]
    m *= 1 + sum(x["Logs"] for x in p["pets_eq"])
    m *= 1 + p["idx_done"] * C["IndexBonus"]["Logs"]
    m *= 1 + p["tidx_done"] * C["TreeIndexBonus"]["Logs"]
    return m


def luck(p):
    m = 1 + 0.05 * p["lv"]["Luck"]
    if "2xLuck" in p["passes"]: m *= 2
    if p.get("megaluck"): m *= 10
    m *= 1 + C["Rebirth"]["LuckPer"] * p["reb"]
    m *= C["GroupLuck"]
    m *= 1 + sum(x["Luck"] for x in p["pets_eq"])
    m *= 1 + p["idx_done"] * C["IndexBonus"]["Luck"]
    return m


def new_player(rng, scenario):
    p = dict(logs=0.0, earned=0.0, souls=0.0, crates=0, reb=0, lv={k: 0 for k in C["upgrades"]},
             copies=np.zeros(len(ROLL)), stars=np.zeros(len(ROLL)), shiny=np.zeros(len(ROLL), bool),
             power=5.0, wlen=3.0, wid="Wooden", trait=None, pets=[], pets_eq=[], idx_done=0, tidx_done=0,
             tree_seen=set(), best_area="StarterGrove", passes=set(), rolls=0, soul_weapons=set(),
             eff=float(np.exp(rng.normal(0, 0.25))), robux=0, rarest=2)
    if scenario in ("paid", "whale"):
        p["passes"] = {"2xLogs", "2xLuck", "VIP", "BladeSlot", "FastRoll"}
        p["robux"] = sum(x["Price"] for x in C["passes"] if x["Id"] in p["passes"]) + 99  # + Starter Pack
        p["soul_weapons"].add("FoundersEdge")
        p["crates"] += 3
    if scenario == "whale":
        p["megaluck"] = True; p["logboost"] = True
    # codes at start: RELEASE (100 souls, 1 crate), TIMBER (10 x crate cost)
    p["souls"] += 100; p["crates"] += 1; p["logs"] += 10 * C["TraitCrateCost"]["StarterGrove"]
    return p


def refresh_weapon(p):
    pw = ROLL_POWER * STAR[p["stars"].astype(int)] * np.where(p["shiny"], C["ShinyMult"], 1)
    pw = np.where(p["copies"] > 0, pw, 0)
    best = int(np.argmax(pw))
    cand = [(pw[best], ROLL_IDS[best], ROLL_LEN[best])] if pw[best] > 0 else []
    for wid in p["soul_weapons"]:
        w = C["weapons"][wid]
        cand.append((w["Power"], wid, w["Length"]))
    cand.append((5.0, "Wooden", 3.0))
    pw_, wid, ln = max(cand)
    p["power"], p["wid"], p["wlen"] = pw_, wid, ln


def area_choice(p, st, mode):
    best, best_rate = "StarterGrove", (0, 0)
    for a in AREA_ORDER:
        if p["power"] >= AREA[a]["RequiredPower"]:
            r = area_rate(st, a, mode, p["eff"])
            if r[1] > best_rate[1]:
                best, best_rate = a, r
    return best, best_rate


def crate_cost(p):
    return C["TraitCrateCost"][p["best_area"]]


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


def spend(p, rng, st_fn):
    """A4 greedy spending policy."""
    for _ in range(200):
        bought = False
        cc = crate_cost(p)
        # trait: free crates first, then Souls crate, then Logs crate while trait < 2.5
        cur = p["trait"]["Mult"] if p["trait"] else 1
        if p["crates"] > 0 and cur < 3:
            p["crates"] -= 1; t = roll_trait(rng)
            if t["Mult"] > cur: p["trait"] = t
            bought = True; continue
        if p["souls"] >= C["SoulCrateCost"] + 50 and cur < 2.5:
            p["souls"] -= C["SoulCrateCost"]; t = roll_trait(rng, True)
            if t["Mult"] > cur: p["trait"] = t
            bought = True; continue
        if cur < 2.5 and p["logs"] >= 4 * cc:
            p["logs"] -= cc; t = roll_trait(rng)
            if t["Mult"] > cur: p["trait"] = t
            bought = True; continue
        # soul shop weapons
        for wid, w in C["SoulShopWeapons"].items():
            if wid not in p["soul_weapons"] and p["souls"] >= w["SoulCost"] + 40 and w["Power"] > p["power"]:
                p["souls"] -= w["SoulCost"]; p["soul_weapons"].add(wid); refresh_weapon(p); bought = True
        # chop upgrades by ROI
        st = st_fn(p)
        mode = p["_mode"]
        base = area_choice(p, st, mode)[1][1] * log_mult(p) + 1e-9
        best, best_roi, best_cost = None, 0, 0
        for uid in ("Blades", "Speed", "Damage", "Reach"):
            lvl = p["lv"][uid]
            if lvl >= C["upgrades"][uid]["MaxLevel"]:
                continue
            cost = upg_cost(uid, lvl)
            p["lv"][uid] += 1
            gain = area_choice(p, st_fn(p), mode)[1][1] * log_mult(p) - base
            p["lv"][uid] -= 1
            roi = gain / cost
            if roi > best_roi:
                best, best_roi, best_cost = uid, roi, cost
        lc = upg_cost("Luck", p["lv"]["Luck"]) if p["lv"]["Luck"] < 100 else math.inf
        if best and p["logs"] >= best_cost and (best_cost <= lc or p["logs"] >= best_cost + lc):
            p["logs"] -= best_cost; p["lv"][best] += 1; bought = True; continue
        if p["logs"] >= lc and (best is None or lc <= 0.5 * best_cost):
            p["logs"] -= lc; p["lv"]["Luck"] += 1; bought = True; continue
        # pets
        egg = C["TraitCrateCost"][p["best_area"]] * C["PetEggMult"]
        pet_bonus = sum(x["Logs"] for x in p["pets_eq"])
        if p["logs"] >= 5 * egg and pet_bonus < 6 and p["logs"] > 0.2 * max(best_cost, 1):
            p["logs"] -= egg; p["pets"].append(roll_pet(rng)); equip_best_pets(p); bought = True; continue
        # rebirth
        rc = C["Rebirth"]["BaseCost"] * C["Rebirth"]["CostMult"] ** p["reb"]
        maxed = all(p["lv"][u] >= C["upgrades"][u]["MaxLevel"] for u in ("Blades", "Speed", "Damage", "Reach"))
        if p["logs"] >= rc and (maxed or p["logs"] >= 3 * rc):
            p["logs"] = 0; p["reb"] += 1
            for u in p["lv"]: p["lv"][u] = 0
            bought = True; continue
        if not bought:
            break


def simulate(scenario, mode, hours, n_agents=150, seed=1, checkpoints=(0.5, 2, 8, 24, 72, 200)):
    rng = np.random.default_rng(seed)
    out = {h: [] for h in checkpoints if h <= hours}
    for a in range(n_agents):
        p = new_player(rng, scenario)
        p["_mode"] = "idle" if mode == "idle" else "active"
        refresh_weapon(p)
        t, cps, last_daily, next_treant = 0.0, list(out.keys()), 0.0, 300.0
        roll_int = (C["FastRollInterval"] / 0.85 if "FastRoll" in p["passes"] else C["AutoRollInterval"])
        while cps:
            dt = 30.0 if t < 7200 else (120.0 if t < 86400 else 300.0)
            st = stats(p)
            area, (trees_s, base_s) = area_choice(p, st, p["_mode"])
            lm = log_mult(p) * EVENT_LOGS
            gain = base_s * lm * dt
            # tree index: sample which types were chopped
            n_trees = trees_s * dt
            if n_trees > 0:
                elig = [x for x in TREES_BY_AREA[area] if p["_mode"] == "idle" or p["power"] >= x["Strength"]]
                for x in elig:
                    pr = x["Weight"] / sum(y["Weight"] for y in TREES_BY_AREA[area])
                    if x["Id"] not in p["tree_seen"] and rng.random() < 1 - (1 - pr) ** n_trees:
                        p["tree_seen"].add(x["Id"])
                p["tidx_done"] = sum(all(x["Id"] in p["tree_seen"] for x in TREES_BY_AREA[ar]) for ar in AREA_ORDER)
            if AREA_ORDER.index(area) > AREA_ORDER.index(p["best_area"]):
                p["best_area"] = area
            for a_ in AREA_ORDER:
                if p["power"] >= AREA[a_]["RequiredPower"] and ("t_" + a_) not in p:
                    p["t_" + a_] = t / 3600
            # rolls (auto-roll on in every mode)
            n_rolls = dt / roll_int
            L = luck(p) * EVENT_LUCK
            pr = 0.9 * roll_probs(L) + 0.1 * roll_probs(2 * L)
            hits = rng.poisson(n_rolls * pr)
            if hits.any():
                p["copies"] += hits
                spare = np.maximum(p["copies"] - 1, 0)
                p["stars"] = np.searchsorted(CUM_FUSE, spare, side="right") - 1
                p["stars"] = np.minimum(p["stars"], 5)
                p["shiny"] |= (p["stars"] >= 5) & (spare >= CUM_FUSE[5] + C["ShinyCopies"])
                p["rarest"] = max(p["rarest"], float(ROLL_ONEIN[hits > 0].max()))
                done = 0
                for ar in AREA_ORDER:
                    ids = AREA_WEAPONS[ar]
                    if ids and all(p["copies"][WIDX[i]] > 0 for i in ids if i in WIDX):
                        done += 1
                p["idx_done"] = done
                refresh_weapon(p)
            p["rolls"] += n_rolls
            # extras
            if mode == "active":
                p["souls"] += 30 * dt / 3600  # A3 NPC kills
                if t >= next_treant:
                    next_treant += C["WorldBoss"]["Every"]
                    if rng.random() < 0.5:
                        p["souls"] += 60; p["crates"] += 1
                        gain += crate_cost(p) * C["WorldBoss"]["LogsMult"]
            if "VIP" in p["passes"] and t - p.get("_vip", -1e9) >= C["VIPDailyCrateHours"] * 3600:
                p["_vip"] = t; p["crates"] += 1
            if t - last_daily >= 4 * 3600 or t == 0:  # A6 daily login + quests
                last_daily = t
                p["souls"] += 80; p["crates"] += 1; gain += 2 * crate_cost(p)
            p["logs"] += gain; p["earned"] += gain
            spend(p, rng, stats)
            t += dt
            while cps and t >= cps[0] * 3600:
                h = cps.pop(0)
                st = stats(p)
                ar, (ts, bs) = area_choice(p, st, p["_mode"])
                out[h].append(dict(earned=p["earned"], income=bs * log_mult(p) * EVENT_LOGS * 3600, power=p["power"],
                                   weapon=p["wid"], area=ar, reb=p["reb"], logmult=log_mult(p), luck=luck(p),
                                   blades=st["blades"], dmg=p["lv"]["Damage"], speed=p["lv"]["Speed"], reach=p["lv"]["Reach"],
                                   luck_lv=p["lv"]["Luck"], trait=p["trait"]["Id"] if p["trait"] else "-",
                                   pets=sum(x["Logs"] for x in p["pets_eq"]), rolls=p["rolls"], rarest=p["rarest"],
                                   idx=p["idx_done"], tidx=p["tidx_done"], souls=p["souls"], trees_s=ts,
                                   t_pine=p.get("t_PineForest", 1e9), t_crystal=p.get("t_CrystalCanyon", 1e9), t_frost=p.get("t_FrostPeaks", 1e9),
                                   robux=p["robux"]))
    return out


def pct(vals, q):
    return float(np.percentile(vals, q))


def summarize(out):
    rows = []
    for h, lst in out.items():
        if not lst: continue
        def tri(k): return [pct([x[k] for x in lst], q) for q in (10, 50, 90)]
        areas = {}
        for x in lst: areas[x["area"]] = areas.get(x["area"], 0) + 1
        rows.append(dict(h=h, earned=tri("earned"), income=tri("income"), power=tri("power"), reb=tri("reb"),
                         logmult=tri("logmult"), luck=tri("luck"), rolls=tri("rolls"), rarest=tri("rarest"),
                         blades=tri("blades"), dmg=tri("dmg"), area_mix={k: v / len(lst) for k, v in areas.items()},
                         tidx=tri("tidx"), idx=tri("idx"), pets=tri("pets"), souls=tri("souls"),
                         t_pine=tri("t_pine"), t_crystal=tri("t_crystal"), t_frost=tri("t_frost"), trees_s=tri("trees_s"),
                         luck_lv=tri("luck_lv"), speed=tri("speed"), reach=tri("reach"),
                         trait=max(set(x["trait"] for x in lst), key=[x["trait"] for x in lst].count)))
    return rows


if __name__ == "__main__":
    print(f"mutation E[LogMult]={MUT_LOG:.4f} E[HealthMult]={MUT_HP:.4f}; event avg Logs x{EVENT_LOGS:.4f} Luck x{EVENT_LUCK:.4f}")
    scen = sys.argv[1] if len(sys.argv) > 1 else "free"
    mode = sys.argv[2] if len(sys.argv) > 2 else "active"
    hours = float(sys.argv[3]) if len(sys.argv) > 3 else 24
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 60
    res = summarize(simulate(scen, mode, hours, n))
    json.dump(res, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "results", f"res_{scen}_{mode}.json"), "w"), indent=1, default=float)
    for r in res:
        print(r["h"], "earned", [f"{v:.3g}" for v in r["earned"]], "inc/h", [f"{v:.3g}" for v in r["income"]],
              "pow", [f"{v:.0f}" for v in r["power"]], "reb", r["reb"], "area", r["area_mix"], "trait", r["trait"])
