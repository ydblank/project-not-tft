# Fight flow and teams

How a match starts, who is in it, and what happens when fighters die. Each level tool below is a small node in the arena scene (`assets/levels/node_2d.tscn`) with its own script, so a rule can be changed in one place.

**Code:** `assets/levels/` (`fight_countdown.gd`, `enemy_respawner.gd`, `bot_toggle.gd`, `team_size.gd`, `dummy_toggle.gd`, `control_switcher.gd`, `loadout_switcher.gd`, `arena_bounds.gd`, `shrinking_zone.gd`), `assets/characters/`.

## Match flow

- **3-2-1-FIGHT! countdown** at the start. Fighters are frozen until it finishes; Esc still works during it.
- **Player lives and respawn:** 3 lives, respawn after 3s, 1.5s of invulnerability and blinking after respawning, "GAME OVER" at 0 lives.
- **Respawning enemies** with an ON/OFF button at the top of the screen (visible while paused; the delay is a setting).
- **Death / hurt / knockback animations** for every fighter. Dead enemies linger, then fade out.
- **Training dummy** is hidden by default. A "Dummy: HIDDEN / SHOWN" button at the top of the screen (visible while paused) brings it back (it has no collision and cannot be hit while hidden).

## Arena

The floor is 31 x 15 tiles (496 x 240 px, about 2.7x the original 17 x 9). Five stone-pillar cover walls stand on it (four 2 x 2 blocks built from 1 x 2 pillar tiles, and a 1 x 5 centre column, GAM-80 part 2): solid, so they stop arrows and fireballs (a held fireball explodes on them) and bots path around them. It is painted in the `TileMap` of `assets/levels/node_2d.tscn`: floor tiles are atlas rows 2-4 (they carry the navigation data, so bots path over them), the top and bottom edges are solid wall rows, and the left and right sides open onto void, which is "outside". The camera follows you, so the whole floor no longer fits on screen at once.

Solid wall and pillar tiles are not "outside": you can stand on the walkable edge of the bottom wall without taking damage. Standing outside the arena tiles slows you (x0.5) and deals damage over time (8% max HP per second after a short grace period), with a warning tint and label. The camera follows you a little way into the void so you stay on screen (see [Game feel](game-feel.md)).

Tunables (pause menu): outside damage %, outside speed.

**Fighters are solid** (they block each other). Their physics `safe_margin` is 0.005 instead of Godot's 0.08 (set in `player_character.tscn`, `enemy_character.tscn` and `component_character.tscn`). With the default, a bot walking into an idle fighter (for example the second player in 2P mode) pressed on it and slowly dragged it across the arena, about 1.7 px per second; at 0.005 that is about 0.1 px per second. Walls and pillars still slide the same.

### Shrinking zone (GAM-81)

A Fortnite-style closing circle. Turn it on with the **Shrinking Zone: OFF / ON** button at the top of the screen (visible while paused) or **F4** to turn it off and on. It **starts on** (the `start_enabled` setting on the `ShrinkingZone` node): the first closing comes 30s after the 3-2-1 countdown.

- The circle starts big enough to cover the whole floor. Every **30s** it closes in over **6s** onto a circle with **0.7x the radius**, placed at a random spot inside the old one, until it reaches a minimum radius of 56px.
- The current edge is drawn in red, and while the zone is closing the circle it closes onto shows as a white outline (it is hidden while the zone waits, so nobody knows the next spot in advance). Everything outside the edge is tinted red. A label under the button counts down ("Zone closes in 12", "ZONE CLOSING!", "Final zone"). The clock waits while the 3-2-1 countdown runs and while the game is paused.
- Being outside the circle is treated exactly like being outside the arena: slowed (x0.5), 8% max HP per second after a short grace period, and the warning reads "OUTSIDE THE ZONE". Bots treat the edge as a wall, stay inside it, and walk back in if it closes on them.
- The music speeds up as the zone closes (see [Sound](sound.md#music)), and the camera zooms in and frames the zone (see [Game feel](game-feel.md#camera-and-background)).
- **Security-camera bubble:** a fighter you control that is outside the zone and off-screen gets the round camera bubble with an arrow back in; its label reads "ZONE 216" (distance back to the circle) instead of "ARENA". The bubble's zoom is never lower than the main camera's.
- Turning it off and on starts over.
- The values (`interval`, `shrink_time`, `shrink_factor`, `min_radius`) are exports on the `ShrinkingZone` node (`assets/levels/shrinking_zone.gd`). `ArenaBounds.is_inside()` asks the zone, so every system that already respects the arena edge respects the zone.

## Teams (2v2)

- **Ally archer** fights on your side. Enemies are a **Knight (melee)** and an **Archer (ranged)**.
- **Team colour:** a stronger tint plus an outline (blue = your team, red = enemies). Shader: `assets/effects/team_tint.gdshader`.
- **Switch character (R):** swaps control with your teammate. The fighter you leave goes to the AI. A gold arrow marks who you control. If your controlled fighter dies for good, control jumps to a living teammate.
- **Loadout switcher (F2 or the button at the top, visible while paused):** try Archer / Knight / Thief on the player.

## Turning fighters off

- **"AI Bots: ON / OFF" button** removes every AI-controlled fighter from the fight. They go to sleep: hidden, no collision, cannot be hit, health bar hidden, nothing respawns. Switching it on brings them back. Human-controlled fighters are never touched. In 2P mode, Player 2 can still take a sleeping enemy.
- **"Teams: 2v2 / 1v1" button** (second row, centred under "Respawn"): in 1v1 your ally and the second enemy sit the match out. The enemy kept is the one Player 2 controls, otherwise the knight. They are put to sleep like with the AI Bots button, with an extra mark so "AI Bots: ON" does not wake them. R and Player 2's swap key do nothing while there is nobody to swap to. Switching back to 2v2 brings everyone back. Together with 2P local mode this makes a true player-vs-player duel.

## Known limitations

- Multiplayer combat is not networked (host team id still equals the enemy team id).
- Switching characters mid-swing can leave the other fighter mid-action.
- The fighter handed to the AI copies the ally archer's AI settings (fine while both are archers).
- The out-of-arena warning was reported once showing after a death but could not be reproduced.
