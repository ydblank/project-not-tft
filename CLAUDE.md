# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Project Not TFT clone": a 2D top-down arena fighter in **Godot 4.7** (GDScript, Mobile renderer). Main scene is `assets/levels/node_2d.tscn`. Feature behaviour is documented per feature in [docs/](docs/README.md); read the matching doc before changing a feature and update it in the same commit.

## Commands

Godot lives at `/Applications/Godot.app/Contents/MacOS/Godot` (not on `PATH`).

```bash
/Applications/Godot.app/Contents/MacOS/Godot -e --path .      # open the editor
/Applications/Godot.app/Contents/MacOS/Godot --path .         # run the game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit   # smoke-load: catches script / scene load errors
```

**Tests** are `McpTestSuite` scripts in `tests/` (`test_*` methods, `assert_*` helpers, `suite_name()`). There is no CLI runner: run them through the `godot_ai` addon's `run_tests` MCP tool with the editor open (filter by suite or test name to run one). After editing a script that tests `preload`, restart the editor, because Godot's preload cache goes stale and a green run can be misleading.

## Architecture

### Combat pipeline

A fighter is a `CharacterBody2D` whose behaviour lives in child component nodes (`assets/scenes/*_component.*`, `assets/combat/combat_component.*`) wired together with `@export` node references. Each physics frame:

1. A **controller** writes a `CombatIntent` (held buttons plus move / aim direction). `PlayerController` reads input; `AIComponent` is the bot brain. Both produce the same intent type, so a fighter can change hands at runtime (see `ControlSwitcher`, `LocalCoop`).
2. `CombatComponent` ticks the **`ActionStateMachine`**, which is pure logic: no nodes, no input singletons. Keep it that way, because the unit tests construct it directly.
3. `CombatComponent` applies the machine's events (VFX, projectiles, hitbox window), computes velocity, and calls `MovementComponent.drive()`.
4. Incoming hits arrive at `HitboxComponent`, which applies damage and then calls `CombatComponent.receive_reaction()`.

Weapons are data: `WeaponData` and `AttackMove` resources (`assets/combat/weapons/*.tres`), looked up through the `Weapons` registry (`assets/resources/weapons.gd`). Tuning a weapon means editing a `.tres`, not code.

### Level tools

`node_2d.tscn` is the arena. Match rules are small sibling nodes under its root, each with one script and one job (`FightCountdown`, `EnemyRespawner`, `BotToggle`, `TeamSize`, `ControlSwitcher`, `LocalCoop`, `ArenaBounds`, `CameraFollow`, ...). They find fighters through **groups**: `players`, `allies`, `enemies`, `dummies`, `ai_fighters`. Put new match rules in a new sibling node rather than growing an existing one.

### Autoloads and tuning

- `Combat` (`assets/commons/combat.gd`): damage formulas (static, unit-tested) and global hit-stop.
- `Sfx` (`assets/commons/sfx.gd`): all sound goes through `Sfx.play(&"name")`; the name-to-file table is `SOUNDS`.
- `Noray`, `PacketHandshake` (netfox) and `_mcp_game_helper` (godot_ai) come from `addons/`.
- Live-tunable values flow `DevSettings.DEFS` (the table and the saved file) → `PauseMenu` (sliders) → `DevTuning` (pushes values into the running game). A new tunable needs a row in `DEFS` and an apply step in `dev_tuning.gd`.

Multiplayer (`MultiplayerManager`, `MultiplayerComponent`) is partial and not networked for combat.

## Coding standard

Follow the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html). The points most often missed:

- **Naming:** `snake_case` for files, folders, functions, variables and signals; `PascalCase` for `class_name` and node names; `CONSTANT_CASE` for constants and enum members; signals in the past tense; a leading `_` for private members and virtual callbacks.
- **Script order:** `@tool` → `class_name` → `extends` → `##` doc comment → signals → enums → constants → `@export` → public vars → private vars → `@onready` → `_init` / `_ready` / `_process` → public methods → private methods → inner classes.
- **Format:** tabs for indentation (the `.editorconfig` sets only UTF-8; Godot's editor default is tabs), static types on exports, parameters and returns, `##` comments on exported variables and public methods, two blank lines between functions.
- **Style used here:** short comment block under `extends` saying what the script owns, magic numbers lifted into documented `const`s (see the top of `combat_component.gd`).
- **Existing exceptions** (do not copy): `Attack.gd` and `MultiplayerManager.gd` use PascalCase file names.

## Folder structure

Godot's own guidance ([project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)): group files by feature, keep a scene next to its script, `snake_case` names everywhere (avoids case-sensitivity breakage when exporting from Windows or macOS to Linux), third-party code only in `addons/`.

Target layout for new work:

```
res://
├── addons/            third-party plugins only, never edited here
├── assets/            raw art, audio and fonts (no scripts)
├── <feature>/         one folder per feature: scene + script + its resources together
├── docs/              feature docs (see docs/README.md)
└── tests/             McpTestSuite scripts, named test_<feature>.gd
```

**The repo does not match this yet.** Scripts, scenes and resources currently live in feature folders *under* `assets/` (`assets/combat`, `assets/characters`, `assets/levels`, `assets/scenes` (components), `assets/ui`, `assets/dev`, `assets/effects`, `assets/commons` (autoloads), `assets/resources`, `assets/objects`), beside the raw art in `assets/art` and `assets/audio`. Until a dedicated migration happens, put new files in the matching existing folder instead of scattering a second layout, and never move files by hand: do it in the Godot FileSystem dock so scene references and `.uid` files are updated.

## Gotchas

- Commit the `.uid` file with every script and shader: scenes reference scripts by UID.
- `*.tmp` files next to scenes (for example `player_character.tscn1002027093.tmp`) are editor leftovers that were committed by accident. Do not edit them or add more.
- `sfx/` at the repo root holds raw licensed sound packs; it is git-ignored. Only the files in `assets/audio/sfx/` belong in the game.
- Never edit `addons/`: `godot_ai` and `netfox.*` are third-party.
- The `tests/` suites extend `McpTestSuite` from the `godot_ai` addon, so they only run where that plugin is enabled.
