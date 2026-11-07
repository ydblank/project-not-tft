extends Node2D
class_name SpinSlash

# The sword Whirlwind's own animation: a white crescent swoosh that sweeps round the fighter
# (thin and faint at its tail, thick and bright at its head), the blade riding its leading edge,
# and small specks flung off the edge. Follows the fighter; fades out when the spin ends.
# Drawn in code, so its size always matches the spin radius.

## Angle the crescent trails behind its head (radians).
const SWEEP := 2.6
const SEGMENTS := 24
## Width of the crescent at its head, as a share of the radius.
const HEAD_WIDTH := 0.28
const FADE_TIME := 0.15
const COLOR_SWOOSH := Color(1.0, 1.0, 1.0)
const COLOR_EDGE := Color(0.85, 0.95, 1.0)
const COLOR_BLADE := Color(0.82, 0.86, 0.95)
const COLOR_HILT := Color(0.55, 0.35, 0.2)
const SPECK_INTERVAL := 0.03
const SPECK_LIFE := 0.25
const SPECK_SPEED := 70.0

var follow: Node2D = null
var radius: float = 32.0
var duration: float = 0.6
var turns: float = 2.0
var start_angle: float = 0.0

var _t: float = 0.0
var _speck_left: float = 0.0
var _specks: Array[Dictionary] = [] # {pos, vel, age}


## Creates the effect for one spin under `parent`, following `p_follow`.
static func spawn(parent: Node, p_follow: Node2D, p_radius: float, p_duration: float, p_turns: float, p_start_angle: float) -> SpinSlash:
	var fx := SpinSlash.new()
	fx.follow = p_follow
	fx.radius = p_radius
	fx.duration = p_duration
	fx.turns = p_turns
	fx.start_angle = p_start_angle
	parent.add_child(fx)
	fx.global_position = p_follow.global_position
	return fx


func _ready() -> void:
	z_index = 4 # over bodies, like the other swing effects


## Current angle of the crescent's head (eases in at the start of the spin).
func head_angle() -> float:
	var p := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
	return start_angle + ease(p, 0.8) * TAU * turns


## Ends the effect early (the spin was interrupted): just the fade-out is left.
func finish() -> void:
	_t = maxf(_t, duration)


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration + FADE_TIME:
		queue_free()
		return
	if is_instance_valid(follow):
		global_position = follow.global_position
	if _t < duration:
		_speck_left -= delta
		while _speck_left <= 0.0:
			_speck_left += SPECK_INTERVAL
			var a := head_angle() + randf_range(-0.3, 0.1)
			var out := Vector2.from_angle(a)
			_specks.append({"pos": out * radius * randf_range(0.8, 1.05), "vel": (out + out.orthogonal() * 0.8) * SPECK_SPEED * randf_range(0.6, 1.2), "age": 0.0})
	for s in _specks:
		s.age += delta
		s.pos += s.vel * delta
	_specks = _specks.filter(func(s: Dictionary) -> bool: return s.age < SPECK_LIFE)
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - clampf((_t - duration) / FADE_TIME, 0.0, 1.0)
	var head := head_angle()
	# Crescent from the tail (faint, thin) to the head (bright, wide).
	for i in SEGMENTS:
		var t0 := float(i) / SEGMENTS
		var t1 := float(i + 1) / SEGMENTS
		var a0 := head - SWEEP * (1.0 - t0)
		var a1 := head - SWEEP * (1.0 - t1)
		var w0 := radius * HEAD_WIDTH * pow(t0, 1.6)
		var w1 := radius * HEAD_WIDTH * pow(t1, 1.6)
		var quad := PackedVector2Array([
			Vector2.from_angle(a0) * radius, Vector2.from_angle(a1) * radius,
			Vector2.from_angle(a1) * (radius - w1), Vector2.from_angle(a0) * (radius - w0),
		])
		draw_colored_polygon(quad, Color(COLOR_SWOOSH, lerpf(0.05, 0.9, t1) * fade))
	# A thin bright edge along the outside and a faint inner echo.
	draw_arc(Vector2.ZERO, radius, head - SWEEP * 0.6, head, 16, Color(COLOR_EDGE, fade), 1.2)
	draw_arc(Vector2.ZERO, radius * 0.6, head - SWEEP * 0.5, head - 0.2, 12, Color(COLOR_SWOOSH, 0.25 * fade), 1.0)
	# The sword at the head of the swoosh.
	var dir := Vector2.from_angle(head)
	draw_line(dir * 4.0, dir * (radius - 1.0), Color(COLOR_BLADE, fade), 2.0)
	draw_line(dir * 4.0 + dir.orthogonal() * 3.0, dir * 4.0 - dir.orthogonal() * 3.0, Color(COLOR_HILT, fade), 2.0)
	for s in _specks:
		var life: float = 1.0 - s.age / SPECK_LIFE
		draw_rect(Rect2(s.pos - Vector2.ONE, Vector2(2, 2)), Color(COLOR_SWOOSH, life * fade))
