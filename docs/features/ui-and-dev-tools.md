# UI and dev tools

On-screen overlays, the pause menu and the live-tunable dev settings.

**Code:** `assets/ui/controls_hint.*`, `assets/levels/out_of_arena_indicator.gd`, `assets/levels/parry_trainer.gd` and `training_attacker.gd`, `assets/dev/` (`pause_menu.gd`, `dev_settings.gd`, `dev_tuning.gd`), tests in `tests/test_dev_settings.gd`.

## On-screen UI

- **Fighter bars (health, shield, name) have a styled look** (`assets/levels/hud_style.gd`, the `HudStyle` node; it restyles the bars the fighter scenes already have, so respawns get it too): rounded bars with a dark framed background; the health fill blends green (healthy) to amber (about half) to red (under a quarter); the "last hit" trail behind the health bar is a warm cream; the shield bar is blue and turns red and pulses while the guard is broken; names have an outline so they read over any tile and are tinted by team (light blue for you and your ally, soft red for enemies). Positions and sizes are unchanged; the colours are constants at the top of the script.
- **Knockback %** next to every fighter's health bar ("KB 0%"): how far hits throw that fighter. It starts at 0%, rises with every hit it takes (+15% per hit and +1% per damage, up to 500%). It never goes back down, like the damage percent in Smash: only a respawn resets it. The number goes white, then yellow (100%), then red (200% and up), and pops when it rises. It sits above the bar on the side away from the fighter's name. Hide it with **Show knockback % next to health bars** in Settings > Display. Code: `assets/levels/knockback_meter.gd` (it only draws; the meter itself is `knockback_scale` on each `HitboxComponent`, see [Combat](combat.md)).
- **Centre-screen call-outs** (`assets/levels/combat_text.gd`, the `CombatText` node), for the fighter you control: **GUARD BREAK!** (orange) when you break someone's guard and **GUARD BROKEN!** (red) when yours breaks; the old small word over the fighter is gone. A **hit combo counter** ("3 HITS") below it counts the hits you land in a row. It appears from 2 hits, pops with each hit, and ends after 1.6s without a hit or when you get hit (it then fades out). Blocked and parried hits do not count.
- **Controller overlay** (F1 toggles it): shows pressed keys, with symbols for LMB / RMB / Space and text for W A S D F.
- **Out-of-arena camera bubble:** when the fighter you control is outside the arena and off screen (it stays hidden while you can still see them), a round live "security camera" view of it appears on the side of the screen the fighter went out toward (left or right), level with it. An arrow around the rim points back to the arena, with the distance underneath. The arrow is green while you are getting closer, red while you are moving away and yellow when holding still, and it grows and pulses faster the farther out you are.
- **Cooldown spinners** on the buttons: dash charges as dots with a recharge ring, the shield for block, and the charge ring for attack. The skill button (E) shows its icon, the cooldown sweep with the seconds left, and glows when ready (see [Skills](skills.md#hud)). The ULT button (Q) fills a red ring with the ultimate meter, throbs red when ready and sweeps out the time left while it runs (see [Ultimate](ultimate.md#look)).
- **Ultimate meter:** a thin bar under every fighter's HUD health bar, enemies included (see [Ultimate](ultimate.md#look)).
- **Tile ruler** (F5): rings at 2 to 12 tiles around your fighter, for judging skill ranges.

## Parry trainer

A practice mode for the parry (see [Combat](combat.md)). Turn it on with the **Parry Training: OFF / ON** button at the top of the screen (visible while paused) or **F3**.

- It switches the match to 1v1 against the melee knight (like **Teams: 1v1**), puts both fighters face to face, and makes both unkillable.
- The knight stops using its AI. It walks up and swings on a fixed timer (every 2s, plus a short pause after being parried or hit). The **Pattern** button cycles `Single light`, `Light combo x3` and `Light, light, heavy` (heavies cannot be parried). The **Speed** button slows his swings to about 0.55x, so the wind-up is easier to read.
- **Warning:** a sword's light swing starts up in only 0.06s, too short to react to. So before each sequence the knight stands still and his body fades to a red tint (slowly at first, strongest just before the swing), then he swings. The **Warning** button cycles `0.4s` (default: a normal ~0.25s reaction puts your block inside the 0.2s parry window), `0.7s` (early on purpose: you must wait) and `off` (pure timing). Only the first swing of a combo is warned. The warning belongs to the trainer; real fights and weapon timings are unchanged.
- A panel on the right shows a short guide, your stats (parries, blocked, hit, counters, streak, best streak, parry rate) and feedback on the last try: how many ms before the hit your block went up, whether you blocked too early, re-blocked too soon, were hit with no block, or got a counter in. **Reset** clears the stats.
- Turning it off gives the knight its AI back, restores the previous team size and makes both fighters mortal again.

## Party screen

When the game starts, a **Pick your party** screen sets the class and weapon of **You** and your **Ally** (Archer / Bow, Knight / Sword, Thief / Dagger, Mage / Staff) with `<` / `>` (mouse), or with Up / Down to pick a row and Left / Right to change it (arrow keys, D-pad or stick), then **OK** (the controller's Start button does the same). The game is paused while it is open, so the 3-2-1 countdown only begins after OK; Esc does nothing on it. The ally's name tag follows the class ("Ally mage").

- Behind the screen only the arena shows: fighters and all HUD layers are hidden until Start.
- The choice is remembered for the session: **Retry** keeps the party and skips the screen. The pause menu's **Change party** brings it back.
- Three more rows set the match: **Mode** (1 Player / 2 Players, like the Mode button), **AI bots** (On / Off, like the AI Bots button) and **Difficulty** (Easy / Normal / Hard, saved like the pause menu's). Mode and AI bots are remembered with the party and applied again after Retry, because the level reloads with its scene defaults.
- The class rows only change your side; the enemy team is unchanged.
- The **Skip the 3-2-1 countdown** test setting also skips this screen.
- Code: `assets/levels/party_select.gd` (the `PartySelect` node), using the loadouts in `LoadoutSwitcher.LOADOUTS`.

## Window size and fullscreen

The game is laid out at a fixed **1152 x 648** and **stretched to fit the window** (`[display]` in `project.godot`: `canvas_items` stretch, `keep` aspect). A bigger window or screen therefore draws everything bigger (a 1920 x 1080 screen shows it about 1.67x larger) and does not show more of the arena. It was not like this before: with no display settings the game ran in a plain 1152 x 648 window, which looks small on a 1080p screen.

- **Starts maximised** (`window/size/mode=2`). When it is un-maximised the window is 1600 x 900.
- **F11** switches between fullscreen and maximised, and so does the **Display: Windowed / Fullscreen (F11)** button at the top of the screen (visible while paused). Code: `assets/levels/display_toggle.gd`.
- A screen that is not 16:9 gets black bars rather than a stretched picture.
- **Inside the Godot editor:** the editor's embedded Game tab only supports a window ("Embedded window only supports Windowed mode"), so maximise, fullscreen and F11 do nothing there. They apply when the game runs as its own window (run it with the embedded game turned off, or from an exported build). Checked only for the settings loading and the 1152 x 648 layout being kept; the actual scale-up was not seen.

## Pause menu

**Esc** (or **Start** on a controller) opens the pause menu: Resume / **Retry** / **Difficulty** / **Settings** / **Dev Tools** / Exit. Esc or B goes back from any sub-menu.

- **Retry** restarts the match: it reloads the level (the 3-2-1 countdown runs again) and saves your settings first. Your party is kept.
- **Change party** reloads the level and shows the party screen again.
- **LB / RB** on a controller flip between the main menu, Settings and Dev Tools (wrapping), so the dev toggles are a shoulder press away. They do nothing on the key bindings screen or the exit confirmation.

- **Difficulty:** Left / Right on the button (or clicking it) change **Easy / Normal / Hard** (also a 0 to 2 slider at the top of Dev Tools; the choice is saved). It only changes the **enemy bots**, never your teammate, you, or a fighter a human controls: how hard they hit and how fast they react (details in [AI](ai.md#difficulty)).
- **Exit asks first:** Exit opens "Exit the game?" with **OK** and **Cancel**. Cancel is pre-selected, so a stray press does not quit. Esc or B also cancels.
- **Controller:** the D-pad or left stick moves between buttons (including the test buttons in Dev Tools, which only take focus while the menu is open), A confirms, and B backs out. Godot has no controller A binding for menus by default, so `GamepadControls` adds one for `ui_accept`.

**Settings** (for players): Audio (sound effects and music volume), Display (window mode, camera shake, death slow-motion, damage numbers, knockback %) and Controls (controller on / off, controller rumble strength, and **Key bindings**, see [Controls](controls.md#key-bindings)). The list is `PLAYER_SECTIONS` in `pause_menu.gd`.

**Dev Tools:** the test and mode buttons (Host / Join and the address field, Respawn, Player (loadout), Dummy, Mode (1P / 2P), AI Bots, Teams, Parry Training, Shrinking Zone) in a grid at the top, then every other dev setting as a scrolling list (see [Dev settings](#dev-settings)).

- **Where the buttons come from:** each level tool still builds its own button and adds it to the `game_option` group. The pause menu moves those into the Dev Tools grid (`_collect_options`), so they are only seen while paused. A new test button only needs `add_to_group("game_option")`.
- **Player settings:** a button that is a player setting also gets the meta `settings_section` with a section title (`"Display"`, `"Controls"`), and the menu puts it in that Settings section instead. The window mode and controller toggles do this.
- **Host / Join:** the buttons and the address field are in the same group (`MultiplayerManager` finds the address field through the `ip_input` group).
- Both screens apply changes live and save to disk (also on Resume). Each has its own **Reset to defaults**, which only resets that screen's values.

Saved at `user://dev_settings.cfg`, which on Windows is `%APPDATA%\Godot\app_userdata\Project Not TFT clone\dev_settings.cfg`.

## Dev settings

The list of settings is the `DEFS` table in `assets/dev/dev_settings.gd`. Groups:

- **Match:** skip the 3-2-1 countdown (the row was listed twice; the duplicate is gone) (takes effect on the next launch; for testing, so the game starts with everyone free at once)
- **Dash:** charges, recharge per charge, slow reload, first-charge speed, gap, speed, duration, invulnerable toggle
- **Movement:** walk speed, strafe speed while shooting, speed while charging / blocking
- **Combat:** attack speed, damage, knockback, hitstop, camera shake, quick-combo cooldown, combo hitstun, stun immunity, parry window, heavy super armor durability, damage numbers on/off, enemy wind-up warnings on/off
- **Skills:** cooldown scale and every skill reach, in tiles; each starts at the skills table (`assets/resources/skills.gd`) and overrides it only once moved (see [Skills](skills.md#balancing-ranges))
- **Audio:** sound effects volume, music volume (shown as 0 to 100, default 80)
- **Ultimate:** meter fill speed, duration, and "Always full" for testing (every fighter, bots included; see [Ultimate](ultimate.md#balancing))
- **Camera:** follow strength, death slow-motion and zoom (on / off)
- **Arena:** outside damage %, outside speed
- **AI:** attack cooldown, dodging on/off, dodge cooldown, respawn delay

To add a setting: add a row to `DEFS`, then apply it in `dev_tuning.gd`. Only settings that differ from their default are written to the save file, so a changed default reaches everyone who never touched that setting.
