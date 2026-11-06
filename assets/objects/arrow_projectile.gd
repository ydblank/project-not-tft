extends Area2D
class_name ArrowProjectile

# Carries one HitData. Delivers it to the first enemy hurtbox it touches and
# is removed by walls or after `lifetime`.

@export var projectile_speed: float = 250.0
@export var lifetime: float = 2.0
## Physics layers that stop the arrow (walls / tiles).
@export_flags_2d_physics var wall_mask: int = 3

var hit: HitData = null
var shooter: Node2D = null
var _done: bool = false

## `_charge_mult` is the heavy charge multiplier; plain arrows ignore it, subclasses (fireball) size themselves by it.
func setup(p_hit: HitData, p_shooter: Node2D, _charge_mult: float = 1.0) -> void:
	hit = p_hit
	shooter = p_shooter

func _ready() -> void:
	add_to_group("projectiles") # lets the AI see incoming arrows
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(lifetime, false).timeout.connect(_finish)

func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := Vector2.RIGHT.rotated(rotation) * projectile_speed * delta
	if _hits_wall(global_position, global_position + step):
		_on_wall_hit()
		return
	global_position += step

# Ray along this frame's movement; characters are skipped (their hurtbox
# handles hits), anything else stops the arrow. Also prevents tunnelling.
func _hits_wall(from: Vector2, to: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, wall_mask)
	var excluded: Array[RID] = []
	for i in 4:
		query.exclude = excluded
		var result := space.intersect_ray(query)
		if result.is_empty():
			return false
		if result.collider is CharacterBody2D:
			excluded.append(result.rid)
			continue
		return true
	return false

func _on_area_entered(area: Area2D) -> void:
	if _done or hit == null:
		return
	var hurtbox := area as HitboxComponent
	if hurtbox == null or hurtbox.get_entity() == shooter:
		return
	# Fighters that are already staggered or flying back: the arrow flies on through them (no machine-gunning a stunned target).
	var target_combat := CombatComponent.find_on(hurtbox.get_entity())
	if target_combat:
		var target_state := target_combat.get_state()
		if target_state == ActionStateMachine.State.STAGGER or target_state == ActionStateMachine.State.KNOCKBACK:
			return
	hit.direction = Vector2.RIGHT.rotated(rotation)
	match hurtbox.receive_hit(hit):
		HitboxComponent.Result.HIT:
			_on_target_hit(hurtbox)
			_finish()
		HitboxComponent.Result.BLOCKED:
			_break_apart() # a blocked arrow snaps and drops instead of vanishing
		HitboxComponent.Result.PARRIED:
			_reflect(hurtbox.get_entity(), hurtbox.team)

## Called when the projectile runs into a wall. Subclasses can do more than vanish (the fireball explodes).
func _on_wall_hit() -> void:
	_finish()


## Called after a hit lands, just before the projectile ends. For subclass effects.
func _on_target_hit(_hurtbox: HitboxComponent) -> void:
	pass


func _finish() -> void:
	if _done:
		return
	_done = true
	queue_free()

## A parried arrow turns around and flies back at its shooter, a bit faster and harder.
func _reflect(parrier: Node2D, parrier_team: int) -> void:
	if parrier == null or hit == null:
		return
	rotation += PI
	projectile_speed *= 1.3
	hit.team = parrier_team
	hit.attacker = parrier
	hit.damage *= 1.5
	shooter = parrier
	lifetime = 2.0
	get_tree().create_timer(lifetime, false).timeout.connect(_finish)
	HitFX.parry(self, global_position, Vector2.RIGHT.rotated(rotation))

## The arrow snaps in two; the halves tumble away and fade.
func _break_apart() -> void:
	if _done:
		return
	var parent := get_parent()
	var forward := Vector2.RIGHT.rotated(rotation)
	if parent:
		for i in 2:
			var half := Line2D.new()
			half.points = PackedVector2Array([Vector2.ZERO, -forward * 5.0 if i == 0 else forward * 5.0])
			half.width = 1.5
			half.default_color = Color(0.75, 0.6, 0.4)
			half.z_index = 5
			parent.add_child(half)
			half.global_position = global_position
			var drift := forward.orthogonal() * (14.0 if i == 0 else -14.0) - forward * 8.0
			var tween := half.create_tween().set_parallel(true)
			tween.tween_property(half, "global_position", global_position + drift, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(half, "rotation", randf_range(-2.0, 2.0), 0.4)
			tween.tween_property(half, "modulate:a", 0.0, 0.4)
			tween.chain().tween_callback(half.queue_free)
	_finish()
