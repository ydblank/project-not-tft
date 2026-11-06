# Changelog

## Unreleased

- **Arena enlarged** to 31 x 15 tiles (GAM-80, part 1). → [Fight flow](features/fight-flow.md)
- **Cover walls** inside the arena (GAM-80, part 2): four 2 x 2 pillar blocks and a 1 x 5 centre column, drawn with the tileset's stone-pillar tiles, that block projectiles and movement, so you can hide from ranged attacks. → [Fight flow](features/fight-flow.md)
- **Wall impacts:** arrows, fireballs and melee swings that hit a wall now show stone chips and play a dull thump layered with a stone hit (GAM-80, part 3). → [Game feel](features/game-feel.md)
- **Fix:** standing on the edge of the bottom wall no longer counts as "outside the arena" (no more damage there). → [Fight flow](features/fight-flow.md)
- **Camera:** it no longer leaves you stuck at the screen edge: near the arena edge, or outside it, it slides past the arena (up to 400px away) to keep you within 60% of the way to the screen edge. → [Game feel](features/game-feel.md)
- **AI vs cover walls:** bots no longer attack walls; they sidestep or path around to get a clear angle before swinging or shooting (GAM-80, part 4). → [AI](features/ai.md)
- **AI teamwork:** bots protect friends (archers most) by going after whoever attacks them, pile onto low-HP targets together, and melee bots favour enemy archers and mages. 竊・[AI](features/ai.md)
- **Fix:** a bot pushing on an idle fighter (for example the second player in 2P mode) no longer drags it across the arena. Fighters stay solid; their physics contact margin is now much smaller, so the slow creep is gone. → [Fight flow](features/fight-flow.md)
- **Controller aim snaps for the first second of an attack, then follows how far you turn the stick**, so a bow shot is easy to line up: for the first 1 s it snaps straight to the stick (so flicking toward an enemy while backing away still hits them); after that it turns with the stick (at most 150 degrees per second) and stops as soon as the stick stops or is let go, instead of carrying on toward where the stick points.
- **Controller aim gets finer as a shot charges:** after the first second, the fuller the charge the less the aim moves for the same stick movement, down to a quarter at a full charge, so the end of a charge is for small corrections. → [Controls](features/controls.md#xbox-controller-1p)
- **Fix:** with only the left stick in use, the controller aim froze about a second into a charge (walking no longer steered it). The aim stick is now the right stick when pushed, otherwise the way you walk, in every phase of a charge.
- **Fix:** the controller aim during a charge no longer stays on an old direction after a quick flick: while you turn the stick faster than about 45 degrees per second it heads for where the stick points (at most 150 degrees per second) and catches up, and it still stops when the stick stops.
- **Fix:** fine-aiming a charge with the controller no longer gets stuck. Gentle pushes of the right stick (the dead zone is now accounted for) move the aim, and it resumes as soon as you turn the stick again, including after letting go. → [Controls](features/controls.md#xbox-controller-1p)
- **Dev setting: skip the 3-2-1 countdown** (Settings, Match group; next launch). Off by default.
- **Dash:** the first charge to come back after using all of them returns 2x faster (about 1.25s instead of 2.5s). A new dev setting, "First charge back after all used: speed x". → [Controls](features/controls.md#xbox-controller-1p)
- **Difficulty (Easy / Normal / Hard)** in the pause menu: scales how hard the enemy bots hit and how fast they react (not your teammate or you). Saved. → [AI](features/ai.md#difficulty)
- **Pause menu:** Exit now asks "Exit the game?" with Confirm and Cancel (Cancel pre-selected). With a controller on: A confirms and B backs out, a hint line shows the buttons, and the D-pad reaches the paused buttons at the top. → [UI and dev tools](features/ui-and-dev-tools.md#pause-menu)
- **Bigger screen:** the game now scales to the window (fixed 1152 x 648 layout, stretched), so a 1080p screen shows everything about 1.67x larger instead of a small window. It starts maximised; F11 or the paused "Display" button toggles fullscreen. Inside the editor's embedded Game tab only windowed mode works. → [UI and dev tools](features/ui-and-dev-tools.md#window-size-and-fullscreen)
- **Xbox controller support (1P, on by default):** works together with the keyboard and mouse; the "Controller" button at the top of the screen (visible while paused) turns it off. Left stick or D-pad to move, right stick to aim, RT or X to attack, LB (L1) to block, LT (L2), A or RB to dash, Y to switch character, Start to pause. Works at the same time as keyboard and mouse: using the controller switches aim to it (right stick, else the way you walk), and a mouse click or a real mouse move switches back. → [Controls](features/controls.md#xbox-controller-1p)
- **Death slow-motion:** when any fighter dies the game drops into slow motion (0.15x for about a second, audio slowed too) and the camera punches in on the body, then eases back. Can be switched off in the pause menu's Settings. → [Game feel](features/game-feel.md)
- **AI getting back into the zone:** a bot caught outside the shrinking zone (or knocked out of the arena) now walks round walls and pillars to get back in. Before, it walked in a straight line and got stuck pushing against the wall (GAM-81, part 1). → [AI](features/ai.md)
- **Camera and the shrinking zone:** the camera zooms in (up to 1.5x) and leans toward the zone as it closes. A fighter caught outside a well-closed zone is no longer chased by the camera, so the security-camera bubble shows it (labelled "ZONE") with its zoom matched to the main camera (GAM-81, part 1). → [Game feel](features/game-feel.md#camera-and-background)
- **Music:** the arena now plays the Battle Theme on a seamless loop (a trimmed WAV, so there is no gap at the loop point). It starts when the 3-2-1 countdown ends, follows the Music volume slider and keeps playing while paused. It speeds up (up to 1.25x, same key) as the shrinking zone closes. → [Sound](features/sound.md#music)
- **Test buttons only show while paused.** The buttons at the top of the screen (Host / Join and the address field, AI Bots, Respawn, Teams, Dummy, Player, Mode, Parry Training, Shrinking Zone) stay in the same spots but are hidden during combat and appear when you press Esc. The F2, F3 and F4 keys still work. → [UI and dev tools](features/ui-and-dev-tools.md#pause-menu)
- **Shrinking zone** (GAM-81, part 1): a Fortnite-style circle that closes in every 30s (over 6s, to 0.7x the size, at a random spot, down to a minimum). Being outside it slows and damages you like being outside the arena, and bots stay inside it. On from the start; turn it off with the top button (pause to see it) or F4. → [Fight flow](features/fight-flow.md#shrinking-zone-gam-81)
- **AI:** bots no longer stand idle when their only enemy is far away (for example an archer kiting after their partner died): they know where every living enemy is and go after it. → [AI](features/ai.md)
- **Parry:** only melee fighters can parry now; archers and mages just block melee hits. Melee can still parry arrows and fireballs. → [Combat](features/combat.md)
- **Parry trainer** (F3 or the top button while paused): a 1v1 against the knight with a fixed attack pattern, a short guide, parry stats and feedback on your timing, and a subtle red tint on the knight before each swing (0.4s, 0.7s or off). 竊・[UI and dev tools](features/ui-and-dev-tools.md#parry-trainer)
- **Parry counter:** after a parry, clicking attack counter-attacks instantly (no need to release block first, for 0.7s). → [Combat](features/combat.md)
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
