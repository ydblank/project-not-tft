@tool
extends RefCounted
class_name HitData

# Everything a hurtbox needs to resolve one hit. Built by the attacker,
# consumed by HitboxComponent.receive_hit().

var attacker: Node2D = null
var team: int = -1
## Damage before the victim's defense is applied.
var damage: float = 0.0
## Unit vector from the attacker toward the victim.
var direction: Vector2 = Vector2.ZERO
var reaction: AttackMove.Reaction = AttackMove.Reaction.STAGGER
var stagger_time: float = 0.2
## move.knockback_mult × charge multiplier.
var knockback_force_mult: float = 1.0
var hitstop: float = 0.05
## Fired by a ranged weapon (arrow) rather than a melee swing.
var is_ranged: bool = false
## Came from a heavy move (charged or not).
var is_heavy: bool = false
## Non-final hit of a combo: the victim is held in hitstun while the combo continues.
var is_combo_chain: bool = false
## Last hit of a combo, or a heavy: gets the bigger hit-confirm effect.
var is_finisher: bool = false
## Damage over time (burning ground): ignores block, causes no reaction or hitstop.
var is_dot: bool = false
