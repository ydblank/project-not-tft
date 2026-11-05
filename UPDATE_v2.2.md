# Update v2.2

Combat, AI and game-feel overhaul. Everything below is new or changed since the last commit (`ecd4e25`).
Tests: 64 passing (`tests/`: combat data, combat state machine, dev settings).

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

---

## Fight flow

- **3-2-1-FIGHT! countdown** at the start. Fighters are frozen until it finishes; Esc still works during it.
- **Respawning enemies** with an ON/OFF button at the top of the screen (the delay is a setting).
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
- **Depth sorting:** whoever is lower on screen is drawn in front, so standing above an enemy now puts you partly behind him.

## UI

- **On-screen controller overlay** (replaces the keyboard hint panel): shows pressed keys; symbols for LMB / RMB / Space, text for W A S D F.
- **Cooldown spinners** on the buttons: dash charges as dots with a recharge ring, the shield for block, and the charge ring for attack.
- **Pause menu (Esc)** with **Dev settings** sliders. They apply live, are saved to disk (also on Resume) and have a "Reset to defaults" button.
  - Saved at `%APPDATA%\Godot\app_userdata\Project Not TFT clone\dev_settings.cfg`.

### Dev settings available

- **Dash:** charges, recharge per charge, slow reload, gap, speed, duration, invulnerable toggle
- **Movement:** walk speed, strafe speed while shooting, speed while charging / blocking
- **Combat:** attack speed, damage, knockback, hitstop, camera shake, quick-combo cooldown, combo hitstun, stun immunity
- **Camera:** follow strength
- **Arena:** outside damage %, outside speed
- **AI:** attack cooldown, dodging on/off, dodge cooldown, respawn delay

---

## New files

| Area | Files |
|---|---|
| Characters | `assets/characters/ally_archer.tscn`, `ally_character.gd`, `enemy_archer.tscn` |
| Level | `assets/levels/arena_bounds.gd`, `enemy_respawner.gd`, `loadout_switcher.gd`, `fight_countdown.gd`, `control_switcher.gd`, `camera_follow.gd` |
| Dev tools | `assets/dev/dev_settings.gd`, `dev_tuning.gd`, `pause_menu.gd` |
| Effects | `assets/effects/hit_fx.gd`, `team_tint.gdshader` |
| Tests | `tests/test_dev_settings.gd` |

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
- The camera isn't limited to the arena, so a high follow strength can show empty space.
- The AI only stands at the arena edge if you are outside; it does not follow you out.
- No sound effects yet (only the music track).
- The new AI behaviours were checked one by one in the running game, but only combo-breaking got a repeated test. The rest need real play to tune.
