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
		if to_mouse != Vector2.ZERO:
			intent.aim_dir = to_mouse.normalized()
	intent.attack_held = Input.is_action_pressed(input_attack)
	intent.block_held = Input.is_action_pressed(input_block)
	intent.dash_held = Input.is_action_pressed(input_dash)


func _is_local_authority() -> bool:
	var mp := multiplayer.multiplayer_peer
	if mp == null or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return true
	return entity == null or entity.is_multiplayer_authority()
