# Blade Forest economy simulator (audit 2026-11-20)

Reproducible model used by [`../FULL_GAME_ECONOMY_FUTURE_AUDIT.md`](../FULL_GAME_ECONOMY_FUTURE_AUDIT.md) §4–§5.
Every balance number is parsed from `src/shared/BladeConfig.luau`; behaviour and geometry
assumptions (A1–A6) are labelled at the top of `sim.py`. Results are **model estimates**.

| File | Purpose |
| --- | --- |
| `bf_config.py` | Parses BladeConfig.luau (weapons, trees, upgrades, traits, pets, events, rebirth, prices) |
| `sim.py` | Monte Carlo player simulator (free / paid / whale × active / afk / idle) |
| `shared.py` | 20-player shared-forest supply and hit-traffic estimate for Crystal Wilds |
| `sens.py` | Density sensitivity (every area as dense as Crystal Wilds) |
| `summarize.py` | Prints p10 / median / p90 tables from `results/` |
| `results/` | JSON outputs and run logs used in the audit (40 agents per scenario; 30 for `sens`) |

Audited config: `m0/foundations` @ `75f5985`. `main` has no `src/`, so point the parser at that file:

```bash
export BF_CONFIG=/path/to/checkout-of-m0-foundations/src/shared/BladeConfig.luau
python3 sim.py free active 200 40     # scenario, mode, hours, agents -> results/res_free_active.json
python3 sim.py paid active 200 40
python3 sim.py whale active 200 40
python3 sim.py free afk 200 40
python3 sim.py free idle 200 40
python3 shared.py
python3 sens.py
python3 summarize.py
```

Requires Python 3 and numpy. Calibration: the idle model predicts 3,438 Logs/s for the dev profile's
observed build in Crystal Wilds against ~3,400 Logs/s measured in Studio on 2026-11-20.
