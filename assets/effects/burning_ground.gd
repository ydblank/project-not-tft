extends Node2D
class_name BurningGround

# Fire left on the ground by the Mage's Inferno skill. Every `tick` seconds it burns every
# fighter of another team standing inside it: an unblockable damage-over-time hit that also
# staggers them briefly, every tick. It fades out after `duration`.
#
# Looks: a scorched patch, animated flames (Ground_Fire.png, made by
# tools/make_ground_fire_sprites.gd) scattered over it, each on its own frame so they flicker
# out of step, and a rim in the team colour (blue for your side, red for the enemy).
# Bots treat it as a danger zone and walk out of it (group "danger_zones", see danger_at()).

const HURTBOX_MASK := 2
const FLAME_TEXTURE: Texture2D = preload("res://assets/art/1 Characters/Other/Ground_Fire.png")
const FLAME_FRAMES := 8
const FLAME_FPS := 12.0
## Flames per square pixel of area (a 56 px radius gets about 30).
const FLAME_DENSITY := 0.003
const FLAME_MIN_SCALE := 0.55
const FLAME_MAX_SCALE := 1.0
## Flames grow in over this long at the start and die down over FADE_TIME at the end.
const GROW_TIME := 0.25
const FADE_TIME := 0.4
const SCORCH := Color(0.25, 0.08, 0.04, 0.45)
const GLOW := Color(1.0, 0.45, 0.1, 0.18)
const SIZZLE_DB := -16.0

var radius: float = 56.0
var duration: float = 3.0
var tick: float = 0.5
var damage_per_tick: float = 1.0
## Stagger applied by each burn tick (0 = none).
var stagger_time: float = 0.25
var team: int = -1
var attacker: Node2D = null

var _age: float = 0.0
var _tick_left: float = 0.0
var _rim_color: Color = Color(1, 0.3, 0.2)
var _flames: Array[Sprite2D] = []
var _flame_phase: Array[float] = []
var _flame_scale: Array[float] = []


## Creates burning ground for `skill` at `pos` under `parent`.
static func spawn(parent: Node, pos: Vector2, skill: SkillData, p_attacker: Node2D, p_team: int, p_damage_per_tick: float) -> BurningGround:
	if parent == null or skill == null:
		return null
	var ground := BurningGround.new()
	ground.radius = skill.burn_radius()
	ground.duration = skill.dot_duration
	ground.tick = maxf(skill.dot_tick, 0.05)
	ground.damage_per_tick = p_damage_per_tick
	ground.stagger_time = skill.dot_stagger_time
	ground.team = p_team
	ground.attacker = p_attacker
	parent.add_child(ground)
	ground.global_position = pos
	return ground


func _ready() -> void:
	z_index = 1 # like the shrinking zone: over the floor and the fighters standing in it
	y_sort_enabled = true # flames further down overlap the ones behind them
	add_to_group("danger_zones")
	_tick_left = tick
	_rim_color = SkillMarker.color_for_team(get_tree(), team)
	_scatter_flames()


## True when `point` is inside this fire and it can hurt a fighter of `for_team`.
func danger_at(point: Vector2, for_team: int) -> bool:
	return for_team != team and _age < duration and global_position.distance_to(point) <= radius



func _scatter_flames() -> void:
	var count := maxi(int(PI * radius * radius * FLAME_DENSITY), 6)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		# Even spread over the disc (sunflower pattern) with a little jitter.
		var r := radius * 0.92 * sqrt((i + 0.5) / count)
		var a := i * 2.39996 + rng.randf_range(-0.3, 0.3)
		var flame := Sprite2D.new()
		flame.texture = FLAME_TEXTURE
		flame.hframes = FLAME_FRAMES
		flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flame.offset = Vector2(0, -FLAME_TEXTURE.get_height() * 0.5) # the foot sits on the ground
		flame.position = Vector2.from_angle(a) * r
		flame.flip_h = rng.randf() < 0.5
		add_child(flame)
		_flames.append(flame)
		_flame_phase.append(rng.randf() * FLAME_FRAMES)
		_flame_scale.append(rng.randf_range(FLAME_MIN_SCALE, FLAME_MAX_SCALE) * (1.0 - 0.3 * r / radius))
	_update_flames()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration + FADE_TIME:
		queue_free()
		return
	if _age < duration:
		_tick_left -= delta
		if _tick_left <= 0.0:
			_tick_left += tick
			_burn()
	_update_flames()
	queue_redraw()


func _update_flames() -> void:
	var grow := clampf(_age / GROW_TIME, 0.0, 1.0)
	var fade := 1.0 - clampf((_age - duration) / FADE_TIME, 0.0, 1.0)
	var size := ease(grow, 0.5) * fade
	for i in _flames.size():
		var flame := _flames[i]
		flame.frame = int(_flame_phase[i] + _age * FLAME_FPS) % FLAME_FRAMES
		flame.scale = Vector2(_flame_scale[i], _flame_scale[i] * size)
		flame.modulate.a = fade


func _burn() -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var burned: Array[Node2D] = []
	for result in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox := result.collider as HitboxComponent
		if hurtbox == null or hurtbox.is_same_team(team) or burned.has(hurtbox.get_entity()):
			continue
		burned.append(hurtbox.get_entity())
		var hit := HitData.new()
		hit.attacker = attacker if is_instance_valid(attacker) else null
		hit.team = team
		hit.damage = damage_per_tick
		hit.direction = (hurtbox.global_position - global_position).normalized()
		hit.is_dot = true
		hit.is_ranged = true
		hit.reaction = AttackMove.Reaction.STAGGER
		hit.stagger_time = stagger_time
		hurtbox.receive_hit(hit)
	if not burned.is_empty():
		Sfx.play(&"burn", SIZZLE_DB, 0.5, 0.08)


func _draw() -> void:
	var fade := 1.0 - clampf((_age - duration) / FADE_TIME, 0.0, 1.0)
	var grow := clampf(_age / GROW_TIME, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * ease(grow, 0.4), Color(SCORCH, SCORCH.a * fade))
	var glow := GLOW
	glow.a *= fade * (0.8 + 0.2 * sin(_age * 9.0))
	draw_circle(Vector2.ZERO, radius * 0.75, glow)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(_rim_color, 0.8 * fade), 1.5)


## Way out of the fire from `point` (unit vector, away from the centre).
func danger_escape(point: Vector2) -> Vector2:
	var off := point - global_position
	return off.normalized() if off.length() > 0.5 else Vector2.RIGHT


## Lingering fire: walk out, no need to burn a dash on it.
func danger_is_incoming() -> bool:
	return false
