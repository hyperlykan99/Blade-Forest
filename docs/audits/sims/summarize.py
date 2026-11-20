import json, sys, os
HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
def f(x):
    a=abs(x)
    if a>=1e12: return f"{x/1e12:.2f}T"
    if a>=1e9: return f"{x/1e9:.2f}B"
    if a>=1e6: return f"{x/1e6:.2f}M"
    if a>=1e3: return f"{x/1e3:.1f}K"
    return f"{x:.2f}"
for sc in sys.argv[1:] or ["free_active","free_afk","free_idle","paid_active","whale_active"]:
    R=json.load(open(os.path.join(HERE, f"res_{sc}.json")))
    print("==",sc)
    for r in R:
        t=lambda k: "/".join(f(v) for v in r[k])
        print(f"{r['h']:>5}h earned {t('earned')} | inc/h {t('income')} | pow {t('power')} | reb {t('reb')} | LogMult {t('logmult')} | luck {t('luck')} | rolls {t('rolls')} | blades {t('blades')} dmg {t('dmg')} luckLv {t('luck_lv')} | pets {t('pets')} | souls {t('souls')} | trees/s {t('trees_s')} | tidx {t('tidx')} idx {t('idx')} | area {r['area_mix']} trait {r['trait']}")
    r=R[-1]
    tm=lambda k: "/".join(("-" if v>1e8 else f"{v*60:.0f}m" if v<2 else f"{v:.1f}h") for v in r[k])
    print("  milestones (p10/p50/p90): Pine", tm("t_pine"), " Crystal", tm("t_crystal"), " Frost-power", tm("t_frost"))
