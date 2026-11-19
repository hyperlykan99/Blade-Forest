# Blade-Forest

A Roblox simulator where players spin orbiting blades to chop trees, roll for weapons, collect pets, and fight bosses across a growing forest world.

| | |
|---|---|
| Place ID | `73142469975141` |
| Universe ID | `10777481912` |
| Group ID | `76836496` |
| Engine | Roblox Studio (Team Create), Luau |
| Sync tool | [Rojo](https://rojo.space) 7.5+ |

## Team roles

- **Claude** is the primary developer. It edits the live place through the Roblox Studio MCP and keeps this repo in sync.
- **ChatGPT** handles game design, planning and progress reviews. It reads `docs/` first.
- **Codex** may help with coding and debugging. It works through pull requests against `src/`.

Before starting work, every contributor (human or AI) reads `docs/AI_HANDOFF.md`.

## Repository layout

```
default.project.json   Rojo project: maps src/ to the Roblox data model
src/
  server/              ServerScriptService scripts (*.server.luau)
  shared/              ReplicatedStorage modules (BladeConfig, UITheme, UIIcons)
  client/              StarterPlayerScripts (*.client.luau)
  gui/                 StarterGui.GameUI scripts
  serverstorage/       ServerStorage modules (SwordTools, TreeKit)
docs/
  GAME_DESIGN.md       What the game is and how its systems fit together
  CURRENT_STATUS.md    What works, what is live, known issues
  CHANGELOG.md         Dated history of changes
  AI_HANDOFF.md        Read first: conventions, gotchas, how to work safely
  TASKS.md             Backlog and owner action items
```

Models, terrain, meshes and UI layouts are **not** stored here; they live in the place file. Only code is synced. Keep `.rbxl` and `.rbxlx` files out of Git (see `.gitignore`).

## Working with the code

1. Install Rojo (`aftman add rojo-rbx/rojo` or download a release) and the Rojo Studio plugin.
2. Run `rojo serve`, then click **Connect** in the Studio plugin.
3. Edit files in `src/`; they sync into Studio live.
4. Playtest in Studio, then commit and push.

To pull changes that were made directly in Studio back into files, save the place locally as `BladeForest.rbxl` and run:

```
rojo syncback --input BladeForest.rbxl
```

## Rules

- Never commit secrets: no API keys, Open Cloud keys, `.ROBLOSECURITY` cookies or webhook URLs. Store secrets in Roblox's Secrets store.
- Do not force-push `main`. Use branches and pull requests for anything non-trivial.
- The server decides all rewards and costs. Clients only request.
