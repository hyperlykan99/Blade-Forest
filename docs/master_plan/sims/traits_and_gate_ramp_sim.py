# Blade Forest master plan: 12-trait crate odds and island strength-ramp check. Estimates only.
import math
old=[("Sapling",50,.25),("Woodcutter",28,.5),("Lumberjack",14,.75),("TimberTitan",6,1.0),("ForestWarden",1.8,1.5),("AncientRoot",.2,2.0)]
new=[("SwiftFeet",10,0),("KeenEdge",6,0),("SoulReaper",6,0),("MutationHunter",3,0),("Beastmaster",1,0),("FortuneBark",1,0)]
allt=old+new; tot=sum(w for _,w,_ in allt)
print("== 12-trait Logs crate odds (existing weights kept, new added)")
for n,w,b in allt: print(f"  {n}: {w/tot*100:.2f}%  (was {w:.2f}%)" if (n,w,b) in old else f"  {n}: {w/tot*100:.2f}% (new)")
eold=sum(w*b for _,w,b in old)/100; enew=sum(w*b for _,w,b in allt)/tot
print(f"  expected Logs bonus of one crate: old +{eold*100:.1f}%  new +{enew*100:.1f}%")
p=0.2/tot; print(f"  Ancient Root: 1 in {1/p:.0f} crates (was 1 in 500); median crates to first = {math.log(2)/p:.0f}")
print("  trait Logs sits in Permanent group (cap +600%): best single trait +200%, two slots (no duplicates) +350%")
print("\n== Strength ramp check: arrival Power vs island Common-tree Strength (WeakDamageMult 0.1 below Strength)")
for isl,gate,common,leg in [("Crystal Wilds (G2 cand.)",60,250,1400),("Crystal Wilds (current legacy gate)",250,250,1400),("Frostbound (G3 cand.)",500,2000,20000),("Frostbound (legacy gate)",2000,2000,20000)]:
    print(f"  {isl}: arrival Power {gate}, Common Strength {common} -> {'FULL damage' if gate>=common else 'x0.1 damage on every tree'}")
