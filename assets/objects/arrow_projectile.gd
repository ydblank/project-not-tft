extends CharacterBody2D

@export var projectile_speed: float = 250
@export var dmg: float = 4
var shooter: Node = null

func _ready() -> void:
	velocity = Vector2.RIGHT.rotated(rotation) * projectile_speed

func _physics_process(delta: float) -> void:
	var collision = move_and_collide(velocity * delta)
	if collision:
		var body = collision.get_collider()
		if body == shooter:
			return  # skip collision with shooter
		if body and body.has_method("take_hit"):
			var direction = (body.global_position - global_position).normalized()
			body.take_hit(direction, dmg)
		queue_free()
