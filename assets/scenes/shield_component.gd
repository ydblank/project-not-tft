extends Node2D

@export var offset_distance: float = 17.0
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $HitboxComponent
@onready var hitbox_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D

var is_active: bool = false

func _ready() -> void:
	visible = false
	if hitbox:
		hitbox.monitoring = false

func activate_shield(player: Node2D) -> void:
	is_active = true
	visible = true
	if hitbox:
		hitbox.monitoring = true
	_update_position(player)

func deactivate_shield() -> void:
	is_active = false
	visible = false
	if hitbox:
		hitbox.monitoring = false

func _process(_delta: float) -> void:
	if not is_active:
		return
	var player := get_parent() as Node2D
	if player:
		_update_position(player)

func _update_position(player: Node2D) -> void:
	var dir := (get_global_mouse_position() - player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	position = dir * offset_distance
	rotation = dir.angle()
