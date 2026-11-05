@tool
extends Resource
class_name WeaponData

enum Kind {MELEE, RANGED}

@export var display_name: String = ""
@export var kind: Kind = Kind.MELEE
## Ranged weapons spawn this instead of a melee hitbox (must be an ArrowProjectile scene).
@export var projectile_scene: PackedScene

@export_group("Stats")
@export var base_damage: float = 0.0
@export var attack_speed_bonus: float = 0.0

@export_group("Moves")
@export var light_moves: Array[AttackMove] = []
@export var heavy_move: AttackMove

@export_group("Charge")
## Holding attack at least this long turns the press into a charged heavy.
@export var charge_threshold: float = 0.4
## Total hold time at which the charge is full.
@export var max_charge_time: float = 1.5
@export var heavy_min_mult: float = 1.0
@export var heavy_max_mult: float = 1.5

@export_group("Combo")
## After an attack's recovery, the next light hit continues the combo within this window.
@export var combo_window: float = 0.5
## A tap made while busy is remembered this long.
@export var input_buffer: float = 0.3

@export_group("AI")
## Distance at which an AI starts its light combo with this weapon.
@export var ai_engage_range: float = 30.0


func light_move_count() -> int:
	return light_moves.size()


func get_light_move(index: int) -> AttackMove:
	if light_moves.is_empty():
		return null
	return light_moves[clampi(index, 0, light_moves.size() - 1)]
