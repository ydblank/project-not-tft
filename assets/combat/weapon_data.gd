@tool
extends Resource
class_name WeaponData

## A weapon: its moves (AttackMove sub-resources), how it fights (melee or ranged, projectile) and its
## skill. Its balance numbers (power, attack speed, damage per move, charge, cooldowns, AI range, type and
## skill) come from the table in assets/resources/weapons.gd when it loads (Weapons.get_weapon_data).

## How a weapon fights: melee hitbox or projectile.
enum Kind {MELEE, RANGED}
## What kind of weapon it is (a family: several swords can share SWORD). Set from the weapons table.
enum Type {NONE, SWORD, DAGGER, BOW, STAFF}

@export var display_name: String = ""
## Weapon family (sword, dagger, bow, staff). Set from the table in assets/resources/weapons.gd.
@export var weapon_type: Type = Type.NONE
@export var kind: Kind = Kind.MELEE
## Ranged weapons spawn this instead of a melee hitbox (must be an ArrowProjectile scene).
@export var projectile_scene: PackedScene

@export_group("Stats")
## Multiplier on the fighter's power (the class damage stat). 1.0 = the fighter's power as it is.
@export var power_mult: float = 1.0
@export var attack_speed_bonus: float = 0.0

@export_group("Moves")
@export var light_moves: Array[AttackMove] = []
@export var heavy_move: AttackMove
## Melee heavy combo: one charge + release plays every hit in order with no
## further input. Empty = the single heavy_move (e.g. the bow).
@export var heavy_combo: Array[AttackMove] = []

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
## After finishing the whole quick (light) combo, new light attacks are locked
## for this long. 0 = no cooldown (single-move weapons like the bow).
@export var light_combo_cooldown: float = 0.0
## Non-final hits of a combo (quick or heavy) hold the victim in hitstun this long, so
## the next hit connects. Only a dash gets them out. The final hit uses its own reaction.
@export var combo_hitstun: float = 0.55
## A tap made while busy is remembered this long.
@export var input_buffer: float = 0.3

@export_group("Skill")
## The weapon's special skill (E). Specific to this weapon resource, not its type. Empty = no skill.
@export var skill: SkillData

@export_group("AI")
## Distance at which an AI starts its light combo with this weapon.
@export var ai_engage_range: float = 30.0


func light_move_count() -> int:
	return light_moves.size()


func get_light_move(index: int) -> AttackMove:
	if light_moves.is_empty():
		return null
	return light_moves[clampi(index, 0, light_moves.size() - 1)]


func heavy_hit_count() -> int:
	return maxi(heavy_combo.size(), 1)


## The heavy move for hit `index` (the heavy combo if there is one).
func get_heavy_move(index: int) -> AttackMove:
	if heavy_combo.is_empty():
		return heavy_move
	return heavy_combo[clampi(index, 0, heavy_combo.size() - 1)]
