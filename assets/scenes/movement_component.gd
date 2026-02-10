extends Node2D
class_name MovementComponent

@export var stats_component: StatsComponent

var move_speed: float = 100.0
@export var is_controllable: bool = true

@export_group("Input Keys")
@export var input_up: String = "W"
@export var input_down: String = "S"
@export var input_left: String = "A"
@export var input_right: String = "D"
@export var input_dash: String = "dash"

@export_group("Dash")
@export var dash_enabled: bool = true
var dash_speed: float = 300.0
var dash_duration: float = 0.2
var dash_cooldown: float = 0.5

var lunge_distance: float = 10.0
var lunge_burst_time: float = 0.1
var lunge_pause_time: float = 0.2

@export_group("Movement Modifiers")
@export var movement_slowed_multiplier: float = 0.25

var velocity: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.DOWN
var facing_direction: Vector2 = Vector2.DOWN

var _movement_locked: bool = false
var _is_dashing: bool = false
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_velocity: Vector2 = Vector2.ZERO

var _lunge_velocity: Vector2 = Vector2.ZERO
var _lunge_time_left: float = 0.0
var _lunge_pause_entered: bool = false

var knockback_timer: float = 0.0
var stagger_timer: float = 0.0

@export var entity: CharacterBody2D
var attack_component: AttackComponent

func _ready() -> void:
	if not entity:
		push_error("MovementComponent: Parent must be CharacterBody2D")
		return
	
	# Find AttackComponent via parent if needed (optional, for charge checks)
	_find_attack_component()
	
	if stats_component:
		_apply_stats_from_component()
	
	set_physics_process(true)

func _find_attack_component() -> void:
	if not entity:
		return
	for child in entity.get_children():
		if child is AttackComponent:
			attack_component = child
			return
		for grandchild in child.get_children():
			if grandchild is AttackComponent:
				attack_component = grandchild
				return

func _apply_stats_from_component() -> void:
	if not stats_component:
		return
	
	var entity_stats: Dictionary = stats_component.get_entity_stats()
	if entity_stats.has("move_speed"):
		move_speed = float(entity_stats.get("move_speed", move_speed))
	
	dash_speed = stats_component.dash_speed
	dash_duration = stats_component.dash_duration
	dash_cooldown = stats_component.dash_cooldown
	
	lunge_distance = stats_component.lunge_distance
	lunge_burst_time = stats_component.lunge_burst_time
	lunge_pause_time = stats_component.lunge_pause_time

func _physics_process(delta: float) -> void:
	if not entity:
		return
	
	if not _is_authority():
		return
	
	if knockback_timer > 0.0:
		_process_knockback(delta)
		return
	
	var input_dir: Vector2 = _get_input_direction()
	var is_currently_attacking: bool = _is_attacking()
	
	if is_controllable and _is_authority():
		if input_dir != Vector2.ZERO:
			if not is_currently_attacking:
				facing_direction = input_dir.normalized()
				last_direction = input_dir.normalized()
		elif velocity != Vector2.ZERO and not is_currently_attacking:
			last_direction = velocity.normalized()
	
	if _should_early_return(input_dir):
		return
	
	if _lunge_time_left > 0.0 or _is_dashing or _is_charging():
		input_dir = Vector2.ZERO
	
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = max(_dash_cooldown_left - delta, 0.0)
	
	if stagger_timer > 0.0:
		stagger_timer = max(stagger_timer - delta, 0.0)
		input_dir = Vector2.ZERO
	
	if input_dir != Vector2.ZERO and not is_currently_attacking:
		facing_direction = input_dir.normalized()
	
	_process_movement(delta, input_dir)
	
	if is_controllable and _is_authority():
		_process_dash_input(input_dir)

func _get_input_direction() -> Vector2:
	if not is_controllable or not _is_authority():
		return Vector2.ZERO
	
	var raw_input := Vector2(
		Input.get_action_strength(input_right) - Input.get_action_strength(input_left),
		Input.get_action_strength(input_down) - Input.get_action_strength(input_up)
	)
	
	return raw_input.normalized() if raw_input.length() > 0 else Vector2.ZERO

func _process_knockback(delta: float) -> void:
	knockback_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 1000 * delta)
	entity.velocity = velocity
	entity.move_and_slide()
	velocity = entity.velocity

func _should_early_return(input_dir: Vector2) -> bool:
	if input_dir == Vector2.ZERO and \
	   not _is_dashing and \
	   _lunge_time_left <= 0.0 and \
	   not _is_holding_attack() and \
	   stagger_timer <= 0.0 and \
	   knockback_timer <= 0.0:
		return true
	return false

func _process_movement(delta: float, input_dir: Vector2) -> void:
	if _is_dashing:
		_dash_time_left -= delta
		velocity = _dash_velocity
		if _dash_time_left <= 0.0:
			_is_dashing = false
			_dash_cooldown_left = dash_cooldown
	
	elif _lunge_time_left > 0.0:
		_lunge_time_left -= delta
		if _lunge_time_left > lunge_pause_time:
			velocity = _lunge_velocity
			_lunge_pause_entered = false
		else:
			velocity = Vector2.ZERO
			if not _lunge_pause_entered:
				_lunge_pause_entered = true
				if attack_component:
					if attack_component.has_method("maybe_spawn_payload_during_lunge_pause"):
						attack_component.maybe_spawn_payload_during_lunge_pause()
				else:
					_find_attack_component()
					if attack_component and attack_component.has_method("maybe_spawn_payload_during_lunge_pause"):
						attack_component.maybe_spawn_payload_during_lunge_pause()
	
	else:
		if _movement_locked:
			velocity = Vector2.ZERO
		else:
			var current_speed := move_speed
			
			if _is_authority():
				if _is_holding_attack() and _is_past_heavy_threshold():
					current_speed *= movement_slowed_multiplier
			
			velocity = input_dir * current_speed
	
	entity.velocity = velocity
	entity.move_and_slide()
	velocity = entity.velocity

func _process_dash_input(input_dir: Vector2) -> void:
	if not dash_enabled:
		return
	
	if Input.is_action_just_pressed(input_dash) and \
	   not _is_dashing and \
	   _dash_cooldown_left <= 0.0 and \
	   not _is_attacking():
		stagger_timer = 0.0
		start_dash(input_dir)

func start_dash(dir: Vector2) -> void:
	var dash_dir := dir
	
	if dash_dir == Vector2.ZERO:
		dash_dir = facing_direction if facing_direction != Vector2.ZERO else last_direction
	
	_is_dashing = true
	_dash_time_left = dash_duration
	_dash_velocity = dash_dir.normalized() * dash_speed
	facing_direction = dash_dir

func start_lunge(direction: Vector2, distance_multiplier: float = 1.0) -> void:
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = last_direction
	
	var dist: float = lunge_distance * distance_multiplier
	
	_lunge_velocity = dir * (dist / max(lunge_burst_time, 0.001))
	_lunge_time_left = lunge_burst_time + lunge_pause_time
	_lunge_pause_entered = false

func apply_knockback(direction: Vector2, knockback_force: float, duration: float = 0.3) -> void:
	velocity = direction.normalized() * knockback_force
	knockback_timer = duration
	stagger_timer = 0.0
	_lunge_time_left = 0.0
	_lunge_pause_entered = false
	_is_dashing = false

func apply_stagger(duration: float) -> void:
	velocity = Vector2.ZERO
	knockback_timer = 0.0
	stagger_timer = max(stagger_timer, duration)
	_lunge_time_left = 0.0
	_lunge_pause_entered = false
	_is_dashing = false

func lock_movement() -> void:
	_movement_locked = true

func unlock_movement() -> void:
	_movement_locked = false

func stop_all_movement() -> void:
	velocity = Vector2.ZERO
	_lunge_time_left = 0.0
	_lunge_velocity = Vector2.ZERO
	_lunge_pause_entered = false
	_is_dashing = false
	_dash_time_left = 0.0
	knockback_timer = 0.0
	stagger_timer = 0.0

func get_velocity() -> Vector2:
	return velocity

func get_is_dashing() -> bool:
	return _is_dashing

func get_lunge_time_left() -> float:
	return _lunge_time_left

func is_moving() -> bool:
	return velocity.length() > 0.0

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

func _is_attacking() -> bool:
	if not attack_component:
		return false
	if not attack_component.has_method("get_attack_state"):
		return false
	return attack_component.get_attack_state() != AttackComponent.AttackState.IDLE

func _is_holding_attack() -> bool:
	if not attack_component:
		return false
	if not attack_component.has_method("get_attack_is_holding"):
		return false
	return attack_component.get_attack_is_holding()

func _is_charging() -> bool:
	if not attack_component:
		return false
	if not attack_component.has_method("get_is_charging"):
		return false
	return attack_component.get_is_charging()

func _is_past_heavy_threshold() -> bool:
	if not attack_component:
		return false
	return attack_component.attack_hold_time >= attack_component.heavy_threshold
