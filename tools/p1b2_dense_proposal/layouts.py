import os
import math, random, copy, gen, sim
ORDER = ['Secret','Mythic','Legendary','Epic','Rare','Uncommon','Common']
LANDMARKS = {'Z1': (2888, 32), 'Z2': (3000, 18), 'Z3': (2885, 142), 'Z4': (3040, -196)}
LM_CLEAR = 6.5

def build(option, seed=20261121):
    cur = sim.load_csv(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'current_manifest_v12_copy.csv'))
    recs = [dict(src=i+1, type=r[3], scale=r[4], rot=r[5], mut=r[6]) for i, r in enumerate(cur)]
    zones = copy.deepcopy(gen.ZONES_A); pockets = copy.deepcopy(gen.POCKETS)
    s = {'A': 6.0, 'B': 4.5, 'C': 6.0}[option]
    if option == 'C':  # +220 new trees (area weights), zones grow
        rng = random.Random(seed + 7)
        for k in range(220):
            w = [(t, v[4]) for t, v in sim.TYPES.items()]; r = rng.uniform(0, 100.6); acc = 0
            for t, wt in w:
                acc += wt
                if r <= acc: break
            recs.append(dict(src=0, type=t, scale=round(rng.uniform(0.85, 1.15), 2), rot=rng.randrange(360), mut='-'))
        for z, add in zip(zones, (55, 55, 55, 55)): z['n'] += add; z['a'] *= 1.2; z['b'] *= 1.2
    spots = []  # (zone_id, x, z, is_landmark)
    for z in zones:
        lm = LANDMARKS[z['id']]
        pts = gen.place_zone(z, z['n'] - 1, s, random.Random(f"{seed}-{option}-{z['id']}"), landmarks=[(lm[0], lm[1], LM_CLEAR)])
        spots.append((z['id'], lm[0], lm[1], True))
        spots += [(z['id'], x, zz, False) for x, zz, _ in pts]
    for p in pockets:
        pts = gen.place_zone(p, p['n'], 4.5, random.Random(f"{seed}-{option}-{p['id']}"))
        spots += [(p['id'], x, zz, False) for x, zz, _ in pts]
    # assignment: Secret + Mythics to landmark spots; rest stratified (largest remainder) by rarity
    rng = random.Random(seed + 1)
    lm_recs = [r for r in recs if r['type'] in ('Secret', 'Mythic')]
    lm_order = {'Z2': 'Secret'}
    out = []
    used = set()
    for zid, x, z, is_lm in spots:
        if not is_lm: continue
        want = lm_order.get(zid, 'Mythic')
        r = next(r for r in lm_recs if r['type'] == want and id(r) not in used); used.add(id(r))
        out.append((zid, x, z, r, True))
    rest = [r for r in recs if id(r) not in used]
    rest.sort(key=lambda r: (ORDER.index(r['type']), r['src']))
    slots = [(zid, x, z) for zid, x, z, is_lm in spots if not is_lm]
    # stratify: deal records in rarity order across zones proportional to slot count
    by_zone = {}
    for zid, x, z in slots: by_zone.setdefault(zid, []).append((x, z))
    for v in by_zone.values(): rng.shuffle(v)
    total = len(slots); quota = {k: len(v) for k, v in by_zone.items()}; given = {k: 0 for k in by_zone}
    for idx, r in enumerate(rest):
        # pick zone whose share is most behind
        k = min(by_zone, key=lambda k: (given[k] / quota[k] if given[k] < quota[k] else 9, k))
        x, z = by_zone[k][given[k]]; given[k] += 1
        out.append((k, x, z, r, False))
    # composition: within each zone, larger-scale records go to the outer ring (records unchanged, only re-seated)
    zc = {z['id']: (z['cx'], z['cz']) for z in zones}
    res = [o for o in out if o[4]]
    for k in by_zone:
        grp = [o for o in out if o[0] == k and not o[4]]
        c = zc.get(k, (sum(o[1] for o in grp) / len(grp), sum(o[2] for o in grp) / len(grp)))
        pos = sorted(((o[1], o[2]) for o in grp), key=lambda p: math.hypot(p[0] - c[0], p[1] - c[1]))
        recs_sorted = sorted((o[3] for o in grp), key=lambda r: (r['scale'], r['src']))
        res += [(k, p[0], p[1], r, False) for p, r in zip(pos, recs_sorted)]
    return res

def rows(layout):
    return [(x, 4.0, z, r['type'], r['scale'], r['rot'], r['mut']) for _, x, z, r, _ in layout]
