# Controls and local 2-player

How a human drives a fighter. Input is polled every physics frame by `PlayerController`, which writes a `CombatIntent`; the combat code never reads input directly.

**Code:** `assets/combat/player_controller.gd`, `assets/levels/gamepad_controls.gd`, `assets/levels/local_coop.gd`, `assets/levels/control_switcher.gd`, input actions in `project.godot` (Project Settings → Input Map).

## Keyboard and mouse (1P)

| Input | Action |
|---|---|
| W A S D | Move |
| LMB | Attack: tap = quick attack, hold = charge heavy, release = heavy |
| RMB | Block (hold) |
| Space | Dash |
| **E** | **Skill**: hold to aim (shows the marker), release to cast; a tap casts at once. See [Skills](skills.md) |
| **Q** | **Ultimate** (when its meter is full). See [Ultimate](ultimate.md) |
| **R** | **Switch to your teammate** |
| F1 | Show / hide the on-screen controller overlay |
| F5 | Show / hide the tile ruler (for skill ranges) |
| F2 | Cycle test loadout: Archer, Knight, Thief |
| Esc | Pause menu (Resume / Settings / Exit) |

You start as the **Knight with the sword**.

## Xbox controller (1P)

An Xbox 360 / XInput-style controller can drive Player 1 at the same time as the keyboard and mouse. A GPD Win 4's built-in controller shows up this way.

**It is on by default**, so the keyboard, mouse and controller all work at the same time. The **Controller: ON / OFF** button at the top of the screen (visible while paused: press Esc) turns it off for keyboard and mouse only; it says "ON (none found)" when no recognised controller is connected. The choice lasts for the session; set `enabled` on the `GamepadControls` node to change the starting state. With it off, the controller does nothing at all: no bindings, and its sticks cannot take aim from the mouse.

| Input | Action |
|---|---|
| Left stick or D-pad | Move |
| Right stick | Aim (see below) |
| RT or X | Attack: tap = quick attack, hold = charge heavy, release = heavy |
| LB (L1) | Block (hold) |
| LT (L2) or A | Dash |
| B | Skill (hold to aim, release to cast) |
| RB (R1) | Ultimate |
| Y | Switch to your teammate (R) |
| Start | Pause menu (Esc). In menus: D-pad or left stick moves, **A confirms**, **B backs out / cancels** |

- **Controller aim: snaps for the first second of an attack, then works like a dial.** The "aim stick" is the **right stick when it is pushed, otherwise the way you are walking (left stick or D-pad)**, so a controller where only the left stick is used aims where it walks, charged shots included (a charge used to freeze the aim after a second in that case, which was a bug). When you are not attacking, the aim turns quickly but smoothly toward the aim stick (once it is pushed past its dead zone, about 30%; a stick resting near the centre does not move it; with neither stick pushed it stays put). **For the first second of an attack it snaps straight to where the aim stick points** (within one frame), so flicking toward an enemy while backing away never sends the shot the old way. After that, while the attack button is still held (or an aimed skill is being aimed), **the aim is a dial: it turns by as much as you turn the aim stick, and stops the moment the stick stops or is let go.** Spin the stick all the way round and the aim keeps turning the same way, a full circle and more (it never heads back toward where the stick points, which is what made a full spin cancel itself before); spin the other way to turn it back. Repeated spins add up, so to aim far round, keep spinning. **The fuller the charge, the less the aim moves** for the same stick movement: from 40% of the way to a full charge it eases down, and at a full charge the aim only follows a quarter of the stick's movement (and top speed), so the end of a charge is for small corrections. On the frame an attack ends the aim is not moved, because the shot fires on it. **Aimed skills use the same aim** (holding the skill button for the mage's fireball or the bow's volley): it snaps for the first second, then is the same dial and gets finer the longer you aim (down to a quarter of the stick's movement over the next 1.5 s), and it stays steady through the cast and on the frame you release, so the volley goes where you lined it up. A fireball's landing spot is along that aim; the distance comes from how hard you push the right stick, or the left stick when only that one is in use. The numbers are `PAD_AIM_COMMIT`, `PAD_AIM_FINE_MIN`, `PAD_AIM_TURN`, `PAD_AIM_FAST_WINDOW`, `PAD_AIM_MAX_DEG_PER_SEC`, `PAD_AIM_SLOW_START`, `PAD_AIM_FULL_CHARGE_SCALE` and `PAD_SKILL_AIM_RAMP` in `player_controller.gd`.
- **Controller mode:** using a stick or button switches aim to the controller, and the mouse cursor is then ignored (it would otherwise sit still off to one side and pull every attack toward it). A mouse click, or moving the mouse more than 24 pixels with no controller input in between, switches back to the mouse. Small cursor jitter does not (`_input` in `player_controller.gd`).
- The bindings are added to the existing input actions at run time by `assets/levels/gamepad_controls.gd` (the `GamepadControls` node), so `project.godot` is unchanged. The action buttons in the table above are the defaults; they can be changed in [Key bindings](#key-bindings). RT and LT must be pulled about half way to count.
- Only controllers Godot recognises are used. A device Godot has no layout for (for example the GPD Win 4's extra `0x3537/0x1041` interfaces) is ignored, because it sends raw numbers that can look like a stuck stick. Plugging a controller in or out re-applies the bindings.
- Local 2-player mode keeps its keyboard controls: the stick aim only works in 1P mode.
- **Rumble** (`assets/levels/gamepad_rumble.gd`, the `GamepadRumble` node): the pad vibrates for what happens to the fighter you control, but **only while you are using the controller** (a keyboard and mouse player with a pad plugged in feels nothing, and nothing buzzes if the Controller button is off). The strength is the **Controller rumble** slider in Settings > Controls (0 = off, default 0.7). The patterns:
  - **Hurt:** a thud that grows with how much of your health the hit took.
  - **Blocked hit:** a short dull thud (heavier for a heavy hit). **Parry:** a sharp, bright snap.
  - **You land a hit:** a light tap (nothing if it was blocked or parried). **Heavy swing:** a weighty thump.
  - **Dash:** a tiny tick. **Skill cast:** a medium pulse. **Clash:** a medium jolt. **Armor broken:** a pulse. **Death:** a long, strong rumble.
  - **Charging a shot or heavy attack:** a low hum that builds with the charge, and a sharp pulse when it is full.
  - A big rumble is never cut short by a small one that follows it. Verified by reading the pad's vibration back in the running game; whether it feels right in your hands is not checked.- **Not covered yet:** the test and mode buttons shown while paused (AI Bots, Teams, ...) cannot be reached with the controller (use the keys F2, F3, F4 or the mouse) and the on-screen controller picture still shows keyboard and mouse.
- Checked with scripted controller events on the real Xbox 360 device (movement, aim, attack, block, dash, pause, character switch); not played by hand yet.

## Key bindings

Pause → Settings → Controls → **Key bindings** lists every Player 1 action (Move up / down / left / right, Attack, Block, Dash, Skill, Ultimate) with its keyboard / mouse binding and its controller binding. **Click a binding, then press the new key, mouse button, controller button, trigger or stick direction.** Esc (or Start) cancels.

- **Conflicts swap:** a key or button that another action already uses moves over, and that action gets the old one (or just loses it, when it has another: binding Space elsewhere leaves Dash on F).
- **Controller:** movement and aim stay on the sticks and D-pad. Start, Guide and Y (switch character) cannot be bound. A trigger or stick bound to an action counts once pushed half way.
- **Saved** at `user://keybinds.cfg` (next to `dev_settings.cfg`). **Reset to defaults** goes back to the project's keys (project.godot) and the controller defaults below.
- The on-screen key overlay (F1) follows the new keys.
- **Not rebindable yet:** R (switch character), the F-keys, Esc, and the local 2-player keys.
- Code: `assets/levels/keybinds.gd` (`Keybinds`: the bindings, swapping, saving), the screen in `assets/dev/pause_menu.gd`; `GamepadControls` reads its controller bindings from `Keybinds`. Tests: `tests/test_keybinds.gd`.

## Local 2-player mode

A **"Mode: 1P (mouse) / 2P (local)"** button at the top of the screen (visible while paused) switches modes. In 2P the mouse is not used: the **direction keys set the attack direction** (diagonals work, for example W+A).

| | Move / aim | Attack | Block | Dash | Skill | Ultimate |
|---|---|---|---|---|---|---|
| **Player 1** (blue team) | W A S D | F | G | H | J | K |
| **Player 2** (takes over the enemy knight) | Arrow keys | N | M | , (comma) | / (slash) | Right Shift |

Character switching still works in 2P:

- **R** swaps Player 1 with their ally.
- **. (period)** swaps Player 2 between the enemy knight and archer. The one left behind goes back to the AI.
- If Player 2's fighter dies and a new one respawns, Player 2 gets the new one.
- Switching back to 1P hands everything back to the AI and restores the mouse controls.

## Switching characters in 1P

See [Fight flow → Teams](fight-flow.md#teams-2v2) for the rules of **R** and the F2 loadout switcher.
