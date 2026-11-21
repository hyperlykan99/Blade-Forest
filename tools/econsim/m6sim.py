"""Estimate M6 issuance and progression against the checked-in 200-hour M5 overlay."""
from collections import Counter
import argparse
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "tools/econsim/results"
DESIGN = (ROOT / "src/shared/M6Design.luau").read_text()


def rule(key):
    return int(re.search(rf"D\.{key}=(\d+)", DESIGN)[1])


def costs(block):
    return [dict((k, int(v)) for k, v in re.findall(r"(\w+)=(\d+)", body))
            for body in re.findall(r"Costs=\{([^}]+)\}", block)]


AWAKEN = costs(DESIGN.split("D.Awakening={", 1)[1].split("D.Recipes=", 1)[0])
FORGE = costs(DESIGN.split("D.Recipes={", 1)[1].split("D.Trials=", 1)[0])
ISLANDS = ("Bark", "Crystal", "Frost")


def reward(share, heart=False, weekly=False):
    return (.62 if not heart else 1.75 if weekly else .48,
            math.floor((48 if not heart else 100 if weekly else 35) + share * 16),
            (10 if not heart else 24 if weekly else 7) + math.floor(share * 5))


def simulate(name, m5, co_op=False):
    last = json.loads((RESULTS / f"m2/res_{name.replace('-', '_')}.json").read_text())[-1]
    paid = name.startswith("paid")
    active = name.endswith("active")
    per_day = 4 if active else 8
    unit, hourly_logs = last["unit"][1], last["income"][1]
    gates = (0, last["t_cw"][1], last["t_fr"][1])
    tree_rate = last["trees_s"][1]
    hours = 200
    stock, earned, spent, clears, runes = (Counter() for _ in range(5))
    split = .38 if co_op else 1
    timeline = {}
    completed = set()
    logs_grant = logs_displaced = 0
    stage = 0
    next_loan = 22 if paid else 28  # assumed time to obtain a qualifying 5-star weapon
    for day in range(hours // per_day):
        start = day * per_day
        end = start + per_day
        islands = [i for i, gate in enumerate(gates) if gate <= end]
        farm = islands if active else islands[-1:]
        for i in farm:
            raw = min(rule("MaterialPerDay"), math.floor(tree_rate * 3600 * per_day /
                      len(farm) / rule("ChopsPerMaterial")))
            key = ISLANDS[i]
            earned[key] += raw
            stock[key] += raw
        sources = Counter(Souls=(21 if paid else 18) * per_day,
                          Essence=(720 if paid else 540) * per_day)
        if active:
            salvages = min(rule("SalvagesPerDay"), 16 if paid else 10)
            sources[ISLANDS[islands[-1]]] += salvages * 2
            sources["Essence"] += salvages * 9
            sources["ExpeditionFrostCore"] += (6 if paid else 4) if 2 in islands else 0
            sources["TrialSeal"] += 1
            if 2 in islands and day % 3 == 0:
                runes["Refined expedition"] += 1
            raid_window = 2 if co_op else 1
            for j in range(min(raid_window, rule("RaidClaimsPerDay"))):
                if j and len(islands) < 2:
                    break
                i = islands[(day + j) % len(islands)]
                key = ISLANDS[i]
                log, souls, mats = reward(split)
                logs_grant += log * unit
                logs_displaced += hourly_logs * ((6 if co_op else 8) / 60)
                sources.update({key: mats, "Souls": souls, f"Sigil{key}": 1})
                clears[key] += 1
                runes["Etched raid" if i == 0 else "Refined raid"] += 1
        earned.update(sources)
        stock.update(sources)

        def buy(label, cost):
            if any(stock[k] < n for k, n in cost.items()):
                return False
            stock.subtract(cost)
            spent.update(cost)
            timeline.setdefault(label, end)
            return True

        if active and stage < len(AWAKEN) and end >= next_loan and buy(f"Awakening {stage + 1}", AWAKEN[stage]):
            stage += 1
        if active:
            for index, (cost, mastery_hour, island) in enumerate(zip(
                FORGE[:6], (4, 12, 22, 40, 72, 110), (0, 1, 2, 2, 2, 2)
            )):
                if index not in completed and island in islands and end >= mastery_hour and buy(f"Forge {index + 1}", cost):
                    completed.add(index)
            if "Etched craft" not in timeline and buy("Etched craft", {"Souls": 85, "Bark": 8}):
                runes["Etched craft"] += 1
            if 2 in islands and day % 7 in (5, 6) and buy("Winter Key", FORGE[6]):
                weekly = day % 7 == 5
                log, souls, mats = reward(split, heart=True, weekly=weekly)
                logs_grant += log * unit
                logs_displaced += hourly_logs * (8 / 60)
                stock.update(Souls=souls, Frost=mats)
                earned.update(Souls=souls, Frost=mats)
                clears["Heart weekly" if weekly else "Heart repeat"] += 1
                runes["Ancient Heart" if weekly else "Radiant Heart"] += 1
    # Wall-clock affordability uses bounded sources. Aura exposure is a separate sensitivity.
    baseline = m5["total_logs_overlay"]
    bonus = (baseline * .07 * .35) if stage else 0
    return {"play_hours": hours, "hours_per_day": per_day, "baseline_m5_logs": round(baseline),
            "earned_inventory": earned, "spent_inventory": spent, "ending_inventory": stock,
            "first_affordable_play_hours": timeline, "encounter_clears": clears, "rune_issuance": runes,
            "raid_damage_share_assumption": split if active else None,
            "encounter_logs_granted": round(logs_grant), "logs_displaced": round(logs_displaced),
            "logs_net_change_pct": round(100 * (logs_grant - logs_displaced) / baseline, 3),
            "logs_net_change_with_rune_sensitivity_pct": round(100 * (logs_grant - logs_displaced + bonus) / baseline, 3)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    m5 = json.loads((RESULTS / "m5/M5_ISSUANCE_200H.json").read_text())["runs"]
    result = {"method": "M5 200-hour median anchored affordability and issuance overlay",
              "assumptions": ["M2 tree rates and island gate medians anchor the checked-in M5 overlay",
                              "Daily farm caps apply per island; active routes visit every unlocked island",
                              "One assumed successful raid each active day solo or two with teammates, 38% contribution in co-op",
                              "Assumes seasonal costs and rewards as written and an eligible five-star at 28h free or 22h paid",
                              "Mastery eligibility and baseline Essence and Souls accrual are scenario inputs",
                              "Account-wide forked economies are modeled; no live telemetry or playtest DPS calibration",
                              "Optional rune sensitivity assumes 7% effective Logs bonus during 35% of income"],
              "runs": {name: simulate(name, row) for name, row in m5.items()}}
    result["runs"]["free-active-cooperative"] = simulate("free-active", m5["free-active"], co_op=True)
    content = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(content)
    else:
        print(content, end="")


if __name__ == "__main__":
    main()
