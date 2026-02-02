extends CharacterBody2D

#@export var stats: StatsComponent
#@export var health: HealthComponent
#
#@export var damage_number_scene: PackedScene = preload("res://assets/effects/damage_number.tscn")
#@onready var healthbar = $Healthbar
#
#var max_hp = 500
#var hp = 0
#
#
#func _ready() -> void:
	#if stats != null:
		#var combined_stats = stats.get_entity_stats()
		#max_hp = combined_stats.get("hp", 500)
	#
	#hp = max_hp
	#healthbar.init_health(hp)
#
#func take_damage(damage: float):
	#var dmg: float = damage
	#
	## Apply defense calculation if stats resource is available
	#if stats != null:
		#dmg = Combat.calculations.calculate_receive_damage(stats, damage)
	#
	#_show_damage_number(int(round(dmg)))
	#hp -= dmg
	#print(hp)
	#healthbar.health = hp
	#
	#if hp < 0:
		#hp = max_hp
#
#func _show_damage_number(amount: int) -> void:
	#if amount <= 0:
		#return
	#if damage_number_scene == null:
		#return
#
	#var dn := damage_number_scene.instantiate()
	#get_tree().current_scene.add_child(dn)
#
	#var spawn_pos := global_position + Vector2(0, -20)
	#var marker := get_node_or_null("DamageSpawn")
	#if marker != null and marker is Node2D:
		#spawn_pos = (marker as Node2D).global_position
#
	#if dn.has_method("setup"):
		#dn.call("setup", amount, spawn_pos)
	#else:
		#(dn as Node2D).global_position = spawn_pos
