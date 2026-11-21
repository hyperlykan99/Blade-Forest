"""Measure the median free-active income per price tier (I_ref) to calibrate Unit = UnitMinutes x I_ref / 60."""
import json, sys, numpy as np
import m1sim as S
cps = (0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 24, 36, 48, 72)
out = S.simulate("free", "active", 72, int(sys.argv[1]) if len(sys.argv) > 1 else 16, seed=7, checkpoints=cps)
by = {}
for h, lst in out.items():
    for x in lst:
        by.setdefault(x["tier"], []).append(x["income"])
mins = float(sys.argv[2]) if len(sys.argv) > 2 else 2.0
for t in sorted(by):
    v = by[t]
    print(f"tier {t}: n={len(v):3d} income/h p25 {np.percentile(v,25):.3g} median {np.median(v):.3g} p75 {np.percentile(v,75):.3g} -> Unit({mins} min) {np.median(v)*mins/60:.3g}")
