extends Node2D

@export var slash_effect = "slash"
@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D

var weapon_damage: float = 1.0

func _ready():
	var mouse_position = get_global_mouse_position()
	look_at(mouse_position)
	
	if mouse_position.x > global_position.x:
		sprite.rotation = 45.0
		sprite.flip_h = true
	else:
		sprite.rotation = 90.0
		sprite.flip_h = false
	
	animation_player.play(slash_effect)

#func _on_area_2d_body_entered(body: Node2D) -> void:
	#pass
	##body.take_damage(weapon_damage)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == slash_effect:
		queue_free()
