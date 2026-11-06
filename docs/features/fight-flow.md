# Fight flow and teams

How a match starts, who is in it, and what happens when fighters die. Each level tool below is a small node in the arena scene (`assets/levels/node_2d.tscn`) with its own script, so a rule can be changed in one place.

**Code:** `assets/levels/` (`fight_countdown.gd`, `enemy_respawner.gd`, `bot_toggle.gd`, `team_size.gd`, `dummy_toggle.gd`, `control_switcher.gd`, `loadout_switcher.gd`, `arena_bounds.gd`), `assets/characters/`.

## Match flow

- **3-2-1-FIGHT! countdown** at the start. Fighters are frozen until it finishes; Esc still works during it.
- **Player lives and respawn:** 3 lives, respawn after 3s, 1.5s of invulnerability and blinking after respawning, "GAME OVER" at 0 lives.
- **Respawning enemies** with an ON/OFF button at the top of the screen (the delay is a setting).
- **Death / hurt / knockback animations** for every fighter. Dead enemies linger, then fade out.
- **Training dummy** is hidden by default. A "Dummy: HIDDEN / SHOWN" button at the top of the screen brings it back (it has no collision and cannot be hit while hidden).

## Arena

The floor is 31 x 15 tiles (496 x 240 px, about 2.7x the original 17 x 9). It is painted in the `TileMap` of `assets/levels/node_2d.tscn`: floor tiles are atlas rows 2-4 (they carry the navigation data, so bots path over them), the top and bottom edges are solid wall rows, and the left and right sides open onto void, which is "outside". The camera follows you and stays clamped to the arena, so the whole floor no longer fits on screen at once.

Standing outside the arena tiles slows you (x0.5) and deals damage over time (8% max HP per second after a short grace period), with a warning tint and label. The camera never leaves the arena (see [Game feel](game-feel.md)).

Tunables (pause menu): outside damage %, outside speed.

## Teams (2v2)

- **Ally archer** fights on your side. Enemies are a **Knight (melee)** and an **Archer (ranged)**.
- **Team colour:** a stronger tint plus an outline (blue = your team, red = enemies). Shader: `assets/effects/team_tint.gdshader`.
- **Switch character (R):** swaps control with your teammate. The fighter you leave goes to the AI. A gold arrow marks who you control. If your controlled fighter dies for good, control jumps to a living teammate.
- **Loadout switcher (F2 or the button at the top):** try Archer / Knight / Thief on the player.

## Turning fighters off

- **"AI Bots: ON / OFF" button** removes every AI-controlled fighter from the fight. They go to sleep: hidden, no collision, cannot be hit, health bar hidden, nothing respawns. Switching it on brings them back. Human-controlled fighters are never touched. In 2P mode, Player 2 can still take a sleeping enemy.
- **"Teams: 2v2 / 1v1" button** (second row, centred under "Respawn"): in 1v1 your ally and the second enemy sit the match out. The enemy kept is the one Player 2 controls, otherwise the knight. They are put to sleep like with the AI Bots button, with an extra mark so "AI Bots: ON" does not wake them. R and Player 2's swap key do nothing while there is nobody to swap to. Switching back to 2v2 brings everyone back. Together with 2P local mode this makes a true player-vs-player duel.

## Known limitations

- Multiplayer combat is not networked (host team id still equals the enemy team id).
- Switching characters mid-swing can leave the other fighter mid-action.
- The fighter handed to the AI copies the ally archer's AI settings (fine while both are archers).
- The out-of-arena warning was reported once showing after a death but could not be reproduced.
