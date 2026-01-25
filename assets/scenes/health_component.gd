extends Node2D
class_name HealthComponent

signal health_changed(new_hp: float, max_hp: float)
signal damage_taken(amount: float)
signal died()
signal healed(amount: float)

@export var _max_hp: float = 100
@export var invincible: bool = false

var _hp: float = 0
var _is_dead: bool = false

func _ready():
	_hp = _max_hp
	health_changed.emit(_hp, _max_hp)
	
func set_max_hp(max_hp: float):
	_max_hp = max_hp
	_hp = min(_hp, _max_hp)
	health_changed.emit(_hp, _max_hp)
	
func set_hp(hp: float):
	_hp = min(hp, _max_hp)
	health_changed.emit(_hp, _max_hp)

func get_hp() -> float:
	return _hp

func get_max_hp() -> float:
	return _max_hp

func is_dead() -> bool:
	return _is_dead

func take_damage(damage: float) -> void:
	if invincible or _is_dead:
		return
	
	var actual_damage = max(damage, 0)
	_hp -= actual_damage
	_hp = max(_hp, 0)
	
	damage_taken.emit(actual_damage)
	health_changed.emit(_hp, _max_hp)
	
	if _hp <= 0:
		die()

func heal(amount: float) -> void:
	if _is_dead:
		return
	
	var actual_heal = max(amount, 0)
	var old_hp = _hp
	_hp = min(_hp + actual_heal, _max_hp)
	
	var healed_amount = _hp - old_hp
	if healed_amount > 0:
		healed.emit(healed_amount)
		health_changed.emit(_hp, _max_hp)

func die() -> void:
	if _is_dead:
		return
	
	_is_dead = true
	died.emit()

func revive(hp_amount: float = -1) -> void:
	_is_dead = false
	if hp_amount < 0:
		_hp = _max_hp
	else:
		_hp = min(hp_amount, _max_hp)
	health_changed.emit(_hp, _max_hp)

func get_hp_percentage() -> float:
	if _max_hp <= 0:
		return 0.0
	return (_hp / _max_hp) * 100.0
