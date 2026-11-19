# P1b.2 dense-forest proposal tooling (offline; no Studio writes)

Python 3 with numpy and scipy (matplotlib for `plot.py`). Run from this folder.

| File | Purpose |
|---|---|
| `sim.py` | Port of CombatServer/BladeConfig hit detection (20 Hz, 4 samples per blade, slack 1.3×Scale, 0.4 s per-blade cooldown, weak 10%, regrowth with re-roll). **Estimates only** |
| `gen.py` | Terrain grid loader, keep-outs, path channels, seeded hex-lattice zone placement, zone definitions |
| `layouts.py` | Builds options A / B / C from the v12 records (same 620 records for A and B) |
| `exp.py` | Sweep / 30-s walk / 120-s farm experiments → `results.json` |
| `spacing.py` | Trees per sweep against lattice spacing |
| `perf.py` | Totals and local (40 / 80-stud) parts, lights and emitters |
| `plot.py` | Blueprint images |
| `build_outputs.py` | Writes `dense_A.csv` (byte-identical to `docs/proposals/p1b2_dense_forest/…DENSE_A_PROPOSAL.csv`) |
| `terrain_grid_8stud.txt` | Read-only Studio raycast sample of the footprint (dev place v12) |
| `ydict_A.json` | Studio-raycast ground Y for every Option A spot |
| `current_manifest_v12_copy.csv` | Copy of `docs/p1b_tree_spots_crystal_wilds.csv` from `p1b2/crystal-wilds` (unchanged) |
