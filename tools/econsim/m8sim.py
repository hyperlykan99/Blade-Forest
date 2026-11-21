"""Project M8 season pace and reward issuance over the existing M6 economy model."""
from pathlib import Path
import json
import math
import re

ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "tools/econsim/results"
SOURCE = (ROOT / "src/shared/M8Design.luau").read_text()
LEVEL_XP = int(re.search(r"XPPerLevel=(\d+)", SOURCE)[1])
TRACK_SOURCE = SOURCE.split("Track={", 1)[1].split("Challenges=", 1)[0]
TRACK = [{k: float(v) for k, v in re.findall(r"(Logs|Souls|Essence|XP)=([.\d]+)", row)}
         for row in re.findall(r"\{([^{}]+)\}", TRACK_SOURCE)]
SOURCES = {key: {k: int(v) for k, v in re.findall(r"(XP|Cap|Every)=(\d+)", fields)}
           for key, fields in re.findall(r"(\w+)=\{((?:(?:Every|XP|Cap)=\d+,?)+)\}",
                                         SOURCE.split("D.Sources={", 1)[1].split("D.BySeason", 1)[0])}
CHALLENGES = {key: (int(goal), int(xp)) for key, goal, xp in re.findall(
    r'Source="(\w+)",Goal=(\d+),XP=(\d+)', SOURCE.split("Challenges={", 1)[1].split("Events=", 1)[0])}
assert len(TRACK) == 12 and len(SOURCES) == 6 and len(CHALLENGES) == 4

# Daily activity on a play day. Weekly contract, challenge and event behavior is
# modeled separately. These are reproducible scenario inputs, not player telemetry.
SCENARIOS = {
    "new-free-active": dict(play_days=3, hours=1.0, trees=140, daily=1, weekly=0, trials=0, boss=0, depth=0),
    "free-active": dict(play_days=4, hours=1.5, trees=350, daily=2, weekly=1, trials=1, boss=1, depth=0),
    "paid-active": dict(play_days=4, hours=1.5, trees=560, daily=2, weekly=1, trials=1, boss=1, depth=1),
    "unattended-afk": dict(play_days=6, hours=4, trees=1800, daily=0, weekly=0, trials=0, boss=0, depth=0),
}


def xp(kind, n):
    rule = SOURCES[kind]
    return min(rule["Cap"], n // rule.get("Every", 1) * rule["XP"])


def project(inputs):
    cumulative, completion, hours = 0, None, 0
    week_levels = []
    target = LEVEL_XP * len(TRACK)
    for week in range(1, 9):
        inputs_week = {"Trees": 0, "Contracts": 0, "Trials": 0, "Boss": 0}
        for day in range(1, inputs["play_days"] + 1):
            daily = {"Trees": inputs["trees"], "Daily": inputs["daily"],
                     "Weekly": inputs["weekly"] if day == inputs["play_days"] else 0,
                     "Trials": inputs["trials"], "Boss": inputs["boss"], "Depths": inputs["depth"]}
            for key in inputs_week:
                increment = daily["Daily"] + daily["Weekly"] if key == "Contracts" else daily[key]
                before = inputs_week[key]
                inputs_week[key] += increment
                goal, grant = CHALLENGES[key]
                if before < goal <= inputs_week[key]:
                    cumulative += grant
            cumulative += sum(xp(key, n) for key, n in daily.items())
            hours += inputs["hours"]
            if completion is None and cumulative >= target:
                completion = {"week": week, "play_day_in_week": day, "play_hours": hours}
        if week == 3 and inputs["trees"] * inputs["play_days"] * 2 >= 400:
            cumulative += 250
        if week == 7 and (inputs["daily"] * inputs["play_days"] + inputs["weekly"]) * 2 >= 6:
            cumulative += 350
        if completion is None and cumulative >= target:
            completion = {"week": week, "play_day_in_week": inputs["play_days"], "play_hours": hours}
        week_levels.append(min(len(TRACK), cumulative // LEVEL_XP))
    paid = TRACK[:week_levels[-1]]
    totals = {k: round(sum(x.get(k, 0) for x in paid), 2) for k in ("Logs", "Souls", "Essence", "XP")}
    return {"week_levels": week_levels, "completion": completion, "reachable_reward_total": totals}


def main():
    m6 = json.loads((RESULTS / "m6/M6_ISSUANCE_200H.json").read_text())["runs"]
    rows = {name: project(inputs) for name, inputs in SCENARIOS.items()}
    for name in ("free-active", "paid-active"):
        baseline = json.loads((RESULTS / f"m2/res_{name.replace('-', '_')}.json").read_text())[-1]
        gross = rows[name]["reachable_reward_total"]["Logs"] * baseline["unit"][1]
        rows[name]["gross_season_logs_at_late_unit"] = round(gross)
        rows[name]["portion_of_m5_200h_logs_pct"] = round(100 * gross / m6[name]["baseline_m5_logs"], 4)
    report = {"method": "Bounded reward overlay anchored to M6 and the M2 late-game median price unit",
              "inputs": SCENARIOS, "runs": rows,
              "collection": {"weapon_target": 119, "forms_target": 63, "tree_discoveries": 28,
                             "buying_required": False, "estimated_full_completion": None}}
    out = RESULTS / "m8/M8_SEASON_OVERLAY.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    for name, row in rows.items():
        print(name, row)


if __name__ == "__main__":
    main()
