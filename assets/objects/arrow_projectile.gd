extends CharacterBody2D

@export var projectile_speed: float = 250
var weapon_damage: float = 1.0
var shooter: Node = null

@onready var area_2d: Area2D = $Area2D

func _ready() -> void:
	velocity = Vector2.RIGHT.rotated(rotation) * projectile_speed

func _physics_process(_delta: float) -> void:
	# Movement is handled by CharacterBody2D, but damage is triggered via Area2D overlap
	# to match how the melee slash works.
	move_and_slide()


func _can_hit_node(target: Node) -> bool:
	if target == null:
		return false
	if target == shooter:
		return false
	return true


func _apply_damage_to_target(target: Node) -> void:
	# Prefer the slash-style API (take_damage). Fallback to take_hit if present.
	if target.has_method("take_damage"):
		target.take_damage(weapon_damage)
		queue_free()
		return
	if target.has_method("take_hit"):
		var direction = (target.global_position - global_position).normalized()
		target.take_hit(direction, weapon_damage)
		queue_free()
		return


func _on_area_2d_body_entered(body: Node) -> void:
	if not _can_hit_node(body):
		return
	_apply_damage_to_target(body)


func _on_area_2d_area_entered(area: Area2D) -> void:
	# Mirrors slash.gd: it receives an Area2D and damages the area's parent.
	var target := area.get_parent()
	if not _can_hit_node(target):
		return
	_apply_damage_to_target(target)
