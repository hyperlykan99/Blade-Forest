"""Blade Forest economy model. Inputs are verbatim from BladeConfig (read 2026-11-18).
Behavioural assumptions (chop pacing, session lengths, purchase choices) are ESTIMATES."""
import math, random

# ---- verified config -------------------------------------------------------
POOL = [("FrostboundReaper",1e8,19905),("SeraphsLight",5e7,14572),("Dragonflame",2.5e7,10667),("GlacialEdge",1.5e7,8476),
("Celestial",1e7,7063),("PrismSaber",6.5e6,5818),("Galaxy",4e6,4676),("StarfallReaper",2.5e6,3785),("Starbreaker",1.5e6,3008),
("ShadowKatana",1e6,2506),("Umbraxe",7e5,2134),("Void",5e5,1834),("MagmaHook",3.5e5,1562),("SoulfireScythe",2.5e5,1343),
("SunsteelSword",1e5,889),("BonewhiteReaper",7e4,757),("VenomfangAxe",5e4,651),("Inferno",3.5e4,554),("Bloodthorn",2.5e4,476),
("GlacierFang",1e4,315),("CrimsonCrescent",7e3,269),("WarlordAxe",5e3,231),("Frost",3.5e3,197),("RedcliffAxe",2.5e3,169),
("SilverLabrys",1e3,112),("BloodvineScythe",700,95),("Emerald",500,82),("EmberHatchet",350,70),("Golden",250,60),
("EngravedAxe",100,40),("BoneScythe",70,34),("RoninKatana",50,29),("WillowScythe",35,25),("Iron",25,21),
("WoodsmanAxe",9,13),("LumberHatchet",6,11),("FarmhandScythe",4,9),("RustySickle",3,8)]
WOODEN_POWER = 7
STAR = {0:1,1:1.15,2:1.35,3:1.6,4:2,5:2.5}
UP = {"Blades":(100,18,1,1,5),"Speed":(30,1.28,3,.15,50),"Damage":(40,1.15,1,.1,100),"Reach":(60,1.3,4,.2,40),"Luck":(150,1.16,1,.05,100)}
AREAS = [("StarterGrove",0),("PineForest",40),("CrystalCanyon",250),("FrostPeaks",2000)]
TREES = {  # (weight, strength, health, logs)
"StarterGrove":[(55,1,4,1),(25,3,10,3),(13,8,35,10),(5.5,16,110,40),(1.5,30,320,150),(.5,45,1000,600),(.1,70,3000,2500)],
"PineForest":[(55,40,300,50),(25,60,620,110),(13,90,1250,260),(5.5,140,2700,650),(1.5,220,6200,1900),(.5,330,19000,7500),(.1,500,55000,30000)],
"CrystalCanyon":[(55,250,3500,900),(25,400,7000,2000),(13,600,13000,4200),(5.5,900,24000,9000),(1.5,1400,50000,25000),(.5,2100,150000,1e5),(.1,3200,450000,4e5)],
"FrostPeaks":[(55,2000,40000,9000),(25,4000,85000,20000),(13,7000,160000,42000),(5.5,12000,300000,90000),(1.5,20000,600000,250000),(.5,30000,1.8e6,1e6),(.1,45000,5.5e6,4e6)]}
CRATE = {"StarterGrove":750,"PineForest":25000,"CrystalCanyon":600000,"FrostPeaks":8000000}
MUTS = [(800,25,5),(200,8,3),(70,4,2),(40,3,1.5)]  # checked rarest-first (RollMutation)
TRAITS = [(1.25,50),(1.5,28),(1.75,14),(2,6),(2.5,1.8),(3,.2)]
PETS = [(.1,0,45),(.15,0,30),(.25,0,14),(.4,.05,7),(.6,.1,3),(1,.2,.9),(2,.5,.1)]

# ---- exact roll odds ------------------------------------------------------
def roll_probs(luck):
    out, alive = [], 1.0
    for wid, x, pw in POOL:
        eff = x if x <= 10 else max(x / max(luck, 1), 1)
        p = alive * (1 / eff)
        out.append((wid, x, eff, p, pw))
        alive *= (1 - 1 / eff)
    out.append(("Wooden", 2, 2, alive, WOODEN_POWER))
    return out

def mut_mult():
    alive, e_logs, e_hp = 1.0, 0.0, 0.0
    for one, lm, hm in MUTS:
        p = alive / one; e_logs += p * lm; e_hp += p * hm; alive *= 1 - 1 / one
    return e_logs + alive, e_hp + alive

# ---- progression model (ESTIMATE) ----------------------------------------
WALK = 1.6       # s between trees (estimate)
TREES_IN_REACH = 1.3  # simultaneous trees hit (estimate)

class P:
    def __init__(s, kind):
        s.kind, s.logs, s.t = kind, 0.0, 0.0
        s.lv = {k: 0 for k in UP}
        s.best = WOODEN_POWER; s.bestId = "Wooden"; s.rolls = 0
        s.trait = 1.0; s.pets = []; s.boost_luck = []; s.boost_logs = []
        s.passes = set(); s.rebirths = 0; s.spent = 0
        s.events = []
    def val(s, k): b = UP[k]; return b[2] + b[3] * s.lv[k]
    def cost(s, k): b = UP[k]; return math.floor(b[0] * b[1] ** s.lv[k])
    def area(s):
        a = "StarterGrove"
        for n, req in AREAS:
            if s.best >= req: a = n
        return a
    def boost(s, lst):
        m = 1.0
        for exp, mult in lst:
            if exp > s.t: m *= mult
        return m
    def luck(s):
        l = s.val("Luck") * s.boost(s.boost_luck)
        if "2xLuck" in s.passes: l *= 2
        l *= 1.1  # group (assume joined)
        l *= 1 + sum(p[1] for p in s.pets)
        l *= 1 + .1 * s.rebirths
        return l
    def logmult(s):
        m = s.boost(s.boost_logs)
        if "2xLogs" in s.passes: m *= 2
        if "VIP" in s.passes: m *= 1.1
        m *= s.trait * (1 + sum(p[0] for p in s.pets)) * (1 + .25 * s.rebirths)
        return m
    def income_rate(s):
        area = s.area(); blades = int(s.val("Blades")) + (1 if "BladeSlot" in s.passes else 0)
        raw = s.val("Speed"); speed = min(raw, 5.5)
        dmg = s.best * s.val("Damage") * raw / speed
        hit_interval = (2 * math.pi / speed) / blades
        mlog, mhp = mut_mult()
        tw = sum(t[0] for t in TREES[area]); logs_per_s = 0.0
        for w, st, hp, lg in TREES[area]:
            d = dmg if s.best >= st else dmg * 0.1
            hits = math.ceil(hp * mhp / d)
            secs = hits * hit_interval / TREES_IN_REACH + WALK
            logs_per_s += (w / tw) * lg * mlog / secs
        return logs_per_s * s.logmult()

def play(p, seconds, rng, roll_interval=None, buy_crates=True):
    step = 10.0
    ri = roll_interval or (0.8 if "FastRoll" in p.passes else 1.1)
    end = p.t + seconds
    while p.t < end:
        p.logs += p.income_rate() * step
        n = int(step / ri)
        probs = None
        L = p.luck()
        for i in range(n):
            p.rolls += 1
            l = L * (2 if p.rolls % 10 == 0 else 1)
            r_alive = 1.0
            got = ("Wooden", WOODEN_POWER)
            for wid, x, pw in POOL:
                eff = x if x <= 10 else max(x / l, 1)
                if rng.random() * eff < 1: got = (wid, pw); break
            if got[1] > p.best:
                p.best, p.bestId = got[1], got[0]
                p.events.append((round(p.t / 60, 1), got[0], got[1], p.area()))
        # greedy spending: damage/speed/blades/reach upgrades, crates/eggs when cheap relative to income
        for _ in range(40):
            area = p.area(); opts = []
            for k in ("Blades", "Damage", "Speed", "Reach", "Luck"):
                if p.lv[k] < UP[k][4]: opts.append((p.cost(k), k))
            if buy_crates and len(p.pets) < 3: opts.append((CRATE[area] * 1.5, "Egg"))
            if buy_crates and p.trait < 2: opts.append((CRATE[area] * 2.0, "Crate"))  # x2 = 'worth it' margin
            if not opts: break
            opts.sort()
            c, k = opts[0]
            if c > p.logs: break
            p.logs -= c
            if k == "Egg":
                r = rng.random() * 100
                for pet in PETS:
                    r -= pet[2]
                    if r <= 0: p.pets.append(pet); break
            elif k == "Crate":
                r = rng.random() * 100; ws = TRAITS
                if "LuckyCrates" in p.passes:
                    ws = [(m, w * (2 if m >= 1.75 else 1)) for m, w in TRAITS]
                tot = sum(w for _, w in ws); r = rng.random() * tot
                for m, w in ws:
                    r -= w
                    if r <= 0: p.trait = max(p.trait, m); break
            else:
                p.lv[k] += 1
        p.t += step
    return p

def snapshot(p):
    return dict(min=round(p.t / 60), area=p.area(), best=f"{p.bestId} ({p.best})", rolls=p.rolls,
                luck=round(p.luck(), 2), logmult=round(p.logmult(), 2), income_per_min=f"{p.income_rate()*60:,.0f}",
                lv=dict(p.lv), trait=p.trait, pets=len(p.pets))

def archetype(kind, seed):
    rng = random.Random(seed); p = P(kind)
    if kind in ("casual", "whale"):
        p.passes |= {"2xLogs"}
        p.passes.add("StarterPack")
        p.boost_luck.append((30 * 60, 2))  # StarterLuck 30 min
        p.best, p.bestId = 60, "FoundersEdge"  # Epic exclusive, power 60 (verified)
    if kind == "casual":
        p.passes |= {"FastRoll"}
    if kind == "whale":
        p.passes |= {"VIP", "BladeSlot", "2xLuck", "FastRoll", "LuckyCrates"}
    # D1: 45 minutes; playtime gifts 20-min LuckPotion x3 for 10 min (verified), 60-min Mega would be D1 for 60+ min only
    p.boost_luck.append((20 * 60 + 600, 3))
    if kind == "whale":  # products IF they were live: Mega Luck chained for the session (199 R$ / 15 min)
        p.boost_luck.append((45 * 60, 10))
    play(p, 45 * 60, rng)
    d1 = snapshot(p)
    # D2..D7: 40 min/day free, 60 min casual, 120 min whale (ESTIMATE)
    per = {"free": 40, "casual": 60, "whale": 120}[kind]
    for day in range(2, 8):
        p.boost_luck.append((p.t + 900, 3))  # daily-ish luck potion (dailies/quests give these; verified rewards)
        if kind == "whale": p.boost_luck.append((p.t + per * 60, 10))
        play(p, per * 60, rng)
    d7 = snapshot(p)
    return d1, d7, p.events

if __name__ == "__main__":
    import json
    print("== exact roll odds at luck 1 (displayed vs actual) ==")
    for wid, x, eff, prob, pw in roll_probs(1):
        print(f"{wid:18s} shown 1 in {x:>12,.0f}   actual 1 in {1/prob:>14,.1f}")
    print("\n== max luck stack ==")
    for L in (1, 6.6, 13.2, 27720, 55440):
        pr = roll_probs(L)
        top = pr[0]
        print(f"luck {L:>8}: P(FrostboundReaper)/roll = {top[3]:.3g}  -> expected rolls {1/top[3]:,.0f}; "
              f"guaranteed (eff=1) items: {[w for w,x,eff,_,_ in pr if eff==1][:3]}")
    print("\n== archetypes (median of 25 seeds) ==")
    for k in ("free", "casual", "whale"):
        runs = [archetype(k, s) for s in range(25)]
        runs.sort(key=lambda r: r[1]["lv"]["Damage"])
        d1, d7, ev = runs[12]
        areas_d1 = {}; areas_d7 = {}
        for r in runs:
            areas_d1[r[0]["area"]] = areas_d1.get(r[0]["area"], 0) + 1
            areas_d7[r[1]["area"]] = areas_d7.get(r[1]["area"], 0) + 1
        print(k, "D1", json.dumps(d1)); print(k, "D7", json.dumps(d7))
        print(k, "area dist D1", areas_d1, "D7", areas_d7)
        print(k, "first unlocks", ev[:8])
