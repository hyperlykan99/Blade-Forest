import sim, json, sys, os
sim.DENSITY["FrostPeaks"] = 1/31
sim.DENSITY["PineForest"] = 1/31
sim.DENSITY["StarterGrove"] = 1/31
res = sim.summarize(sim.simulate("free", "active", 72, 30, seed=7, checkpoints=(0.5, 2, 8, 24, 72)))
json.dump(res, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "results", "res_sens_dense.json"), "w"), default=float)
