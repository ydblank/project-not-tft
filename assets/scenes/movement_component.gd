extends Node2D
class_name MovementComponent

# Physics executor only. CombatComponent decides the velocity every frame;
# this component owns the speed stats and moves the body.

@export var stats_component: StatsComponent
@export var entity: CharacterBody2D

var move_speed: float = 100.0
var dash_speed: float = 300.0
var velocity: Vector2 = Vector2.ZERO

var _last_good_position: Vector2 = Vector2.ZERO
var _reported: bool = false


func _ready() -> void:
	if entity == null:
		entity = owner as CharacterBody2D
	if entity == null:
		push_error("MovementComponent: entity must be a CharacterBody2D")
	else:
		_last_good_position = entity.global_position
	if stats_component:
		move_speed = float(stats_component.get_entity_stats().get("move_speed", move_speed))
		dash_speed = stats_component.dash_speed


func drive(desired_velocity: Vector2) -> void:
	if entity == null:
		return
	# Safety net: a single invalid (NaN / infinite) number would otherwise poison the
	# position, the camera and everything that reads them. Drop it and carry on.
	if not desired_velocity.is_finite():
		_report("velocity", desired_velocity)
		desired_velocity = Vector2.ZERO
	if not entity.global_position.is_finite():
		_report("position", entity.global_position)
		entity.global_position = _last_good_position
	entity.velocity = desired_velocity
	entity.move_and_slide()
	velocity = entity.velocity
	if entity.global_position.is_finite():
		_last_good_position = entity.global_position
	else:
		_report("position after move", entity.global_position)
		entity.global_position = _last_good_position
		velocity = Vector2.ZERO


func is_moving() -> bool:
	return velocity.length() > 0.0


## Logs the first invalid value per fighter so the source can be found.
func _report(what: String, value: Vector2) -> void:
	if _reported:
		return
	_reported = true
	push_warning("[NaN guard] %s: invalid %s = %s" % [entity.name if entity else name, what, value])
