"""M2 island-progression model for Blade Forest.

Reuses verified BladeConfig values from economy_sim.py. ALL gate thresholds, session
schedules and pacing values here are CANDIDATES / ESTIMATES for discussion, not approved design.

Run:  python3 docs/m2_island_sim.py
"""
import math, random, statistics, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from economy_sim import POOL, WOODEN_POWER, UP, TREES, CRATE, MUTS, TRAITS, PETS, mut_mult

# ---------------- island mapping (proposal) ----------------
# Island 1 = Starter Grove + Pine woodlands (Pine zone keeps its 40-Power tree-strength curve)
# Island 2 = Crystal Canyon content, Island 3 = Frost Peaks content
ISLAND_TREES = {1: ("StarterGrove", "PineForest"), 2: ("CrystalCanyon",), 3: ("FrostPeaks",)}

# ---------------- candidate gates (TUNABLE, not approved) ----------------
GATE2 = dict(trees=600, power=60)            # + "defeat Blade King" (modelled as +3 min once Power >= 60)
GATE3_POWER_OPTIONS = (500, 1000, 2000)       # compared side by side
GATE3_LOGS_ON_I2 = 25_000_000                 # checklist option L: Logs earned while on Island 2
GATE3_TREES_ON_I2 = 6_000                     # checklist option T: trees chopped on Island 2 (less paid-sensitive)
SESSION_MIN = [45, 45, 45, 45, 45, 45, 45] + [45] * 20   # EQUAL playtime for every archetype
WALK, TREES_IN_REACH = 1.6, 1.3               # ESTIMATES (same as economy_sim.py)

def per_roll_probs(luck):
    ps, alive = [], 1.0
    for _, x, pw in POOL:
        eff = x if x <= 10 else max(x / max(luck, 1), 1)
        p = alive / eff
        ps.append((p, pw)); alive *= 1 - 1 / eff
    ps.append((alive, WOODEN_POWER))
    return ps

def sample_best(rng, n, luck):
    """Best power obtained in n rolls (9/10 at luck, 1/10 at 2*luck - the 'every 10th roll' rule)."""
    if n <= 0: return 0
    a, b = per_roll_probs(luck), per_roll_probs(luck * 2)
    n_lucky = n // 10; n_norm = n - n_lucky
    u = rng.random(); qa = qb = 0.0
    for (pa, pw), (pb, _) in zip(a, b):
        qa += pa; qb += pb
        p_none = (max(1 - qa, 0) ** n_norm) * (max(1 - qb, 0) ** n_lucky)
        if 1 - p_none >= u: return pw
    return WOODEN_POWER

class Player:
    def __init__(s, kind, capped):
        s.kind, s.capped = kind, capped
        s.t = 0.0; s.logs = 0.0; s.lv = {k: 0 for k in UP}
        s.best = WOODEN_POWER; s.trait = 1.0; s.pets = []
        s.passes = set(); s.luck_boosts = []; s.island = 1
        s.trees = 0; s.logs_i2 = 0.0; s.trees_i2 = 0.0; s.boss_at = None
        s.unlock = {}
        if kind != "free":
            s.passes |= {"2xLogs", "StarterPack"}; s.best = 60  # Founder's Edge
            s.luck_boosts.append((1800, 2))
        if kind == "casual": s.passes.add("FastRoll")
        if kind in ("heavy", "heavy_mega"): s.passes |= {"VIP", "BladeSlot", "2xLuck", "FastRoll", "LuckyCrates"}
    def val(s, k): b = UP[k]; return b[2] + b[3] * s.lv[k]
    def cost(s, k): b = UP[k]; return math.floor(b[0] * b[1] ** s.lv[k])
    def boost(s):
        m = 1.0
        for exp, mult in s.luck_boosts:
            if exp > s.t: m *= mult
        return m
    def luck(s):
        up = s.val("Luck"); boost = s.boost(); pas = 2 if "2xLuck" in s.passes else 1
        pet = 1 + sum(p[1] for p in s.pets); group = 1.1
        if not s.capped:
            return up * boost * pas * pet * group
        # VARIANT B: paid luck adds instead of multiplying, total roll luck capped at 25x
        free_part = up * pet * group * (min(s.boost(), 10) if s.kind == "free" else 1)
        paid_add = (pas - 1) + (s.boost() - 1 if s.kind != "free" else 0)
        return min(free_part + paid_add, 25)
    def logmult(s):
        m = 1.0
        if "2xLogs" in s.passes: m *= 2
        if "VIP" in s.passes: m *= 1.1
        return m * s.trait * (1 + sum(p[0] for p in s.pets))
    def zone(s):
        if s.island == 1: return "PineForest" if s.best >= 40 else "StarterGrove"
        return ISLAND_TREES[s.island][0]
    def rates(s):
        area = s.zone(); blades = int(s.val("Blades")) + (1 if "BladeSlot" in s.passes else 0)
        raw = s.val("Speed"); speed = min(raw, 5.5)
        dmg = s.best * s.val("Damage") * raw / speed
        hit = (2 * math.pi / speed) / blades
        mlog, mhp = mut_mult(); tw = sum(t[0] for t in TREES[area]); lps = tps = 0.0
        for w, st, hp, lg in TREES[area]:
            d = dmg if s.best >= st else dmg * 0.1
            secs = math.ceil(hp * mhp / d) * hit / TREES_IN_REACH + WALK
            lps += (w / tw) * lg * mlog / secs; tps += (w / tw) / secs
        return lps * s.logmult(), tps

def spend(p, rng):
    for _ in range(60):
        area = p.zone(); opts = [(p.cost(k), k) for k in UP if p.lv[k] < UP[k][4]]
        if len(p.pets) < 3: opts.append((CRATE[area] * 1.5, "Egg"))
        if p.trait < 2: opts.append((CRATE[area] * 2.0, "Crate"))
        if not opts: return
        c, k = min(opts)
        if c > p.logs: return
        p.logs -= c
        if k == "Egg":
            r = rng.random() * 100
            for pet in PETS:
                r -= pet[2]
                if r <= 0: p.pets.append(pet); break
        elif k == "Crate":
            ws = [(m, w * (2 if ("LuckyCrates" in p.passes and m >= 1.75) else 1)) for m, w in TRAITS]
            r = rng.random() * sum(w for _, w in ws)
            for m, w in ws:
                r -= w
                if r <= 0: p.trait = max(p.trait, m); break
        else:
            p.lv[k] += 1

def run(kind, capped, g3_power, seed, horizon_min=20 * 60, checklist="L"):
    rng = random.Random(seed); p = Player(kind, capped); step = 10.0
    ri = 0.8 if "FastRoll" in p.passes else 1.1
    played = 0.0
    for day, mins in enumerate(SESSION_MIN):
        p.luck_boosts.append((p.t + 900, 3))  # free daily luck potion (dailies/quests/gifts; verified rewards)
        if kind == "heavy_mega": p.luck_boosts.append((p.t + mins * 60, 10))  # HYPOTHETICAL: products live
        end = p.t + mins * 60
        while p.t < end:
            lps, tps = p.rates()
            p.logs += lps * step; p.trees += tps * step
            if p.island == 2: p.logs_i2 += lps * step; p.trees_i2 += tps * step
            p.best = max(p.best, sample_best(rng, int(step / ri), p.luck()))
            spend(p, rng); p.t += step
            m = p.t / 60
            if p.island == 1:
                if p.best >= GATE2["power"] and p.boss_at is None: p.boss_at = m + 3
                if p.trees >= GATE2["trees"] and p.boss_at is not None and m >= p.boss_at:
                    p.island = 2; p.unlock[2] = m
            elif p.island == 2 and p.best >= g3_power and ((p.logs_i2 >= GATE3_LOGS_ON_I2) if checklist == "L" else (p.trees_i2 >= GATE3_TREES_ON_I2)):
                p.island = 3; p.unlock[3] = m
            if m >= horizon_min: return p
    return p

def pct(xs, q):
    xs = sorted(xs); k = (len(xs) - 1) * q; f = math.floor(k); c = min(f + 1, len(xs) - 1)
    if math.inf in (xs[f], xs[c]): return math.inf
    return xs[f] + (xs[c] - xs[f]) * (k - f)

def fmt(v):
    if v is None or v == math.inf or v != v: return "  >20h"
    return f"{v:6.0f}m" if v < 120 else f"{v/60:5.1f}h"

def job(args):
    kind, capped, g3, chk, seeds = args
    i2, i3 = [], []
    for sd in range(seeds):
        p = run(kind, capped, g3, sd, checklist=chk)
        i2.append(p.unlock.get(2, math.inf)); i3.append(p.unlock.get(3, math.inf))
    return args, i2, i3

if __name__ == "__main__":
    from multiprocessing import Pool
    SEEDS = int(os.environ.get("SEEDS", 200))
    kinds = ("free", "casual", "heavy", "heavy_mega")
    tasks = [(k, c, g, chk, SEEDS) for chk in ("L", "T") for c in (False, True) for g in GATE3_POWER_OPTIONS for k in kinds]
    with Pool() as pool:
        res = pool.map(job, tasks)
    last = None
    for (k, c, g, chk, _), i2, i3 in res:
        head = (chk, c, g)
        if head != last:
            print(f"\n== checklist {'Logs earned on I2 >= 25M' if chk=='L' else 'Trees chopped on I2 >= 6,000'} | "
                  f"{'B: paid luck additive, cap 25x' if c else 'A: CURRENT luck stacking'} | Gate3 Power >= {g} | {SEEDS} seeds, equal 45-min sessions ==")
            last = head
        miss = sum(1 for x in i3 if x == math.inf) / len(i3)
        print(f"  {k:10s} I2 p10/p50/p90 {fmt(pct(i2,.1))} {fmt(pct(i2,.5))} {fmt(pct(i2,.9))} | "
              f"I3 {fmt(pct(i3,.1))} {fmt(pct(i3,.5))} {fmt(pct(i3,.9))} | I3 not in 20h: {miss:4.0%}")
