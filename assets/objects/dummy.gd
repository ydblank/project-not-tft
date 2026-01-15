extends CharacterBody2D

@export var def = 0

@export var damage_number_scene: PackedScene = preload("res://assets/effects/damage_number.tscn")

var dummy_stats: Dictionary = {}

var CombatClass = Combat

func _ready() -> void:
	dummy_stats = {
		"def": def
	}

func take_damage(damage: float):
	var dmg: float = Combat.calculations.calculate_receive_damage(dummy_stats, damage)
	_show_damage_number(int(round(dmg)))

func _show_damage_number(amount: int) -> void:
	if amount <= 0:
		return
	if damage_number_scene == null:
		return

	var dn := damage_number_scene.instantiate()
	get_tree().current_scene.add_child(dn)

	var spawn_pos := global_position + Vector2(0, -20)
	var marker := get_node_or_null("DamageSpawn")
	if marker != null and marker is Node2D:
		spawn_pos = (marker as Node2D).global_position

	if dn.has_method("setup"):
		dn.call("setup", amount, spawn_pos)
	else:
		(dn as Node2D).global_position = spawn_pos
