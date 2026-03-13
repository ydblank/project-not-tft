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
@export var shield: ShieldComponent

@export_group("Damage Settings")
@export var use_combat_calculations: bool = true
@export var damage_number_scene: PackedScene

@export_group("Knockback")
@export var enable_knockback: bool = true
@export var base_knockback_force: float = 220.0
@export var knockback_duration: float = 0.25

@export var knockback_scale_start: float = 1.0
@export var knockback_scale_gain_per_hit: float = 0.15
@export var knockback_scale_gain_per_damage: float = 0.01
@export var knockback_scale_max: float = 4.0

@export var knockback_scale_decay_per_sec: float = 0.25

@export_group("Debug")
@export var debug_knockback: bool = true

var knockback_scale: float = 1.0


func _ready() -> void:
	if not health:
		health = _find_health_component()

	knockback_scale = knockback_scale_start
	set_process(knockback_scale_decay_per_sec > 0.0)


func _process(delta: float) -> void:
	if knockback_scale_decay_per_sec <= 0.0:
		return

	knockback_scale = max(
		knockback_scale_start,
		knockback_scale - knockback_scale_decay_per_sec * delta
	)


func _find_health_component() -> HealthComponent:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child is HealthComponent:
				return child
	return null


func take_damage(
	damage: float,
	attacker: Node = null,
	direction: Vector2 = Vector2.ZERO,
	allow_knockback: bool = true,
	knockback_mult: float = 1.0
) -> void:
	if not can_be_hit:
		hit_blocked.emit()
		return

	if not health:
		push_warning("HitboxComponent: No HealthComponent found, cannot take damage")
		return

	# --- Final damage after combat calculations ---
	var final_damage: float = damage
	if use_combat_calculations and stats != null:
		final_damage = CombatGlobal.calculate_receive_damage(stats, damage)

	# --- Shield interception ---
	var damage_to_health: float = final_damage
	var kb_mult_final: float = knockback_mult

	var blocked_by_shield: bool = false
	if shield != null and shield.is_active:
		# Directional blocking (only if your ShieldComponent implements it)
		var can_block := true
		if shield.has_method("blocks_attack_from"):
			can_block = bool(shield.call("blocks_attack_from", attacker))

		if can_block:
			# If your ShieldComponent has tuning vars, use them; otherwise defaults apply.
			var shield_damage_mult: float = shield.damage_mult_while_blocking
			var shield_kb_mult: float = shield.knockback_mult_while_blocking
			# Drain shield HP first (ShieldComponent must implement absorb_damage(dmg: float) -> float leftover)
			if shield.has_method("absorb_damage"):
				var leftover_v = shield.call("absorb_damage", damage_to_health * shield_damage_mult)

				# Coerce Variant -> float safely (int or float)
				if typeof(leftover_v) == TYPE_INT:
					damage_to_health = float(leftover_v + 0.0) # +0.0 forces float math
				elif typeof(leftover_v) == TYPE_FLOAT:
					damage_to_health = leftover_v
				else:
					damage_to_health = 0.0

				kb_mult_final *= shield_kb_mult
				var leftover: float = (shield.call("absorb_damage", damage_to_health * shield_damage_mult) as float)
				damage_to_health = leftover
				kb_mult_final *= shield_kb_mult

				if damage_to_health <= 0.0:
					blocked_by_shield = true
				if debug_knockback:
					print(
						"[SHIELD] active=", shield.is_active,
						" hp=", snappedf(shield.shield_hp, 0.01), "/", snappedf(shield.max_shield_hp, 0.01),
						" absorbed_in=", snappedf(final_damage, 0.01),
						" leftover_to_hp=", snappedf(damage_to_health, 0.01)
					)
	if blocked_by_shield:
		hit_blocked.emit()
		hit_received.emit(attacker, 0.0, direction)
		_hitstop(5)
		# Optional: show "0" damage number (commented out)
		# _show_damage_number(0)
		return

	# --- Knockback scaling: only scale when actual HP damage is taken ---
	knockback_scale += knockback_scale_gain_per_hit + (damage_to_health * knockback_scale_gain_per_damage)
	knockback_scale = min(knockback_scale, knockback_scale_max)

	# --- Apply damage to HP ---
	health.take_damage(damage_to_health)
	hit_received.emit(attacker, damage_to_health, direction)

	var anim := get_parent().get_node_or_null("AnimationComponent")
	if anim and anim.has_method("flash_red"):
		anim.flash_red()

	# --- Knockback ---
	var applied: bool = false
	var force: float = 0.0
	var dir: Vector2 = direction

	if enable_knockback and allow_knockback:
		if dir == Vector2.ZERO and attacker is Node2D:
			dir = global_position - (attacker as Node2D).global_position

		if dir != Vector2.ZERO:
			var move: MovementComponent = get_parent().get_node_or_null("MovementComponent")
			if move != null:
				force = base_knockback_force * knockback_scale * max(kb_mult_final, 0.0)
				move.apply_knockback(dir, force, knockback_duration)
				applied = true

	if debug_knockback:
		var atk_name: String = "null"
		if attacker != null:
			atk_name = attacker.name

		var stack := get_stack()
		var caller: String = "unknown"
		if stack.size() > 1:
			caller = str(stack[1].get("source", "unknown")) + ":" + str(stack[1].get("line", "?"))

		print(
			"[KB] caller=", caller,
			" target=", get_parent().name,
			" attacker=", atk_name,
			" dmg=", snappedf(damage_to_health, 0.01),
			" scale=", snappedf(knockback_scale, 0.01),
			" allow=", allow_knockback,
			" kb_mult=", snappedf(kb_mult_final, 0.01),
			" force=", snappedf(force, 0.01),
			" dir=", dir,
			" applied=", applied,
			" shielded=", blocked_by_shield
		)

	_hitstop(5)
	_show_damage_number(int(round(damage_to_health)))


func set_team(new_team: int) -> void:
	team = new_team


func is_same_team(other_team: int) -> bool:
	return team == other_team


func _on_area_entered(area: Area2D) -> void:
	hitbox_area_entered.emit(area)


func _on_body_entered(body: Node2D) -> void:
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


func _hitstop(frames: int = 3) -> void:
	var fps: float = Engine.get_frames_per_second()
	if fps <= 0:
		return

	var freeze_time: float = float(frames) / float(fps)
	get_tree().paused = true
	await get_tree().create_timer(freeze_time, true, false, true).timeout
	get_tree().paused = false
