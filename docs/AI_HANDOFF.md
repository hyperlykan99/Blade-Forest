# AI Handoff — read this first

_Last updated: 2026-11-18 by Claude_

## Who does what

- **Claude** is the primary developer. It edits the live place through the Roblox Studio MCP and updates this file after every significant change.
- **ChatGPT** is the planner and reviewer. It writes plans into `TASKS.md` and does not edit code.
- **Codex** is a coding and debugging helper. It works on a branch and opens a PR. Claude applies merged code to the place.

## Source of truth

The source of truth is the Roblox place (`73142469975141`, Team Create) until the scripts are exported into `src/`. After export and Rojo setup, `src/` becomes the source of truth for code. Models, terrain and UI layout always stay in the place.

## Hard rules

1. **Server decides.** Rewards, costs and rolls run on the server. Clients send requests through remotes.
2. **Saves:** a new save field goes in `DataService.DEFAULT`. `reconcile` back-fills old saves. Never rename or remove fields.
3. **Assets come from the Creator Store.** Don't build custom models. Terrain and UI are fine.
4. **Edit in Edit mode only.** Script edits made during Play mode are lost.
5. No force-push. No secrets in the repo.

## Architecture

| Location | Scripts |
|---|---|
| ServerScriptService | CombatServer, WorldServer, DataService, RollService, AreaService, PvPService, SoulService, TraitService, StoreService, Progress, AFKService, MetaService, LeaderboardService, ExtrasService |
| ReplicatedStorage | BladeConfig (all tuning data), UIIcons, UITheme |
| StarterPlayerScripts | BladeEffects, RollController, IndexController, ChopEffects, AutoChop, PvPSoulController, TraitsController, StoreController, UIStyler, AFKController, MetaController, TutorialController, HudExtras, ExtrasController |
| StarterGui.GameUI | UIController |
| ServerStorage | SwordTools, TreeKit |

**Remotes** (ReplicatedStorage): ShopAction, Hits, Shatter, Reward, Notify, DataSync, GetData, Roll, SoulReward, PvPToggle, SoulShop, TraitAction, Meta, AFKRejoin, Leaderboards. `Extras` is created at runtime by ExtrasService.

## UI conventions

- **UIStyler** builds the side docks from the `TILES` list. A button's parent must be a ScreenGui. A `Badge` attribute shows a counter.
- **Compact mode** applies when `(TouchEnabled and not KeyboardEnabled) or viewport.Y < 560`.
- `T.Panel(...)` gives the wood skin and makes only one panel open at a time.
- Toasts: fire `GameUI.HudNotice`.
- Timers and bars: use `UITheme.AttachToHud(widget, "StatusRail"|"Toasts")`.
- Don't name new buttons after existing TILES (this happened before with `BladesButton`; the new one became `BladeToggle`).
- RollBar already has a UIScale. Change `barScale` in RollController; don't add a second UIScale.

## Tree templates

Tree templates are in `ReplicatedStorage.TreeModels`:

- Pivot at the trunk base.
- An invisible `Hitbox` is the PrimaryPart, with `PivotOffset = (0, -h/2, 0)`.
- Attributes: `TreeType`, `LeafColor`.

## Studio-only test hooks (ServerStorage)

These do nothing in live servers.

- `DevGrant:Invoke(player, fnName, ...)`
- `DevStore:Invoke(player, "Pass"|"Product", id)`
- `DevMeta:Invoke("Event", id)`
- `DevExtras:Invoke("Treant")`

## Gotchas

- In plugin or command-bar context, `require` caches modules. Clone the module and require the clone to test edits.
- If DataStores are blocked in Studio, LeaderboardService clears itself. That's expected.
- Some Creator Store assets are unusable: the camp asset turned out to be a jeep, the unicorn rig breaks when scaled, and the 1,570-part cherry tree is too heavy. Check part count and rig before using an asset.

## Security review (2026-11-18)

- No API keys, tokens, cookies or webhook URLs were found in the scripts.
- Pass, product, group and place IDs are public and safe to commit.
- The dev hooks in StoreService, MetaService and ExtrasService are gated to Studio with `RunService:IsStudio()`.
- ⚠️ **Suspected backdoor scripts were found in Creator Store imports.** There are 14 ModuleScripts named `LightConfig.Type` (plus similar ones such as `…Runtime.RuntimeInput…ScreenBuilder`) nested deep inside models in `ServerStorage.NPCImports`, `PetImports`, `TreeImports`, `TreeImports2`, `WeaponImports2/3` and `BoardTemplate`. They pose as a 2013 "type library", a known malware disguise. **They are currently inert:** ServerStorage doesn't run scripts, no game script references these folders, and the templates in use (ReplicatedStorage, Workspace) contain no foreign scripts.
- Rule: never clone anything from the `*Imports` folders into Workspace or ReplicatedStorage. When importing a new asset, strip every `LuaSourceContainer` inside it first.

## Last session

- Set up the repo skeleton and docs.
- No gameplay changes.
- Next step: export the scripts into `src/` (see TASKS.md, "Repo sync").
