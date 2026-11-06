# UI and dev tools

On-screen overlays, the pause menu and the live-tunable dev settings.

**Code:** `assets/ui/controls_hint.*`, `assets/levels/out_of_arena_indicator.gd`, `assets/levels/parry_trainer.gd` and `training_attacker.gd`, `assets/dev/` (`pause_menu.gd`, `dev_settings.gd`, `dev_tuning.gd`), tests in `tests/test_dev_settings.gd`.

## On-screen UI

- **Controller overlay** (F1 toggles it): shows pressed keys, with symbols for LMB / RMB / Space and text for W A S D F.
- **Out-of-arena camera bubble:** when the fighter you control is outside the arena and off screen (it stays hidden while you can still see them), a round live "security camera" view of it appears on the side of the screen the fighter went out toward (left or right), level with it. An arrow around the rim points back to the arena, with the distance underneath. The arrow is green while you are getting closer, red while you are moving away and yellow when holding still, and it grows and pulses faster the farther out you are.
- **Cooldown spinners** on the buttons: dash charges as dots with a recharge ring, the shield for block, and the charge ring for attack.

## Parry trainer

A practice mode for the parry (see [Combat](combat.md)). Turn it on with the **Parry Training: OFF / ON** button at the top of the screen (visible while paused) or **F3**.

- It switches the match to 1v1 against the melee knight (like **Teams: 1v1**), puts both fighters face to face, and makes both unkillable.
- The knight stops using its AI. It walks up and swings on a fixed timer (every 2s, plus a short pause after being parried or hit). The **Pattern** button cycles `Single light`, `Light combo x3` and `Light, light, heavy` (heavies cannot be parried). The **Speed** button slows his swings to about 0.55x, so the wind-up is easier to read.
- **Warning:** a sword's light swing starts up in only 0.06s, too short to react to. So before each sequence the knight stands still and his body fades to a red tint (slowly at first, strongest just before the swing), then he swings. The **Warning** button cycles `0.4s` (default: a normal ~0.25s reaction puts your block inside the 0.2s parry window), `0.7s` (early on purpose: you must wait) and `off` (pure timing). Only the first swing of a combo is warned. The warning belongs to the trainer; real fights and weapon timings are unchanged.
- A panel on the right shows a short guide, your stats (parries, blocked, hit, counters, streak, best streak, parry rate) and feedback on the last try: how many ms before the hit your block went up, whether you blocked too early, re-blocked too soon, were hit with no block, or got a counter in. **Reset** clears the stats.
- Turning it off gives the knight its AI back, restores the previous team size and makes both fighters mortal again.

## Pause menu

**Esc** opens the pause menu (Resume / Settings / Exit).

**Test and mode buttons:** the buttons along the top of the screen (AI Bots, Respawn, Teams, Dummy, Player (loadout), Mode (1P / 2P), Parry Training and Shrinking Zone) are only visible while the game is paused, so the combat screen stays clean. They sit in their usual spots and work while paused. Each level tool still builds its own button and adds it to the `game_option` group; the pause menu moves those onto a layer above its dim (`pause_menu.gd`, `_collect_options`) and shows that layer only while paused. A new button of this kind only needs `add_to_group("game_option")`. The Host / Join buttons and the address field are in the same group, so they are paused-only too (`MultiplayerManager` finds the address field through the `ip_input` group).

**Dev settings:** the **Settings** screen has the sliders. They apply live, are saved to disk (also on Resume) and have a "Reset to defaults" button.

Saved at `user://dev_settings.cfg`, which on Windows is `%APPDATA%\Godot\app_userdata\Project Not TFT clone\dev_settings.cfg`.

## Dev settings

The list of settings is the `DEFS` table in `assets/dev/dev_settings.gd`. Groups:

- **Dash:** charges, recharge per charge, slow reload, gap, speed, duration, invulnerable toggle
- **Movement:** walk speed, strafe speed while shooting, speed while charging / blocking
- **Combat:** attack speed, damage, knockback, hitstop, camera shake, quick-combo cooldown, combo hitstun, stun immunity, parry window, heavy super armor durability, damage numbers on/off, enemy wind-up warnings on/off
- **Audio:** sound effects volume, music volume
- **Camera:** follow strength, death slow-motion and zoom (on / off)
- **Arena:** outside damage %, outside speed
- **AI:** attack cooldown, dodging on/off, dodge cooldown, respawn delay

To add a setting: add a row to `DEFS`, then apply it in `dev_tuning.gd`.
