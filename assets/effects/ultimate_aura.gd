extends Node2D
class_name UltimateAura

# The ultimate's look on a fighter (GAM-23), drawn behind its sprite. Purely visual.
#   - Ready (meter full): a pulsing red glow hugging the fighter's outline, a red pool of light at
#     its feet and embers rising off it. Every fighter shows it, so you can read an enemy's ultimate.
#   - Active: the same in the ultimate's own colour, brighter and faster, with an arc at the feet
#     that empties over the duration.
# Created by AnimationComponent. The outline glow is a copy of the sprite drawn with a shader that
# turns its pixels into a blurred silhouette, so it follows every animation frame.

const READY_COLOR := Color(1.0, 0.12, 0.08)
## Pool of light at the feet: half-size of the ellipse, and where its centre sits under the fighter.
const POOL_SIZE := Vector2(15.0, 6.0)
const POOL_POS := Vector2(0, 9)
## Glow strength and pulse speed (cycles per second) while ready / while active.
const READY_ALPHA := 0.55
const ACTIVE_ALPHA := 0.9
const READY_PULSE := 1.6
const ACTIVE_PULSE := 4.0
## Embers per second, how fast they rise (px/s) and how long they live.
const EMBER_RATE_READY := 10.0
const EMBER_RATE_ACTIVE := 26.0
const EMBER_SPEED := 22.0
const EMBER_LIFE := 0.8
## How fast the aura fades in and out.
const FADE_SPEED := 5.0

const GLOW_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 glow_color : source_color = vec4(1.0, 0.1, 0.1, 1.0);
uniform float spread = 2.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * spread;
	float a = texture(TEXTURE, UV).a;
	float edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		edge += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a;
		edge += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px * 0.5).a;
	}
	float glow = clamp(edge / 10.0, 0.0, 1.0);
	COLOR = vec4(glow_color.rgb, max(glow, a * 0.35) * glow_color.a);
}
"""

static var _glow_shader: Shader

var combat: CombatComponent
var sprite: Sprite2D

var _glow: Sprite2D
var _glow_material: ShaderMaterial
var _amount: float = 0.0 # 0..1, eases in and out
var _color: Color = READY_COLOR
var _time: float = 0.0
var _ember_left: float = 0.0
var _embers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(p_combat: CombatComponent, p_sprite: Sprite2D) -> void:
	combat = p_combat
	sprite = p_sprite
	_rng.randomize()
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER_CODE
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = _glow_shader
	_glow = Sprite2D.new()
	_glow.name = "UltimateGlow"
	_glow.material = _glow_material
	_glow.visible = false
	add_child(_glow)


func _process(delta: float) -> void:
	_time += delta
	var active := combat != null and combat.is_ult_active()
	var full := combat != null and combat.is_ult_ready()
	var dead := combat != null and combat.get_state() == ActionStateMachine.State.DEAD
	var target := 0.0 if dead else (1.0 if active or full else 0.0)
	_amount = move_toward(_amount, target, FADE_SPEED * delta)
	if active:
		_color = combat.get_ult_color()
	elif full:
		_color = READY_COLOR
	_update_glow(active)
	_update_embers(delta, active)
	queue_redraw()


func _update_glow(active: bool) -> void:
	if sprite == null or not is_instance_valid(sprite) or _amount <= 0.0:
		_glow.visible = false
		return
	_glow.visible = sprite.visible
	_glow.texture = sprite.texture
	_glow.hframes = sprite.hframes
	_glow.vframes = sprite.vframes
	_glow.frame = sprite.frame
	_glow.flip_h = sprite.flip_h
	_glow.flip_v = sprite.flip_v
	_glow.offset = sprite.offset
	_glow.centered = sprite.centered
	_glow.texture_filter = sprite.texture_filter
	_glow.position = sprite.position
	_glow.rotation = sprite.rotation
	var pulse := _pulse(active)
	_glow.scale = sprite.scale * (1.0 + 0.06 * pulse)
	var c := _color
	c.a = (ACTIVE_ALPHA if active else READY_ALPHA) * (0.65 + 0.35 * pulse) * _amount
	_glow_material.set_shader_parameter("glow_color", c)
	_glow_material.set_shader_parameter("spread", 2.0 + pulse * (1.5 if active else 1.0))


## 0..1 heartbeat.
func _pulse(active: bool) -> float:
	return 0.5 + 0.5 * sin(_time * TAU * (ACTIVE_PULSE if active else READY_PULSE))


func _update_embers(delta: float, active: bool) -> void:
	for i in range(_embers.size() - 1, -1, -1):
		var e: Dictionary = _embers[i]
		e.age += delta
		e.pos += e.vel * delta
		if e.age >= EMBER_LIFE:
			_embers.remove_at(i)
	if _amount <= 0.0:
		return
	_ember_left -= delta * (EMBER_RATE_ACTIVE if active else EMBER_RATE_READY) * _amount
	while _ember_left <= 0.0:
		_ember_left += 1.0
		_embers.append({
			"pos": Vector2(_rng.randf_range(-9.0, 9.0), _rng.randf_range(-4.0, 10.0)),
			"vel": Vector2(_rng.randf_range(-5.0, 5.0), -EMBER_SPEED * _rng.randf_range(0.7, 1.4)),
			"age": 0.0,
			"size": _rng.randf_range(1.0, 2.0),
		})


func _draw() -> void:
	if _amount <= 0.0 and _embers.is_empty():
		return
	var active := combat != null and combat.is_ult_active()
	var pulse := _pulse(active)
	# Pool of light at the feet: soft stacked ellipses.
	for i in 4:
		var t := float(i) / 3.0
		var c := _color
		c.a = (0.22 - 0.05 * i) * _amount * (0.7 + 0.3 * pulse)
		_draw_ellipse(POOL_POS, POOL_SIZE * (1.0 + t * 0.6 + 0.1 * pulse), c)
	# Embers rise and fade.
	for e in _embers:
		var c := _color.lightened(0.3)
		c.a = (1.0 - e.age / EMBER_LIFE) * _amount
		draw_rect(Rect2(e.pos, Vector2(e.size, e.size)), c)
	# Active: the time left as an arc round the feet.
	if active and combat:
		var ratio := combat.get_ult_time_ratio()
		var c := _color
		c.a = 0.9 * _amount
		_draw_ellipse_arc(POOL_POS, POOL_SIZE * 1.25, ratio, c, 1.5)


func _draw_ellipse(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		points.append(center + Vector2(cos(a) * size.x, sin(a) * size.y))
	draw_colored_polygon(points, color)


## An arc of the ellipse starting at the top, covering `ratio` of the way round.
func _draw_ellipse_arc(center: Vector2, size: Vector2, ratio: float, color: Color, width: float) -> void:
	if ratio <= 0.0:
		return
	var steps := maxi(int(32 * ratio), 2)
	var points := PackedVector2Array()
	for i in steps + 1:
		var a := -PI * 0.5 + TAU * ratio * float(i) / float(steps)
		points.append(center + Vector2(cos(a) * size.x, sin(a) * size.y))
	draw_polyline(points, color, width)
