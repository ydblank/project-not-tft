extends Node2D
class_name StatsComponent

enum f {FAILED, SUCCESS}

# Base
@export var base_max_health: float = 100.0
@export var base_phys_mult: float = 1.0
@export var base_mag_mult: float = 1.0
@export var base_str: float = 1.0
@export var base_defense: int = 0
@export var base_knockback_res: int = 0
@export var base_attack_speed: float = 1.0
@export var base_move_speed: float = 100.0

# Dash
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.2
## Pause between chained dashes (starts when a dash ends). 0 = instant.
@export var dash_cooldown: float = 0.0
## Dash charges; dashing again right away uses the next one.
@export var dash_charges: int = 3
## Seconds for each charge to come back (one at a time).
@export var dash_recharge_time: float = 1.5
## Slower: how long the first charge takes to return after all were used in a row.
@export var dash_reload_time: float = 2.5

@export var entity_class: Classes.CLASSES = Classes.CLASSES.NONE: set = _set_entity_class
@export var entity_weapon: Weapons.WEAPONS = Weapons.WEAPONS.NONE: set = _set_entity_weapon

@export var character_sprite: Sprite2D

var class_obj: Dictionary = {}
var weapon_data: WeaponData = null

func _ready() -> void:
	_assign_obj()

func _set_entity_class(value: Classes.CLASSES) -> void:
	entity_class = value
	_assign_obj()

func _set_entity_weapon(value: Weapons.WEAPONS) -> void:
	entity_weapon = value
	_assign_obj()

func _get_class_obj(_class: Classes.CLASSES) -> Dictionary:
	var fallback: Dictionary = Classes.classStats.get(Classes.CLASSES.NONE, {})
	return Classes.classStats.get(_class, fallback)

func _assign_obj() -> bool:
	class_obj = _get_class_obj(entity_class)
	weapon_data = Weapons.get_weapon_data(entity_weapon)

	if character_sprite and class_obj.get("sprite_path", "") != "":
		character_sprite.texture = load(class_obj.sprite_path)

	return f.SUCCESS

# Get entity stats (base + class)
func get_entity_stats() -> Dictionary:
	var class_stats: Dictionary = class_obj

	return {
		"hp": base_max_health + float(class_stats.get("bonus_hp", 0)),
		"str": float(base_str) + float(class_stats.get("bonus_str", 0)),
		"def": float(base_defense) + float(class_stats.get("bonus_def", 0)),
		"knockback_res": float(base_knockback_res) + float(class_stats.get("bonus_knockback_res", 0)),
		"attack_speed": base_attack_speed + float(class_stats.get("bonus_attack_speed", 0.0)),
		"move_speed": base_move_speed + float(class_stats.get("bonus_move_speed", 0))
	}

func get_weapon_data() -> WeaponData:
	if weapon_data == null:
		weapon_data = Weapons.get_weapon_data(entity_weapon)
	return weapon_data
