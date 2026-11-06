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

## Extra pixels the camera may drift past the point where the arena edge reaches the screen edge
## (the camera limit: it can never leave the arena area).
@export var edge_margin: float = 24.0

var _home: Vector2


func _ready() -> void:
	if camera == null and get_parent():
		camera = get_parent().get_node_or_null("Camera2D") as Camera2D
	if camera:
		_home = camera.global_position


func _process(delta: float) -> void:
	if camera == null:
		return
	if not camera.global_position.is_finite():
		camera.global_position = _home # never stay lost after an invalid number
	var target := _home
	var focus: Variant = _focus_point()
	if focus != null and (focus as Vector2).is_finite():
		target = _home + (focus - _home) * follow_strength
	target = _keep_on_arena(target)
	if not target.is_finite():
		target = _home
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
	var p2 := get_tree().get_first_node_in_group("p2_controlled") as Node2D
	if p2:
		return point.lerp(p2.global_position, 0.5) # local co-op: frame both players
	var mate: Node2D = null
	for node in get_tree().get_nodes_in_group("allies"):
		if node is Node2D and node != player:
			mate = node
			break
	if mate:
		point = point.lerp(mate.global_position, teammate_weight)
	return point


## The camera never leaves the arena, even when a fighter is launched far outside it.
func _keep_on_arena(target: Vector2) -> Vector2:
	var arena := get_tree().get_first_node_in_group("arena") as ArenaBounds
	if arena == null:
		return target
	var rect := arena.get_world_rect()
	if rect.size == Vector2.ZERO:
		return target
	# Arena smaller than the screen: the camera stays centred. Larger: it may move only as far as keeps the arena edge on screen.
	var view := get_viewport().get_visible_rect().size / (camera.zoom if camera else Vector2.ONE)
	var arena_size := rect.size + Vector2(16, 16)
	var room := Vector2(maxf((arena_size.x - view.x) * 0.5, 0.0), maxf((arena_size.y - view.y) * 0.5, 0.0)) + Vector2(edge_margin, edge_margin)
	var centre := rect.get_center()
	return Vector2(clampf(target.x, centre.x - room.x, centre.x + room.x), clampf(target.y, centre.y - room.y, centre.y + room.y))
