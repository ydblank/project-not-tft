# Changelog

## Unreleased

- **Class ultimates on Q** (GAM-23): each class has a 5 s ultimate that charges from the hits you land (by the hit's multiplier, not its damage), up to 2x faster below half HP. Knight **Unbreakable** (no damage, stagger or knockback, walks faster), Thief **Shadow Rush** (1.4x move and attack speed, single-target projectiles fly through), Archer **Deadeye** (every shot a charged heavy at the quick-shot pace), Mage **Arcane Surge** (skill cooldown, cast and heavy charge 75% shorter). A red Tekken-style aura shows on any fighter whose ultimate is ready, enemies included, and a meter sits under every HUD health bar. Controller RB (dash moves to LT and A only), 2P K and Right Shift. Bots use it, the balance lives in `assets/resources/ultimates.gd`, and Dev Tools → Ultimate has fill speed, duration and an "Always full" test switch. → [Ultimate](features/ultimate.md)
- **Combat call-outs:** "GUARD BREAK!" / "GUARD BROKEN!" now show in the middle of the screen (for guard breaks you cause or suffer), and a new hit combo counter ("3 HITS") shows the hits you land in a row. → [UI and dev tools](features/ui-and-dev-tools.md#on-screen-ui)
- **Knockback %:** the meter now starts at 0% (it showed 100%), no longer fades back down (only a respawn resets it, like Smash damage %) and tops out at 500% instead of 300%, so late hits throw further than before. → [UI and dev tools](features/ui-and-dev-tools.md)
- **Shrinking zone:** the "Zone closes in N" warning now only shows for the last 5 seconds before the zone closes. → [Fight flow](features/fight-flow.md)
- **Party screen:** at the start you pick the class and weapon of yourself and your ally (Knight, Thief, Archer, Mage), plus 1 or 2 players, AI bots on or off and the difficulty, before the countdown. Retry keeps the party; Pause → Change party shows the screen again. Also fixes a music error when Retry is pressed during the countdown. → [UI and dev tools](features/ui-and-dev-tools.md#party-screen)
- **Dagger:** the quick-combo cooldown drops from 0.6s to 0.35s, and a press turns into a heavy charge after 0.25s instead of 0.4s (new `charge_threshold` field in the weapons table). → [Combat](features/combat.md)
- **Pause menu:** new **Retry** button restarts the match, and LB / RB on a controller flip between the main menu, Settings and Dev Tools. → [UI and dev tools](features/ui-and-dev-tools.md#pause-menu)
- **Fix:** the knockback % and bar-style overlays no longer error (and freeze the game in the editor) when a fighter is freed, for example on respawn or when switching teams or modes during the countdown. → [UI and dev tools](features/ui-and-dev-tools.md)
- **Weapons table:** every weapon's type (new: sword, dagger, bow, staff), skill, power, attack speed, damage of each hit, charge, cooldown and AI range now live in one table, `assets/resources/weapons.gd`. The Quick-combo cooldown and Combo hitstun sliders override it only once moved. → [Combat](features/combat.md)
- **Key bindings:** Pause → Settings → Controls → Key bindings rebinds every Player 1 action on keyboard / mouse and controller (click, then press). Conflicts swap, Reset to defaults restores them, and they are saved. The pause menu also drops the controller hint line and the "change #" label. → [Controls](features/controls.md#key-bindings)
- **Pause menu split:** Settings now holds only player options (audio, display, controls), and a new **Dev Tools** screen holds the test buttons (AI Bots, Teams, Zone, Host / Join, ...) in a grid plus all dev sliders. The test buttons no longer cover the menu. → [UI and dev tools](features/ui-and-dev-tools.md#pause-menu)
- **Weapon skills on E** (GAM-20): sword Whirlwind (a spin that hits around you, cuts down projectiles, blocks and briefly parries), dagger Shadow Lunge (a dash that stops at the first enemy), bow Arrow Volley (5 x 5 arrows, one hit per target per volley), staff Inferno (big fireball after a 1 s cast, then burning ground that staggers on every tick). The Whirlwind has its own spinning-swoosh animation, the burning ground has animated pixel flames, and bots step out of enemy skill areas and fire. All skill balance numbers (damage, cooldown, cast time, reach) live in one table, `assets/resources/skills.gd`, and the Skills sliders start from it. Hold to aim with a blue (your team) or red (enemy) AoE marker; controller B, 2P J and /. HUD skill button with cooldown, bots use skills by their tags, Skills sliders in tiles and an F5 tile ruler for balancing ranges. Also removes a duplicated "Skip the countdown" settings row. → [Skills](features/skills.md)
- **Arena enlarged** to 31 x 15 tiles (GAM-80, part 1). → [Fight flow](features/fight-flow.md)
- **Cover walls** inside the arena (GAM-80, part 2): four 2 x 2 pillar blocks and a 1 x 5 centre column, drawn with the tileset's stone-pillar tiles, that block projectiles and movement, so you can hide from ranged attacks. → [Fight flow](features/fight-flow.md)
- **Wall impacts:** arrows, fireballs and melee swings that hit a wall now show stone chips and play a dull thump layered with a stone hit (GAM-80, part 3). → [Game feel](features/game-feel.md)
- **Fix:** standing on the edge of the bottom wall no longer counts as "outside the arena" (no more damage there). → [Fight flow](features/fight-flow.md)
- **Camera:** it no longer leaves you stuck at the screen edge: near the arena edge, or outside it, it slides past the arena (up to 400px away) to keep you within 60% of the way to the screen edge. → [Game feel](features/game-feel.md)
- **AI vs cover walls:** bots no longer attack walls; they sidestep or path around to get a clear angle before swinging or shooting (GAM-80, part 4). → [AI](features/ai.md)
- **AI teamwork:** bots protect friends (archers most) by going after whoever attacks them, pile onto low-HP targets together, and melee bots favour enemy archers and mages. 竊・[AI](features/ai.md)
- **Fix:** a bot pushing on an idle fighter (for example the second player in 2P mode) no longer drags it across the arena. Fighters stay solid; their physics contact margin is now much smaller, so the slow creep is gone. → [Fight flow](features/fight-flow.md)
- **Controller aim snaps for the first second of an attack, then follows how far you turn the stick**, so a bow shot is easy to line up: for the first 1 s it snaps straight to the stick (so flicking toward an enemy while backing away still hits them); after that it turns with the stick (at most 150 degrees per second) and stops as soon as the stick stops or is let go, instead of carrying on toward where the stick points.
- **Prettier fighter bars:** rounded, framed bars; the health fill goes green, amber, then red as health drops; the shield bar is blue (red and pulsing while the guard is broken); names are outlined and tinted by team. → [UI and dev tools](features/ui-and-dev-tools.md#on-screen-ui)
- **Knockback % in the UI:** every fighter's knockback meter is now shown next to its health bar ("KB 0%" up to "KB 500%", white to yellow to red, with a pop when it rises). Can be hidden in Settings > Display. → [UI and dev tools](features/ui-and-dev-tools.md#on-screen-ui)
- **AI punishes a broken guard:** when a fighter's guard breaks, bots rush them at once (new target, no attack cooldown, no backing off), unless they are very far (260 px). It is a chance rolled once per break: 25% on Easy, 60% on Normal, 90% on Hard. → [AI](features/ai.md)
- **Knight's Whirlwind moves further:** you can walk at 60% of normal speed while spinning (it was the shared 25%), about 37 px during the spin instead of 16. New `move_speed_mult` skill field and a Dev Tools slider. → [Skills](features/skills.md)
- **Controller aim is a dial while you charge or aim a skill (after the first second):** spin the stick round and the aim keeps turning the same way, so a full spin no longer cancels itself and swings back. It stops when the stick stops, and still gets finer as the charge fills. → [Controls](features/controls.md#xbox-controller-1p)
- **Controller rumble:** the pad vibrates when you are hurt, block, parry, land a hit, swing a heavy attack, dash, cast a skill, charge a shot (a hum that builds, a pulse when full) or die. Only while the controller is in use; strength slider in Settings > Controls (0 = off). → [Controls](features/controls.md#xbox-controller-1p)
- **Controller aim for aimed skills** (mage fireball, bow volley): they use the same steady aim as a charged shot (snap for the first second, then follows the stick only while you turn it, finer the longer you aim, steady through the cast and on release). With only the left stick in use, a fireball now lands at the distance you push, not always at the minimum. → [Controls](features/controls.md#xbox-controller-1p)
- **Controller aim gets finer as a shot charges:** after the first second, the fuller the charge the less the aim moves for the same stick movement, down to a quarter at a full charge, so the end of a charge is for small corrections. → [Controls](features/controls.md#xbox-controller-1p)
- **Fix:** with only the left stick in use, the controller aim froze about a second into a charge (walking no longer steered it). The aim stick is now the right stick when pushed, otherwise the way you walk, in every phase of a charge.
- **Fix:** the controller aim during a charge no longer stays on an old direction after a quick flick: while you turn the stick faster than about 45 degrees per second it heads for where the stick points (at most 150 degrees per second) and catches up, and it still stops when the stick stops.
- **Fix:** fine-aiming a charge with the controller no longer gets stuck. Gentle pushes of the right stick (the dead zone is now accounted for) move the aim, and it resumes as soon as you turn the stick again, including after letting go. → [Controls](features/controls.md#xbox-controller-1p)
- **Dev setting: skip the 3-2-1 countdown** (Settings, Match group; next launch). Off by default.
- **Dash:** the first charge to come back after using all of them returns 2x faster (about 1.25s instead of 2.5s). A new dev setting, "First charge back after all used: speed x". → [Controls](features/controls.md#xbox-controller-1p)
- **Difficulty (Easy / Normal / Hard)** in the pause menu: scales how hard the enemy bots hit and how fast they react (not your teammate or you). Saved. → [AI](features/ai.md#difficulty)
- **Pause menu:** Exit now asks "Exit the game?" with OK and Cancel (Cancel pre-selected). With a controller on: A confirms and B backs out, a hint line shows the buttons, and the D-pad reaches the paused buttons at the top. → [UI and dev tools](features/ui-and-dev-tools.md#pause-menu)
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
