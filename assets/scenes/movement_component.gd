extends Node2D
class_name MovementComponent

# Physics executor only. CombatComponent decides the velocity every frame;
# this component owns the speed stats and moves the body.

@export var stats_component: StatsComponent
@export var entity: CharacterBody2D

var move_speed: float = 100.0
var dash_speed: float = 300.0
var velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	if entity == null:
		entity = owner as CharacterBody2D
	if entity == null:
		push_error("MovementComponent: entity must be a CharacterBody2D")
	if stats_component:
		move_speed = float(stats_component.get_entity_stats().get("move_speed", move_speed))
		dash_speed = stats_component.dash_speed


func drive(desired_velocity: Vector2) -> void:
	if entity == null:
		return
	entity.velocity = desired_velocity
	entity.move_and_slide()
	velocity = entity.velocity


func is_moving() -> bool:
	return velocity.length() > 0.0
