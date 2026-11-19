import os
import math, random, json, numpy as np, sim, layouts, sys
from scipy.spatial import cKDTree
LAYOUTS = {'Current': sim.load_csv(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'current_manifest_v12_copy.csv'))}
for o in 'ABC': LAYOUTS[o] = layouts.rows(layouts.build(o))
PR = sim.PROFILES

def polyline(wps, speed=16.0):
    segs = []; acc = 0
    for a, b in zip(wps, wps[1:]):
        L = math.dist(a, b); segs.append((acc, L, a, b)); acc += L
    def f(t):
        d = min(t * speed, acc)
        for s0, L, a, b in segs:
            if d <= s0 + L: u = (d - s0) / L; return (a[0] + (b[0]-a[0])*u, a[1] + (b[1]-a[1])*u)
        return wps[-1]
    return f, acc
# Same physical route on every layout: plaza -> Z1 -> Z2 (gorge) -> gorge pockets -> Z4 -> back west along south
ROUTE = [(2790,0),(2860,6),(2944,4),(3000,-10),(3000,-60),(2992,-100),(2985,-130),(3005,-165),(3040,-190),(3075,-195),(3030,-205),(2990,-185)]

def sweep_test(name, pr, n=60, seed=5):
    rows = LAYOUTS[name]; rng = random.Random(seed); res = []
    for k in range(n):
        f = sim.Forest(rows, seed=k)
        i = rng.randrange(len(rows)); a = rng.uniform(0, 2*math.pi); d = rng.uniform(0, 6)
        p = (rows[i][0] + d*math.cos(a), rows[i][2] + d*math.sin(a))
        r = sim.run(f, pr, lambda t: p, 2*math.pi/pr['Speed'] + 0.06, t0=rng.uniform(0, 10))
        res.append(r['distinct_hit'])
    return float(np.mean(res)), float(np.percentile(res, 10)), float(np.percentile(res, 90))

def walk_test(name, pr, dur=30):
    rows = LAYOUTS[name]; f = sim.Forest(rows, seed=99); path, L = polyline(ROUTE)
    r = sim.run(f, pr, path, dur)
    # dead time: fraction of ticks where no live tree centre in hit envelope
    e = sim.envelope(pr); kd = cKDTree([(x[0], x[2]) for x in rows]); dead = 0; T = int(dur/0.05)
    for k in range(T):
        p = path(k*0.05); near = kd.query_ball_point(p, e['centre_max'])
        if not any(math.dist(p, (rows[j][0], rows[j][2])) >= e['centre_min'] for j in near): dead += 1
    return dict(distinct=r['distinct_hit'], felled=r['felled'], logs=r['logs'], dead_frac=dead/T)

def farm_test(name, pr, centre, dur=120):
    rows = LAYOUTS[name]; f = sim.Forest(rows, seed=7)
    path = lambda t: (centre[0] + 10*math.cos(t*0.4), centre[1] + 10*math.sin(t*0.4))  # slow 10-stud circle
    kd = cKDTree([(x[0], x[2]) for x in rows]); local = kd.query_ball_point(centre, 30)
    # candidates/tick proxy
    e = sim.envelope(pr); qc = []
    for k in range(0, int(dur/0.05), 10):
        p = path(k*0.05); qc.append(len(kd.query_ball_point(p, e['query_radius'] + 1.7)))
    r = sim.run(f, pr, path, dur)
    alive_local = float(np.mean([f.alive[j] for j in local])) if local else float('nan')
    return dict(felled_per_min=r['felled']*60/dur, logs_per_min=r['logs']*60/dur, hits_per_s=r['hits']/dur,
                alive_local_end=alive_local, local_trees=len(local), query_parts_per_tick=float(np.mean(qc)),
                narrow_checks_per_s=float(np.mean(qc))*pr['Blades']*20)

def densest(name):
    rows = LAYOUTS[name]; P = np.array([(x[0], x[2]) for x in rows]); kd = cKDTree(P)
    c = max(range(len(P)), key=lambda i: len(kd.query_ball_point(P[i], 20))); return tuple(P[c])

if __name__ == '__main__':
    out = {}
    for name in LAYOUTS:
        out[name] = {}
        dc = densest(name) if name == 'Current' else (3000, -15)
        for pr in PR:
            key = pr['name'].split(' (')[0]
            sw = sweep_test(name, pr); wk = walk_test(name, pr); fm = farm_test(name, pr, dc)
            out[name][key] = dict(sweep=sw, walk=wk, farm=fm)
            print(name, key, 'sweep', [round(v,1) for v in sw], 'walk', {k: round(v,2) for k,v in wk.items()}, 'farm', {k: round(v,2) for k,v in fm.items()}, flush=True)
        out[name]['_farm_centre'] = dc
    json.dump(out, open('results.json', 'w'), indent=1)
