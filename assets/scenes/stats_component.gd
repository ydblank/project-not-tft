extends Node2D
class_name StatsComponent

enum f {FAILED, SUCCESS}

# Base
@export var base_max_health: float = 100.0
@export var base_phys_mult: float = 1.0
@export var base_mag_mult: float = 1.0
@export var base_attack: int = 0
@export var base_defense: int = 0
@export var base_knockback_res: int = 0
@export var base_attack_speed: float = 1.0
@export var base_move_speed: float = 100.0

# Dash
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.5

# Combo
@export var combo_max_hits: int = 3
@export var combo_chain_speed_multiplier: float = 0.6
@export var combo_final_cooldown: float = .5
@export var combo_chain_window: float = 0.5
@export var combo_stagger_duration: float = 0.2
@export var combo_pre_final_delay_multiplier: float = 1.15
@export var melee_slash_spawn_delay: float = 0.1
@export var combo_pause_time: float = 0.25


@export var entity_class: Classes.CLASSES = Classes.CLASSES.NONE: set = _set_entity_class
@export var entity_weapon: Weapons.WEAPONS = Weapons.WEAPONS.NONE: set = _set_entity_weapon

var class_obj: Dictionary = {}
var weapon_obj: Dictionary = {}

var max_health: float = 0.0
var attack: int = 0
var defense: int = 0
var knockback_res: int = 0
var attack_speed_mult: float = 1.0
var move_speed: float = 0.0

func _init() -> void:
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
	
func _get_weapon_obj(_weapon: Weapons.WEAPONS) -> Dictionary:
	var fallback: Dictionary = Weapons.weaponStats.get(Weapons.WEAPONS.NONE, {})
	return Weapons.weaponStats.get(_weapon, fallback)

func _assign_obj(_class: Classes.CLASSES = Classes.CLASSES.NONE, _weapon: Weapons.WEAPONS = Weapons.WEAPONS.NONE) -> bool:
	var stat_class: Classes.CLASSES = _class if _class != Classes.CLASSES.NONE else entity_class
	var stat_weapon: Weapons.WEAPONS = _weapon if _weapon != Weapons.WEAPONS.NONE else entity_weapon

	class_obj = _get_class_obj(stat_class)
	weapon_obj = _get_weapon_obj(stat_weapon)

	return f.SUCCESS

# Get entity stats (base + class)
func get_entity_stats() -> Dictionary:
	var class_stats: Dictionary = class_obj
	
	return {
		"hp": base_max_health + float(class_stats.get("bonus_hp", 0)),
		"str": float(base_attack) + float(class_stats.get("bonus_str", 0)),
		"def": float(base_defense) + float(class_stats.get("bonus_def", 0)),
		"knockback_res": float(base_knockback_res) + float(class_stats.get("bonus_knockback_res", 0)),
		"attack_speed": base_attack_speed + float(class_stats.get("bonus_attack_speed", 0.0)),
		"move_speed": base_move_speed + float(class_stats.get("bonus_move_speed", 0))
	}

# Get weapon stats
func get_entity_weapon() -> Dictionary:
	return weapon_obj
