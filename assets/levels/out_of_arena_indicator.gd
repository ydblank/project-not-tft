extends CanvasLayer
class_name OutOfArenaIndicator

# While the fighter you control is outside the arena, a round "security camera"
# bubble shows a live view of it, with an arrow around the rim pointing the way
# back in. The arrow shows how you are doing:
#   green  = getting closer to the arena
#   red    = moving away
#   yellow = holding still
# and it grows and pulses faster the farther out you are. The distance to the
# arena edge is printed under the bubble.

@export var bubble_size: float = 130.0
## Screen margin from the left edge, in pixels.
@export var margin_left: float = 18.0
## How far (world pixels) counts as "very far" for the arrow size and colour.
@export var far_distance: float = 140.0
## World zoom inside the bubble.
@export var bubble_zoom: float = 3.0

const COLOR_CLOSER := Color(0.35, 1.0, 0.45)
const COLOR_AWAY := Color(1.0, 0.3, 0.25)
const COLOR_STILL := Color(1.0, 0.85, 0.3)
const MASK_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = length(UV - vec2(0.5));
	COLOR = vec4(c.rgb, c.a * step(d, 0.5));
}
"""

var _root: Control
var _viewport: SubViewport
var _camera: Camera2D
var _ring: Control
var _label: Label
var _arrow_dir: Vector2 = Vector2.RIGHT
var _arrow_color: Color = COLOR_STILL
var _arrow_scale: float = 1.0
var _time: float = 0.0
var _last_distance: float = 0.0
var _trend: float = 0.0 # smoothed: negative = closing in, positive = moving away
var _shown: bool = false
var _arena: ArenaBounds


func _ready() -> void:
	layer = 7
	_build()
	_set_shown(false, true)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Live view of the world around the fighter (shares the main world).
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(bubble_size), int(bubble_size))
	_viewport.world_2d = get_viewport().world_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * bubble_zoom
	_viewport.add_child(_camera)

	var holder := Control.new()
	holder.name = "Holder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(bubble_size, bubble_size)
	holder.size = Vector2(bubble_size, bubble_size)
	holder.position = Vector2(margin_left + 20.0, 200.0)
	holder.pivot_offset = holder.size * 0.5
	_root.add_child(holder)

	var shader := Shader.new()
	shader.code = MASK_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.material = mat
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(view)

	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_draw_ring)
	holder.add_child(_ring)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 5)
	_label.position = Vector2(0, bubble_size + 4.0)
	_label.size = Vector2(bubble_size, 22.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_label)


func _process(delta: float) -> void:
	_time += delta
	_place_bubble()
	var player := _local_player()
	var arena := _get_arena()
	if player == null or arena == null or arena.is_inside(player.global_position):
		_set_shown(false)
		_last_distance = 0.0
		_trend = 0.0
		return

	_set_shown(true)
	_camera.global_position = player.global_position

	# Direction and distance back to the arena.
	var target := arena.closest_inside_point(player.global_position)
	var dir := (target - player.global_position).normalized()
	if dir != Vector2.ZERO:
		_arrow_dir = dir
	var distance := _distance_to_arena(arena, player.global_position, _arrow_dir)

	# Trend: closing in, moving away or holding still (smoothed so it doesn't flicker).
	if _last_distance > 0.0 and delta > 0.0:
		var speed := (distance - _last_distance) / delta
		_trend = lerpf(_trend, clampf(speed / 40.0, -1.0, 1.0), minf(delta * 6.0, 1.0))
	_last_distance = distance
	if _trend < -0.2:
		_arrow_color = COLOR_CLOSER
	elif _trend > 0.2:
		_arrow_color = COLOR_AWAY
	else:
		_arrow_color = COLOR_STILL

	var farness := clampf(distance / far_distance, 0.0, 1.0)
	_arrow_scale = lerpf(0.8, 1.5, farness)
	_label.text = "ARENA  %d" % int(round(distance))
	_label.add_theme_color_override("font_color", _arrow_color)
	_ring.queue_redraw()


## Straight-line distance (world pixels) from `from` back to the arena edge along `dir`.
func _distance_to_arena(arena: ArenaBounds, from: Vector2, dir: Vector2) -> float:
	var d := 0.0
	while d < 1500.0 and not arena.is_inside(from + dir * d):
		d += 4.0
	return d


func _draw_ring() -> void:
	var center := Vector2(bubble_size, bubble_size) * 0.5
	var radius := bubble_size * 0.5
	# Pulsing frame; faster and redder the farther out we are.
	var farness := clampf(_last_distance / far_distance, 0.0, 1.0)
	var pulse := 0.65 + 0.35 * sin(_time * lerpf(4.0, 12.0, farness))
	var frame := _arrow_color
	frame.a = pulse
	_ring.draw_arc(center, radius - 1.5, 0.0, TAU, 48, Color(0, 0, 0, 0.8), 5.0, true)
	_ring.draw_arc(center, radius - 1.5, 0.0, TAU, 48, frame, 3.0, true)
	# Small "REC" dot, for the security-camera look.
	if fmod(_time, 1.0) < 0.6:
		_ring.draw_circle(center + Vector2(-radius * 0.62, -radius * 0.62), 4.0, Color(1, 0.15, 0.15))

	# Arrow on the rim pointing toward the arena.
	var tip_dist := radius + 6.0 + 8.0 * (0.5 + 0.5 * sin(_time * lerpf(5.0, 12.0, farness)))
	var base := center + _arrow_dir * (tip_dist - 6.0 * _arrow_scale)
	var tip := center + _arrow_dir * (tip_dist + 10.0 * _arrow_scale)
	var side := _arrow_dir.orthogonal() * 9.0 * _arrow_scale
	var points := PackedVector2Array([tip, base + side, base - side])
	_ring.draw_colored_polygon(points, Color(0, 0, 0, 0.85))
	var inner := PackedVector2Array([
		center + _arrow_dir * (tip_dist + 7.0 * _arrow_scale),
		base + side * 0.62,
		base - side * 0.62,
	])
	_ring.draw_colored_polygon(inner, _arrow_color)


func _set_shown(value: bool, instant: bool = false) -> void:
	if value == _shown and not instant:
		return
	_shown = value
	var holder := _root.get_node("Holder") as Control
	if instant:
		holder.visible = value
		return
	if value:
		holder.visible = true
		holder.scale = Vector2(0.2, 0.2)
		holder.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(holder, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(holder, "modulate:a", 1.0, 0.15)
	else:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(holder, "scale", Vector2(0.2, 0.2), 0.15)
		tween.tween_property(holder, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(func(): holder.visible = _shown)


func _local_player() -> Node2D:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate and candidate.is_multiplayer_authority():
			var health := CombatComponent.find_on(candidate)
			if health and health.get_state() == ActionStateMachine.State.DEAD:
				return null
			return candidate
	return null


func _get_arena() -> ArenaBounds:
	if not is_instance_valid(_arena):
		_arena = get_tree().get_first_node_in_group("arena") as ArenaBounds
	return _arena


## Left edge, vertically centred (follows the window size).
func _place_bubble() -> void:
	var holder := _root.get_node("Holder") as Control
	holder.position = Vector2(margin_left + 20.0, (get_viewport().get_visible_rect().size.y - bubble_size) * 0.5)
