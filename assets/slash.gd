extends Node2D

@export var slash_effect = "slash_2"

var weapon_damage: float = 1.0

func _ready():
	look_at(get_global_mouse_position())
	$AnimationPlayer.play(slash_effect)

func _on_area_2d_body_entered(body: Node2D) -> void:
	pass
	#body.take_damage(weapon_damage)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == slash_effect:
		queue_free()
