"""Builds the M1 balance report (results/m1/REPORT.txt) from results/m1/res_*.json plus static
calculations: max build, 20-player server supply with Forest Renewal, future island scaling,
old-vs-new (audit baseline) and dev-profile time-to-afford."""
import json, math, os
import numpy as np
import m1sim as S

HERE = os.path.dirname(os.path.abspath(__file__))
R = os.path.join(HERE, "results")


def load(name, base=False):
    f = os.path.join(R, "baseline" if base else "m1", f"res_{name}.json")
    return json.load(open(f)) if os.path.exists(f) else None


def g(x):
    if x is None: return "-"
    a = abs(x)
    for e, s in ((1e15, "Qa"), (1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if a >= e: return f"{x / e:.2f}{s}"
    return f"{x:.3g}"


def hrs(x):
    if x >= 1e8: return "not reached"
    return f"{x * 60:.0f} min" if x < 1 else f"{x:.1f} h"


def section(t):
    print("\n" + "=" * 100 + "\n" + t + "\n" + "=" * 100)


H = [0.5, 2, 8, 24, 72, 200]
SCN = ["free_new", "free_casual", "free_active", "free_afk", "paid_active", "paid_afk", "whale_active"]
data = {s: load(s) for s in SCN}

section("1. Per-scenario medians (p10 / p50 / p90 where shown). Model estimates, one solo server.")
for s in SCN:
    d = data[s]
    if not d: continue
    print(f"\n[{s}]")
    print(f"{'h':>5} | {'Logs/h':>22} | {'earned':>9} | {'Souls held':>10} | {'Power':>6} | {'reb':>3} | {'LogMult':>7} | {'Luck':>5} | {'tier':>4} | {'walk':>4} | boss% | area mix")
    for r in d:
        inc = r["income"]
        print(f"{r['h']:>5} | {g(inc[0]):>6} {g(inc[1]):>7} {g(inc[2]):>7} | {g(r['earned'][1]):>9} | {g(r['souls'][1]):>10} | {r['power'][1]:>6.0f} | {r['reb'][1]:>3.0f}"
              f" | {r['logmult'][1]:>7.1f} | {r['luck'][1]:>5.1f} | {r['tier'][1]:>4.0f} | {r['walk'][1]:>4.1f} | {100 * r['boss_share'][1]:>4.0f}% | "
              + ", ".join(f"{k}:{v:.0%}" for k, v in r["area_mix"].items()))

section("2. Island unlock and first rare weapon (median over the 200 h run; p10 / p50 / p90)")
for s in SCN:
    d = data[s]
    if not d: continue
    r = d[-1]
    f = r["first"]
    print(f"{s:>13}: Pine area {hrs(r['t_pine'][1])} | Crystal Wilds {hrs(r['t_cw'][0])} / {hrs(r['t_cw'][1])} / {hrs(r['t_cw'][2])}"
          f" | Frostbound {hrs(r['t_fr'][0])} / {hrs(r['t_fr'][1])} / {hrs(r['t_fr'][2])}"
          f" | first Legendary {hrs(f['Legendary'][1])}, Mythic {hrs(f['Mythic'][1])}, Secret {hrs(f['Secret'][1])}, Divine {hrs(f['Divine'][1])}")

section("3. AFK vs active and free vs paid (cumulative Logs earned, median)")
def ratio(a, b, label):
    A, B = data.get(a), data.get(b)
    if not (A and B): return
    print(label + ": " + "  ".join(f"{x['h']}h {y['earned'][1] / max(x['earned'][1], 1):.2f}" for x, y in zip(A, B)))
ratio("free_active", "free_afk", "free AFK / free active   (target 0.60-0.75)")
ratio("paid_active", "paid_afk", "paid AFK / paid active   ")
ratio("free_active", "paid_active", "paid / free (active)     ")
ratio("free_active", "whale_active", "whale / free (active)    ")
ratio("free_active", "free_casual", "casual / active          ")
A, B = data.get("free_active"), data.get("free_afk")
if A and B:
    print("AFK / active power: " + "  ".join(f"{x['h']}h {y['power'][1] / max(x['power'][1], 1):.2f}" for x, y in zip(A, B)))
    print("AFK / active rebirths: " + "  ".join(f"{x['h']}h {y['reb'][1]:.0f}/{x['reb'][1]:.0f}" for x, y in zip(A, B)))

section("4. Upgrade configuration and affordability (cost of the LAST level in minutes of median free-active income)")
fa = data.get("free_active")
print(f"{'Upgrade':>10} | {'levels':>6} | {'first':>7} | {'last level':>10} | {'total to max':>12} | " + " | ".join(f"{h}h" for h in H))
for uid, u in S.UPG.items():
    first = S.upg_cost(uid, 0); last = S.upg_cost(uid, u["MaxLevel"] - 1)
    tot = sum(S.upg_cost(uid, l) for l in range(u["MaxLevel"]))
    cells = []
    for r in (fa or []):
        cells.append(f"{last / max(r['income'][1], 1) * 60:.1f}m")
    print(f"{uid:>10} | {u['MaxLevel']:>6} | {g(first):>7} | {g(last):>10} | {g(tot):>12} | " + " | ".join(cells))
if fa:
    print("\nMedian levels owned (free active):")
    for r in fa:
        print(f"  {r['h']:>5}h " + ", ".join(f"{k} {v[1]:.0f}" for k, v in r["lv"].items()) + " | Soul upgrades " + ", ".join(f"{k} {v[1]:.0f}" for k, v in r["soul_lv"].items()))

section("5. Rebirth pacing (cost = max(MinCost, Units x Growth^n x Unit(tier)))")
print("n      " + " ".join(f"{n:>8}" for n in range(0, 16, 2)))
for t in S.P["PriceTiers"]:
    print(f"tier {t['Tier']} " + " ".join(f"{g(max(S.P['Rebirth']['MinCost'], S.P['Rebirth']['Units'] * S.P['Rebirth']['Growth'] ** n * t['Unit'])):>8}" for n in range(0, 16, 2)))
print("Rebirth Logs bonus R(n): " + ", ".join(f"n={n} x{1 + S.soft(0.25 * n, 3):.2f}" for n in (1, 2, 4, 8, 12, 16, 20)) + " (old: 1+0.25n)")

section("6. Price tiers and unit prices (Unit = ~2 min of median free-active income at that tier)")
for t in S.P["PriceTiers"]:
    print(f"tier {t['Tier']} {t['Name']:<10} Power>={t['MinPower']:<6} island<={t['MaxIsland']:<16} Unit {g(t['Unit']):>7} | crate {g(t['Unit'] * S.P['Prices']['TraitCrate'])} egg {g(t['Unit'] * S.P['Prices']['PetEgg'])}"
          f" | King {g(t['Unit'] * S.P['Bosses']['BladeKing']['LogsUnits'])} Treant {g(t['Unit'] * S.P['Bosses']['Treant']['LogsUnits'])}")

section("7. Maximum build (all upgrades max, 5-star Shiny FrostboundReaper, Ancient Root, 3-4 Dragons, every index, 20 rebirths, max Soul upgrades)")
for passes, label in ((set(), "free max"), ({"2xLogs", "2xLuck", "VIP", "BladeSlot", "FastRoll"}, "paid max")):
    p = S.new_player(np.random.default_rng(0), "free"); p["passes"] = passes
    p["lv"] = {k: S.UPG[k]["MaxLevel"] for k in S.UPG}; p["reb"] = 20
    p["trait"] = [t for t in S.C["traits"] if t["Id"] == "AncientRoot"][0]
    drag = [x for x in S.C["pets"] if x["Id"] == "Dragon"][0]
    p["pets_eq"] = [drag] * (4 if "VIP" in passes else 3)
    p["idx_std"] = set(S.AREA_ORDER); p["idx_mas"] = set(S.AREA_ORDER); p["tidx"] = 4
    p["soul_lv"] = {k: S.SOUL[k]["MaxLevel"] for k in S.SOUL}
    I = S.P["Index"]
    p["idx_luck"] = 4 * (I["WeaponStandard"]["Luck"] + I["WeaponMastery"]["Luck"])
    p["idx_logs"] = 4 * (I["WeaponStandard"]["Logs"] + I["WeaponMastery"]["Logs"]) + 4 * I["Tree"]["Logs"]
    p["power"] = S.C["weapons"]["FrostboundReaper"]["Power"] * 2.5 * 1.5; p["wlen"] = 6.4; p["isl_max"] = 2
    a, ts, inc = S.income(p)
    print(f"{label}: S_perm {S.s_perm(p):.2f} -> x{1 + S.soft(S.s_perm(p), 6):.2f}; pets x{1 + S.soft(sum(x['Logs'] for x in p['pets_eq']), 3):.2f};"
          f" rebirth x{1 + S.soft(5, 3):.2f}; LogMult (no temp) x{S.log_mult(p):.1f}, with x2 event x{S.log_mult(p, 2):.1f};"
          f" Luck x{S.luck(p):.1f} (cap 50), with Mega Luck x{S.luck(p, 10):.1f}; income {g(inc * 3600)}/h in {a}")
print("Old rules (audit §8): free max about x106-122, paid max x466 (x1,630 with 10 rebirths); luck x644 free max.")

section("8. 20-player server: Crystal Wilds tree supply, crowding and Forest Renewal")
area = "CrystalCanyon"
types = S.TREES_BY_AREA[area]
W = sum(t["Weight"] for t in types)
ren = S.P["Renewal"]
def supply(renewal_share, red):
    # renewal applies to Common..Epic trees felled by players who own it
    e = 0.0
    for t in types:
        r = t["Respawn"]
        if t["Rarity"] in ren["Rarities"]:
            r = max(ren["MinRespawn"], r * (1 - red * renewal_share))
        e += t["Weight"] * r
    return 620 / (e / W)
mid = S.new_player(np.random.default_rng(0), "free")
mid["lv"] = {k: S.UPG[k]["MaxLevel"] for k in S.UPG}; mid["lv"]["Damage"] = 25; mid["lv"]["Speed"] = 17
mid["power"] = 2134; mid["wlen"] = 5.1; mid["isl_max"] = 1
st = S.stats(mid)
demand = S.area_rate(st, area, "active")[0]
base_supply = supply(0, 0)
print(f"620 trees; supply without renewal {base_supply:.1f} trees/s; one mid-game player (Power 2,134, max walk) wants {demand:.1f} trees/s")
for n in (1, 5, 10, 20):
    for share, label in ((0.0, "nobody has Renewal"), (1.0, "everyone max Renewal (-40%)")):
        sup = supply(share, ren["MaxReduction"])
        # rebuild budget: accelerated respawns are capped server-wide
        accel = n * demand * share
        if accel > ren["ServerBudgetPerSecond"]:
            sup = base_supply + (sup - base_supply) * ren["ServerBudgetPerSecond"] / accel
        each = min(1.0, sup / (n * demand))
        print(f"  {n:2d} players, {label:<28}: each gets {each:6.1%} of solo income; rebuilds {min(sup, n * demand):5.1f}/s")
print(f"Renewal server budget: at most {ren['ServerBudgetPerSecond']} accelerated rebuilds per second per server (TreeKit CPU guard); "
      f"Legendary+ trees never accelerated; minimum respawn {ren['MinRespawn']} s.")

section("9. Future island scaling check (Island 4 = Strength x10, Logs x12, prices x12 vs Frost; density sweep)")
frost = S.TREES_BY_AREA["FrostPeaks"]
for dens in (1 / 150, 1 / 60, 1 / 31):
    for tmult, label in ((1, "Frost (today)"), (12, "Island 4 (x12 Logs, x10 Strength)")):
        S.DENSITY["FrostPeaks"] = dens
        saved = [(t["Logs"], t["Strength"], t["Health"]) for t in frost]
        if tmult != 1:
            for t in frost: t["Logs"] *= 12; t["Strength"] *= 10; t["Health"] *= 10
        p = S.new_player(np.random.default_rng(0), "free"); p["lv"] = {k: S.UPG[k]["MaxLevel"] for k in S.UPG}
        p["lv"]["Damage"] = 40; p["isl_max"] = 2
        p["power"] = (2500 if tmult == 1 else 25000); p["wlen"] = 6.4
        st = S.stats(p)
        _, fr = S.area_rate(st, "FrostPeaks", "active")
        _, cw = S.area_rate(st, "CrystalCanyon", "active")
        for t, (lg, sg, hp) in zip(frost, saved): t["Logs"], t["Strength"], t["Health"] = lg, sg, hp
        print(f"  density 1/{1 / dens:.0f} stud^2, {label:<34} Power {p['power']:>6}: base Logs/s {g(fr)} vs Crystal Wilds {g(cw)} -> {'OK (island order = income order)' if fr > cw else 'FAILS (Crystal Wilds pays more)'}")
S.DENSITY["FrostPeaks"] = 1 / 150

section("10. Old rules (audit baseline) vs M1, free active median")
old = load("free_active", base=True)
if old and fa:
    print(f"{'h':>5} | {'old Logs/h':>10} | {'M1 Logs/h':>10} | {'old earned':>10} | {'M1 earned':>10} | {'old LogMult':>11} | {'M1 LogMult':>10} | {'old Luck':>8} | {'M1 Luck':>7} | old reb | M1 reb")
    for o, n in zip(old, fa):
        print(f"{o['h']:>5} | {g(o['income'][1]):>10} | {g(n['income'][1]):>10} | {g(o['earned'][1]):>10} | {g(n['earned'][1]):>10} | {o['logmult'][1]:>11.1f} | {n['logmult'][1]:>10.1f} | {o['luck'][1]:>8.1f} | {n['luck'][1]:>7.1f} | {o['reb'][1]:>7.0f} | {n['reb'][1]:>6.0f}")
    print(f"Old: Crystal {hrs(old[-1]['t_crystal'][1])}, Frost Power {hrs(old[-1]['t_frost'][1])}. M1: Crystal Wilds {hrs(fa[-1]['t_cw'][1])}, Frostbound {hrs(fa[-1]['t_fr'][1])}.")
    print("Time-to-afford (minutes of the player's own median income at the same horizon), old -> M1:")
    for o, n in zip(old, fa):
        oc = {"StarterGrove": 750, "PineForest": 25000, "CrystalCanyon": 600000, "FrostPeaks": 8000000}[o["area_mix"] and max(o["area_mix"], key=o["area_mix"].get)]
        print(f"  {o['h']:>5}h trait crate {oc / o['income'][1] * 60:6.2f} -> {n['unit'][1] / n['income'][1] * 60:6.2f} min;"
              f" pet egg {1.5 * oc / o['income'][1] * 60:6.2f} -> {1.5 * n['unit'][1] / n['income'][1] * 60:6.2f} min")

section("11. Dev test profile (p_394034825) under old and new formulas")
dev = S.new_player(np.random.default_rng(0), "free")
dev["passes"] = {"2xLogs", "2xLuck", "VIP", "BladeSlot", "FastRoll"}
dev["reb"] = 2; dev["lv"] = {k: 0 for k in S.UPG}; dev["power"] = 1834; dev["best_power"] = 1834; dev["wlen"] = 5.1; dev["isl_max"] = 2
dev["idx_logs"] = S.P["Index"]["Tree"]["Logs"]; dev["idx_luck"] = 0
old_lm = 2 * 1.1 * 1.5 * 1.05
new_lm = S.log_mult(dev)
old_luck = 2 * 1.1 * 1.2
new_luck = S.luck(dev)
print(f"LogMult old x{old_lm:.2f} -> M1 x{new_lm:.2f} ({new_lm / old_lm - 1:+.1%}); Luck old x{old_luck:.2f} -> M1 x{new_luck:.2f} ({new_luck / old_luck - 1:+.1%})")
print(f"Price tier: Power 1,834 + Frostbound unlocked -> tier {S.price_tier(dev)} (Unit {g(S.unit(dev))}); old price base = Frost Peaks crate 8.0M")
_, ts, inc = S.income(dev)
print(f"Income at the profile's current build (all upgrades at 0 after its rebirths, Crystal Wilds): old x{old_lm:.2f} -> M1 {g(inc * 3600)}/h")
for k, oldp, newp in (("Trait crate", 8e6, S.unit(dev) * S.P["Prices"]["TraitCrate"]),
                      ("Pet egg", 12e6, S.unit(dev) * S.P["Prices"]["PetEgg"]),
                      ("Next rebirth (3rd)", 9e6, S.rebirth_cost(2, dev))):
    old_inc = inc / new_lm * old_lm
    print(f"  {k:<18}: old {g(oldp):>7} = {oldp / old_inc / 60:6.1f} min of old income | M1 {g(newp):>7} = {newp / inc / 60:6.1f} min of M1 income")
print("  After re-buying chop upgrades (minutes of play) the same items cost far fewer minutes; see section 10 for typical builds.")

section("12. Balance failures and bottlenecks found by the model")
notes = []
if fa:
    if fa[-1]["area_mix"].get("CrystalCanyon", 0) > 0.5 and fa[-1]["power"][1] >= 2000:
        notes.append("Frostbound Reach (legacy Frost density 1/150) pays less than dense Crystal Wilds at every horizon: players stay in Crystal Wilds even after unlocking Frostbound (audit M8). Must be fixed by the Frostbound build density/rewards (M4b): see section 9.")
    if fa[-1]["first"]["Divine"][1] >= 1e8:
        notes.append("Free players do not reach a Divine weapon by rolling within 200 h at median (Divine gamma 0.5). Deterministic Divine route (forge, M2/M6) is still required.")
    if fa[-1]["souls"][1] > 20000:
        notes.append(f"Souls still accumulate: median {fa[-1]['souls'][1]:.0f} unspent at 200 h (more Soul sinks needed in later milestones).")
for n_ in notes: print(" - " + n_)
