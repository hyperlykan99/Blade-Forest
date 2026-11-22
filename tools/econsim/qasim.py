"""Repeatable QA comparison of early Monte Carlo and the M1–M8 economy overlays."""
from pathlib import Path
import json
import subprocess
import sys

import m1sim
import m5sim
import m6sim
import m8sim

ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "results"


def early():
    m5sim.use_v2()
    results = {}
    for scenario, mode in [("free", "active"), ("free", "casual"), ("free", "afk"),
                           ("paid", "active"), ("paid", "afk")]:
        curves = m1sim.summarize(m1sim.simulate(scenario, mode, 1 / 6, n_agents=12,
                                              seed=811, checkpoints=(1 / 12, 1 / 6)))
        results[f"{scenario}-{mode}"] = curves
    return results


def main():
    # Refresh the three existing milestone projections before using them as anchors.
    for script, args in [
        ("m5sim.py", ["--anchored", "--hours", "200"]),
        ("m6sim.py", []),
        ("m8sim.py", []),
    ]:
        result = subprocess.run([sys.executable, str(ROOT / script), *args], capture_output=True, text=True, check=True)
        if script != "m8sim.py":
            target = RESULTS / "qa" / f"{script[:-3]}_200h.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(result.stdout)
    long = {}
    for name in ("free_active", "free_afk", "free_casual", "paid_active", "paid_afk", "whale_active"):
        rows = json.loads((RESULTS / "m2" / f"res_{name}.json").read_text())
        long[name] = [rows[0], rows[-1]]
    result = {
        "early": early(), "legacy_long_run_anchors": long,
        "scope": "Early 12-agent runs, fixed seed. 200-hour anchors are historical M2 Monte Carlo. "
                 "M5–M8 issuance and co-op paths are milestone overlays, not full game simulations."
    }
    (RESULTS / "qa" / "QA_ECONOMY_COMPARISON.json").write_text(json.dumps(result, indent=2) + "\n")
    print("QA economy projections complete")


if __name__ == "__main__":
    main()
