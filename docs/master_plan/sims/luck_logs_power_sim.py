# Blade Forest master plan: luck, Logs, power, Divine-route and save-size model.
# Inputs mirror BladeConfig (branch p1b2r/camera-visibility-fix @ d222d98). Estimates only.
# Run: python3 luck_logs_power_sim.py
import math
# ---------- current config (verified from BladeConfig) ----------
ONEIN = dict(Wooden=2, RustySickle=3, FarmhandScythe=4, LumberHatchet=6, WoodsmanAxe=9,
 Iron=25, WillowScythe=35, RoninKatana=50, BoneScythe=70, EngravedAxe=100,
 Golden=250, EmberHatchet=350, Emerald=500, BloodvineScythe=700, SilverLabrys=1000,
 RedcliffAxe=2500, Frost=3500, WarlordAxe=5000, CrimsonCrescent=7000, GlacierFang=10000,
 Bloodthorn=25000, Inferno=35000, VenomfangAxe=50000, BonewhiteReaper=70000, SunsteelSword=100000,
 SoulfireScythe=250000, MagmaHook=350000, Void=500000, Umbraxe=700000, ShadowKatana=1000000,
 Starbreaker=1500000, StarfallReaper=2500000, Galaxy=4000000, PrismSaber=6500000, Celestial=10000000,
 GlacialEdge=15000000, Dragonflame=25000000, SeraphsLight=50000000, FrostboundReaper=100000000)
pool = sorted([(k,v) for k,v in ONEIN.items() if k!='Wooden'], key=lambda x:-x[1])
def eff(o, L): return o if o<=10 else max(o/max(L,1),1)
def cascade(L, poolx=pool):
    surv=1.0; res={}
    for k,o in poolx:
        p=1/eff(o,L); res[k]=surv*p; surv*=(1-p)
    res['Wooden']=surv; return res
print("== Current cascade: displayed vs actual (luck 1) for commons")
r=cascade(1)
for k in ['Wooden','RustySickle','FarmhandScythe','LumberHatchet','WoodsmanAxe','Iron']:
    print(f"  {k}: shown 1/{ONEIN[k]}  actual 1/{1/r[k]:.1f}")
# current luck stack
def cur_luck(upg=1, pots=(), pass2x=False, reb=0, group=True, pet=0, idx=0, event=1):
    L=upg
    for p in pots: L*=p
    if pass2x: L*=2
    L*=(1+0.1*reb)*(1.1 if group else 1)*(1+pet)*(1+0.1*idx)*event
    return L
arche = {
 'Free early (D1)':      dict(upg=1.5, idx=0, pet=0.0),
 'Free mid (D7)':        dict(upg=3.0, idx=2, pet=0.3, pots=(3,)),
 'Free max (no rebirth)':dict(upg=6, idx=3, pet=1.5, pots=(3,2), event=5),
 'Heavy payer':          dict(upg=3.0, idx=2, pet=0.3, pots=(10,3), pass2x=True),
 'Max everything':       dict(upg=6, idx=3, pet=1.5, pots=(10,3,2), pass2x=True, event=5),
}
print("\n== Current luck stack")
for n,a in arche.items(): print(f"  {n}: x{cur_luck(**a):,.0f}")
# expected hours to first item of a tier with current pool (roll every 1.1 s auto, 0.6 fast)
tiers = {'Legendary':['Bloodthorn','Inferno','VenomfangAxe','BonewhiteReaper','SunsteelSword'],
 'Mythic':['SoulfireScythe','MagmaHook','Void','Umbraxe','ShadowKatana'],
 'Secret':['Starbreaker','StarfallReaper','Galaxy','PrismSaber','Celestial'],
 'Divine':['GlacialEdge','Dragonflame','SeraphsLight','FrostboundReaper']}
def hours_to(tier, L, interval):
    r=cascade(L); p=sum(r[k] for k in tiers[tier]); 
    return interval/p/3600 if p>0 else float('inf')
print("\n== Current: expected play-hours to first item of tier (auto-roll)")
print("  archetype | luck | Legendary | Mythic | Secret | Divine")
for n,a in arche.items():
    L=cur_luck(**a); iv=0.6 if 'Heavy' in n or 'Max every' in n else 1.1
    print(f"  {n} | {L:,.0f} | " + " | ".join(f"{hours_to(t,L,iv):.3g}" for t in tiers))
# ---------- proposed luck model ----------
# Permanent group additive-capped, temporary = max (not product), pass x2 kept, global hard cap, tier exponents
EXP = {'Common':1,'Uncommon':1,'Rare':1,'Epic':1,'Legendary':0.9,'Mythic':0.75,'Secret':0.6,'Divine':0.5}
CAP = 50.0
def new_luck(upg_bonus=0, reb=0, group=True, pet=0, idx=0, temp=(), pass2x=False, event=1):
    perm = 1 + min(upg_bonus + 0.05*reb + (0.1 if group else 0) + pet + 0.05*idx, 4.0)  # perm cap 5x
    t = max([1]+list(temp)+[event])
    L = perm * t * (2 if pass2x else 1)
    return min(L, CAP)
arche_new = {
 'Free early (D1)':       dict(upg_bonus=0.25),
 'Free mid (D7)':         dict(upg_bonus=1.0, idx=4, pet=0.3, temp=(3,)),
 'Free max':              dict(upg_bonus=2.5, reb=10, idx=12, pet=1.0, temp=(3,), event=5),
 'Heavy payer':           dict(upg_bonus=1.0, idx=4, pet=0.3, temp=(10,), pass2x=True),
 'Max everything':        dict(upg_bonus=2.5, reb=10, idx=12, pet=1.0, temp=(10,), pass2x=True, event=5),
}
print("\n== Proposed luck (perm additive cap x5, temp = strongest one, pass x2, hard cap 50)")
for n,a in arche_new.items(): print(f"  {n}: x{new_luck(**a):.1f}")

# ---------- proposed per-island altar ladder (32 rollable per island) ----------
LADDER = [('Common',[2,3,4,6,9]),('Uncommon',[25,35,50,70,100]),('Rare',[250,350,500,700,1000]),
 ('Epic',[2500,3500,5000,7000,10000]),('Legendary',[25000,40000,60000,100000]),
 ('Mythic',[250000,400000,600000,1000000]),('Secret',[1500000,4000000,10000000]),('Divine',[50000000])]
items=[(r,o) for r,os in LADDER for o in os]
print("\n== Proposed altar: items per island =", len(items))
def eff2(r,o,L):
    if o<=10: return o
    return max(o/ max(L,1)**EXP[r], 1)
def cascade2(L):
    srt=sorted(items,key=lambda x:-x[1]); surv=1; res={}
    for r,o in srt:
        p=1/eff2(r,o,L); res[(r,o)]=surv*p; surv*=1-p
    return res
def hours_tier2(tier,L,iv):
    c=cascade2(L); p=sum(v for (r,o),v in c.items() if r==tier)
    return iv/p/3600
print("  archetype | luck | Legendary | Mythic | Secret | Divine  (hours of auto-roll at ONE island altar)")
rows=[]
for n,a in arche_new.items():
    L=new_luck(**a); iv=0.6 if ('Heavy' in n or 'Max every' in n) else 1.1
    hs=[hours_tier2(t,L,iv) for t in ['Legendary','Mythic','Secret','Divine']]
    rows.append((n,L,hs))
    print(f"  {n} | {L:.1f} | " + " | ".join(f"{h:.3g}" for h in hs))
# gap: heavy vs free mid
fm=[r for r in rows if r[0]=='Free mid (D7)'][0][2]; hp=[r for r in rows if r[0]=='Heavy payer'][0][2]
print("  heavy/free-mid speedup per tier:", [round(a/b,1) for a,b in zip(fm,hp)])
fm_c=[hours_to(t,cur_luck(**arche['Free mid (D7)']),1.1) for t in tiers]; hp_c=[hours_to(t,cur_luck(**arche['Heavy payer']),0.6) for t in tiers]
print("  CURRENT heavy/free-mid speedup per tier:", [round(a/b,1) for a,b in zip(fm_c,hp_c)])

print("\n== Logs multiplier stack")
def cur_logs(boost=1, pass2x=False, vip=False, trait=1, reb=0, pvp=False, pet=0, idx=1, tidx=1, ev=1):
    return boost*(2 if pass2x else 1)*(1.1 if vip else 1)*trait*(1+0.25*reb)*(1.5 if pvp else 1)*(1+pet)*idx*tidx*ev
print("  current free max (no rebirth):", round(cur_logs(trait=3,pvp=True,pet=6,idx=1.4,tidx=1.2,ev=2)))
print("  current paid max (no rebirth):", round(cur_logs(boost=2,pass2x=True,vip=True,trait=3,pvp=True,pet=6,idx=1.4,tidx=1.2,ev=2)))
print("  current paid max, 10 rebirths:", round(cur_logs(boost=2,pass2x=True,vip=True,trait=3,reb=10,pvp=True,pet=6,idx=1.4,tidx=1.2,ev=2)))
def new_logs(perm_bonus=0, pet=0, temp=(), pass2x=False, vip=False):
    perm = 1 + min(perm_bonus + (0.1 if vip else 0), 6.0)     # trait, rebirth, index, mastery: additive, cap +600%
    petm = 1 + min(pet, 3.0)                                   # pets: additive, cap +300%
    t = max([1]+list(temp))                                    # strongest temporary boost only
    return perm*petm*t*(2 if pass2x else 1)
print("  proposed free max:", round(new_logs(perm_bonus=6, pet=3, temp=(2,))))
print("  proposed paid max:", round(new_logs(perm_bonus=6, pet=3, temp=(2,), pass2x=True, vip=True)))
print("  proposed free D7-ish:", round(new_logs(perm_bonus=1.0, pet=0.5)), " paid D7-ish:", round(new_logs(perm_bonus=1.0, pet=0.5, temp=(2,), pass2x=True, vip=True)))
print("  current  free D7-ish:", round(cur_logs(trait=1.5,pet=0.5,idx=1.2,tidx=1.05)), " paid D7-ish:", round(cur_logs(boost=2,pass2x=True,vip=True,trait=1.5,pet=0.5,idx=1.2,tidx=1.05)))

print("\n== Power stack per weapon")
print("  current: star 2.5 x shiny 1.5 =", 2.5*1.5)
print("  proposed: star 2.5 x shiny 1.5 x awakening 1.6 =", 2.5*1.5*1.6, "(runes/forge do NOT raise Power)")

print("\n== Deterministic Divine route (Altar Essence, 1 per roll; recipe 100k + boss materials)")
for n,iv in [('free auto 1.1 s',1.1),('Fast Roll 0.6 s',0.6)]:
    print(f"  {n}: {100000*iv/3600:.1f} h of rolling")

print("\n== Save size estimate (JSON)")
w = '{"Copies":12,"Star":5,"Shiny":true,"Fav":true,"Aw":3,"Runes":["r1","r2","r3"],"Seen":1,"Pulled":1}'
print("  per weapon entry ~", len(w)+20, "bytes; 120 weapons ~", (len(w)+20)*120//1024, "KB; full profile est < 60 KB vs 4 MB key limit")
