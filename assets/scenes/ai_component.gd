extends Node2D
class_name AIComponent

@export var entity: CharacterBody2D
@export var movement_component: MovementComponent
@export var attack_component: AttackComponent
@export var health_component: HealthComponent
@export var hitbox_component: HitboxComponent
@export var animation_component: AnimationComponent

@export_group("Detection Settings")
@export var detection_range: float = 200.0
@export var detection_angle: float = 360.0
@export var target_groups: Array[String] = ["players"]
@export var target_team: int = -1

@export_group("Behavior Settings")
@export var attack_range: float = 50.0
@export var chase_range: float = 400.0
@export var retreat_hp_threshold: float = 0.3
@export var attack_cooldown: float = 1.5
@export var decision_interval: float = 0.2
@export var idle_wander: bool = false
@export var wander_radius: float = 50.0
@export var use_pathfinding: bool = true
@export var pathfinding_update_interval: float = 0.1

@export_group("State Durations")
@export var idle_duration: float = 2.0
@export var retreat_duration: float = 1.0
@export var stun_duration: float = 0.5

enum AIState {
	IDLE,
	CHASE,
	ATTACK,
	RETREAT,
	STUNNED,
	DEAD
}

var current_state: AIState = AIState.IDLE
var current_target: Node2D = null
var attack_cooldown_timer: float = 0.0
var state_timer: float = 0.0
var decision_timer: float = 0.0

var spawn_position: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var pathfinding_timer: float = 0.0

@onready var detection_area: Area2D = $DetectionArea
@onready var state_timer_node: Timer = $StateTimer
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	if not entity:
		push_error("AIComponent: Parent must be CharacterBody2D")
		return
	
	if not movement_component:
		push_error("AIComponent: MovementComponent is required but not assigned")
		return
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
		detection_area.area_entered.connect(_on_detection_area_area_entered)
		print("[AI] DetectionArea connected")
	else:
		print("[AI] Warning: DetectionArea not found as child")
	
	if state_timer_node:
		state_timer_node.timeout.connect(_on_state_timer_timeout)
		print("[AI] StateTimer connected")
	else:
		print("[AI] Warning: StateTimer not found as child")
	
	if navigation_agent:
		navigation_agent.path_desired_distance = 4.0
		navigation_agent.target_desired_distance = attack_range * 0.8
		if movement_component:
			navigation_agent.max_speed = movement_component.move_speed
		print("[AI] NavigationAgent2D configured")
	else:
		print("[AI] NavigationAgent2D not found (pathfinding disabled)")
	
	spawn_position = entity.global_position
	wander_target = spawn_position
	
	movement_component.is_controllable = false
	
	if health_component:
		health_component.died.connect(_on_entity_died)
	
	if hitbox_component:
		hitbox_component.hit_received.connect(_on_hit_received)
	
	print("[AI] AIComponent ready - Entity: ", entity.name, " State: IDLE")
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not _is_authority():
		print('here not authority')
		return
	
	if _is_dead():
		if current_state != AIState.DEAD:
			_change_state(AIState.DEAD)
		return
	
	_update_timers(delta)
	_update_decision(delta)
	_update_state(delta)

func _update_timers(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	
	if state_timer > 0.0:
		state_timer = max(state_timer - delta, 0.0)
	
	decision_timer += delta
	pathfinding_timer += delta

func _update_decision(_delta: float) -> void:
	if decision_timer < decision_interval:
		return
	
	decision_timer = 0.0
	
	if current_target and not _is_valid_target(current_target):
		print("[AI] Target invalid, clearing target")
		current_target = null
	
	if not current_target:
		current_target = _find_nearest_target()
		if current_target:
			print("[AI] Found target: ", current_target.name, " Distance: ", _get_distance_to_target())
		else:
			print("[AI] No target found")
	
	match current_state:
		AIState.IDLE:
			_handle_idle_state()
		AIState.CHASE:
			_handle_chase_state()
		AIState.ATTACK:
			_handle_attack_state()
		AIState.RETREAT:
			_handle_retreat_state()
		AIState.STUNNED:
			_handle_stunned_state()
		AIState.DEAD:
			_handle_dead_state()

func _update_state(_delta: float) -> void:
	if current_state == AIState.STUNNED:
		if state_timer <= 0.0:
			print("[AI] Stun expired, returning to IDLE")
			_change_state(AIState.IDLE)
		return
	
	if current_state == AIState.DEAD:
		return
	
	if not current_target:
		if current_state != AIState.IDLE:
			print("[AI] No target, changing to IDLE")
			_change_state(AIState.IDLE)
		return
	
	var distance_to_target := _get_distance_to_target()
	var hp_percentage := _get_hp_percentage()
	
	match current_state:
		AIState.IDLE:
			if distance_to_target <= detection_range:
				print("[AI] IDLE -> CHASE: Target in range (", distance_to_target, " <= ", detection_range, ")")
				_change_state(AIState.CHASE)
			else:
				print("[AI] IDLE: Target too far (", distance_to_target, " > ", detection_range, ")")
		
		AIState.CHASE:
			if distance_to_target <= attack_range and attack_cooldown_timer <= 0.0:
				print("[AI] CHASE -> ATTACK: In attack range (", distance_to_target, " <= ", attack_range, ")")
				_change_state(AIState.ATTACK)
			elif distance_to_target > chase_range:
				print("[AI] CHASE -> IDLE: Target out of chase range (", distance_to_target, " > ", chase_range, ")")
				_change_state(AIState.IDLE)
			elif hp_percentage <= retreat_hp_threshold:
				print("[AI] CHASE -> RETREAT: Low HP (", hp_percentage * 100, "% <= ", retreat_hp_threshold * 100, "%)")
				_change_state(AIState.RETREAT)
			else:
				print("[AI] CHASE: Distance=", distance_to_target, " AttackRange=", attack_range, " Cooldown=", attack_cooldown_timer)
		
		AIState.ATTACK:
			if attack_component and attack_component.get_attack_state() == AttackComponent.AttackState.IDLE:
				if distance_to_target <= attack_range and attack_cooldown_timer <= 0.0:
					print("[AI] ATTACK: Still in range, attacking again")
					_change_state(AIState.ATTACK)
				elif distance_to_target <= chase_range:
					print("[AI] ATTACK -> CHASE: Target moved away (", distance_to_target, ")")
					_change_state(AIState.CHASE)
				else:
					print("[AI] ATTACK -> IDLE: Target too far (", distance_to_target, " > ", chase_range, ")")
					_change_state(AIState.IDLE)
			else:
				var attack_state_str := "null"
				if attack_component:
					attack_state_str = str(attack_component.get_attack_state())
				print("[AI] ATTACK: AttackComponent busy, state=", attack_state_str)
		
		AIState.RETREAT:
			if state_timer <= 0.0:
				if distance_to_target <= attack_range:
					print("[AI] RETREAT -> ATTACK: Target close (", distance_to_target, ")")
					_change_state(AIState.ATTACK)
				elif distance_to_target <= chase_range:
					print("[AI] RETREAT -> CHASE: Target in range (", distance_to_target, ")")
					_change_state(AIState.CHASE)
				else:
					print("[AI] RETREAT -> IDLE: Target far (", distance_to_target, ")")
					_change_state(AIState.IDLE)
			else:
				print("[AI] RETREAT: Timer remaining=", state_timer)

func _handle_idle_state() -> void:
	if not movement_component:
		return
	
	if idle_wander and not current_target:
		print('hereraaa')
		_wander_behavior()
	else:
		print("[AI] IDLE: Waiting for target to enter detection range")
		movement_component.velocity = Vector2.ZERO

func _handle_chase_state() -> void:
	if not current_target:
		print("[AI] CHASE: No target!")
		return
	
	if not movement_component:
		print("[AI] CHASE: No movement_component!")
		return
	
	if attack_component and attack_component.get_attack_state() != AttackComponent.AttackState.IDLE:
		print("[AI] CHASE: Attack in progress, stopping movement")
		movement_component.velocity = Vector2.ZERO
		return
	
	var distance := _get_distance_to_target()
	var direction: Vector2
	
	if use_pathfinding and navigation_agent:
		if pathfinding_timer >= pathfinding_update_interval:
			navigation_agent.target_position = current_target.global_position
			pathfinding_timer = 0.0
			print("[AI] CHASE: Updated pathfinding target to ", current_target.global_position)
		
		if navigation_agent.is_navigation_finished():
			print("[AI] CHASE: Navigation finished, using direct movement")
			direction = (current_target.global_position - entity.global_position).normalized()
		else:
			var next_path_position := navigation_agent.get_next_path_position()
			var waypoint_distance := entity.global_position.distance_to(next_path_position)
			
			if waypoint_distance < 1.0:
				print("[AI] CHASE: Waypoint too close (", waypoint_distance, "), using direct movement")
				direction = (current_target.global_position - entity.global_position).normalized()
			else:
				direction = (next_path_position - entity.global_position).normalized()
				print("[AI] CHASE: Pathfinding - Next waypoint: ", next_path_position, " Distance: ", waypoint_distance, " Direction: ", direction)
	else:
		direction = (current_target.global_position - entity.global_position).normalized()
		print("[AI] CHASE: Direct movement - Distance: ", distance, " Direction: ", direction)
	
	movement_component.facing_direction = direction
	
	if direction != Vector2.ZERO:
		var speed := movement_component.move_speed
		movement_component.velocity = direction * speed
		print("[AI] CHASE: Moving at speed ", speed, " Velocity: ", movement_component.velocity)
	else:
		movement_component.velocity = Vector2.ZERO
		print("[AI] CHASE: No direction, stopped")

func _handle_attack_state() -> void:
	if not current_target:
		print("[AI] ATTACK: No target!")
		return
	
	if not attack_component:
		print("[AI] ATTACK: No attack_component!")
		return
	
	if attack_cooldown_timer > 0.0:
		print("[AI] ATTACK: On cooldown (", attack_cooldown_timer, "s remaining)")
		return
	
	if attack_component.get_attack_state() != AttackComponent.AttackState.IDLE:
		print("[AI] ATTACK: AttackComponent busy, state=", attack_component.get_attack_state())
		return
	
	var direction := (current_target.global_position - entity.global_position).normalized()
	
	if movement_component:
		movement_component.facing_direction = direction
	
	var distance := _get_distance_to_target()
	if distance <= attack_range:
		print("[AI] ATTACK: Executing attack! Distance: ", distance, " <= ", attack_range)
		attack_component.handle_attack_input(AttackComponent.AttackType.LIGHT)
		attack_cooldown_timer = attack_cooldown
	else:
		print("[AI] ATTACK: Target out of range (", distance, " > ", attack_range, ")")

func _handle_retreat_state() -> void:
	if not current_target:
		print("[AI] RETREAT: No target!")
		return
	
	if not movement_component:
		print("[AI] RETREAT: No movement_component!")
		return
	
	if attack_component and attack_component.get_attack_state() != AttackComponent.AttackState.IDLE:
		print("[AI] RETREAT: Attack in progress, stopping")
		movement_component.velocity = Vector2.ZERO
		return
	
	var direction: Vector2
	
	if use_pathfinding and navigation_agent:
		var retreat_position := entity.global_position + (entity.global_position - current_target.global_position).normalized() * 100.0
		if pathfinding_timer >= pathfinding_update_interval:
			navigation_agent.target_position = retreat_position
			pathfinding_timer = 0.0
			print("[AI] RETREAT: Updated pathfinding retreat position to ", retreat_position)
		
		if navigation_agent.is_navigation_finished():
			direction = Vector2.ZERO
		else:
			var next_path_position := navigation_agent.get_next_path_position()
			direction = (next_path_position - entity.global_position).normalized()
	else:
		direction = (entity.global_position - current_target.global_position).normalized()
		print("[AI] RETREAT: Direct retreat - Direction: ", direction)
	
	movement_component.facing_direction = direction
	
	if direction != Vector2.ZERO:
		movement_component.velocity = direction * movement_component.move_speed
		print("[AI] RETREAT: Moving away at speed ", movement_component.move_speed)
	else:
		movement_component.velocity = Vector2.ZERO

func _handle_stunned_state() -> void:
	print("[AI] STUNNED: Timer remaining=", state_timer)
	if movement_component:
		movement_component.velocity = Vector2.ZERO

func _handle_dead_state() -> void:
	print("[AI] DEAD: Cleaning up")
	if movement_component:
		movement_component.stop_all_movement()
	if attack_component:
		attack_component.reset_attack_state()

func _change_state(new_state: AIState) -> void:
	if current_state == new_state:
		return
	
	var old_state_name := _get_state_name(current_state)
	var new_state_name := _get_state_name(new_state)
	
	current_state = new_state
	
	match new_state:
		AIState.IDLE:
			state_timer = idle_duration
		AIState.RETREAT:
			state_timer = retreat_duration
		AIState.STUNNED:
			state_timer = stun_duration
		AIState.DEAD:
			state_timer = 0.0
	
	print("[AI] State change: ", old_state_name, " -> ", new_state_name)

func _find_nearest_target() -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance: float = INF
	
	for group_name in target_groups:
		var targets := get_tree().get_nodes_in_group(group_name)
		for target in targets:
			if not target is Node2D:
				continue
			
			var target_node := target as Node2D
			if not _is_valid_target(target_node):
				continue
			
			var distance := entity.global_position.distance_to(target_node.global_position)
			if distance < nearest_distance and distance <= detection_range:
				nearest_distance = distance
				nearest_target = target_node
	
	return nearest_target

func _is_valid_target(target: Node2D) -> bool:
	if not target:
		return false
	
	if not is_instance_valid(target):
		return false
	
	var target_hitbox := _get_hitbox_from_target(target)
	if target_hitbox:
		if hitbox_component and hitbox_component.is_same_team(target_hitbox.team):
			return false
		
		if target_team >= 0 and target_hitbox.team != target_team:
			return false
	
	var target_health := _get_health_from_target(target)
	if target_health and target_health.is_dead():
		return false
	
	return true

func _get_hitbox_from_target(target: Node2D) -> HitboxComponent:
	for child in target.get_children():
		if child is HitboxComponent:
			return child as HitboxComponent
		for grandchild in child.get_children():
			if grandchild is HitboxComponent:
				return grandchild as HitboxComponent
	return null

func _get_health_from_target(target: Node2D) -> HealthComponent:
	for child in target.get_children():
		if child is HealthComponent:
			return child as HealthComponent
		for grandchild in child.get_children():
			if grandchild is HealthComponent:
				return grandchild as HealthComponent
	return null

func _get_distance_to_target() -> float:
	if not current_target:
		return INF
	return entity.global_position.distance_to(current_target.global_position)

func _get_hp_percentage() -> float:
	if not health_component:
		return 1.0
	return health_component.get_hp_percentage() / 100.0

func _is_dead() -> bool:
	if not health_component:
		return false
	return health_component.is_dead()

func _wander_behavior() -> void:
	if not movement_component:
		return
	
	var distance_to_wander_target := entity.global_position.distance_to(wander_target)
	
	if distance_to_wander_target < 10.0:
		var angle := randf() * TAU
		var offset := Vector2(cos(angle), sin(angle)) * wander_radius
		wander_target = spawn_position + offset
	
	var direction := (wander_target - entity.global_position).normalized()
	movement_component.facing_direction = direction
	movement_component.velocity = direction * movement_component.move_speed * 0.5

func _on_detection_area_body_entered(body: Node2D) -> void:
	if not body is Node2D:
		return
	
	var target_node := body as Node2D
	if _is_valid_target(target_node):
		if not current_target:
			current_target = target_node

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == current_target:
		current_target = null

func _on_detection_area_area_entered(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent is Node2D:
		_on_detection_area_body_entered(parent as Node2D)

func _on_entity_died() -> void:
	_change_state(AIState.DEAD)

func _on_hit_received(attacker: Node, _damage: float, direction: Vector2) -> void:
	if current_state == AIState.STUNNED or current_state == AIState.DEAD:
		return
	
	if not current_target and attacker is Node2D:
		current_target = attacker as Node2D
	
	if movement_component:
		var knockback_force := 200.0
		var knockback_duration := 0.2
		movement_component.apply_knockback(direction, knockback_force, knockback_duration)
	
	_change_state(AIState.STUNNED)

func _on_state_timer_timeout() -> void:
	pass

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

func get_current_state() -> AIState:
	return current_state

func get_current_target() -> Node2D:
	return current_target

func set_target(target: Node2D) -> void:
	if _is_valid_target(target):
		current_target = target

func force_state(state: AIState) -> void:
	_change_state(state)

func _get_state_name(state: AIState) -> String:
	match state:
		AIState.IDLE:
			return "IDLE"
		AIState.CHASE:
			return "CHASE"
		AIState.ATTACK:
			return "ATTACK"
		AIState.RETREAT:
			return "RETREAT"
		AIState.STUNNED:
			return "STUNNED"
		AIState.DEAD:
			return "DEAD"
		_:
			return "UNKNOWN"
