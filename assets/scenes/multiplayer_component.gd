extends Node
class_name MultiplayerComponent

@export var entity_path: NodePath = ^"../.."
@export var movement_component_path: NodePath = ^"../MovementComponent"
@export var attack_component_path: NodePath = ^"../AttackComponent"
@export var health_component_path: NodePath = ^"../HealthComponent"

@export var send_rate_hz: float = 20.0

var _send_accum: float = 0.0

var entity: CharacterBody2D
var movement_component: MovementComponent
var attack_component: AttackComponent
var health_component: HealthComponent

func _ready() -> void:
	entity = get_node(entity_path) as CharacterBody2D
	movement_component = get_node_or_null(movement_component_path) as MovementComponent
	attack_component = get_node_or_null(attack_component_path) as AttackComponent
	health_component = get_node_or_null(health_component_path) as HealthComponent

	# Authority based on node name "1","2",...
	if String(entity.name).is_valid_int():
		entity.set_multiplayer_authority(int(String(entity.name)))

func _physics_process(delta: float) -> void:
	if not _net_active():
		return
	if not entity.is_multiplayer_authority():
		return

	_send_accum += delta

	var denom: float = send_rate_hz
	if denom < 1.0:
		denom = 1.0
	var interval: float = 1.0 / denom

	if _send_accum < interval:
		return
	_send_accum = 0.0

	# Pull movement state
	var pos: Vector2 = entity.global_position
	var vel: Vector2 = entity.velocity

	var facing: Vector2 = Vector2.DOWN
	var last_dir: Vector2 = Vector2.DOWN
	var is_dashing: bool = false
	var lunge_time_left: float = 0.0
	var knockback_timer: float = 0.0
	var stagger_timer: float = 0.0

	if movement_component:
		facing = movement_component.facing_direction
		last_dir = movement_component.last_direction
		is_dashing = movement_component.get_is_dashing()
		lunge_time_left = movement_component.get_lunge_time_left()
		knockback_timer = movement_component.knockback_timer
		stagger_timer = movement_component.stagger_timer
	else:
		if vel != Vector2.ZERO:
			facing = vel.normalized()
			last_dir = facing

	# Attack state (for remote animation)
	var is_attacking: bool = false
	if attack_component:
		is_attacking = attack_component.get_attack_state() != AttackComponent.AttackState.IDLE

	# Health (optional)
	var hp: float = 0.0
	if health_component and health_component.has_method("get_hp"):
		hp = float(health_component.call("get_hp"))

	rpc(
		"sync_remote_state",
		pos,
		vel,
		facing,
		last_dir,
		is_attacking,
		is_dashing,
		lunge_time_left,
		knockback_timer,
		stagger_timer,
		hp
	)

@rpc("unreliable", "any_peer")
func sync_remote_state(
	pos: Vector2,
	vel: Vector2,
	facing: Vector2,
	last_dir: Vector2,
	remote_is_attacking: bool,
	remote_is_dashing: bool,
	remote_lunge_time_left: float,
	remote_knockback_timer: float,
	remote_stagger_timer: float,
	remote_hp: float
) -> void:
	# Don’t apply on authority
	if _net_active() and entity.is_multiplayer_authority():
		return

	# Apply transform/state
	entity.global_position = pos
	entity.velocity = vel

	if movement_component:
		movement_component.velocity = vel
		movement_component.facing_direction = facing
		movement_component.last_direction = last_dir
		movement_component.knockback_timer = remote_knockback_timer
		movement_component.stagger_timer = remote_stagger_timer

		# keep internal flags consistent enough for visuals
		# (these are private in your component, so we don't touch _is_dashing / _lunge_time_left directly)

	if attack_component:
		attack_component.set_remote_attacking(remote_is_attacking)

	if health_component and health_component.has_method("set_hp"):
		health_component.call("set_hp", remote_hp)

func _net_active() -> bool:
	var mp := multiplayer.multiplayer_peer
	return mp != null and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
