extends Node2D

@export var float_distance: float = 24
@export var duration: float = 0.65
@export var spread_x: float = 0.0

@onready var label: Label = $Label

var _pending_amount: int = 0
var _pending_color: Color = Color(1, 1, 1, 1)
var _pending_world_position: Vector2 = Vector2.ZERO
var _has_pending_setup: bool = false
var _is_ready: bool = false

func setup(amount: int, world_position: Vector2, color: Color = Color(1, 1, 1, 1)) -> void:
	_pending_amount = amount
	_pending_world_position = world_position
	_pending_color = color
	_has_pending_setup = true
	_try_start()

func _try_start() -> void:
	if not _is_ready:
		return
	if not _has_pending_setup:
		return
	if label == null:
		queue_free()
		return

	global_position = _pending_world_position
	label.text = str(_pending_amount)
	label.modulate = _pending_color

	if spread_x != 0.0:
		global_position.x += randf_range(-spread_x, spread_x)

	label.modulate.a = 1.0

	var start_pos := global_position
	var end_pos := start_pos + Vector2(0, -float_distance)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", end_pos, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

func _ready() -> void:
	_is_ready = true
	_try_start()
