# UI and dev tools

On-screen overlays, the pause menu and the live-tunable dev settings.

**Code:** `assets/ui/controls_hint.*`, `assets/levels/out_of_arena_indicator.gd`, `assets/dev/` (`pause_menu.gd`, `dev_settings.gd`, `dev_tuning.gd`), tests in `tests/test_dev_settings.gd`.

## On-screen UI

- **Controller overlay** (F1 toggles it): shows pressed keys, with symbols for LMB / RMB / Space and text for W A S D F.
- **Out-of-arena camera bubble:** when the fighter you control is outside the arena and off screen (it stays hidden while you can still see them), a round live "security camera" view of it appears on the side of the screen the fighter went out toward (left or right), level with it. An arrow around the rim points back to the arena, with the distance underneath. The arrow is green while you are getting closer, red while you are moving away and yellow when holding still, and it grows and pulses faster the farther out you are.
- **Cooldown spinners** on the buttons: dash charges as dots with a recharge ring, the shield for block, and the charge ring for attack.

## Pause menu

**Esc** opens the pause menu (Resume / Settings / Exit) with the **Dev settings** sliders. They apply live, are saved to disk (also on Resume) and have a "Reset to defaults" button.

Saved at `user://dev_settings.cfg`, which on Windows is `%APPDATA%\Godot\app_userdata\Project Not TFT clone\dev_settings.cfg`.

## Dev settings

The list of settings is the `DEFS` table in `assets/dev/dev_settings.gd`. Groups:

- **Dash:** charges, recharge per charge, slow reload, gap, speed, duration, invulnerable toggle
- **Movement:** walk speed, strafe speed while shooting, speed while charging / blocking
- **Combat:** attack speed, damage, knockback, hitstop, camera shake, quick-combo cooldown, combo hitstun, stun immunity, parry window, heavy super armor durability, damage numbers on/off, enemy wind-up warnings on/off
- **Audio:** sound effects volume, music volume
- **Camera:** follow strength
- **Arena:** outside damage %, outside speed
- **AI:** attack cooldown, dodging on/off, dodge cooldown, respawn delay

To add a setting: add a row to `DEFS`, then apply it in `dev_tuning.gd`.
