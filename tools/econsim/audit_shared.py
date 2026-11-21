"""20-player shared-forest load (model estimate). Uses sim.py formulas + median 8 h free-active build."""
from sim import *
area = "CrystalCanyon"
types = TREES_BY_AREA[area]
W = sum(t["Weight"] for t in types)
e_resp = sum(t["Weight"] * t["Respawn"] for t in types) / W
N_TREES = 620  # Crystal Wilds tree count (P1b.2r, verified 2026-11-20)
supply = N_TREES / e_resp  # trees/s if every tree were cut the moment it respawned
print(f"Crystal Wilds: {N_TREES} trees, mean respawn {e_resp:.1f}s -> max sustainable supply {supply:.1f} trees/s")
builds = {
 "early (30 min, Power 550)": dict(lv=dict(Blades=4, Speed=17, Damage=11, Reach=30, Luck=59), passes=set(), power=554., wlen=4.1, trait=None, reb=0, pets_eq=[], idx_done=0, tidx_done=0),
 "mid (8 h, Power 3,000)":   dict(lv=dict(Blades=5, Speed=50, Damage=18, Reach=40, Luck=100), passes=set(), power=3008., wlen=5.7, trait=None, reb=9, pets_eq=[], idx_done=0, tidx_done=0),
 "max build (Power 74,600)":  dict(lv=dict(Blades=5, Speed=50, Damage=100, Reach=40, Luck=100), passes={"BladeSlot"}, power=19905*2.5*1.5, wlen=6.4, trait=None, reb=0, pets_eq=[], idx_done=0, tidx_done=0),
}
for name, p in builds.items():
    st = stats(p)
    ts, _ = area_rate(st, area, "active")
    outer = st["reach"] - 0.5 + st["length"] + st["slack"]; inner = max(st["reach"] - 0.5 - st["slack"], 0)
    slots = DENSITY[area] * math.pi * (outer**2 - inner**2)
    hit_rate = st["blades"] * st["speed"] / TAU
    # hits that do NOT kill: per tree killed, hits = ceil(HP/dmg)
    hits_per_tree = sum(t["Weight"] * math.ceil(t["Health"] * MUT_HP / st["dmg"]) for t in types if st["power"] >= t["Strength"]) / sum(t["Weight"] for t in types if st["power"] >= t["Strength"])
    print(f"\n{name}: solo demand {ts:.1f} trees/s, ~{slots:.0f} trees in sweep, {hits_per_tree:.1f} hits per tree -> {ts*hits_per_tree:.0f} hit events/s")
    for n in (1, 3, 5, 10, 20):
        share = min(1.0, supply / (n * ts))
        hits_total = n * ts * share * hits_per_tree
        print(f"   {n:2d} players in CW: each gets {share*100:5.1f}% of solo income; zone {n*ts*share:5.1f} trees/s; ~{hits_total:6.0f} hit events/s broadcast (~{hits_total*48/1024:6.1f} KB/s to every client within 220 studs)")
