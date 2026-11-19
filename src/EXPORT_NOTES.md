# Script export (P0)

- **Source:** offline backup `BladeForest_ORIGINAL_73142469975141_2026-11-18_PRE_ISLANDS.rbxl`, SHA-256 `e050c6c36bf177a1629e94c09bdefd75ee4d3c7dd869e9858603c29556d64ffd`. Read with a read-only parser. Nothing was written to Studio.
- **Exported:** 34 scripts, 393,047 bytes. Per-file SHA-256 is in `EXPORT_MANIFEST.json`.
- **Verified:** every file matches live Studio (place 73142469975141) by length and Adler-32 checksum, 34 of 34.
- **Excluded:** 152 script containers inside unused Creator Store import folders (ServerStorage `NPCImports` 69, `PetImports` 22, `WeaponImports3` 21, `WeaponImports2` 20, `TreeImports2` 13, `BoardTemplate` 4, `TreeImports` 3). They include the suspected backdoor `LightConfig.Type` modules. They were not exported and not executed.
- **Rojo:** `default.project.json` now sets `$ignoreUnknownInstances` everywhere, so a sync cannot delete maps, models, UI or import folders. `GameUI` is declared as a `ScreenGui`.
  - A live Rojo round trip was **not** run, because Rojo isn't installed and syncing is out of scope for P0.
  - **Never `rojo serve` into the original place.** Use the dev experience only.
- **Not included:** models, terrain, UI layout and other non-script instances. They exist only in the place file and the private backup.
