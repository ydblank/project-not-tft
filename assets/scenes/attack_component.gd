extends Node2D
class_name AttackComponent

# This component owns all attack / combo / charge logic.
# It assumes it is instanced as a child of the player (CharacterBody2D) node.
const DEBUG_ATTACK := false

@export var stats_component: StatsComponent
@export var movement_component: MovementComponent
@export var animation_component: AnimationComponent
@export var health_component: HealthComponent
@export var hitbox_component: HitboxComponent
@export var entity: Node2D
@export var allow_player_control: bool = true

var set_attack_direction: Vector2 = Vector2.ZERO

enum AttackState { IDLE, STARTUP, ACTIVE, RECOVERY, COMBO_WINDOW }
enum AttackType { LIGHT, HEAVY }

# Local offsets (relative to aim direction)
const SLASH_OFFSETS := {
	"slash": Vector2(0, -10), # above the swing
	"slash_2": Vector2(0, 10) # below the swing
}

const ATTACK_EFFECT: PackedScene = preload("res://assets/effects/slash.tscn")

var attack_state: AttackState = AttackState.IDLE
var current_attack_type: AttackType = AttackType.LIGHT
var combo_step: int = 0
var buffered_attack: bool = false

# Charge / heavy logic
var attack_hold_time: float = 0.0
var attack_is_holding: bool = false
var heavy_threshold: float = 0.25
var max_charge_time: float = 1.5

var is_charging: bool = false
var charge_time: float = 0.0

var _shake_strength: float = 0.1
var _shake_time: float = 0.0

var _charge_damage_mult: float = 1.0
var _charge_knockback_mult: float = 1.0

var _attack_effect_spawned: bool = false
var _attack_hit_targets: Dictionary = {}

var _combo_directions: Array = []
var _heavy_attack_direction: Vector2 = Vector2.ZERO

@onready var attack_timer: Timer = $AttackTimer


# ---------------- NET HELPERS ----------------
func _net_active() -> bool:
	var mp := multiplayer.multiplayer_peer
	return mp != null and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


# Spawns a slash on ALL peers (and locally). Uses the same visuals as your singleplayer slash:
# - Light: follow_mouse = true BUT uses p_aim_pos (attacker’s mouse) instead of local mouse.
# - Heavy: follow_mouse = false with fixed rotation.
@rpc("reliable", "any_peer", "call_local")
func rpc_spawn_slash(
	p_spawn_pos: Vector2,
	p_follow_mouse: bool,
	p_fixed_rotation: float,
	p_slash_effect: String,
	p_attacker_id: int,
	p_attacker_team: int,
	p_damage: float,
	p_combo_step: int,
	p_combo_total_hits: int,
	p_aim_pos: Vector2
) -> void:
	if ATTACK_EFFECT == null:
		return

	if entity == null:
		entity = get_parent() as Node2D
		if entity == null:
			return

	var fx = ATTACK_EFFECT.instantiate()
	fx.global_position = p_spawn_pos
	fx.follow_mouse = p_follow_mouse
	fx.fixed_rotation = p_fixed_rotation
	fx.slash_effect = p_slash_effect
	fx.hits_players = true

	# ✅ Light attack: keep follow_mouse visuals but feed attacker’s aim position
	if p_follow_mouse:
		fx.use_network_aim = true
		fx.network_aim_pos = p_aim_pos


	if fx.has_method("set_attack_context"):
		fx.call(
			"set_attack_context",
			p_attacker_id,
			p_attacker_team,
			p_damage,
			p_combo_step,
			p_combo_total_hits
		)

	entity.get_parent().add_child(fx)


# ---------------- READY ----------------
func _ready() -> void:
	set_process(true)
	if _is_authority():
		set_process_input(true)
	else:
		set_process_input(false)

	attack_timer.one_shot = true
	var cb := Callable(self, "_on_attack_timer_timeout")
	while attack_timer.timeout.is_connected(cb):
		attack_timer.timeout.disconnect(cb)
	attack_timer.timeout.connect(cb)

	if DEBUG_ATTACK:
		print("[ATK] ready entity=", (str(entity.name) if entity else "null"), " timer=", attack_timer)


func set_remote_attacking(is_attacking: bool) -> void:
	attack_state = (AttackState.ACTIVE if is_attacking else AttackState.IDLE)


func reset_attack_state() -> void:
	attack_state = AttackState.IDLE
	current_attack_type = AttackType.LIGHT
	combo_step = 0
	buffered_attack = false
	_attack_effect_spawned = false
	_attack_hit_targets.clear()
	_combo_directions.clear()
	_heavy_attack_direction = Vector2.ZERO

	attack_is_holding = false
	attack_hold_time = 0.0
	is_charging = false
	charge_time = 0.0
	_shake_time = 0.0

	_charge_damage_mult = 1.0
	_charge_knockback_mult = 1.0

	if attack_timer:
		attack_timer.stop()


func get_knockback_mult() -> float:
	return _charge_knockback_mult


func get_attack_state() -> AttackState:
	return attack_state


func get_attack_is_holding() -> bool:
	return attack_is_holding


func get_is_charging() -> bool:
	return is_charging


func maybe_spawn_payload_during_lunge_pause() -> void:
	if _attack_effect_spawned:
		return
	_spawn_attack_payload(combo_step)
	_attack_effect_spawned = true

func handle_attack_input(p_attack: AttackType, force: bool = false) -> void:
	if not force and not allow_player_control:
		return
	if _is_dead():
		return
	if DEBUG_ATTACK:
		print("[ATK] input type=", ("LIGHT" if p_attack == AttackType.LIGHT else "HEAVY"), " state=", attack_state, " step=", combo_step)

	current_attack_type = p_attack

	match attack_state:
		AttackState.IDLE:
			combo_step = 0
			buffered_attack = false
			_start_attack_by_type(p_attack)

		AttackState.COMBO_WINDOW:
			var max_hits := _combo_total_hits()
			if combo_step < max_hits - 1:
				combo_step += 1
				buffered_attack = false
				_start_attack_by_type(p_attack)
			else:
				combo_step = 0
				buffered_attack = false
				attack_state = AttackState.IDLE

		AttackState.RECOVERY:
			buffered_attack = true

		_:
			buffered_attack = true


func _start_attack_by_type(p_attack: AttackType) -> void:
	if p_attack == AttackType.LIGHT:
		start_attack()
	else:
		start_heavy_attack


func _input(event: InputEvent) -> void:
	if not allow_player_control or _is_dead():
		return
	if DEBUG_ATTACK and (event.is_action_pressed("Attack") or event.is_action_released("Attack")):
		print("[ATK] action Attack pressed=", event.is_action_pressed("Attack"), " released=", event.is_action_released("Attack"), " holding=", attack_is_holding, " hold_time=", attack_hold_time)

	if event.is_action_pressed("Attack"):
		attack_is_holding = true
		attack_hold_time = 0.0
		_shake_time = 0.0

	elif event.is_action_released("Attack") and attack_is_holding:
		attack_is_holding = false
		if attack_hold_time >= heavy_threshold:
			charge_time = attack_hold_time
			charge_heavy_attack()
		else:
			handle_attack_input(AttackType.LIGHT)


func _process(delta: float) -> void:
	if attack_is_holding:
		attack_hold_time = min(attack_hold_time + delta, max_charge_time)
		_shake_time += delta
		var ratio: float = clamp(attack_hold_time / max_charge_time, 0.0, 1.0)
		if _is_authority():
			var sprite: Sprite2D = _get_sprite()
			if attack_hold_time >= 0.2 and sprite:
				var shake_intensity: float = _shake_strength * (1.0 + ratio)
				sprite.position.x = sin(_shake_time * (10.0 + 10.0 * ratio)) * shake_intensity
				sprite.position.y = cos(_shake_time * (15.0 + 15.0 * ratio)) * shake_intensity

			if sprite:
				var blink_speed: float = lerp(4.0, 8.0, ratio)
				var blink_on: bool = fmod(_shake_time * blink_speed, 2.0) < 1.0
				sprite.self_modulate = (Color(1, 1, 1, 1) if blink_on else Color(1.5, 1.5, 1.5, 1))
	else:
		_reset_sprite_visuals()


func charge_heavy_attack() -> void:
	var charge_ratio: float = charge_time / max_charge_time
	var threshold: float = heavy_threshold
	if charge_time < threshold:
		_charge_damage_mult = 1.0
		_charge_knockback_mult = 1.0
	else:
		_charge_damage_mult = 1.0 + pow(charge_ratio, 2) * 0.5
		_charge_knockback_mult = 1.0 + pow(charge_ratio, 2) * 0.5

	_reset_sprite_visuals()
	is_charging = false
	charge_time = 0.0
	_shake_time = 0.0

	handle_attack_input(AttackType.HEAVY)


func _initialize_attack_state() -> void:
	attack_state = AttackState.STARTUP
	buffered_attack = false
	_attack_effect_spawned = false
	_attack_hit_targets.clear()


func _set_player_directions(cardinal_dir: Vector2) -> void:
	if movement_component:
		movement_component.facing_direction = cardinal_dir
	_set_player_last_direction(cardinal_dir)
	_call_player_update_anim(cardinal_dir)


func start_attack() -> void:
	_initialize_attack_state()

	var raw_dir: Vector2 = _mouse_raw_direction()
	var cardinal_dir: Vector2 = _mouse_cardinal_direction()
	_set_player_directions(cardinal_dir)

	_combo_directions.append({
		"step": combo_step,
		"raw": raw_dir,
		"cardinal": cardinal_dir
	})

	if _weapon_type() != "range":
		_start_lunge_toward_mouse()
	else:
		_spawn_attack_payload(combo_step)
		_attack_effect_spawned = true

	_start_attack_timer(get_startup_time())


func _start_attack_timer(wait_time: float) -> void:
	if attack_timer:
		attack_timer.wait_time = wait_time
		attack_timer.start()
		if DEBUG_ATTACK:
			print("[ATK] timer started wait_time=", wait_time, " weapon_type=", _weapon_type())


func start_heavy_attack() -> void:
	_initialize_attack_state()

	var raw_dir: Vector2
	if combo_step == 0:
		raw_dir = _mouse_raw_direction()
		if raw_dir == Vector2.ZERO:
			raw_dir = _get_player_last_direction()
		_heavy_attack_direction = raw_dir
		_combo_directions.clear()
		_combo_directions.append({
			"step": combo_step,
			"raw": raw_dir,
			"cardinal": _mouse_cardinal_direction()
		})
	else:
		raw_dir = _heavy_attack_direction
		if raw_dir == Vector2.ZERO:
			raw_dir = _get_player_last_direction()
		if _combo_directions.is_empty():
			_combo_directions.append({
				"step": 0,
				"raw": raw_dir,
				"cardinal": _mouse_cardinal_direction()
			})

	var cardinal_dir: Vector2 = _cardinal_from_raw(raw_dir)
	_set_player_directions(cardinal_dir)

	_start_heavy_lunge(raw_dir)
	_start_attack_timer(get_startup_time() + 0.25)


func _on_attack_timer_timeout() -> void:
	if DEBUG_ATTACK:
		print("[ATK] timer timeout state=", attack_state, " type=", current_attack_type, " step=", combo_step)
	match attack_state:
		AttackState.STARTUP:
			enable_hitbox()
			if attack_timer:
				attack_timer.wait_time = get_active_time()
				attack_state = AttackState.ACTIVE
				attack_timer.start()

		AttackState.ACTIVE:
			attack_state = AttackState.RECOVERY
			disable_hitbox()
			if attack_timer:
				attack_timer.wait_time = get_recovery_time()
				attack_timer.start()

		AttackState.RECOVERY:
			if current_attack_type == AttackType.HEAVY and combo_step < _combo_total_hits() - 1:
				combo_step += 1
				start_heavy_attack()
			else:
				if _is_final_combo_step():
					_reset_combo_state()
				else:
					attack_state = AttackState.COMBO_WINDOW
					if attack_timer:
						var combo_window: float = stats_component.combo_chain_window if stats_component else 0.5
						attack_timer.wait_time = combo_window
						attack_timer.start()
					if buffered_attack:
						buffered_attack = false
						handle_attack_input(current_attack_type)

		AttackState.COMBO_WINDOW:
			var max_hits := _combo_total_hits()
			if buffered_attack:
				buffered_attack = false
				if combo_step < max_hits - 1:
					combo_step += 1
					_start_attack_by_type(current_attack_type)
				else:
					combo_step = 0
					attack_state = AttackState.IDLE
			else:
				combo_step = 0
				attack_state = AttackState.IDLE


func enable_hitbox() -> void:
	_attack_hit_targets.clear()


func disable_hitbox() -> void:
	pass


func get_startup_time() -> float:
	if not stats_component:
		return 0.1
	var atk_speed: float = CombatGlobal.calculate_attack_speed(stats_component)
	return 0.01 / max(atk_speed, 0.00001)


func get_active_time() -> float:
	return 0.10


func get_recovery_time() -> float:
	if current_attack_type == AttackType.HEAVY:
		return 0.10
	return 0.15


func _is_final_combo_step() -> bool:
	var max_hits := _combo_total_hits()
	return combo_step >= (max_hits - 1)


func _mouse_raw_direction() -> Vector2:
	if not allow_player_control and set_attack_direction != Vector2.ZERO:
		return set_attack_direction.normalized()
	if not entity:
		return Vector2.ZERO
	var d: Vector2 = (get_global_mouse_position() - entity.global_position).normalized()
	return d


func _mouse_cardinal_direction() -> Vector2:
	if not allow_player_control and set_attack_direction != Vector2.ZERO:
		return _cardinal_from_raw(set_attack_direction)
	var to_mouse := Vector2.ZERO
	if entity:
		to_mouse = get_global_mouse_position() - entity.global_position
	if abs(to_mouse.x) > abs(to_mouse.y):
		return Vector2.RIGHT if to_mouse.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if to_mouse.y > 0.0 else Vector2.UP


func _cardinal_from_raw(raw_dir: Vector2) -> Vector2:
	if abs(raw_dir.x) > abs(raw_dir.y):
		return Vector2.RIGHT if raw_dir.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if raw_dir.y > 0.0 else Vector2.UP


func _attack_combo_animation(step: int) -> StringName:
	var is_left: bool
	if current_attack_type == AttackType.HEAVY and _heavy_attack_direction != Vector2.ZERO:
		is_left = _heavy_attack_direction.x < 0.0
	else:
		var to_mouse: Vector2 = Vector2.ZERO
		if entity:
			to_mouse = get_global_mouse_position() - entity.global_position
		is_left = to_mouse.x < 0.0

	if current_attack_type == AttackType.HEAVY:
		match step:
			0: return &"slash_2"
			1: return &"slash"
			_: return &"slash"

	if is_left:
		return &"slash_2" if (step % 2 == 0) else &"slash"
	return &"slash" if (step % 2 == 0) else &"slash_2"


func _start_lunge_toward_mouse(multiplier: float = 1.0) -> void:
	if not movement_component:
		return

	var dir: Vector2 = _mouse_raw_direction()
	if dir == Vector2.ZERO:
		dir = _get_player_last_direction()

	var dist_mult: float = multiplier
	if _is_final_combo_step():
		dist_mult *= 2.0

	movement_component.start_lunge(dir, dist_mult)


func _start_heavy_lunge(dir: Vector2) -> void:
	if not movement_component:
		return

	var dist_mult: float = 1.5
	if _is_final_combo_step():
		dist_mult *= 2.0

	movement_component.start_lunge(dir, dist_mult)


func _get_weapon_dict() -> Dictionary:
	if not stats_component:
		return {}
	return stats_component.get_entity_weapon()


func _weapon_type() -> String:
	var weapon: Dictionary = _get_weapon_dict()
	return str(weapon.get("type", ""))


func _get_combo_array() -> Array:
	var weapon: Dictionary = _get_weapon_dict()
	if weapon.is_empty():
		return []

	var array_key: String = "quick_attack" if current_attack_type == AttackType.LIGHT else "heavy_attack"
	if weapon.has(array_key) and (weapon[array_key] is Array):
		return weapon[array_key] as Array
	return []


func _combo_total_hits() -> int:
	if not stats_component:
		return 1
	var combo_arr: Array = _get_combo_array()
	if not combo_arr.is_empty():
		return maxi(combo_arr.size(), 1)
	return maxi(stats_component.combo_max_hits, 1)


func _weapon_combo_damage_multiplier(step: int) -> float:
	var combo_arr: Array = _get_combo_array()
	if combo_arr.is_empty():
		return 1.0
	return float(combo_arr[clampi(step, 0, combo_arr.size() - 1)])


func _spawn_attack_payload(step: int) -> void:
	if _weapon_type() == "range":
		spawn_projectile(step)
	else:
		spawn_attack_effect(step)


func spawn_projectile(step: int) -> void:
	if not entity:
		return
	var arrow_projectile: PackedScene = entity.get("arrow_projectile") if entity.has("arrow_projectile") else null
	if arrow_projectile == null:
		return
	var projectile = arrow_projectile.instantiate()
	projectile.global_position = entity.global_position
	projectile.rotation = (get_global_mouse_position() - entity.global_position).angle()

	var base_damage: float = _calc_base_damage()
	var mult: float = _weapon_combo_damage_multiplier(step)
	projectile.weapon_damage = max(base_damage * mult, 1.0)
	projectile.shooter = entity
	entity.get_parent().add_child(projectile)


func spawn_attack_effect(step: int) -> void:
	if not entity:
		return

	var aim_pos: Vector2 = get_global_mouse_position()

	# Local spawn (singleplayer or authority local prediction) - keep the visuals exactly like before.
	var fx = ATTACK_EFFECT.instantiate()

	if current_attack_type == AttackType.HEAVY and _combo_directions.size() > 0:
		var locked_raw: Vector2 = _combo_directions[0]["raw"] as Vector2
		fx.follow_mouse = false

		var angle_deg: float = rad_to_deg(locked_raw.angle()) + 250.0
		if step == 1:
			angle_deg += 220.0
		fx.fixed_rotation = angle_deg

		var offset_distance: float = 15.0
		var anim_name := _attack_combo_animation(step)
		fx.slash_effect = str(anim_name)

		var base_pos: Vector2 = entity.global_position + locked_raw.normalized() * offset_distance
		var local_offset: Vector2 = SLASH_OFFSETS.get(str(anim_name), Vector2.ZERO)
		var rotated_offset: Vector2 = local_offset.rotated(locked_raw.angle())
		fx.global_position = base_pos + rotated_offset
	else:
		fx.global_position = entity.global_position
		if set_attack_direction != Vector2.ZERO:
			fx.follow_mouse = false
			var angle_deg: float = rad_to_deg(set_attack_direction.angle())
			fx.fixed_rotation = angle_deg
		else:
			fx.follow_mouse = true
			fx.slash_effect = str(_attack_combo_animation(step))

	fx.hits_players = true

	var base_damage: float = _calc_base_damage()
	var mult: float = _weapon_combo_damage_multiplier(step)
	var total_damage: float = max(base_damage * mult * _charge_damage_mult, 1.0)
	var total_hits: int = _combo_total_hits()

	var attacker_id: int = -1
	if String(entity.name).is_valid_int():
		attacker_id = String(entity.name).to_int()

	var team_id: int = 0
	if hitbox_component:
		team_id = hitbox_component.team

	if fx.has_method("set_attack_context"):
		fx.call("set_attack_context", attacker_id, team_id, total_damage, step, total_hits)

	# 🔥 SINGLEPLAYER: just add it
	if not _net_active():
		entity.get_parent().add_child(fx)
		return

	# 🔥 MULTIPLAYER:
	# Only the authority should spawn & replicate. Everyone (including self) gets it via call_local RPC.
	if not _is_authority():
		fx.queue_free()
		return

	# Don't double-spawn locally: let call_local spawn for us.
	fx.queue_free()

	rpc(
		"rpc_spawn_slash",
		fx.global_position,
		fx.follow_mouse,
		fx.fixed_rotation,
		fx.slash_effect,
		attacker_id,
		team_id,
		total_damage,
		step,
		total_hits,
		aim_pos
	)


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if not entity:
		return

	if entity.has_method("is_multiplayer_authority") and (not entity.call("is_multiplayer_authority")):
		return

	var hitbox: HitboxComponent = area as HitboxComponent
	if hitbox == null:
		return

	var body: Node = area.get_parent()
	if body == null:
		return
	var body2d := body as Node2D
	if body2d == null:
		return

	if body == entity:
		return

	var my_team := 0
	if hitbox_component:
		my_team = hitbox_component.team
	if hitbox.is_same_team(my_team):
		if DEBUG_ATTACK:
			print("[ATK] teammate hit skipped")
		return

	var key: String = str(body.get_instance_id())
	if _attack_hit_targets.has(key):
		return
	_attack_hit_targets[key] = true

	var dir: Vector2 = (body2d.global_position - entity.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = _get_player_last_direction()

	var dmg: float = _calc_damage(combo_step) * _charge_damage_mult
	hitbox.take_damage(dmg, entity, dir)


func _calc_base_damage() -> float:
	if not stats_component:
		return 1.0
	return CombatGlobal.calculate_attack_damage(stats_component)


func _calc_damage(step: int) -> float:
	var base_damage: float = _calc_base_damage()
	var mult: float = _weapon_combo_damage_multiplier(step)
	return max(base_damage * mult, 1.0)


func _is_dead() -> bool:
	if health_component:
		return health_component.is_dead()
	return false


func _is_authority() -> bool:
	if not entity:
		return true
	if entity.has_method("_local_is_authority"):
		return entity.call("_local_is_authority")
	if entity.has_method("is_multiplayer_authority"):
		var mp = entity.multiplayer.multiplayer_peer
		if mp and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			return entity.call("is_multiplayer_authority")
	return true


func _get_sprite() -> Sprite2D:
	if animation_component:
		return animation_component.get_sprite()
	return null


func _get_player_last_direction() -> Vector2:
	if movement_component:
		return movement_component.last_direction
	return Vector2.DOWN


func _set_player_last_direction(dir: Vector2) -> void:
	if movement_component:
		movement_component.last_direction = dir


func _call_player_update_anim(dir: Vector2) -> void:
	if animation_component:
		animation_component.update_animation_parameters(dir)


func _reset_sprite_visuals() -> void:
	if animation_component:
		animation_component.reset_sprite_visuals()


func _reset_combo_state() -> void:
	buffered_attack = false
	combo_step = 0
	attack_state = AttackState.IDLE
	_charge_damage_mult = 1.0
	_charge_knockback_mult = 1.0
	_heavy_attack_direction = Vector2.ZERO
