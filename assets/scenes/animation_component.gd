extends Node2D
class_name AnimationComponent

# Read-only view of the combat state: picks the AnimationTree state and blend
# direction, and draws charge shake/blink, block tint and the hit flash.

@export var combat_component: CombatComponent
@export var movement_component: MovementComponent

@export var animation_player_path: NodePath = NodePath("../AnimationPlayer")
@export var animation_tree_path: NodePath = NodePath("../AnimationTree")
@export var sprite_path: NodePath = NodePath("../Sprite2D")

@export_group("Animation States")
@export var idle_state_name: String = "Idle"
@export var walk_state_name: String = "Walk"
@export var attack_state_name: String = "Attack"
@export var block_state_name: String = "Block"

@export_group("Feedback")
@export var block_tint: Color = Color(0.75, 0.85, 1.2, 1.0)
@export var hit_flash_color: Color = Color(1, 0.2, 0.2, 1)
@export var hit_flash_time: float = 0.08
@export var charge_shake_strength: float = 0.1

var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var sprite: Sprite2D
var state_machine: AnimationNodeStateMachinePlayback

var _has_block_state: bool = false
var _flash_left: float = 0.0
var _charge_time: float = 0.0


func _ready() -> void:
	animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	animation_tree = get_node_or_null(animation_tree_path) as AnimationTree
	sprite = get_node_or_null(sprite_path) as Sprite2D
	if animation_tree:
		state_machine = animation_tree.get("parameters/playback")
		var root := animation_tree.tree_root as AnimationNodeStateMachine
		_has_block_state = root != null and root.has_node(block_state_name)
	if combat_component and combat_component.hitbox_component:
		combat_component.hitbox_component.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	if combat_component == null or state_machine == null:
		return
	var state := combat_component.get_state()
	var facing := combat_component.get_facing()

	_set_blend(facing)
	state_machine.travel(_pick_state(state))
	_update_feedback(state, delta)


func _pick_state(state: ActionStateMachine.State) -> String:
	match state:
		ActionStateMachine.State.ATTACK:
			var phase := combat_component.get_phase()
			if phase == ActionStateMachine.Phase.STARTUP or phase == ActionStateMachine.Phase.ACTIVE:
				return attack_state_name
		ActionStateMachine.State.BLOCK:
			if _has_block_state:
				return block_state_name
	return walk_state_name if _is_moving() else idle_state_name


func _set_blend(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	var d := dir.normalized()
	for state_name in [idle_state_name, walk_state_name, attack_state_name]:
		animation_tree.set("parameters/" + state_name + "/blend_position", d)
	if _has_block_state:
		animation_tree.set("parameters/" + block_state_name + "/blend_position", d)


func _update_feedback(state: ActionStateMachine.State, delta: float) -> void:
	if sprite == null:
		return

	# Charge: shake grows with the charge, sprite blinks.
	if state == ActionStateMachine.State.CHARGING:
		_charge_time += delta
		var ratio := combat_component.get_charge_ratio()
		var shake := charge_shake_strength * (1.0 + ratio)
		sprite.position = Vector2(
			sin(_charge_time * (10.0 + 10.0 * ratio)) * shake,
			cos(_charge_time * (15.0 + 15.0 * ratio)) * shake)
		var blink_on := fmod(_charge_time * lerpf(4.0, 8.0, ratio), 2.0) < 1.0
		sprite.self_modulate = Color(1, 1, 1, 1) if blink_on else Color(1.5, 1.5, 1.5, 1)
	else:
		_charge_time = 0.0
		sprite.position = Vector2.ZERO
		sprite.self_modulate = Color(1, 1, 1, 1)

	# Hit flash wins over the block tint.
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left > 0.0:
		sprite.modulate = hit_flash_color
	elif state == ActionStateMachine.State.BLOCK:
		sprite.modulate = block_tint
	else:
		sprite.modulate = Color(1, 1, 1, 1)


func _on_hit_received(_attacker: Node, _damage: float, _direction: Vector2) -> void:
	_flash_left = hit_flash_time


func _is_moving() -> bool:
	return movement_component != null and movement_component.is_moving()


func get_sprite() -> Sprite2D:
	return sprite
