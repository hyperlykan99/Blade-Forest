# P1b.2 Crystal Wilds — build tooling

Studio command-bar scripts (Edit mode) that record how Crystal Wilds was built in
**Blade Forest - Island Dev** (Place 103379930563763 / Universe 10777797608).
Every script starts with `_guard.luau` (PlaceId + GameId assert) and has a run-twice guard.

| Script | Stage | Reproducibility |
|---|---|---|
| `B_terrain.luau` | Terrain: slab, Crystal Canyon core CopyRegion → PasteRegion (+2756 X), hills, paths, flat zones; pre-build TerrainRegion snapshot | Slab/core/paths/flats exact; hill noise pass is a parameter-faithful reference (voxels not checksummed) |
| `C_plaza_bounds.luau` | Persistent arrival plaza, return pad, rim walls; backs up + removes P1a test model | Geometry, attributes, prompt exact; cosmetic material/colour approximate |
| `D_trees_replay.luau` | Rebuilds the 620 v12 (sparse) trees from `docs/p1b_tree_spots_crystal_wilds_v12_sparse.csv` (checksum-verified). Superseded by P1b.2r; see tools/p1b2r_dense_redistribution | Exact |
| `E_light_budget.luau` | Disables 14 Frozen-mutation lights on new trees (reversible, `REVERT = true`) | Exact |
| `rollback.luau` | Manual rollback (terrain snapshot, bounds-based tree removal, restore P1a model) | — |

Authoritative state = saved place version **12**. Pre-build checkpoint = version **9**.
Tree manifest: 620 rows, 22454 bytes, Adler-32 **308787882** (no trailing newline), sorted by X then Z.
