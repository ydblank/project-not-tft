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

## The controlled fighter is never allowed farther than this fraction of the way from the screen
## centre to the screen edge, whatever `follow_strength` is. It keeps the gentle lean in a small
## arena and still tracks you in an arena bigger than the screen.
@export_range(0.2, 0.9) var comfort_zone: float = 0.55

## The arena clamp must never leave you stuck at the screen edge: near the arena edge (or outside it) the camera may slide past the arena, showing a little void, as far as keeps you within this fraction of the way from the screen centre to its edge. Applies while you are within outside_follow_limit pixels of the arena. Farther than that (launched far away) the camera stays on the arena and the out-of-arena bubble takes over.
@export_range(0.4, 0.95) var edge_zone: float = 0.6
@export var outside_follow_limit: float = 400.0

## Extra pixels the camera may drift past the point where the arena edge reaches the screen edge
## (the camera limit: it can never leave the arena area).
@export var edge_margin: float = 24.0

## The camera zooms in by up to this factor as the shrinking zone closes (1.5 = 50% closer when the zone
## is at its smallest), so the shrinking circle keeps filling the frame. 1 = never zoom.
@export_range(1.0, 3.0) var zone_zoom_multiplier: float = 1.5
## How quickly the zoom follows (higher = snappier).
@export var zoom_smoothing: float = 3.0
## As the zone closes the camera leans toward its centre by up to this fraction (0 = only follow the
## fighter), so the whole circle stays in frame. The fighter you control is still kept on screen.
@export_range(0.0, 1.0) var zone_focus: float = 0.7

## From this zone progress on (0 = zone just started, 1 = smallest), the camera no longer follows a fighter
## who is outside the zone, so the camera bubble shows it. Below it the fighter is always kept in frame.
@export_range(0.0, 1.0) var zone_release_progress: float = 0.4

## A short extra zoom-and-focus on one point, used by the death slow-motion. `punch_zoom` multiplies the
## zoom, and the camera moves `punch_weight` (0..1) of the way to `punch_focus`. Both are set from outside.
var punch_zoom: float = 1.0
var punch_weight: float = 0.0
var punch_focus: Vector2 = Vector2.ZERO

var _home: Vector2
var _base_zoom: Vector2 = Vector2.ONE
var _zone: ShrinkingZone


func _ready() -> void:
	if camera == null and get_parent():
		camera = get_parent().get_node_or_null("Camera2D") as Camera2D
	if camera:
		_home = camera.global_position
		_base_zoom = camera.zoom


func _process(delta: float) -> void:
	if camera == null:
		return
	# The camera moves in real time, so it keeps its pace through slow-motion (0 during a hitstop freeze).
	delta = delta / Engine.time_scale if Engine.time_scale > 0.01 else 0.0
	_update_zoom(delta)
	if not camera.global_position.is_finite():
		camera.global_position = _home # never stay lost after an invalid number
	var target := _home
	var focus: Variant = _focus_point()
	if focus != null and (focus as Vector2).is_finite():
		target = _home + (focus - _home) * follow_strength
	var keep_player_in_frame := true
	if _zone != null and is_instance_valid(_zone) and _zone.active:
		var progress := _zone.get_progress()
		target = target.lerp(_zone.center, progress * zone_focus)
		# Once the zone is well closed, a fighter caught outside it is not chased: the camera stays on the
		# zone and the "security camera" bubble (OutOfArenaIndicator) shows the fighter instead.
		var player := _controlled_player()
		if progress >= zone_release_progress and player != null and not _zone.contains(player.global_position):
			keep_player_in_frame = false
	if keep_player_in_frame:
		target = _keep_player_comfortable(target)
	target = _keep_on_arena(target)
	if keep_player_in_frame:
		target = _keep_player_on_screen(target)
	if punch_weight > 0.0:
		target = target.lerp(punch_focus, punch_weight) # after the clamps: the focus may take the fighter you control out of frame for a moment
	if not target.is_finite():
		target = _home
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-smoothing * delta))


## Zooms in as the shrinking zone closes, and back out when it is off.
func _update_zoom(delta: float) -> void:
	if _zone == null or not is_instance_valid(_zone):
		_zone = get_tree().get_first_node_in_group("zone") as ShrinkingZone
	var progress := _zone.get_progress() if _zone else 0.0
	var target := _base_zoom * lerpf(1.0, zone_zoom_multiplier, progress) * punch_zoom
	camera.zoom = camera.zoom.lerp(target, 1.0 - exp(-zoom_smoothing * delta))


## Moves the target just enough that the controlled fighter stays inside the comfort zone.
func _keep_player_comfortable(target: Vector2) -> Vector2:
	var player := _controlled_player()
	if player == null or not player.global_position.is_finite():
		return target
	var half_view := get_viewport().get_visible_rect().size / (camera.zoom if camera else Vector2.ONE) * 0.5
	var reach := half_view * comfort_zone
	var pos := player.global_position
	return Vector2(
		clampf(target.x, pos.x - reach.x, pos.x + reach.x),
		clampf(target.y, pos.y - reach.y, pos.y + reach.y))


## After the arena clamp: keep the fighter you control well inside the screen, even at the arena edge or in the void next to it.
func _keep_player_on_screen(target: Vector2) -> Vector2:
	var player := _controlled_player()
	if player == null or not player.global_position.is_finite():
		return target
	var arena := get_tree().get_first_node_in_group("arena") as ArenaBounds
	if arena != null:
		var rect := arena.get_world_rect()
		if rect.size != Vector2.ZERO and not rect.grow(outside_follow_limit).has_point(player.global_position):
			return target
	var half_view := get_viewport().get_visible_rect().size / (camera.zoom if camera else Vector2.ONE) * 0.5
	var reach := half_view * edge_zone
	var pos := player.global_position
	return Vector2(
		clampf(target.x, pos.x - reach.x, pos.x + reach.x),
		clampf(target.y, pos.y - reach.y, pos.y + reach.y))


func _controlled_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate and candidate.is_multiplayer_authority():
			return candidate
	return null


func _focus_point() -> Variant:
	var player := _controlled_player()
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
