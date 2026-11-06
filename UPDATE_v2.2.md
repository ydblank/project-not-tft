# Update v2.2

Combat, AI and game-feel overhaul. Everything below is new or changed since the last commit (`ecd4e25`).
Tests: 75 passing (`tests/`: combat data, combat state machine, dev settings, sound table).

---

## Controls

| Input | Action |
|---|---|
| W A S D | Move |
| LMB | Attack: tap = quick attack, hold = charge heavy, release = heavy |
| RMB | Block (hold) |
| Space | Dash |
| **R** | **Switch to your teammate** (new) |
| F1 | Show / hide the on-screen controller overlay |
| F2 | Cycle test loadout: Archer, Knight, Rogue |
| Esc | Pause menu (Resume / Settings / Exit) |

You now start as the **Knight with the sword** (was the Archer).

### Local 2-player mode

A **"Mode: 1P (mouse) / 2P (local)"** button at the top of the screen switches modes. In 2P the mouse is not used: the **direction keys set the attack direction** (diagonals work, for example W+A).

| | Move / aim | Attack | Block | Dash |
|---|---|---|---|---|
| **Player 1** (blue team) | W A S D | F | G | H |
| **Player 2** (takes over the enemy knight) | Arrow keys | N | M | , (comma) |

Character switching still works in 2P: **R** swaps Player 1 with their ally, and **. (period)** swaps Player 2 between the enemy knight and archer (the one left behind goes back to the AI). If Player 2's fighter dies and a new one respawns, Player 2 gets the new one. Switching back to 1P hands everything back to the AI and restores the mouse controls.

---

## Fight flow

- **3-2-1-FIGHT! countdown** at the start. Fighters are frozen until it finishes; Esc still works during it.
- **Respawning enemies** with an ON/OFF button at the top of the screen (the delay is a setting).
- **"AI Bots: ON / OFF" button** at the top of the screen removes every AI-controlled fighter from the fight (they go to sleep: hidden, no collision, cannot be hit, health bar hidden, nothing respawns) and brings them back when switched on. Human-controlled fighters are never touched. In 2P mode, Player 2 can still take a sleeping enemy.
- **"Teams: 2v2 / 1v1" button** (second row, centred under "Respawn"): in 1v1 your ally and the second enemy sit the match out (the enemy kept is the one Player 2 controls, otherwise the knight). They are put to sleep like with the AI Bots button, with an extra mark so "AI Bots: ON" does not wake them. R and Player 2's swap key do nothing while there is nobody to swap to. Switching back to 2v2 brings everyone back. It works together with 2P local mode (that makes a true player-vs-player duel).
- **Training dummy** is hidden by default; a "Dummy: HIDDEN / SHOWN" button at the top of the screen brings it back (it has no collision and cannot be hit while hidden).
- **Player lives and respawn:** 3 lives, respawn after 3s, 1.5s of invulnerability and blinking after respawning, "GAME OVER" at 0 lives.
- **Death / hurt / knockback animations** for every fighter. Dead enemies linger, then fade out.

## Teams (2v2)

- **Ally archer** fights on your side. Enemies are a **Knight (melee)** and an **Archer (ranged)**.
- **Team colour:** a stronger tint plus an outline (blue = your team, red = enemies).
- **Switch character (R):** swaps control with your teammate. The fighter you leave goes to the AI. A gold arrow marks who you control. If your controlled fighter dies for good, control jumps to a living teammate.
- **Loadout switcher (F2 or the button at the top):** try Archer / Knight / Rogue on the player.

## Combat

- **Melee combos reworked**
  - **Heavy:** one charge and release plays a **3-hit combo** (the finisher knocks back).
  - **Quick:** each hit needs its own click; after the full 3-hit quick combo there is a short cooldown.
  - **Combo lock:** hitting someone mid-combo keeps them staggered (can't attack or block) until the combo ends. **A dash is the way out.** Capped at 1.5s total.
  - **Lunge fix:** your lunge now stops just short of the target, so the final hit no longer whiffs by overshooting.
- **Ranged**
  - **Bow rebalanced:** slower full charge (2.2s), lower damage cap (x2.0), light arrows have very light knockback (x0.2).
  - **Strafing:** you can move slowly while shooting.
  - **Quick shots slowed:** about 1 per second (no more machine gun).
- **Parry:** raise your block just before a normal hit lands (the first 0.2s of a fresh block) and the hit does nothing: you take no shield damage, the attacker is stunned for 0.7s and cannot dash out, and a parried arrow flies back at its shooter, faster and 50% harder. Mashing block does not work: after letting go there is a 0.45s pause before the parry window is available again. Heavy attacks (melee, or a fully drawn arrow) cannot be parried: they hit the block as usual, drain the shield and can break it, which stuns you. "Parry window" is a pause-menu setting.
- **Shield:** a block holds 14 points before it breaks (a broken guard stuns for 2s and the shield refills in about 2s).
- **Super armor on heavies:** while charging or swinging a heavy melee attack, light hits (including arrows) do not interrupt you (the damage still lands), but the armor has durability, like a shield (10 points by default, a pause-menu slider): each light hit wears it down, and when it runs out you are stunned for 1s and the heavy is lost ("ARMOR BREAK!"). A heavy hit breaks through at once. A ring around the fighter shows how much armor is left, shrinking and turning red as it wears down.
- **Attack clashes:** two melee swings of the same weight (light vs light, heavy vs heavy) that meet in the air cancel out: both fighters are thrown back, nobody takes damage, with a spark burst, ring and clang. A heavy against a light swing is not a clash, the heavy's armor wins.
- **Hit-confirm:** the last hit of a combo, and every heavy, gets a bigger effect: an orange ring, a streak along the hit, a hot spark burst, a deeper impact sound, a longer freeze frame and a harder camera shake.
- **Damage numbers** above every fighter: red when you are hit, white when you hit, grey between bots, gold and larger for heavy hits and finishers, orange for arena damage. A pause-menu toggle turns them off.
- **Enemy wind-up warnings** (bots only, pause-menu toggle): a red box shows where a swing will land and fills in as it nears impact; a charging heavy shows a closing red ring and a blinking "!"; a ranged bot drawing or aiming shows a red aim line.
- **Bow charge indicator:** while you draw a heavy shot, an aim line grows with the draw and a ring fills around you, turning gold and pulsing at full power.
- **Arrows:** a blocked arrow snaps in two and the halves drop away; arrows fly through fighters who are already staggered or knocked back, so a stunned target cannot be machine-gunned.
- **Stun rules**
  - **Stun immunity:** 0.5s after a stun ends, weak hits do damage but can't stun again (fixes light-arrow stunlock).
  - **Heavy melee protected:** light ranged hits can't interrupt a heavy melee charge or swing; heavy ranged hits can.
- **Dash**
  - **Triple dash with recharge:** 3 charges that each recharge on their own (1.5s each). Using all of them in a row triggers a slower reload (2.5s).
  - **Faster and looser:** near-instant, and usable out of almost any action (attacks, charging, blocking, even stagger).
  - **Invulnerable while dashing** (i-frames).
  - **Charge through a dash:** hold a heavy charge, dash, keep holding, then release after (or release mid-dash and it fires when the dash ends).
- **Arena:** standing outside the arena tiles slows you (x0.5) and deals damage over time (8% max HP per second after a short grace period), with a warning tint and label.

## AI

- **Dodging:** the AI dashes out of the way of incoming arrows and wind-ups.
- **Stays in the arena:** it treats the arena edge as a wall. It won't walk, retreat or dash out, and walks back in if knocked out.
- **Attack pacing** tuned so the AI actually fights back (attack cooldown 0.7s, personality changes every 1.2s).
- **Ally AI** uses the same brain as the enemy archer and targets enemies.
- **Dash reserve:** movement dashes keep one charge in reserve for dodging and combo breaks.
- **Smarter AI (all can be switched off per fighter in the AIComponent "Smarts" group):**
  - **Combo breaker:** when held in combo hitstun, the AI reacts after about 0.2s and may dash out (60% to 85% chance depending on personality).
  - **Punish dash:** dashes in on a target that is stunned, knocked back or recovering from a swing, and can spend its last charge to do it.
  - **Steadier decisions:** it commits to chasing or retreating for at least 0.7s, retreats more when hurt, and does not run straight back into a corner it just escaped.
  - **Smarter targets:** it scores targets by distance, openings, low health, and whether a teammate is already on them. Targets are kept for 1s so it does not flip between two.
  - **Teamwork:** two fighters on the same target flank from opposite sides. A fighter goes after whoever is on top of a hurt teammate.
  - **Adapts to you:** it blocks and dodges more when you spam attacks, and holds back its heavy while you still have a dash to sidestep it (it goes for it more when you are out of dashes or stunned).
  - **Uses the arena edge:** it approaches from the inside so its hits push you toward the edge, and avoids hanging around the edge itself.

## Game feel

- **Freeze frame on hit** (a true freeze, kept short), plus **camera shake** along the hit direction (bigger on heavy hits and kills). Both only trigger when the **player** hits or gets hit.
- **Hit effects:** blood splats and droplets on fighters, sparks on blocks and on the dummy.
- **Blocking is easy to read:** a shield arc on the guarded side (blue, turning red as the shield drains), a shield meter above the head, a bright pulse and small push-back on each blocked hit, a "BLOCKED" popup, and a "GUARD BREAK!" popup with a red flash and shattering shards when the shield breaks.
- **Dash afterimage trail.**
- **Slash effect follows you** during the swing (it no longer stays at your start position when you lunge).
- **Gentle camera follow:** drifts toward the fighter you control, leaning toward your teammate (follow strength is adjustable). It never leaves the arena, so being launched far outside does not blank the screen.
- **Dark background everywhere:** the project background colour is now the same dark navy as the arena border, so no grey shows when the camera looks past the tiles.
- **Depth sorting:** whoever is lower on screen is drawn in front, so standing above an enemy now puts you partly behind him.

## Sound

- **Sound effects** (files in `assets/audio/sfx/`, played through the `Sfx` helper): sword swing, heavy swing, bow release, dash, hit (heavier and lower for heavy hits), block, guard break, death, countdown ticks, "FIGHT!", and pause-menu open / close.
- **Volume:** a "Sound effects volume" and a "Music volume" slider in the pause menu (Audio group). The level's music player is on the new "Music" bus.
- Swing sounds are played at about 82% (quick) and 88% (heavy) of their recorded pitch, quick swings are 8 dB quieter, heavy swings 9 dB quieter, bow shots 10 dB quieter and arrow impacts 5 dB quieter than melee hits. The fighter who lands a hit sometimes grunts (about 30% of quick hits, 80% of heavy ones, deeper for heavy, at most once every 0.7s per fighter), using the same grunt recording as the dash. The dash is just the grunt (no whoosh), with its pitch and speed varying by only up to 5% each time.
- **Variety:** most sounds have several recordings picked at random (never the same twice in a row): 2 heavy swings, 2 bow shots and 3 hits. Each play also varies pitch (and with it speed) by only up to 4% and loudness by up to 1 dB. Countdown, "FIGHT!" and menu sounds are kept exact.
- Sounds from human-controlled fighters play at full volume; bots-only action plays 7 dB quieter so a crowd of AI does not drown out your own actions.
- The raw sound packs live in `sfx/`, which is **git-ignored** and hidden from the Godot editor (`.gdignore`). Only the sounds the game uses (17 short files, about 1.8 MB) are in the project (`assets/audio/sfx/`). Some were cut down from the Sonniss packs (hits, block, heavy swings, bow shots); the countdown drum-and-wood hit is synthesized; the rest are copies of short loose files.
- Not used yet: footsteps, music tracks, NPC voices, and the other loose sounds (rage, buff, smoke, monster roar). New combat sounds (parry, clash, armor, finisher) reuse existing recordings at different pitches.

## UI

- **On-screen controller overlay** (replaces the keyboard hint panel): shows pressed keys; symbols for LMB / RMB / Space, text for W A S D F.
- **Out-of-arena camera bubble:** when the fighter you control is outside the arena and off screen (it stays hidden while you can still see them), a round live "security camera" view of it appears at the left of the screen, with an arrow around the rim pointing back to the arena and the distance underneath. The arrow is green while you are getting closer, red while you are moving away and yellow when holding still, and it grows and pulses faster the farther out you are.
- **Cooldown spinners** on the buttons: dash charges as dots with a recharge ring, the shield for block, and the charge ring for attack.
- **Pause menu (Esc)** with **Dev settings** sliders. They apply live, are saved to disk (also on Resume) and have a "Reset to defaults" button.
  - Saved at `%APPDATA%\Godot\app_userdata\Project Not TFT clone\dev_settings.cfg`.

### Dev settings available

- **Dash:** charges, recharge per charge, slow reload, gap, speed, duration, invulnerable toggle
- **Movement:** walk speed, strafe speed while shooting, speed while charging / blocking
- **Combat:** attack speed, damage, knockback, hitstop, camera shake, quick-combo cooldown, combo hitstun, stun immunity, parry window, heavy super armor durability, damage numbers on/off, enemy wind-up warnings on/off
- **Audio:** sound effects volume, music volume
- **Camera:** follow strength
- **Arena:** outside damage %, outside speed
- **AI:** attack cooldown, dodging on/off, dodge cooldown, respawn delay

---

## New files

| Area | Files |
|---|---|
| Characters | `assets/characters/ally_archer.tscn`, `ally_character.gd`, `enemy_archer.tscn` |
| Level | `assets/levels/arena_bounds.gd`, `enemy_respawner.gd`, `loadout_switcher.gd`, `fight_countdown.gd`, `control_switcher.gd`, `camera_follow.gd`, `dummy_toggle.gd`, `out_of_arena_indicator.gd`, `local_coop.gd`, `bot_toggle.gd`, `team_size.gd` |
| Dev tools | `assets/dev/dev_settings.gd`, `dev_tuning.gd`, `pause_menu.gd` |
| Effects | `assets/effects/hit_fx.gd`, `block_visual.gd`, `team_tint.gdshader` |
| Sound | `assets/commons/sfx.gd` (the `Sfx` helper), `assets/audio/sfx/` (the sound files) |
| Tests | `tests/test_dev_settings.gd`, `tests/test_sfx.gd` |

## Main files changed

- `assets/combat/action_state_machine.gd`: dash charges, combos, combo lock helpers, charge-through-dash
- `assets/combat/combat_component.gd`: stun rules, arena slow, combo lock, lunge/strafe handling
- `assets/combat/player_controller.gd`: lunge limit
- `assets/combat/weapon_data.gd`, `hit_data.gd` and the sword / dagger / bow `.tres` files
- `assets/scenes/ai_component.gd`, `hitbox_component.gd`, `animation_component.gd`
- `assets/effects/slash.gd`, `assets/ui/controls_hint.*`, `assets/levels/node_2d.tscn`

## Known limitations

- Multiplayer combat is not networked (host team id still equals the enemy team id).
- The 3-hit heavy combo reuses the single attack animation for every hit.
- Switching characters mid-swing can leave the other fighter mid-action.
- The fighter handed to the AI copies the ally archer's AI settings (fine while both are archers).
- The AI only stands at the arena edge if you are outside; it does not follow you out.
- The new AI behaviours and the new combat features (parry, armor, clashes, tells) were checked one by one in the running game with staged hits, not in long live fights. They need real play to tune.
- The AI does not parry on purpose (it can land one by chance), and blocks are judged by where the attacker stands, not by where an arrow comes from.
- The sounds were chosen by name and measurement, not by ear; several volumes and pitches were tuned from feedback and may need more tuning.
- The out-of-arena warning was reported once showing after a death but could not be reproduced.
- Safety nets against invalid positions (NaN) were added after a blank-screen report that could not be reproduced; if it happens again the log prints a "[NaN guard]" line.
- The "Vector2 cannot be normalized" warnings in the game log are engine noise from the grounded movement mode used by enemies and the ally.
