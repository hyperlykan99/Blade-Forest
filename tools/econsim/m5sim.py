"""Paired M4/M5 projections using the existing M1 simulator and the current catalog.

An assumption model, not live telemetry. Uses v2 forest density in both arms,
plays four hours/calendar day (eight for unattended AFK) and records both
currency injections and time displaced by Trials/Expeditions.
"""
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import argparse
import json
import math
import re
from statistics import median

import m1sim as base

DESIGN = Path(__file__).resolve().parents[2] / "src/shared/M5Design.luau"
SOURCE = DESIGN.read_text()
LIMIT = re.search(r"TokenCap=(\d+)", SOURCE)
TOKEN_CAP = int(LIMIT[1])
DEPTH_CAP = int(re.search(r"RewardClaimsPerDay=(\d+)", SOURCE)[1])
SLOT = int(re.search(r"M\.EventSlot=(\d+)", SOURCE)[1])
DELAY = int(re.search(r"M\.EventDelay=(\d+)", SOURCE)[1])
EVENTS = [
    (island or "rotation", int(duration), float(logs), float(luck))
    for island, duration, logs, luck in re.findall(
        r'Name="[^"]+"(?:,Island="([^"]+)")?,Duration=(\d+),Logs=([\d.]+),Luck=([\d.]+)', SOURCE
    )
]
CONTRACTS = [
    [(float(logs), int(souls)) for logs, souls in re.findall(r"\},([.\d]+),(\d+)\}", block)]
    for block in SOURCE.split("M.ContractCatalog=", 1)[1].split("M.ContractOrder", 1)[0].split("\tWeekly={")
]
assert len(EVENTS) == 3 and list(map(len, CONTRACTS)) == [9, 7]
START_OFFSET = 1734560000


def use_v2():
    base.DENSITY.update(StarterGrove=1/65, PineForest=1/63, FrostPeaks=1/58)
    for tree in base.TREES_BY_AREA["FrostPeaks"]:
        tree["Logs"] = math.floor(tree["Logs"] * 1.35)
    for row in base.P["Gates"]["FrostboundReach"]["Requirements"]:
        if row["Id"] == "colossus":
            row["Stage"] = "active"


class Projection:
    def __init__(self, enabled):
        self.enabled = enabled

    def begin(self, p, mode, seed, agent):
        p["m5"] = {"mode": mode, "rng": base.np.random.default_rng(seed * 103 + agent),
                   "day": -1, "week": -1, "colossus_check": 0, "tokens": 0, "token_earned": 0,
                   "depth": 0, "frontier": 0, "materials": 0, "shop": [0, 0, 0],
                   "next_contract": math.inf, "pending": (0, 0), "chain": 0,
                   "delta": dict(contracts=0.0, trials=0.0, expedition=0.0, events=0.0, story=0.0),
                   "souls": 0.0}

    def event(self, t, island):
        now = START_OFFSET + t
        index = int(now // SLOT)
        region, duration, logs, luck = EVENTS[index % 3]
        if region == "rotation":
            region = base.ISL_ORDER[(index // 3) % 3]
        if region == island and DELAY <= now % SLOT < DELAY + duration:
            return logs, luck
        return 1.0, 1.0

    def chop_delta(self, p, area, chop, t, dt):
        if not self.enabled:
            return 0.0
        island = base.AREA_ISL[area]
        regional_logs, _ = self.event(t, island)
        shifted = base.EVENT_NONE * base.log_mult(p, regional_logs)
        shifted += sum(share * base.log_mult(p, max(g, regional_logs)) for share, g, _ in base.EVENT_SLICES)
        gains = chop * (shifted / max(1, base.avg_log_mult(p)) - 1)
        p["m5"]["delta"]["events"] += gains
        return gains

    def altar_probs(self, p, island, t):
        if not self.enabled:
            return base.roll_probs_avg(p, island)
        _, regional_luck = self.event(t, island)
        out = base.EVENT_NONE * base._rp(p, regional_luck, island)
        for share, _, luck in base.EVENT_SLICES:
            out += share * base._rp(p, max(luck, regional_luck), island)
        return out

    def rewards(self, p, t, dt, trees_per_second, unit, income_rate=None):
        s = p["m5"]
        rng = s["rng"]
        afk = s["mode"] == "afk"
        if income_rate is None and p["isl_max"] >= 1 and t >= s["colossus_check"] and not p["kills"].get("CrystalColossus"):
            s["colossus_check"] = t + 1800
            if p["power"] >= 400 and rng.random() < (.15 if afk else .65):
                p["kills"]["CrystalColossus"] = 1
                p["copies"][base.WIDX["Umbraxe"]] = max(1, p["copies"][base.WIDX["Umbraxe"]])
                base.refresh_weapon(p)
        if not self.enabled:
            return 0.0

        earned = 0.0

        def grant(kind, logs, souls=0):
            nonlocal earned
            logs *= unit
            earned += logs
            s["delta"][kind] += logs
            s["souls"] += souls
            p["souls"] += souls

        played_day = (8 if afk else 4) * 3600
        day = int(t // played_day)
        if day != s["day"]:
            s["day"] = day
            if day // 7 != s["week"]:
                s["week"] = day // 7
                s["shop"] = [0, 0, 0]
                s["frontier"] = 0
            completed = 1 if afk else (3 if rng.random() < .80 else 2)
            daily = rng.choice(len(CONTRACTS[0]), completed, replace=False)
            logs = sum(CONTRACTS[0][i][0] for i in daily) + (.35 if completed == 3 else 0)
            souls = sum(CONTRACTS[0][i][1] for i in daily)
            if day % 7 == 6:
                weekly = rng.choice(len(CONTRACTS[1]), 1 if afk else 2, replace=False)
                logs += sum(CONTRACTS[1][i][0] for i in weekly)
                souls += sum(CONTRACTS[1][i][1] for i in weekly)
            s["pending"] = (logs, souls)
            s["next_contract"] = t + played_day * .65

            if not afk:
                tokens = min(TOKEN_CAP, 2 * (6 if p["power"] >= 100 else 4))
                s["token_earned"] += tokens
                s["tokens"] += tokens
                # Two trials use 120 s of play time. Estimate forgone current forest chops.
                inc = base.income(p)[2] if income_rate is None else income_rate
                cost = inc * 120
                earned -= cost
                s["delta"]["trials"] -= cost
                for idx, price, reward_logs, reward_souls in [(0, 12, .5, 0), (1, 14, 0, 15), (2, 18, 0, 0)]:
                    if s["shop"][idx] < 2 and s["tokens"] >= price:
                        s["shop"][idx] += 1
                        s["tokens"] -= price
                        grant("trials", reward_logs, reward_souls)
                if p["isl_max"] == 2 and p["power"] >= 2000:
                    depth = min(18, max(2, int(3 + math.log(p["power"] / 2000, 1.5))))
                    earned -= inc * min(420, depth * 55)
                    s["delta"]["expedition"] -= inc * min(420, depth * 55)
                    claims = list(range(s["frontier"] + 1, depth + 1))[:DEPTH_CAP]
                    for current in claims:
                        grant("expedition", .22 + min(18, current) * .035, 6 + min(18, current))
                        s["materials"] += 1 + (current % 5 == 0)
                    s["frontier"] = max(s["frontier"], depth)
                    s["depth"] = max(s["depth"], depth)
        if t >= s["next_contract"]:
            grant("contracts", *s["pending"])
            s["next_contract"] = math.inf
        # Story is approximated by progress in the existing 3-island ladder.
        target = min(30, int(sum(p["trees"].values()) / 30), (p["isl_max"] + 1) * 10)
        while s["chain"] < target:
            step = s["chain"] % 10 + 1
            grant("story", .18 + step * .055, 3 + step)
            s["chain"] += 1
        return earned

    def snapshot(self, p):
        s = p["m5"]
        return {"m5": dict(s["delta"]), "m5_souls": s["souls"], "m5_depth": s["depth"],
                "m5_tokens": s["token_earned"], "m5_materials": s["materials"]}


def scenario(args):
    scen, mode, n, hours = args
    use_v2()
    data = {}
    for enabled in (False, True):
        runtime = Projection(enabled)
        raw = base.simulate(scen, mode, hours, n, seed=21, checkpoints=(8, 24, 72, hours), extension=runtime)
        data["M5" if enabled else "M4"] = {}
        for h, rows in raw.items():
            row = {key: median(v[key] for v in rows) for key in ("earned", "power", "t_cw", "t_fr", "m5_souls", "m5_depth", "m5_tokens", "m5_materials")}
            row["m5_net_logs"] = {key: median(v["m5"][key] for v in rows) for key in rows[0]["m5"]}
            data["M5" if enabled else "M4"][h] = row
    return f"{scen}-{mode}", data


def anchored_scenario(scen, mode, hours):
    """Long-horizon issuance against the checked-in M2 median progression anchors."""
    path = Path(__file__).parent / "results/m2" / f"res_{scen}_{mode}.json"
    rows = json.loads(path.read_text())
    if hours > rows[-1]["h"]:
        raise ValueError("Anchored projection stops at the final baseline horizon")

    def median_at(key, h):
        prev_t, prev_value = 0, 0
        for row in rows:
            t, value = row["h"], row[key][1]
            if h <= t:
                f = (h - prev_t) / (t - prev_t)
                return prev_value + f * (value - prev_value)
            prev_t, prev_value = t, value
        return prev_value

    def unlock(key):
        return next((r[key][1] for r in rows if r[key][1] < 1e8), math.inf)

    crystal, frost = unlock("t_cw"), unlock("t_fr")
    actor = {"power": 5, "souls": 0, "trees": {}, "kills": {}, "isl_max": 0}
    model = Projection(True)
    model.begin(actor, mode, 21, 0)
    state = actor["m5"]
    cap = base.P["Pools"]["TempLogsMax"]
    baseline_event = base.EVENT_NONE + sum(w * min(cap, lg) for w, lg, _ in base.EVENT_SLICES)
    lw_cap = base.P["Pools"]["TempLuckMax"]
    baseline_luck = base.EVENT_NONE + sum(w * min(lw_cap, lk) for w, _, lk in base.EVENT_SLICES)
    mean_luck_uplift = 0
    for i in range(math.ceil(hours * 12)):
        t = i / 12
        dt_h = min(1/12, hours-t)
        if dt_h <= 0:
            break
        actor["isl_max"] = 2 if t >= frost else 1 if t >= crystal else 0
        actor["power"] = max(5, median_at("power", t))
        unit = max(base.P["PriceTiers"][0]["Unit"], median_at("unit", t))
        dt = dt_h * 3600
        area = ("PineForest", "CrystalCanyon", "FrostPeaks")[actor["isl_max"]]
        island = base.ISL_ORDER[actor["isl_max"]]
        tree_rate = max(0, median_at("trees_s", t))
        actor["trees"][area] = actor["trees"].get(area, 0) + tree_rate * dt
        lg, lk = model.event(t * 3600, island)
        event_logs = base.EVENT_NONE * min(cap, lg)
        event_logs += sum(w * min(cap, max(lg, g)) for w, g, _ in base.EVENT_SLICES)
        event_luck = base.EVENT_NONE * min(lw_cap, lk)
        event_luck += sum(w * min(lw_cap, max(lk, k)) for w, _, k in base.EVENT_SLICES)
        delta = median_at("earned", t + dt_h) - median_at("earned", t)
        state["delta"]["events"] += delta * (event_logs / baseline_event - 1)
        mean_luck_uplift += dt_h * (event_luck / baseline_luck - 1)
        inc = max(0, median_at("income", t) / 3600)
        model.rewards(actor, t * 3600, dt, tree_rate, unit, income_rate=inc)

    baseline = median_at("earned", hours)
    issuance = sum(state["delta"].values())
    return {"baseline_logs": baseline, "m5_net_logs": state["delta"], "m5_souls": state["souls"],
            "m5_tokens": state["token_earned"], "m5_materials": state["materials"], "m5_depth": state["depth"],
            "total_logs_overlay": baseline + issuance, "relative_net_issuance": issuance / baseline,
            "regional_raw_luck_exposure": mean_luck_uplift / hours,
            "anchor_crystal_unlock_h": crystal, "anchor_frost_unlock_h": frost, "anchor_end_power": median_at("power", hours)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agents", type=int, default=6)
    parser.add_argument("--hours", type=float, default=200)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--anchored", action="store_true", help="Fast issuance forecast using checked-in M2 medians")
    args = parser.parse_args()
    if args.agents < 1 or args.jobs < 1 or not math.isfinite(args.hours) or args.hours <= 0:
        parser.error("Agents, jobs, and hours must be positive")
    combos = [(s, m, args.agents, args.hours) for s in ("free", "paid") for m in ("active", "afk")]
    if args.anchored:
        output = {f"{s}-{m}": anchored_scenario(s, m, args.hours) for s, m, _, _ in combos}
        print(json.dumps({"method": "M2 median-anchored issuance overlay", "hours": args.hours, "runs": output}, indent=2))
        return
    with ProcessPoolExecutor(max_workers=args.jobs) as pool:
        output = dict(pool.map(scenario, combos))
    print(json.dumps({"agents_per_arm": args.agents, "hours": args.hours, "runs": output}, indent=2))


if __name__ == "__main__":
    main()
