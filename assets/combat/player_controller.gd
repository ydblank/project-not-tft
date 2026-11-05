extends Node2D
class_name PlayerController

# Turns player input into a CombatIntent every physics frame. Input is polled
# (not event-driven), so presses and releases can't be lost.

@export var entity: Node2D
@export var input_up: StringName = &"W"
@export var input_down: StringName = &"S"
@export var input_left: StringName = &"A"
@export var input_right: StringName = &"D"
@export var input_attack: StringName = &"Attack"
@export var input_block: StringName = &"Block"
@export var input_dash: StringName = &"dash"

var intent := CombatIntent.new()

const LUNGE_SCAN_RANGE := 60.0
## cos of the half-angle of the cone in front of you that counts as "your target".
const LUNGE_CONE_DOT := 0.8
## Stay this far from the target after lunging.
const LUNGE_STOP_GAP := 8.0


func _ready() -> void:
	if entity == null:
		entity = owner as Node2D
	# Read input before CombatComponent consumes the intent this frame.
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	if not _is_local_authority():
		intent.clear()
		return
	intent.move_dir = Input.get_vector(input_left, input_right, input_up, input_down)
	if entity:
		var to_mouse := get_global_mouse_position() - entity.global_position
		if to_mouse != Vector2.ZERO and to_mouse.is_finite():
			intent.aim_dir = to_mouse.normalized()
	intent.lunge_limit = _lunge_limit()
	intent.attack_held = Input.is_action_pressed(input_attack)
	intent.block_held = Input.is_action_pressed(input_block)
	intent.dash_held = Input.is_action_pressed(input_dash)


func _is_local_authority() -> bool:
	var mp := multiplayer.multiplayer_peer
	if mp == null or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return true
	return entity == null or entity.is_multiplayer_authority()


## Stop the attack lunge just short of whoever is in front, so a lunge never
## carries you through (or past) the target and makes the rest of a combo whiff.
func _lunge_limit() -> float:
	if entity == null or intent.aim_dir == Vector2.ZERO:
		return INF
	var best := INF
	for group_name in ["enemies", "dummies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var other := node as Node2D
			if other == null or other == entity:
				continue
			var to_other := other.global_position - entity.global_position
			var dist := to_other.length()
			if dist > LUNGE_SCAN_RANGE or dist <= 0.0:
				continue
			if to_other.normalized().dot(intent.aim_dir) < LUNGE_CONE_DOT:
				continue
			best = minf(best, dist)
	if best == INF:
		return INF
	return maxf(best - LUNGE_STOP_GAP, 0.0)
