extends Node
class_name CameraFollow

# Gentle camera follow. The camera stays centred on the level and drifts toward
# the fighter you control, leaning a bit toward your teammate so both stay in
# frame. `follow_strength` 0 = fixed camera, 1 = locked on you.

@export var camera: Camera2D
@export_range(0.0, 1.0) var follow_strength: float = 0.35
## How much the teammate pulls the framing (0 = only you).
@export_range(0.0, 1.0) var teammate_weight: float = 0.3
## Higher = snappier.
@export var smoothing: float = 5.0

var _home: Vector2


func _ready() -> void:
	if camera == null and get_parent():
		camera = get_parent().get_node_or_null("Camera2D") as Camera2D
	if camera:
		_home = camera.global_position


func _process(delta: float) -> void:
	if camera == null:
		return
	var target := _home
	var focus: Variant = _focus_point()
	if focus != null:
		target = _home + (focus - _home) * follow_strength
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-smoothing * delta))


func _focus_point() -> Variant:
	var player: Node2D = null
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate and candidate.is_multiplayer_authority():
			player = candidate
			break
	if player == null:
		return null
	var point := player.global_position
	var mate: Node2D = null
	for node in get_tree().get_nodes_in_group("allies"):
		if node is Node2D and node != player:
			mate = node
			break
	if mate:
		point = point.lerp(mate.global_position, teammate_weight)
	return point
