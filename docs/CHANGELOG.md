# Changelog

## Unreleased

- **Arena enlarged** to 31 x 15 tiles (GAM-80, part 1). Walls and obstacles that block projectiles are still to do. → [Fight flow](features/fight-flow.md)
- **Camera:** the controlled fighter is always kept inside a comfort zone, so the camera tracks you in the bigger arena. → [Game feel](features/game-feel.md)
- **AI:** fixed the bot freezing or jittering left-right when the player is very close (stable direction when overlapping, ramped back-off, edge sliding, engage hysteresis). → [AI](features/ai.md)
- **Out-of-arena bubble** now appears on the side the fighter left through. → [UI and dev tools](features/ui-and-dev-tools.md)
- **Pause:** Esc now also stops the 3-2-1 start countdown timer. The pause menu shows a "change #" number to identify the build.

## v2.2

Combat, AI and game-feel overhaul, since commit `ecd4e25`.
Tests: 75 passing (`tests/`: combat data, combat state machine, dev settings, sound table).

### Highlights

- **Controls:** start as the Knight; **R** switches to your teammate; local 2-player mode. → [Controls](features/controls.md)
- **Fight flow:** 3-2-1 countdown, lives, respawning enemies, AI Bots and 2v2 / 1v1 toggles, hideable dummy. → [Fight flow](features/fight-flow.md)
- **Combat:** reworked melee combos with combo lock, rebalanced bow, parry, shield, heavy super armor, attack clashes, triple dash with i-frames. → [Combat](features/combat.md)
- **AI:** dodging, arena-edge awareness, combo breaker, punish dash, smarter targets, teamwork, adaptation. → [AI](features/ai.md)
- **Game feel:** freeze frame, camera shake, hit and block effects, gentle camera follow, depth sorting. → [Game feel](features/game-feel.md)
- **Sound:** sound effects with variety, SFX and Music volume sliders. → [Sound](features/sound.md)
- **UI and dev tools:** controller overlay, out-of-arena camera bubble, cooldown spinners, pause menu with live-tunable settings. → [UI and dev tools](features/ui-and-dev-tools.md)

### New files

| Area | Files |
|---|---|
| Characters | `assets/characters/ally_archer.tscn`, `ally_character.gd`, `enemy_archer.tscn` |
| Level | `assets/levels/arena_bounds.gd`, `enemy_respawner.gd`, `loadout_switcher.gd`, `fight_countdown.gd`, `control_switcher.gd`, `camera_follow.gd`, `dummy_toggle.gd`, `out_of_arena_indicator.gd`, `local_coop.gd`, `bot_toggle.gd`, `team_size.gd` |
| Dev tools | `assets/dev/dev_settings.gd`, `dev_tuning.gd`, `pause_menu.gd` |
| Effects | `assets/effects/hit_fx.gd`, `block_visual.gd`, `team_tint.gdshader` |
| Sound | `assets/commons/sfx.gd` (the `Sfx` helper), `assets/audio/sfx/` (the sound files) |
| Tests | `tests/test_dev_settings.gd`, `tests/test_sfx.gd` |

### Main files changed

- `assets/combat/action_state_machine.gd`: dash charges, combos, combo lock helpers, charge-through-dash
- `assets/combat/combat_component.gd`: stun rules, arena slow, combo lock, lunge / strafe handling
- `assets/combat/player_controller.gd`: lunge limit
- `assets/combat/weapon_data.gd`, `hit_data.gd` and the sword / dagger / bow `.tres` files
- `assets/scenes/ai_component.gd`, `hitbox_component.gd`, `animation_component.gd`
- `assets/effects/slash.gd`, `assets/ui/controls_hint.*`, `assets/levels/node_2d.tscn`

Known limitations are listed at the bottom of each feature doc.
