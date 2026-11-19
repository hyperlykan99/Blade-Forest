"""Blade Forest P1b.2 dense-forest simulator (ESTIMATES, not playtests).
Faithful port of CombatServer hit detection + BladeConfig.GetBlades/GetStats (branch p1b2/crystal-wilds @0fc997d)."""
import math, random, numpy as np

TICK = 0.05; HIT_R = 1.3; CD = 0.4; SAMPLES = (0, 0.33, 0.66, 1)
WEAK = 0.1
# Tree types (BladeConfig.TreeTypes, Crystal_*)
TYPES = {  # strength, health, logs, respawn, weight, hitbox width at template scale (measured in Studio)
 'Common':   (250, 3500, 900, 8, 55, 2.38),
 'Uncommon': (400, 7000, 2000, 12, 25, 2.42),
 'Rare':     (600, 13000, 4200, 18, 13, 2.39),
 'Epic':     (900, 24000, 9000, 30, 5.5, 2.35),
 'Legendary':(1400, 50000, 25000, 60, 1.5, 2.86),
 'Mythic':   (2100, 150000, 100000, 110, 0.5, 2.96),
 'Secret':   (3200, 450000, 400000, 220, 0.1, 4.25),
}
MUT = {'-': (1, 1), 'Golden': (1.5, 3), 'Frozen': (2, 4), 'Shadow': (3, 8), 'Rainbow': (5, 25)}  # HealthMult, LogMult
MUT_ONEIN = [('Golden', 40), ('Frozen', 70), ('Shadow', 200), ('Rainbow', 800)]

def power_from_onein(x): return math.floor(5 * x ** 0.45 + 0.5)

def profile(name, weapon_len, power, reach_lvl, blades, speed_lvl, dmg_lvl, star_mult=1.0):
    raw = 3 + 0.15 * speed_lvl; spd = min(raw, 5.5)
    scale = 1 + 0.025 * reach_lvl
    p = power * star_mult
    return dict(name=name, Reach=4 + 0.2 * reach_lvl, Length=weapon_len * scale, Scale=scale,
                Blades=blades, Speed=spd, Power=p, Damage=p * (1 + 0.1 * dmg_lvl) * raw / spd)

PROFILES = [
  profile('New player (Wooden, Reach 0, 1 blade)', 3.0, power_from_onein(2), 0, 1, 0, 0),
  profile('Crystal entry (Glacier Fang, Reach 10, 3 blades)', 4.1, power_from_onein(10000), 10, 3, 10, 30),
  profile('Midgame (Void Reaper, Reach 20, 5 blades)', 5.1, power_from_onein(500000), 20, 5, 20, 60),
  profile('High (Galaxy Cleaver 2-star, Reach 40, 6 blades)', 5.7, power_from_onein(4000000), 40, 6, 50, 100, 1.35),
]

def envelope(pr, half_w=1.19):
    """Analytic annulus of tree-CENTRE distances that can be hit (box treated as its inscribed/circumscribed radius)."""
    slack = HIT_R * pr['Scale']
    r_in = max(pr['Reach'] - 0.5, 1); r_out = r_in + pr['Length']
    return dict(blade_inner=r_in, blade_outer=r_out, slack=slack,
                centre_min=max(0, r_in - slack - half_w * 1.41), centre_min_box=max(0, r_in - slack - half_w),
                centre_max=r_out + slack + half_w, centre_max_box=r_out + slack + half_w * 1.41,
                query_radius=pr['Reach'] + pr['Length'] + 2,
                sweep_s=2 * math.pi / pr['Speed'])

class Forest:
    def __init__(self, rows, seed=1):
        self.rng = random.Random(seed)
        self.x = np.array([r[0] for r in rows]); self.z = np.array([r[2] for r in rows])
        self.n = len(rows)
        self.type = [r[3] for r in rows]; self.scale = [r[4] for r in rows]
        self.rot = np.radians([r[5] for r in rows]); self.mut = [r[6] for r in rows]
        self.hw = np.array([TYPES[t][5] * s / 2 for t, s in zip(self.type, self.scale)])
        self.hp = np.array([TYPES[t][1] * MUT[m][0] for t, m in zip(self.type, self.mut)], float)
        self.alive = np.ones(self.n, bool); self.regrow_at = np.full(self.n, np.inf)
        self.cos = np.cos(self.rot); self.sin = np.sin(self.rot)
    def respawn(self, i):
        w = [(t, v[4]) for t, v in TYPES.items()]
        r = self.rng.uniform(0, sum(x[1] for x in w)); acc = 0
        for t, wt in w:
            acc += wt
            if r <= acc: break
        m = '-'
        for mid, oi in MUT_ONEIN:
            if self.rng.random() < 1 / oi: m = mid; break
        self.type[i] = t; self.mut[i] = m; self.scale[i] = 1.0
        self.hw[i] = TYPES[t][5] / 2; self.hp[i] = TYPES[t][1] * MUT[m][0]
        self.alive[i] = True; self.regrow_at[i] = np.inf

def run(forest, pr, path_fn, duration, t0=0.0):
    """path_fn(t)->(x,z). Returns stats. Simulates server ticks."""
    f = forest; slack = HIT_R * pr['Scale']; qr = pr['Reach'] + pr['Length'] + 2
    cd = {}; hit_set = set(); felled = []; logs = 0; hits = 0
    per_sweep = []; sweep_len = 2 * math.pi / pr['Speed']; cur_sweep = set(); next_sweep = t0 + sweep_len
    t = t0; r_in = max(pr['Reach'] - 0.5, 1)
    while t < t0 + duration:
        # regrowth
        due = np.where(f.regrow_at <= t)[0]
        for i in due: f.respawn(i)
        px, pz = path_fn(t - t0)
        dx = f.x - px; dz = f.z - pz
        # broad phase: GetPartBoundsInRadius (box bound ~ hw*1.41)
        cand = np.where(f.alive & (dx * dx + dz * dz <= (qr + f.hw * 1.42) ** 2))[0]
        for b in range(pr['Blades']):
            ang = t * pr['Speed'] + b * 2 * math.pi / pr['Blades']
            ux, uz = math.cos(ang), math.sin(ang)
            for i in cand:
                if not f.alive[i]: continue
                key = (i, b)
                if t - cd.get(key, -9) < CD: continue
                # local box coords
                hit = False
                for s in SAMPLES:
                    r = r_in + pr['Length'] * s
                    lx, lz = px + ux * r - f.x[i], pz + uz * r - f.z[i]
                    ox = lx * f.cos[i] + lz * f.sin[i]; oz = -lx * f.sin[i] + lz * f.cos[i]
                    h = f.hw[i]
                    cx = min(max(ox, -h), h); cz = min(max(oz, -h), h)
                    if (ox - cx) ** 2 + (oz - cz) ** 2 <= slack * slack: hit = True; break
                if hit:
                    cd[key] = t; hits += 1; hit_set.add(i); cur_sweep.add(i)
                    dmg = pr['Damage'] * (WEAK if pr['Power'] < TYPES[f.type[i]][0] else 1)
                    f.hp[i] -= dmg
                    if f.hp[i] <= 0:
                        f.alive[i] = False; f.regrow_at[i] = t + TYPES[f.type[i]][3]
                        felled.append(f.type[i]); logs += TYPES[f.type[i]][2] * MUT[f.mut[i]][1]
        if t >= next_sweep:
            per_sweep.append(len(cur_sweep)); cur_sweep = set(); next_sweep += sweep_len
        t += TICK
    return dict(distinct_hit=len(hit_set), felled=len(felled), hits=hits, logs=logs,
                per_sweep=per_sweep, alive_frac=f.alive.mean(), t_end=t)

def load_csv(path):
    rows = []
    for l in open(path).read().strip().split('\n'):
        a = l.split(','); rows.append((float(a[0]), float(a[1]), float(a[2]), a[3], float(a[4]), float(a[5]), a[6]))
    return rows
