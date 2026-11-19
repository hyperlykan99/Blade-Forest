import numpy as np, math, exp, sim, layouts
from scipy.spatial import cKDTree
# Measured: lights = Epic/Legendary/Mythic/Secret 1 each + mutation Order>=2 (Frozen/Shadow/Rainbow) 1 each
#           emitters = Rare/Epic/Legendary/Mythic/Secret 1 each + any mutation 1
PARTS = {'Common':8,'Uncommon':8,'Rare':8,'Epic':8,'Legendary':8,'Mythic':3,'Secret':16}
def fx(t, m):
    L = (t in ('Epic','Legendary','Mythic','Secret')) + (m in ('Frozen','Shadow','Rainbow'))
    P = (t in ('Rare','Epic','Legendary','Mythic','Secret')) + (m != '-')
    return L, P
for name in ['Current','A','B','C']:
    rows = exp.LAYOUTS[name]; P = np.array([(r[0], r[2]) for r in rows]); kd = cKDTree(P)
    parts = np.array([PARTS[r[3]] for r in rows]); F = np.array([fx(r[3], r[6]) for r in rows])
    tot = (parts.sum(), F[:,0].sum(), F[:,1].sum())
    # worst-case local load: max over tree positions of counts within R
    out = [f"{name}: total parts {tot[0]} lights {tot[1]} emitters {tot[2]}"]
    for R in (40, 80):
        best = max(range(len(P)), key=lambda i: len(kd.query_ball_point(P[i], R)))
        idx = kd.query_ball_point(P[best], R)
        out.append(f"  within {R}: trees {len(idx)} parts {parts[idx].sum()} lights {F[idx,0].sum()} emitters {F[idx,1].sum()}")
    # steady-state expectation (respawn re-roll) for densest 80-stud window
    print('\n'.join(out))
w = {t: v[4] for t, v in sim.TYPES.items()}; W = sum(w.values())
pm = {'Golden':1/40,'Frozen':1/70,'Shadow':1/200,'Rainbow':1/800}; pany = sum(pm.values())
eL = (w['Epic']+w['Legendary']+w['Mythic']+w['Secret'])/W + pm['Frozen']+pm['Shadow']+pm['Rainbow']
eP = (w['Rare']+w['Epic']+w['Legendary']+w['Mythic']+w['Secret'])/W + pany
print(f"steady-state per tree: lights {eL:.3f} emitters {eP:.3f}; for 620: {620*eL:.0f}/{620*eP:.0f}; 840: {840*eL:.0f}/{840*eP:.0f}")
