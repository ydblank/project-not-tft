# Calculations

Every number rule in combat in one place: the stats a fighter has, damage dealt, damage taken, attack speed and knockback.

**Code:** `assets/resources/classes.gd` (class table), `assets/scenes/stats_component.gd` (base + class stats), `assets/commons/combat.gd` (the formulas, `Combat` autoload, unit-tested), `assets/combat/combat_component.gd` (`build_hit`), `assets/scenes/hitbox_component.gd` (`receive_hit`), `assets/combat/action_state_machine.gd` (attack speed on move times). Weapons are data in `assets/combat/weapons/*.tres`.

## Stats

`StatsComponent.get_entity_stats()` returns each stat as **base + class bonus**. Add any new bonus (artifact, consumable, skill) here so they stack in one place.

| Stat | Key | Base | Meaning |
|---|---|---|---|
| Power | `power` | 0 | Damage stat for physical and magic attacks. Comes from the class. |
| Defense | `def` | 0 | Percent cut of incoming damage (10 = 10% less). |
| Knockback resistance | `knockback_res` | 0 | Stored, **not used yet** by the knockback rules. |
| Attack speed | `attack_speed` | 1.0 | Multiplier on move times. Around 0.85 to 1.25 for the classes. |
| HP | `hp` | 100 | Max health. |
| Move speed | `move_speed` | 100 | Walking speed. |

Class table (the design sheet, Linear GAM-29; `power` is the sheet's "damage" column):

| Class | Starting weapon | Power | Defense | Knockback res | Attack speed (sheet rating) | HP |
|---|---|---|---|---|---|---|
| Knight | Sword | 10 | 10 | 10 | 0.85x (2) | 100 |
| Thief | Dagger | 5 | 7 | 5 | 1.25x (10) | 100 |
| Archer | Bow (the sheet says Fist) | 7 | 5 | 5 | 1.10x (7) | 100 |
| Mage | Staff | 12 | 3 | 5 | 1.00x (5) | 100 |

- **Attack speed rating:** the sheet rates it 1 to 10. The class bonus is `0.05 × rating - 0.25`, so the multiplier is `1.0 + bonus` (rating 5 = 1.0x).
- **One weapon per class.** No secondary weapons.
- **Archer:** keeps the bow until the slingshot is added with the ranged weapons work.

## Damage dealt

```
hit damage = max(power × weapon.power_mult × move.damage_mult × charge_mult × Damage x, 1)
```

- `power`: the attacker's stat above.
- `weapon.power_mult`: multiplier from the weapon's `.tres` (sword, dagger and bow are 1.0, the staff is 0.75 because the Mage's power is high; unarmed defaults to 1.0).
- `move.damage_mult`: per move (the sword's quick hits are 0.5, 0.5, 1.2).
- `charge_mult`: 1.0 for quick attacks; a charged heavy scales between `heavy_min_mult` and `heavy_max_mult` of the weapon.
- `Damage x`: the pause-menu tunable, 1.0 by default.
- Never below 1.

Examples: Knight, sword quick hit 3 = 10 × 1.0 × 1.2 = **12**. Thief, dagger quick hit with a 1.0 move = **5**. Archer, bow quick shot = **7**. Mage, staff quick shot = 12 × 0.75 × 1.0 = **9**; a full-charge staff fireball = 12 × 0.75 × 1.5 × 2.5 = **33.75** (full bow draw: **21**). A full-charge fireball does 33.75 at the centre of its blast and 50% of that at the rim; each fighter is hit once.

## Damage taken

```
after defense = max((1 - def / 100) × hit damage, 1)
```

Then, in order (`HitboxComponent.receive_hit`):

1. **Ignored** while dashing (i-frames), against the same team and against yourself.
2. **Defense** as above (when the hitbox uses combat calculations).
3. **Parry** (block raised in the first 0.2s, normal hits only): no damage, no shield damage.
4. **Block** (facing the attacker): the shield absorbs `damage × damage_mult_while_blocking` (1.0). While it holds, the hit is fully blocked. A hit that empties the shield is a guard break: the rest gets through and the owner is stunned.
5. **Health** takes the remaining damage.

Example: Knight (def 10) takes a 20-damage hit = 18. Archer (def 5) takes it as 19.

**Environment damage** (standing outside the arena) skips defense, blocking and knockback: `max HP × 8% × seconds` (the pause-menu "Outside damage" setting).

## Attack speed

```
attack speed = max(class attack speed + weapon.attack_speed_bonus, 0.001)   × dev "Attack speed x"
move duration = base duration / max(attack speed, 0.05)
```

The class value already includes the base 1.0. Examples: Knight + sword = 0.85 + 0.10 = **0.95**. Thief + dagger = 1.25 + 0.25 = **1.5**. Mage + staff = 1.0 + 0.0 = **1.0**, so the order is Knight (0.95) < Mage (1.0) < Archer (1.15) < Thief (1.5).

## Knockback

```
force = 220 × knockback_scale × move.knockback_mult × charge_mult
```

Only hits whose reaction is "knockback" push (the final hit of a combo, heavies). `knockback_scale` belongs to the victim, like a smash-style percent meter:

- starts at 1.0, grows by `0.15 + 0.01 × damage taken` on every hit, up to 4.0;
- falls back by 0.25 per second while not being hit.

`knockback_res` will reduce this once it is wired. Today it has no effect.

## Order of operations

1. Controller writes an intent; the state machine times the move with **attack speed**.
2. `build_hit` makes the hit with **damage dealt**.
3. The victim's hitbox runs **damage taken** (dash, defense, parry, block).
4. Health loses the remaining damage; the **knockback** force is applied by the reaction.

## Adding a new modifier

- A permanent bonus (artifact, consumable, level): add it to the matching stat in `get_entity_stats()`.
- A bonus on the hit (for example "+10% damage after a dash"): multiply it in `build_hit`, next to `Damage x`.
- A bonus on damage taken (for example damage-type matchups): apply it right after defense in `receive_hit`.
- Keep the pure math in `combat.gd` (static, unit-tested) and the node access in the components.
