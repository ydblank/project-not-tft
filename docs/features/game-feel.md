# Game feel and visual effects

Feedback that makes hits, blocks and movement readable.

**Code:** `assets/effects/` (`hit_fx.gd`, `block_visual.gd`, `slash.gd`, `damage_number.gd`), `assets/levels/camera_follow.gd`, hit-stop in `assets/commons/combat.gd` (the `Combat` autoload).

## Hit feedback

- **Freeze frame on hit** (a true freeze, kept short), plus **camera shake** along the hit direction (bigger on heavy hits and kills). Both only trigger when the **player** hits or gets hit.
- **Hit effects:** blood splats and droplets on fighters, sparks on blocks and on the dummy.
- **Wall impact:** an arrow, a fireball or a sword swing that hits a wall throws stone chips and sparks back off the wall and plays a dull thump layered with a stone hit (quieter when a bot fired it).
- **Death slow-motion:** whenever a fighter dies (any fighter: you, your teammate, an enemy, killed by a hit or by the zone), the game drops to **0.15x speed** for about a second and the camera **punches in 1.6x** on the fallen fighter, with the audio slowing to 0.6x too. It then eases back over about half a second (about 1.5 s in total, in real time). A new death during it does not stack. Tuned on the `DeathSlowMo` node (`assets/levels/death_slowmo.gd`: `slow_scale`, `hold`, `ramp_out`, `zoom_multiplier`, `focus_weight`, `audio_speed`) and switched on or off with the **Death slow-motion and zoom** checkbox in the pause menu's Settings (Camera group). It runs through `Combat.set_slowmo()`, so the freeze frame on hits still works on top of it (it returns to the slow speed, not to normal speed). The camera zoom and focus go through `CameraFollow.punch_*`, and the camera moves in real time so it keeps its pace in slow motion.
- **Slash effect follows you** during the swing (it no longer stays at your start position when you lunge).
- **Dash afterimage trail.**

## Blocking

Blocking is easy to read:

- a shield arc on the guarded side (blue, turning red as the shield drains);
- a shield meter above the head;
- a bright pulse and small push-back on each blocked hit, and a "BLOCKED" popup;
- a "GUARD BREAK!" popup with a red flash and shattering shards when the shield breaks.

## Camera and background

- **Gentle camera follow:** drifts toward the fighter you control, leaning toward your teammate (follow strength is adjustable). Whatever the strength, the fighter you control is never allowed more than 55% of the way from the screen centre to its edge (`comfort_zone` in `camera_follow.gd`), so the camera still tracks you in an arena bigger than the screen. At the arena edge, and outside it, the camera slides past the arena (showing a little void) just far enough to keep you within 60% of the way to the screen edge, so you are never stuck at the edge of the screen (`edge_zone`, within `outside_follow_limit` = 400px of the arena). Launched farther than that, it stays on the arena (so the screen does not go blank) and the out-of-arena bubble shows where you are.
- **Zooms in as the shrinking zone closes:** the camera zoom grows with the zone's progress, up to 1.5x closer at the smallest zone (`zone_zoom_multiplier` in `camera_follow.gd`), and glides back when the zone is off. It also leans toward the zone's centre (`zone_focus`, up to 70%), so the whole circle stays in frame. From 40% progress on (`zone_release_progress`), a fighter caught **outside** the zone is no longer chased by the camera: it can leave the frame, and the "security camera" bubble (see [Fight flow](fight-flow.md)) shows it instead. A fighter inside the zone is always kept in frame.
- **Dark background everywhere:** the project background colour (`rendering/environment/defaults/default_clear_color`) is the same dark navy as the arena border, so no grey shows when the camera looks past the tiles.
- **Depth sorting:** whoever is lower on screen is drawn in front, so standing above an enemy puts you partly behind him.

For the combat-specific indicators (damage numbers, wind-up warnings, bow charge ring, armor ring) see [Combat](combat.md#feedback-on-hits).
