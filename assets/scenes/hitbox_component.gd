extends Area2D
class_name HitboxComponent

# The entity's hurtbox and the single place where an incoming hit is resolved:
#   ignore (dead / same team / disabled) -> shield check -> defense -> health
#   -> knockback %-meter -> reaction on the CombatComponent -> feedback.

enum Result {IGNORED, BLOCKED, HIT}

signal hit_received(attacker: Node, damage: float, direction: Vector2)
signal hit_blocked()

@export var team: int = 0
@export var can_be_hit: bool = true
@export var stats: StatsComponent
@export var health: HealthComponent

@export_group("Damage Settings")
@export var use_combat_calculations: bool = true
@export var damage_number_scene: PackedScene

@export_group("Knockback")
@export var base_knockback_force: float = 220.0
@export var knockback_scale_start: float = 1.0
@export var knockback_scale_gain_per_hit: float = 0.15
@export var knockback_scale_gain_per_damage: float = 0.01
@export var knockback_scale_max: float = 4.0
@export var knockback_scale_decay_per_sec: float = 0.25

@export_group("Debug")
@export var debug_hits: bool = false

var knockback_scale: float = 1.0
var _combat: CombatComponent = null


func _ready() -> void:
	if not health:
		health = _find_sibling(HealthComponent) as HealthComponent
	knockback_scale = knockback_scale_start
	_combat = CombatComponent.find_on(get_entity())
	set_process(knockback_scale_decay_per_sec > 0.0)


func _process(delta: float) -> void:
	knockback_scale = maxf(knockback_scale_start, knockback_scale - knockback_scale_decay_per_sec * delta)


## The character / object this hurtbox belongs to.
func get_entity() -> Node2D:
	if owner is Node2D:
		return owner as Node2D
	return get_parent() as Node2D


func is_same_team(other_team: int) -> bool:
	return team == other_team


func set_team(new_team: int) -> void:
	team = new_team


func receive_hit(hit: HitData) -> Result:
	if hit == null or not can_be_hit or health == null or health.is_dead():
		return Result.IGNORED
	if is_same_team(hit.team) or hit.attacker == get_entity():
		return Result.IGNORED

	# Shield: direction the hit comes FROM, relative to us.
	if _combat:
		var from_dir := -hit.direction
		if is_instance_valid(hit.attacker):
			from_dir = hit.attacker.global_position - global_position
		if _combat.is_blocking_from(from_dir):
			hit_blocked.emit()
			return Result.BLOCKED

	var final_damage := hit.damage
	if use_combat_calculations and stats:
		final_damage = CombatGlobal.calculate_receive_damage(stats, hit.damage)

	knockback_scale = minf(knockback_scale + knockback_scale_gain_per_hit + final_damage * knockback_scale_gain_per_damage, knockback_scale_max)

	health.take_damage(final_damage)
	hit_received.emit(hit.attacker, final_damage, hit.direction)

	var force := 0.0
	if hit.reaction == AttackMove.Reaction.KNOCKBACK:
		force = base_knockback_force * knockback_scale * maxf(hit.knockback_force_mult, 0.0)
	if _combat and not health.is_dead():
		_combat.receive_reaction(hit, force)

	if debug_hits:
		print("[HIT] ", get_entity().name, " dmg=", snappedf(final_damage, 0.01), " reaction=", hit.reaction, " force=", snappedf(force, 0.1), " scale=", snappedf(knockback_scale, 0.01))

	_show_damage_number(int(round(final_damage)))
	Combat.hitstop(hit.hitstop)
	return Result.HIT


func _show_damage_number(amount: int) -> void:
	if amount <= 0 or damage_number_scene == null:
		return
	var dn = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(dn)
	var spawn_pos := global_position + Vector2(0, -20)
	var marker := get_entity().get_node_or_null("DamageSpawn") if get_entity() else null
	if marker is Node2D:
		spawn_pos = (marker as Node2D).global_position
	if dn.has_method("setup"):
		dn.call("setup", amount, spawn_pos)
	else:
		(dn as Node2D).global_position = spawn_pos


func _find_sibling(type: Variant) -> Node:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if is_instance_of(child, type):
				return child
	return null
