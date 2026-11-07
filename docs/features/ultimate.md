# Ultimate

Each class has one ultimate on **Q**. It fills as you land hits and lasts 5 s. On a controller it is **RB**. In 2P mode, Player 1 uses **K** and Player 2 uses **Right Shift**. Unlike the [weapon skill](skills.md) on E, the ultimate belongs to the **class**, not the weapon. (GAM-23)

**Code:**
- **`assets/resources/ultimates.gd` is the balance table: one row per class, plus `DEFAULTS` shared by all. To balance an ultimate, edit its row there.** It holds the meter size, the duration, the low-HP boost and each class's effect numbers. `charge_gain()` and `hp_mult()` are the charge formula.
- `action_state_machine.gd` owns the meter (`ult_charge`), the press, the 5 s timer and the effects that live in the state machine: attack speed, the Archer's auto heavies, the Mage's cooldown, cast and charge times, and the Knight's stun immunity. All of these are pure logic, tested in `tests/test_combat_ultimate.gd`.
- `combat_component.gd` loads the class row (`_ultimate_row`), fills the meter (`on_hit_dealt`), applies the move speed and plays the activation effects.
- `hitbox_component.gd` credits the attacker's meter when a hit reaches health (`_credit_ultimate`), and handles the Knight's immunity (`_immune`). `arrow_projectile.gd` and `fireball_projectile.gd` let projectiles fly through the Thief.
- `assets/effects/ultimate_aura.gd` is the aura on the fighter. `assets/ui/ultimate_bar.gd` is the meter under each HUD health bar. The HUD button is in `assets/ui/controls_hint.gd`.

## The ultimates

| Class | Ultimate | For 5 s |
|---|---|---|
| Knight | **Unbreakable** | Takes **no damage**, no stagger and no knockback, not even from a parry, a guard break or burning ground. Walks 1.2x faster, so it cannot simply be kited. Hits on it show a gold "IMMUNE" and a clang. |
| Thief | **Shadow Rush** | Walks 1.4x faster and attacks 1.4x faster (the quick-combo cooldown too). **Single-target projectiles fly through it**: arrows, volley arrows and quick fireballs, with an afterimage and a "DODGE" pop. AoE still hits: a charged or skill fireball does not go off *on* the Thief, but its blast hits if it explodes nearby, and burning ground still burns. |
| Archer | **Deadeye** | Every shot is a heavy with no charge-up. Hold attack to keep firing at the normal quick-shot pace. Shots are charged to 60% (`auto_heavy_charge`): the bow's heavy is 1.5x and a full draw 2x on top, so a full charge would be 3x a quick shot. 60% gives about 2.1x: steady damage, not burst. |
| Mage | **Arcane Surge** | The skill cooldown runs 4x faster (75% shorter, including a cooldown already running), and the skill cast time and the heavy charge are 75% shorter. Inferno comes back in about 2.5 s. Dash is not affected. |

Roles behind the numbers: the Knight is the frontline tank, the Thief dives the backline, the Archer is steady long-range damage, and the Mage is frail with huge range and crowd control.

## The meter

- **It fills from hits you land on an enemy's health.** Each hit adds **its own multiplier, not its damage**:
  - a weapon move adds `damage_mult × charge`, so the sword's quick hits add 0.5, 0.5 and 1.2, and a full bow draw adds 3.0;
  - a skill hit adds the skill's `damage_mult`;
  - a burning-ground tick adds its share of the burn (0.5 per tick).
- Class power, defense, the weapon's power multiplier, Damage x and difficulty are left out, so a high-power class does not fill faster just from its stats. Faster attackers (the Thief) do fill a little faster.
- **10 points fill it.** An AoE that hits two enemies counts for each of them.
- **Below 50% HP it fills faster**, rising to 2x at 0 HP. Above half HP it fills at the normal rate.
- Blocked, parried and immune hits add nothing, and so do hits on the training dummy. Taking damage never adds anything.
- Nothing is added while the ultimate runs.
- The meter starts empty each match, and empties on death, respawn and a loadout change (F2).

## Using it

- Press Q with a full meter. It works from any state except stagger, knockback and death, including mid-swing and mid-dash. It does not interrupt what you are doing.
- **Activation:** a burst of rings and embers in the ultimate's colour, its name in big letters ("UNBREAKABLE!"), a deep crash (a placeholder sound), and a short freeze and camera shake when it is yours.

## Look

- **Ready:** a pulsing red glow hugging the fighter's outline, a red pool of light at its feet and rising embers, like Tekken's rage aura. **Every fighter shows it**, so you can see when an enemy's ultimate is ready.
- **Active:** the same, brighter and faster, in the ultimate's colour (Knight gold, Thief purple, Archer green, Mage blue), with an arc round the feet that empties over the 5 s.
- **HUD bar:** a thin bar under each fighter's health bar. It is dark red while filling, pulses red when full, and turns the ultimate's colour as it empties while active.
- **Controller overlay (F1):** an "ULT" button, bottom-left of the action buttons. A red ring fills with the meter, the button throbs red when it is ready, and a coloured sweep shows the time left while it runs. It is dimmed for a class without an ultimate.

## AI

`AIComponent` uses the ultimate when `use_ultimate` is on (in the "Smarts" export group) and the meter is full. It looks every 0.25 s and rolls the personality's "skill" chance.

| Class | Fires it when |
|---|---|
| Knight | An enemy is within its reach (+20 px), or it is below half HP and the enemy is close |
| Thief | The target is in view and within its dash range |
| Archer | The target is in view and within 1.5x its engage range |
| Mage | The target is in view and in skill range, right after a skill cast (cooldown still 2 s or more) |
| Any | Below 30% HP with the target within twice its reach |

## Balancing

- **The table:** `assets/resources/ultimates.gd`. `tests/test_combat_ultimate.gd` checks that every class has a row and that every field in it is a known one.
- **Sliders:** Pause menu → Dev Tools → **Ultimate**:
  - meter fill speed x;
  - duration x;
  - **Always full** (testing): every fighter's meter refills whenever its ultimate is not running, bots included.

## Known limitations

- The activation sound is a placeholder (the guard-break crash played low).
- There is no animation of its own; the aura and the burst are the only visuals.
- The numbers are first guesses. One run in the running game was checked: bots filled their meters and fired (the enemy Knight's gold aura and timer arc, the enemy Archer's green bar). The ultimates have not been tuned in long fights.
- The 2P Right Shift binding and the controller RB were not tested by hand.
