"""Golden values for ServerStorage.M1Tests: computed with m1sim's formulas so the Luau
Economy module is checked against the simulator (parity). Prints a Luau table."""
import math, numpy as np
import m1sim as S

E = S.P
def soft(a, c): return S.soft(a, c)
out = {}
out["soft_2_6"] = soft(2, 6); out["soft_10_3"] = soft(10, 3)
# Logs: dev-like (2 rebirths, 2xLogs + VIP, tree index 5%)
perm = 0.05
base = (1 + soft(perm, 6)) * 1 * (1 + soft(0.25 * 2, 3)) * 2 * 1.1
out["logs_dev_base"] = base
out["logs_dev_event2"] = base * 2
# Logs: max build (AncientRoot x3, 3 Dragons, 20 rebirths, all index, SoulBlessing 20)
drag = [x for x in S.C["pets"] if x["Id"] == "Dragon"][0]
trait = [t for t in S.C["traits"] if t["Id"] == "AncientRoot"][0]
I = E["Index"]
idx_logs = 4 * (I["WeaponStandard"]["Logs"] + I["WeaponMastery"]["Logs"]) + 4 * I["Tree"]["Logs"]
idx_luck = 4 * (I["WeaponStandard"]["Luck"] + I["WeaponMastery"]["Luck"])
sb = S.SOUL["SoulBlessing"]["PerLevel"] * 20
permS = (trait["Mult"] - 1) + idx_logs + sb
out["logs_max_base"] = (1 + soft(permS, 6)) * (1 + soft(3 * drag["Logs"], 3)) * (1 + soft(0.25 * 20, 3))
# Luck: dev-like (luck lvl 0, 2 rebirths, group, 2x Luck)
out["luck_dev"] = (1 + soft(0.10 * 2 + 0.10, 4)) * 2
out["luck_max_mega"] = min((1 + soft(0.04 * 100 + 0.1 * 20 + idx_luck + 0.1 + 3 * drag["Luck"] + S.SOUL["SoulFortune"]["PerLevel"] * 20, 4)) * 2 * 10, 50)
out["eff_divine_50"] = 10_000_000 / 50 ** 0.5
out["eff_myth_10"] = 1_000_000 / 10 ** 0.75
for isl in S.ISL_ORDER:
    out["pool_" + isl] = len(S.altar_pool(isl))
pr = S.roll_probs(1.0, "TimberHaven"); out["p_th_luck1_rarest"] = float(pr[S.WIDX[S.altar_pool("TimberHaven")[0]]])
out["th_rarest_id"] = S.altar_pool("TimberHaven")[0]
pr = S.roll_probs(10.0, "CrystalWilds"); out["p_cw_luck10_sum"] = float(pr.sum())
out["rebirth_2_12M"] = max(E["Rebirth"]["MinCost"], math.floor(E["Rebirth"]["Units"] * E["Rebirth"]["Growth"] ** 2 * 12e6))
out["cost_walk_24"] = S.upg_cost("WalkSpeed", 24); out["cost_luck_0"] = S.upg_cost("Luck", 0); out["cost_renewal_19"] = S.upg_cost("Renewal", 19)
out["king_12M_half_lm4"] = math.floor(E["Bosses"]["BladeKing"]["LogsUnits"] * 12e6 * 4 ** E["Bosses"]["LogMultExponent"])
def lua(v):
    if isinstance(v, str): return '"' + v + '"'
    return repr(float(v)) if not float(v).is_integer() else str(int(v))
print("local G = {\n" + "".join(f"\t{k} = {lua(v)},\n" for k, v in out.items()) + "}")
