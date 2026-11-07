extends Node2D
class_name ShrinkingZone

# A Fortnite-style closing circle. When it is on, the arena starts as a circle that covers the whole floor;
# every `interval` seconds it closes in over `shrink_time` seconds onto a smaller circle somewhere inside
# the old one (the circle it is closing onto is shown as a white outline while it closes), until it reaches `min_radius`.
#
# This node only owns the circle (position, timer, drawing, HUD). ArenaBounds asks `contains()` from
# `is_inside()`, so standing outside the circle is handled exactly like standing outside the arena:
# slowed, damaged over time, and the AI treats the edge as a wall and walks back in.
# It starts on (`start_enabled`); the top button (visible while paused) or F4 turns it off and on.

enum Phase {WAIT, SHRINK, DONE}

## Seconds the circle holds still before each closing.
@export var interval: float = 30.0
## Seconds each closing takes.
@export var shrink_time: float = 6.0
## Each new circle's radius is this fraction of the previous one.
@export_range(0.3, 0.95) var shrink_factor: float = 0.7
## The circle never gets smaller than this radius (px).
@export var min_radius: float = 56.0
## Start with the zone running (the first closing comes `interval` seconds after the 3-2-1 countdown).
@export var start_enabled: bool = true

## The "Zone closes in N" warning appears once this many seconds are left before the zone closes.
const WARN_SECONDS := 5.0
const COLOR_HAZE :=Color(0.9, 0.1, 0.1, 0.2)
const COLOR_EDGE := Color(1.0, 0.35, 0.3, 0.9)
const COLOR_NEXT := Color(1.0, 1.0, 1.0, 0.55)
## How far past the circle the red haze reaches (px): more than any screen shows.
const HAZE_REACH := 1600.0
const RING_SEGMENTS := 192

var active: bool = false
var center: Vector2 = Vector2.ZERO
var radius: float = 0.0

var _start_radius: float = 0.0
var _phase: Phase = Phase.WAIT
var _timer: float = 0.0
var _from_center: Vector2
var _from_radius: float
var _next_center: Vector2
var _next_radius: float
var _arena: ArenaBounds

var _button: Button
var _label: Label


func _ready() -> void:
	add_to_group("zone")
	z_index = 1 # over the floor and the fighters, so anyone outside is tinted red
	_build_ui()
	_refresh()
	if start_enabled:
		set_active.call_deferred(true) # after the arena has built its floor


func _exit_tree() -> void:
	active = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		get_viewport().set_input_as_handled()
		set_active(not active)


## True when `world_pos` is inside the circle (always true while the zone is off).
func contains(world_pos: Vector2) -> bool:
	return not active or _on_hold() or world_pos.distance_to(center) <= radius


## The zone stands down (no closing, nobody hurt) while the parry trainer is running.
func _on_hold() -> bool:
	var trainer := get_parent().get_node_or_null("ParryTrainer") as ParryTrainer if get_parent() else null
	return trainer != null and trainer.active


## How far the zone has closed: 0 at the start (or while the zone is off), 1 at the minimum size. It moves
## smoothly during each closing. The music uses it to speed up.
func get_progress() -> float:
	if not active or _start_radius <= min_radius:
		return 0.0
	return clampf((_start_radius - radius) / (_start_radius - min_radius), 0.0, 1.0)


func set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	if active:
		_start()
	queue_redraw()
	_refresh()


func _physics_process(delta: float) -> void:
	if not active or FightCountdown.active or _on_hold():
		return
	_timer += delta
	match _phase:
		Phase.WAIT:
			if _timer >= interval:
				_phase = Phase.SHRINK
				_timer = 0.0
				_from_center = center
				_from_radius = radius
		Phase.SHRINK:
			var t := clampf(_timer / shrink_time, 0.0, 1.0)
			center = _from_center.lerp(_next_center, t)
			radius = lerpf(_from_radius, _next_radius, t)
			if t >= 1.0:
				_timer = 0.0
				_plan_next()
	queue_redraw()
	_update_label()


## Starts over with a circle that covers the whole arena.
func _start() -> void:
	_arena = get_tree().get_first_node_in_group("arena") as ArenaBounds
	var rect := _arena.get_world_rect() if _arena else Rect2(-240.0, -112.0, 480.0, 224.0)
	rect = rect.grow(8.0) # the rect holds tile centres; add half a tile
	center = rect.get_center()
	radius = rect.size.length() * 0.5
	_start_radius = radius
	_timer = 0.0
	_plan_next()


## Picks the next circle: smaller, and inside the current one.
func _plan_next() -> void:
	_phase = Phase.WAIT
	if radius <= min_radius + 0.5:
		_phase = Phase.DONE
		_next_center = center
		_next_radius = radius
		return
	_next_radius = maxf(radius * shrink_factor, min_radius)
	var reach := radius - _next_radius
	var pick := center + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * reach
	if _arena:
		var rect := _arena.get_world_rect()
		pick = pick.clamp(rect.position, rect.end)
	# Keep the new circle inside the old one (clamping to the arena can push it out).
	var offset := pick - center
	if offset.length() > reach:
		pick = center + offset.normalized() * reach
	_next_center = pick


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if not active:
		return
	var c := to_local(center)
	# Red haze over everything outside the circle: a ring of quads (no overlaps, so the alpha stays even).
	var step := TAU / RING_SEGMENTS
	for i in RING_SEGMENTS:
		var a0 := Vector2.from_angle(step * i)
		var a1 := Vector2.from_angle(step * (i + 1))
		draw_colored_polygon(PackedVector2Array([
			c + a0 * radius, c + a0 * (radius + HAZE_REACH),
			c + a1 * (radius + HAZE_REACH), c + a1 * radius]), COLOR_HAZE)
	draw_arc(c, radius, 0.0, TAU, RING_SEGMENTS, COLOR_EDGE, 1.5, true)
	# The white target circle only shows while the zone is closing onto it.
	if _phase == Phase.SHRINK:
		draw_arc(to_local(_next_center), _next_radius, 0.0, TAU, RING_SEGMENTS, COLOR_NEXT, 1.0, true)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	_button = Button.new()
	_button.toggle_mode = true
	_button.focus_mode = Control.FOCUS_NONE
	_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_button.offset_left = 0.0
	_button.offset_right = 0.0
	_button.offset_top = 108.0
	_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_button.tooltip_text = "A circle closes in on the arena every few seconds (F4)"
	_button.toggled.connect(func(pressed: bool): set_active(pressed))
	layer.add_child(_button)
	_button.add_to_group("game_option") # the pause menu shows it in Dev Tools

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.offset_top = 210.0 # below the paused buttons (the last one sits at 172)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_label)


func _refresh() -> void:
	if _button == null:
		return
	_button.set_pressed_no_signal(active)
	_button.text = "Shrinking Zone: ON (F4)" if active else "Shrinking Zone: OFF (F4)"
	_label.visible = active
	_update_label()


func _update_label() -> void:
	if _label == null or not active:
		return
	# The "closes in" warning only shows for the last WARN_SECONDS of the wait; the other texts always show.
	_label.visible = _phase != Phase.WAIT or interval - _timer <= WARN_SECONDS
	match _phase:
		Phase.WAIT:
			_label.text = "Zone closes in %d" % ceili(interval - _timer)
			_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		Phase.SHRINK:
			_label.text = "ZONE CLOSING!"
			_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		Phase.DONE:
			_label.text = "Final zone"
			_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
