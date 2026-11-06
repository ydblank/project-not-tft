extends Node2D
class_name ArenaBounds

# The arena is the walkable floor of a TileMap. Any player / enemy standing
# outside it is slowed and takes damage over time (a % of max HP per second),
# so fights should stay on the arena tiles.
#
# Add this node to the level. It looks for a sibling TileMap named "TileMap"
# unless `tile_map` is set. Entities are found through `groups`.

const ZONE_WARNING_TEXT := "OUTSIDE THE ZONE - get inside the circle!"

@export var tile_map: TileMap
@export var groups: Array[String] = ["players", "enemies", "allies"]
## Floor = tiles that have navigation data (walkable). If the TileMap has none,
## every painted tile counts as arena.
@export var floor_tiles_only: bool = true

@export_group("Outside the arena")
## Walk / block / lunge speed multiplier while outside (dash is unaffected).
@export_range(0.0, 1.0) var speed_multiplier_outside: float = 0.5
## Damage per second as a percentage of max HP.
@export var damage_percent_per_second: float = 8.0
## Seconds between damage ticks.
@export var damage_interval: float = 0.5
## Seconds outside before the first tick (so brushing the edge is harmless).
@export var grace_time: float = 0.4

@export_group("Feedback")
@export var show_warning: bool = true
@export var warning_text: String = "OUT OF THE ARENA - get back in!"
## Draws the detected arena tiles (for checking the setup).
@export var debug_draw: bool = false

var _floor_cells: Dictionary = {} # Vector2i -> true
## Solid tiles (walls, pillars). Not floor, but a fighter can stand on the walkable part of one (the bottom wall row only blocks its lower half), so that is not "outside".
var _wall_cells: Dictionary = {} # Vector2i -> true
var _floor_centers: PackedVector2Array = PackedVector2Array() # world centres of the floor tiles
var _state: Dictionary = {} # entity instance id -> {time, tick}
var _local_outside: bool = false
## The local player is outside because of the shrinking zone, not the arena edge.
var _local_outside_zone: bool = false
var _warning_layer: CanvasLayer
var _warning_tint: ColorRect
var _warning_label: Label
var _pulse: float = 0.0


func _ready() -> void:
	add_to_group("arena") # lets the AI find the arena and stay inside it
	if tile_map == null and get_parent():
		tile_map = get_parent().get_node_or_null("TileMap") as TileMap
	if tile_map == null:
		push_warning("ArenaBounds: no TileMap found; the arena limit is disabled.")
		set_physics_process(false)
		return
	rebuild()
	if show_warning:
		_build_warning()


## Re-reads the TileMap (call after changing tiles at runtime).
func rebuild() -> void:
	_floor_cells.clear()
	_wall_cells.clear()
	var all_cells: Dictionary = {}
	for layer in tile_map.get_layers_count():
		for cell in tile_map.get_used_cells(layer):
			all_cells[cell] = true
			var data := tile_map.get_cell_tile_data(layer, cell)
			if data and data.get_navigation_polygon(0) != null:
				_floor_cells[cell] = true
			elif data and data.get_collision_polygons_count(0) > 0:
				_wall_cells[cell] = true
	if not floor_tiles_only or _floor_cells.is_empty():
		_floor_cells = all_cells
	queue_redraw()


## True on an arena floor tile that is also inside the shrinking zone (when that is on).
func is_inside(world_pos: Vector2) -> bool:
	var cell := tile_map.local_to_map(tile_map.to_local(world_pos))
	return _floor_cells.has(cell) and _in_zone(world_pos)


func _in_zone(world_pos: Vector2) -> bool:
	var zone := get_tree().get_first_node_in_group("zone") as ShrinkingZone
	return zone == null or zone.contains(world_pos)


## True on a solid tile (wall or pillar): not arena floor, but not outside either.
func is_on_wall_tile(world_pos: Vector2) -> bool:
	return _wall_cells.has(tile_map.local_to_map(tile_map.to_local(world_pos)))


func _physics_process(delta: float) -> void:
	var seen: Dictionary = {}
	_local_outside = false
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			var entity := node as Node2D
			if entity == null:
				continue
			var combat := CombatComponent.find_on(entity)
			if combat == null:
				continue
			var id := entity.get_instance_id()
			seen[id] = true
			var outside := _update_entity(entity, combat, id, delta)
			if outside and group_name == "players" and entity.is_multiplayer_authority():
				_local_outside = true
				_local_outside_zone = not _in_zone(entity.global_position)
	for id in _state.keys():
		if not seen.has(id):
			_state.erase(id)


## Returns true while the entity counts as outside (and alive).
func _update_entity(entity: Node2D, combat: CombatComponent, id: int, delta: float) -> bool:
	var health := combat.health_component
	if combat.get_state() == ActionStateMachine.State.DEAD or (health and health.is_dead()):
		combat.speed_multiplier = 1.0
		_state.erase(id)
		return false

	var st: Dictionary = _state.get(id, {"time": 0.0, "tick": 0.0})
	var pos := entity.global_position
	var outside := not is_inside(pos) and not (is_on_wall_tile(pos) and _in_zone(pos))
	if outside:
		combat.speed_multiplier = speed_multiplier_outside
		st.time += delta
		if st.time >= grace_time and health and combat.hitbox_component:
			st.tick += delta
			while st.tick >= damage_interval:
				st.tick -= damage_interval
				var amount := health.get_max_hp() * damage_percent_per_second * 0.01 * damage_interval
				combat.hitbox_component.apply_environment_damage(maxf(amount, 1.0))
	else:
		combat.speed_multiplier = 1.0
		st.time = 0.0
		st.tick = 0.0
	_state[id] = st
	return outside


# ======================================================================
# Warning for the local player
# ======================================================================

func _process(delta: float) -> void:
	if _warning_tint == null:
		return
	_pulse += delta * 4.0
	var target := (0.10 + 0.05 * sin(_pulse)) if _local_outside else 0.0
	_warning_tint.color.a = lerpf(_warning_tint.color.a, target, minf(delta * 8.0, 1.0))
	_warning_label.text = ZONE_WARNING_TEXT if _local_outside_zone else warning_text
	_warning_label.visible = _local_outside


func _build_warning() -> void:
	_warning_layer = CanvasLayer.new()
	_warning_layer.layer = 5
	add_child(_warning_layer)

	_warning_tint = ColorRect.new()
	_warning_tint.color = Color(0.9, 0.1, 0.1, 0.0)
	_warning_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warning_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_layer.add_child(_warning_tint)

	_warning_label = Label.new()
	_warning_label.text = warning_text
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_warning_label.add_theme_font_size_override("font_size", 20)
	_warning_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warning_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning_label.offset_top = 50.0
	_warning_label.visible = false
	_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_layer.add_child(_warning_label)


func _draw() -> void:
	if not debug_draw or tile_map == null:
		return
	var size := Vector2(tile_map.tile_set.tile_size)
	for cell in _floor_cells:
		var center := to_local(tile_map.to_global(tile_map.map_to_local(cell)))
		draw_rect(Rect2(center - size * 0.5, size), Color(0.2, 1.0, 0.3, 0.25), true)


## World position of the arena floor tile nearest to `world_pos` (used by the
## AI to walk back in after being knocked out).
func closest_inside_point(world_pos: Vector2) -> Vector2:
	if _floor_centers.size() != _floor_cells.size():
		_floor_centers = PackedVector2Array()
		for cell in _floor_cells:
			_floor_centers.append(tile_map.to_global(tile_map.map_to_local(cell)))
	var zone := get_tree().get_first_node_in_group("zone") as ShrinkingZone
	var best := world_pos
	var best_d := INF
	for center in _floor_centers:
		if zone != null and not zone.contains(center):
			continue
		var d := world_pos.distance_squared_to(center)
		if d < best_d:
			best_d = d
			best = center
	if best_d == INF:
		return zone.center if zone else best
	return best


## Bounding box (world space) of the arena floor tiles. Used to keep the camera on the arena.
func get_world_rect() -> Rect2:
	if _floor_cells.is_empty():
		return Rect2()
	var first := true
	var rect := Rect2()
	for cell in _floor_cells:
		var center := tile_map.to_global(tile_map.map_to_local(cell))
		if first:
			rect = Rect2(center, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(center)
	return rect
