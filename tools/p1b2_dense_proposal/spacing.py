import random, math, numpy as np, sim, gen, layouts, exp
res = {}
for s in (4.5, 5.0, 5.5, 6.0, 7.0, 8.0):
    rows = []
    for z in gen.ZONES_A:
        pts = gen.place_zone(z, z['n'], s, random.Random(f"sp-{s}-{z['id']}"))
        rows += [(x, 4.0, zz, 'Common', 1.0, 0, '-') for x, zz, _ in pts]
    # realistic types: reuse layout A records cyclically
    A = layouts.rows(layouts.build('A'))
    rows = [(r[0], r[1], r[2], A[i][3], A[i][4], A[i][5], A[i][6]) for i, r in enumerate(rows)]
    exp.LAYOUTS['s'] = rows
    from scipy.spatial import cKDTree
    d, _ = cKDTree([(r[0], r[2]) for r in rows]).query([(r[0], r[2]) for r in rows], 2)
    line = [f"s={s} NN={d[:,1].mean():.2f}"]
    for pr in sim.PROFILES[1:]:
        m, lo, hi = exp.sweep_test('s', pr, n=40)
        line.append(f"{pr['name'].split(' (')[0]}={m:.1f}")
    print(' '.join(line), flush=True)
