# Skills

Each weapon has one special skill on **E**. On a controller it is **B**. In 2P mode, Player 1 uses **J** and Player 2 uses **/**. The skill belongs to the weapon resource itself, not to the weapon type, so two swords can have different skills. (GAM-20)

**Code:**
- `assets/combat/skill_data.gd` is the `SkillData` resource: kind, tags, aim mode, timing, reach, damage and AI hints. Distances are in pixels; one arena tile is `SkillData.TILE`, which is 16 px.
- **`assets/resources/skills.gd` is the balance table: every skill's damage multiplier, burn multiplier, cooldown, cast time, duration and reach (in tiles) in one place. To balance a skill, edit its row there.** The table is applied to each skill when its weapon loads (`Weapons.get_weapon_data`), and `tests/test_combat_skills.gd` checks that every row and field matches a real skill file and property.
- `assets/combat/skills/*.tres` holds how each skill works: kind, tags, aim mode, knockback, stagger, hitstop and timings such as the volley interval. Which weapon has which skill is the `skill` field of its row in the weapons table, `assets/resources/weapons.gd`. The row name in the table is the `.tres` file name.
- `action_state_machine.gd` has the `SKILL_AIM` and `SKILL` states, the cooldown and the interrupt rules. These are pure logic, tested in `tests/test_combat_skills.gd`.
- `assets/combat/skill_caster.gd` (`SkillCaster`) runs the skill and owns the AoE marker. CombatComponent creates one on every fighter.
- `assets/effects/skill_marker.gd` draws the AoE marker. `assets/effects/spin_slash.gd` is the Whirlwind's animation. `assets/effects/burning_ground.gd` is the Mage's fire on the ground.
- `tools/make_ground_fire_sprites.gd` generates the flame sheet `assets/art/1 Characters/Other/Ground_Fire.png` (8 frames of 16 x 20). Run it with `<godot> --headless --path . --script res://tools/make_ground_fire_sprites.gd`.

## The skills

| Weapon | Skill | Multiplier | Cooldown | Tags (for the AI) |
|---|---|---|---|---|
| Sword | **Whirlwind** (spin) | 1.75 | 7 s | defensive, damage, melee |
| Dagger | **Shadow Lunge** (dash strike) | 2.0 | 5 s | gap closer, damage, range |
| Bow | **Arrow Volley** | 1.0 per arrow | 10 s | damage, AoE, range |
| Staff | **Inferno** (big fireball) | 2.0 blast, 0.5 per second burning | 10 s | damage, AoE, range |

### Whirlwind (sword)

- Spins for 0.6 s and hits every enemy within 2 tiles once, with knockback.
- Destroys enemy arrows and fireballs that enter the circle.
- Blocks hits from every side, without draining the shield.
- In the first 0.2 s, a hit is **parried**: a melee attacker is stunned, and an arrow flies back. Heavy hits are blocked, not parried.
- You can move slowly while spinning. Hits cannot interrupt the spin.
- **Animation:** a white crescent swoosh sweeps twice round the fighter. It is thin and faint at its tail and wide and bright at its head, with the sword and hilt riding the leading edge and specks flung off. The fighter turns with it.

### Shadow Lunge (dagger)

- Dashes along the aim for up to 6 tiles.
- Stops at the **first enemy hit**, which takes the damage and a 0.5 s stagger. It also stops at a wall.
- No i-frames: it is for closing the gap, not for escaping.
- A miss still costs the full cooldown.

### Arrow Volley (bow)

- Fires 5 volleys of 5 arrows, 0.18 s apart. Each volley is a 40° fan, and the arrows fly 12 tiles.
- Each volley follows your live aim, so you can sweep it.
- **A fighter is hit by at most one arrow per volley**, so one target takes at most 5 hits.
- You can strafe slowly while firing.

### Inferno (staff)

- **1 s cast:** after you release, the Mage stands still for 1 s while the fireball grows in its hands. The AoE marker stays on the locked spot. The cast time shows like a heavy charge: a ring round the Mage fills from white to gold (and the HUD skill button gets the same gold ring as the Attack button), while an enemy Mage shows the closing red ring and blinking "!" of a charging heavy. Then the fireball is thrown at the aimed spot, at most 10 tiles away. A stagger during the cast cancels the spell, and the cooldown is still spent, so cast from a safe distance. For an enemy Mage, the red circle is your 1 s warning.
- Explodes on an enemy, on a wall, or where you aimed. The blast covers 3.5 tiles, with the same falloff and knockback as the heavy fireball.
- The fireball cannot be parried.
- Leaves **burning ground** of the same size for 3 s, ticking 0.25x every 0.5 s. **Every tick staggers** for 0.25 s; the stagger can be dashed out of and ignores the usual stun immunity. The burning ignores block and does not hurt your own team.
- **Look:** a scorched patch with about 30 animated pixel flames that flicker out of step, grow in at the start and die down at the end, inside a team-coloured rim. The tick sound is a placeholder (the quick whoosh played low) until a real sizzle is added.

Unarmed fighters have no skill, and their HUD button is dimmed.

## Using a skill

- **Aimed skills** (dagger, volley, fireball): hold E to show the marker and the max-range ring, then release to cast. A quick tap casts at once on your current aim.
- **Fireball aim:** it aims at the mouse cursor, pulled in to its range. With a controller it aims along the stick; push the right stick further to put the spot further out, down to 35% of the range at a light push.
- **Sword spin:** casts the moment you press.
- **Cancel:** block (RMB / LB) cancels an aim with no cooldown spent. A dash also leaves the aim.
- **When you can cast:** from idle, from a charge, from a block, or during an attack's recovery.
- **Interrupts:** a stagger interrupts an aim or a normal skill, and the cooldown is still spent. The spin and the dagger dash are *unstoppable*: normal hits do not interrupt them, but a parry stun does.
- **Cooldown resets:** skills are ready at the start of a match, after a respawn and after a loadout change.

## AoE markers

The marker is drawn while you aim, and for the whole of a spin or a volley:

| Skill | Marker |
|---|---|
| Spin | a ring |
| Dagger | a lane, cut short at the first wall |
| Volley | a fan |
| Fireball | the max-range ring around you, plus the blast circle at the aimed spot |

- **Blue** when the caster is on your team, **red** when it is an enemy. A bot aiming a skill shows its red marker for about 0.3 s first, as a warning.
- Burning ground has a rim in the same team colour.

## HUD

The skill button sits top-left of the action buttons in the controller overlay (F1). It shows:
- a generic sparkle icon (a skill's `icon` texture replaces it);
- the cooldown as a dark sweep with the seconds left;
- a glow when the skill is ready again.

## AI

`AIComponent` uses skills when `use_skills` is on (in the "Smarts" export group). It decides with the skill's tags:

| Tag | Used when |
|---|---|
| **Defensive** (spin) | An enemy projectile will hit within about 0.35 s, an enemy is winding up within reach, 2 or more enemies are inside the radius, or 1 open enemy is. |
| **Gap closer** (dagger) | The target is in clear view, within the dash range, not blocking, with no wall in the lane. Preferred on open targets, or on targets just beyond melee reach. |
| **AoE** (volley, fireball) | The target is in range and in view. Always on a group of 2 or more or a stunned target; half the time on a lone healthy one. |

- **Danger zones:** bots walk straight out of an enemy skill area and slide round its edge instead of stepping in (export `avoid_danger`). An area counts while its marker is up (aimed, casting, or a spin or volley running) and for as long as burning ground lasts. For a skill about to land they may dash out instead (a share of their dodge trait). Each SkillCaster and BurningGround answers `danger_at(point, team)` and `danger_escape(point)` through the group `danger_zones`.
- Bots hold an aimed skill for `skill_aim_time` (0.3 s) before releasing, so their red marker shows. The hold is shorter on Hard and longer on Easy, using the same factor as the dodge reaction.
- Each personality has a "skill" chance: 0.8 for courageous, 0.6 for cowardly.

## Balancing ranges

- **Sliders:** Pause menu → Dev Tools → **Skills**. Each slider starts at the skills table's value and only overrides it once you move it (only changed settings are saved, so a slider you never touched follows the table). Dev Tools → Reset to defaults goes back to the table. Distances are in tiles:
  - fireball cast time (seconds);
  - cooldown scale;
  - spin radius;
  - dagger range;
  - volley range and spread;
  - fireball range, blast radius and burning radius.
- **Tile ruler:** **F5** toggles labelled rings at 2, 4, 6, 8, 10 and 12 tiles around your fighter. For scale, the arena is 31 x 15 tiles.
- **Range ring:** the max-range ring shown while aiming gives the same feel for one skill.

## Known limitations

- Only the Whirlwind has its own animation; the other skills use the attack pose.
- The icon is a placeholder.
- Fire avoidance and the cast window were checked against one bot in the running game: the knight left the marked circle 0.5 s into a cast, and walked out of the fire in 0.8 s. Not tuned in long fights.
- Ranges and AI rules are first guesses, checked by script in the running game, not in long live fights.
