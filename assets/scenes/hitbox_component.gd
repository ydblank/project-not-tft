extends Area2D
class_name HitboxComponent

signal hit_received(attacker: Node, damage: float, direction: Vector2)
signal hit_blocked()
signal hitbox_area_entered(area: Area2D)
signal hitbox_body_entered(body: Node2D)

@export var team: int = 0
@export var can_be_hit: bool = true
@export var stats: StatsComponent
@export var health: HealthComponent

@export_group("Damage Settings")
@export var use_combat_calculations: bool = true
@export var damage_number_scene: PackedScene

func _ready():
	
	if not health:
		health = _find_health_component()

func _find_health_component() -> HealthComponent:
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is HealthComponent:
				return child
	return null

func take_damage(damage: float, attacker: Node = null, direction: Vector2 = Vector2.ZERO) -> void:
	if not can_be_hit:
		hit_blocked.emit()
		return
	
	if not health:
		push_warning("HitboxComponent: No HealthComponent found, cannot take damage")
		return
	
	var final_damage = damage
	
	if use_combat_calculations and stats != null:
		final_damage = CombatGlobal.calculate_receive_damage(stats, damage)
	
	health.take_damage(final_damage)
	hit_received.emit(attacker, final_damage, direction)
	
	_show_damage_number(int(round(final_damage)))
		

func set_team(new_team: int) -> void:
	team = new_team

func is_same_team(other_team: int) -> bool:
	return team == other_team

func _on_area_entered(area: Area2D) -> void:
	# Override this in derived classes or connect to signal
	hitbox_area_entered.emit(area)

func _on_body_entered(body: Node2D) -> void:
	# Override this in derived classes or connect to signal
	hitbox_body_entered.emit(body)

func _show_damage_number(amount: int) -> void:
	if amount <= 0:
		return
	if damage_number_scene == null:
		return

	var dn = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(dn)

	var spawn_pos = global_position + Vector2(0, -20)
	var marker = get_parent().get_node_or_null("DamageSpawn")
	if marker != null and marker is Node2D:
		spawn_pos = (marker as Node2D).global_position

	if dn.has_method("setup"):
		dn.call("setup", amount, spawn_pos)
	else:
		(dn as Node2D).global_position = spawn_pos
