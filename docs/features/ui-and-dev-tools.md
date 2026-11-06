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

## Window size and fullscreen

The game is laid out at a fixed **1152 x 648** and **stretched to fit the window** (`[display]` in `project.godot`: `canvas_items` stretch, `keep` aspect). A bigger window or screen therefore draws everything bigger (a 1920 x 1080 screen shows it about 1.67x larger) and does not show more of the arena. It was not like this before: with no display settings the game ran in a plain 1152 x 648 window, which looks small on a 1080p screen.

- **Starts maximised** (`window/size/mode=2`). When it is un-maximised the window is 1600 x 900.
- **F11** switches between fullscreen and maximised, and so does the **Display: Windowed / Fullscreen (F11)** button at the top of the screen (visible while paused). Code: `assets/levels/display_toggle.gd`.
- A screen that is not 16:9 gets black bars rather than a stretched picture.
- **Inside the Godot editor:** the editor's embedded Game tab only supports a window ("Embedded window only supports Windowed mode"), so maximise, fullscreen and F11 do nothing there. They apply when the game runs as its own window (run it with the embedded game turned off, or from an exported build). Checked only for the settings loading and the 1152 x 648 layout being kept; the actual scale-up was not seen.

## Pause menu

**Esc** (or **Start** on a controller) opens the pause menu: Resume / **Difficulty** / Settings / Exit.

- **Difficulty:** the button cycles **Easy / Normal / Hard** (also a 0 to 2 slider at the top of Settings; the choice is saved). It only changes the **enemy bots**, never your teammate, you, or a fighter a human controls: how hard they hit and how fast they react (details in [AI](ai.md#difficulty)).
- **Exit asks first:** Exit opens "Exit the game?" with **Confirm** and **Cancel**. Cancel is pre-selected, so a stray press does not quit. Esc or B also cancels.
- **Controller:** while a controller is on, a hint line under the menu reads "A Confirm   B Resume / Back / Cancel". The D-pad or left stick moves between buttons (including the paused buttons at the top of the screen, which only take focus while the menu is open), A confirms, and B backs out. Godot has no controller A binding for menus by default, so `GamepadControls` adds one for `ui_accept`.

**Test and mode buttons:** the buttons along the top of the screen (Display, Controller, AI Bots, Respawn, Teams, Dummy, Player (loadout), Mode (1P / 2P), Parry Training and Shrinking Zone) are only visible while the game is paused, so the combat screen stays clean. They sit in their usual spots and work while paused. Each level tool still builds its own button and adds it to the `game_option` group; the pause menu moves those onto a layer above its dim (`pause_menu.gd`, `_collect_options`) and shows that layer only while paused. A new button of this kind only needs `add_to_group("game_option")`. The Host / Join buttons and the address field are in the same group, so they are paused-only too (`MultiplayerManager` finds the address field through the `ip_input` group).

**Dev settings:** the **Settings** screen has the sliders. They apply live, are saved to disk (also on Resume) and have a "Reset to defaults" button.

Saved at `user://dev_settings.cfg`, which on Windows is `%APPDATA%\Godot\app_userdata\Project Not TFT clone\dev_settings.cfg`.

## Dev settings

The list of settings is the `DEFS` table in `assets/dev/dev_settings.gd`. Groups:

- **Match:** skip the 3-2-1 countdown (takes effect on the next launch; for testing, so the game starts with everyone free at once)
- **Dash:** charges, recharge per charge, slow reload, first-charge speed, gap, speed, duration, invulnerable toggle
- **Movement:** walk speed, strafe speed while shooting, speed while charging / blocking
- **Combat:** attack speed, damage, knockback, hitstop, camera shake, quick-combo cooldown, combo hitstun, stun immunity, parry window, heavy super armor durability, damage numbers on/off, enemy wind-up warnings on/off
- **Audio:** sound effects volume, music volume
- **Camera:** follow strength, death slow-motion and zoom (on / off)
- **Arena:** outside damage %, outside speed
- **AI:** attack cooldown, dodging on/off, dodge cooldown, respawn delay

To add a setting: add a row to `DEFS`, then apply it in `dev_tuning.gd`.
