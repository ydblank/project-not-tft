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


func setup(p_hit: HitData, p_shooter: Node2D) -> void:
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
		_finish()
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
	hit.direction = Vector2.RIGHT.rotated(rotation)
	if hurtbox.receive_hit(hit) != HitboxComponent.Result.IGNORED:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	queue_free()
