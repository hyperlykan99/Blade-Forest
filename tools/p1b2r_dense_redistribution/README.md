# P1b.2r — dense-forest redistribution tooling (Option A)

Studio command-bar scripts (Edit mode, dev place 103379930563763 / universe 10777797608 only). Both assert PlaceId and GameId.

| File | Purpose |
|---|---|
| `move.luau` | The move exactly as executed. All-or-nothing, idempotent (a second run prints `NO-OP`), PivotTo only, keeps each tree's rotation, verifies, reverts in place on failure |
| `rollback.luau` | Returns the 620 trees to their **exact** pre-move pivots from `ServerStorage.P1bBackups.P1b2r_PreMoveSnapshot`. `DRY_RUN = true` by default; dry run verified OK after the move (620 trees, rotations identical) |

**Data, in Studio and in git:**

| Item | In Studio | In git | Size / checksum |
|---|---|---|---|
| Move map (`srcRow,srcX,srcZ,srcRotDeg,dstX,dstY,dstZ,zone`, rows `;`) | `ServerStorage.P1bBackups.P1b2r_MoveMap` | `docs/p1b2r/p1b2r_move_map.txt` | 25,085 bytes, Adler-32 3646164357 |
| Exact pre-move snapshot | `ServerStorage.P1bBackups.P1b2r_PreMoveSnapshot` (Part1–4) | `docs/p1b2r/p1b2r_premove_snapshot_exact.csv` | Body 57,147 bytes, Adler-32 376139445 |

The Studio snapshot is JSON with full `CFrame:GetComponents()` at %.17g, plus every attribute except Color3 values (JSON cannot store `LeafColor`). The git copy has x, y, z and rotY at %.9g, plus scale, type, mutation, health, strength, reward, respawn, and part / emitter / light counts.

**Rollback:**
- Preferred: Version History → **v14 "P1b.2r PRE-DENSE-REDISTRIBUTION"**.
- Alternative: `rollback.luau` with `DRY_RUN = false`, then save.
