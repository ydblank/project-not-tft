# Controls and local 2-player

How a human drives a fighter. Input is polled every physics frame by `PlayerController`, which writes a `CombatIntent`; the combat code never reads input directly.

**Code:** `assets/combat/player_controller.gd`, `assets/levels/local_coop.gd`, `assets/levels/control_switcher.gd`, input actions in `project.godot` (Project Settings → Input Map).

## Keyboard and mouse (1P)

| Input | Action |
|---|---|
| W A S D | Move |
| LMB | Attack: tap = quick attack, hold = charge heavy, release = heavy |
| RMB | Block (hold) |
| Space | Dash |
| **R** | **Switch to your teammate** |
| F1 | Show / hide the on-screen controller overlay |
| F2 | Cycle test loadout: Archer, Knight, Thief |
| Esc | Pause menu (Resume / Settings / Exit) |

You start as the **Knight with the sword**.

## Local 2-player mode

A **"Mode: 1P (mouse) / 2P (local)"** button at the top of the screen (visible while paused) switches modes. In 2P the mouse is not used: the **direction keys set the attack direction** (diagonals work, for example W+A).

| | Move / aim | Attack | Block | Dash |
|---|---|---|---|---|
| **Player 1** (blue team) | W A S D | F | G | H |
| **Player 2** (takes over the enemy knight) | Arrow keys | N | M | , (comma) |

Character switching still works in 2P:

- **R** swaps Player 1 with their ally.
- **. (period)** swaps Player 2 between the enemy knight and archer. The one left behind goes back to the AI.
- If Player 2's fighter dies and a new one respawns, Player 2 gets the new one.
- Switching back to 1P hands everything back to the AI and restores the mouse controls.

## Switching characters in 1P

See [Fight flow → Teams](fight-flow.md#teams-2v2) for the rules of **R** and the F2 loadout switcher.
