extends RefCounted
class_name HitFX

# Fire-and-forget combat visuals: blood puffs, block sparks and dash afterimages.
# Everything is added to the current scene and frees itself.

const BLOOD_TEXTURE: Texture2D = preload("res://assets/art/1 Characters/Other/S_Blood.png")
const BLOOD_FRAMES := 4
const BLOOD_TIME := 0.28

const COLOR_BLOOD := Color(0.75, 0.08, 0.1)
const COLOR_SPARK := Color(1.0, 0.92, 0.55)
const COLOR_STONE := Color(0.7, 0.75, 0.88)


## Blood splat + droplets thrown along dir (attacker -> victim).
static func blood(host: Node, pos: Vector2, dir: Vector2, heavy: bool) -> void:
	var root := _root(host)
	if root == null:
		return
	dir = _safe_dir(dir)
	var splat := Sprite2D.new()
	splat.texture = BLOOD_TEXTURE
	splat.hframes = BLOOD_FRAMES
	splat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	splat.z_index = 5
	splat.global_position = pos
	splat.rotation = dir.angle()
	splat.scale = Vector2.ONE * (1.4 if heavy else 0.9)
	root.add_child(splat)
	var tween := splat.create_tween()
	tween.tween_property(splat, "frame", BLOOD_FRAMES - 1, BLOOD_TIME).from(0)
	tween.tween_callback(splat.queue_free)
	_burst(root, pos, dir, COLOR_BLOOD, 10 if heavy else 5, 90.0 if heavy else 60.0, 45.0)


## Sparks for blocked hits and hits on non-living targets.
static func sparks(host: Node, pos: Vector2, dir: Vector2, heavy: bool) -> void:
	var root := _root(host)
	if root == null:
		return
	# Sparks fly back toward the attacker, off the shield.
	_burst(root, pos, -_safe_dir(dir), COLOR_SPARK, 12 if heavy else 7, 110.0, 70.0)


## Stone chips thrown back off a wall a projectile just hit. `normal` points out of the wall.
static func wall_chips(host: Node, pos: Vector2, normal: Vector2) -> void:
	var root := _root(host)
	if root == null:
		return
	var out := _safe_dir(normal)
	_burst(root, pos, out, COLOR_STONE, 8, 70.0, 60.0)
	_burst(root, pos, out, COLOR_SPARK, 4, 100.0, 40.0)


## A weapon or projectile hit a wall: stone chips plus a low thump layered with a stone hit. olume_db is relative to the SFX bus.
static func wall_impact(host: Node, pos: Vector2, normal: Vector2, volume_db: float) -> void:
	wall_chips(host, pos, normal)
	Sfx.play(&"wall_hit", volume_db, 0.8)
	Sfx.play(&"wall_stone", volume_db - 4.0, 1.0)


## A fading copy of the sprite, left behind while dashing. Drawn under the fighter.
static func afterimage(sprite: Sprite2D, tint: Color, life: float = 0.25) -> void:
	if sprite == null or not sprite.is_inside_tree():
		return
	var entity := sprite.get_parent()
	var parent := entity.get_parent() if entity else null
	if parent == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.offset = sprite.offset
	ghost.texture_filter = sprite.texture_filter
	ghost.material = sprite.material
	ghost.global_position = sprite.global_position
	ghost.global_scale = sprite.global_scale
	ghost.modulate = tint
	parent.add_child(ghost)
	parent.move_child(ghost, entity.get_index()) # just under the fighter
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, life)
	tween.tween_callback(ghost.queue_free)


static func _burst(root: Node, pos: Vector2, dir: Vector2, color: Color, amount: int, speed: float, spread: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.3
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 120.0
	p.damping_max = 200.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.z_index = 6
	p.global_position = pos
	root.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _root(host: Node) -> Node:
	if host == null or not host.is_inside_tree():
		return null
	return host.get_tree().current_scene


static func _safe_dir(dir: Vector2) -> Vector2:
	return dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT


## Shield shatter: a ring of blue / white shards flying out in every direction.
static func shatter(host: Node, pos: Vector2) -> void:
	var root := _root(host)
	if root == null:
		return
	_burst(root, pos, Vector2.UP, Color(0.55, 0.8, 1.0), 16, 140.0, 180.0)
	_burst(root, pos, Vector2.UP, Color(1, 1, 1), 10, 90.0, 180.0)


const COLOR_PARRY := Color(1.0, 0.85, 0.25)
const COLOR_CLASH := Color(1.0, 0.95, 0.8)
const COLOR_FINISHER := Color(1.0, 0.55, 0.3)


## Gold flash for a perfect block: sparks and a quick ring.
static func parry(host: Node, pos: Vector2, dir: Vector2) -> void:
	var root := _root(host)
	if root == null:
		return
	_burst(root, pos, -_safe_dir(dir), COLOR_PARRY, 16, 150.0, 80.0)
	_ring(root, pos, COLOR_PARRY, 20.0, 0.22, 2.0)


## Two swings meeting: a white burst in every direction and an expanding ring.
static func clash(host: Node, pos: Vector2) -> void:
	var root := _root(host)
	if root == null:
		return
	_burst(root, pos, Vector2.UP, COLOR_CLASH, 22, 170.0, 180.0)
	_burst(root, pos, Vector2.UP, Color(1.0, 0.6, 0.25), 10, 110.0, 180.0)
	_ring(root, pos, COLOR_CLASH, 26.0, 0.25, 2.5)


## Hit-confirm for the last hit of a combo or a heavy: a bigger ring, a streak along the hit and a hot burst.
static func finisher(host: Node, pos: Vector2, dir: Vector2) -> void:
	var root := _root(host)
	if root == null:
		return
	dir = _safe_dir(dir)
	_ring(root, pos, COLOR_FINISHER, 30.0, 0.3, 3.0)
	_burst(root, pos, dir, COLOR_FINISHER, 18, 190.0, 55.0)
	_burst(root, pos, dir, Color(1, 1, 1), 8, 230.0, 25.0)
	var streak := Line2D.new()
	streak.points = PackedVector2Array([-dir * 6.0, dir * 40.0])
	streak.width = 3.0
	streak.default_color = Color(1, 0.9, 0.7)
	streak.global_position = pos
	streak.z_index = 6
	root.add_child(streak)
	var tween := streak.create_tween().set_parallel(true)
	tween.tween_property(streak, "modulate:a", 0.0, 0.18)
	tween.tween_property(streak, "width", 0.5, 0.18)
	tween.chain().tween_callback(streak.queue_free)


## An expanding, fading circle.
static func _ring(root: Node, pos: Vector2, color: Color, radius: float, time: float, width: float) -> void:
	var ring := Line2D.new()
	var points := PackedVector2Array()
	for i in 33:
		points.append(Vector2.RIGHT.rotated(TAU * i / 32.0) * radius * 0.5)
	ring.points = points
	ring.width = width
	ring.default_color = color
	ring.global_position = pos
	ring.z_index = 6
	root.add_child(ring)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(2.2, 2.2), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, time)
	tween.chain().tween_callback(ring.queue_free)
