extends CharacterBody2D

@export var projectile_speed = 250
@export var dmg = 4

var dir: float
var spawnPos: Vector2
var spawnRot: float

func _ready() -> void:
	global_position = spawnPos
	global_rotation = spawnRot

func _physics_process(_delta: float) -> void:
	velocity = Vector2.RIGHT.rotated(dir) * projectile_speed
	move_and_slide()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("take_hit"):
		var direction = (body.global_position - global_position).normalized()
		body.take_hit(direction, dmg)
	queue_free()
