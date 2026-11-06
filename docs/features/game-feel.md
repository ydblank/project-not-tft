# Game feel and visual effects

Feedback that makes hits, blocks and movement readable.

**Code:** `assets/effects/` (`hit_fx.gd`, `block_visual.gd`, `slash.gd`, `damage_number.gd`), `assets/levels/camera_follow.gd`, hit-stop in `assets/commons/combat.gd` (the `Combat` autoload).

## Hit feedback

- **Freeze frame on hit** (a true freeze, kept short), plus **camera shake** along the hit direction (bigger on heavy hits and kills). Both only trigger when the **player** hits or gets hit.
- **Hit effects:** blood splats and droplets on fighters, sparks on blocks and on the dummy.
- **Slash effect follows you** during the swing (it no longer stays at your start position when you lunge).
- **Dash afterimage trail.**

## Blocking

Blocking is easy to read:

- a shield arc on the guarded side (blue, turning red as the shield drains);
- a shield meter above the head;
- a bright pulse and small push-back on each blocked hit, and a "BLOCKED" popup;
- a "GUARD BREAK!" popup with a red flash and shattering shards when the shield breaks.

## Camera and background

- **Gentle camera follow:** drifts toward the fighter you control, leaning toward your teammate (follow strength is adjustable). It never leaves the arena, so being launched far outside does not blank the screen.
- **Dark background everywhere:** the project background colour (`rendering/environment/defaults/default_clear_color`) is the same dark navy as the arena border, so no grey shows when the camera looks past the tiles.
- **Depth sorting:** whoever is lower on screen is drawn in front, so standing above an enemy puts you partly behind him.

For the combat-specific indicators (damage numbers, wind-up warnings, bow charge ring, armor ring) see [Combat](combat.md#feedback-on-hits).
