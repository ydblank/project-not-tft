extends Node2D
class_name SlashEffect

# Visual only. Damage is resolved by CombatComponent's AttackHitbox.

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D


## angle: aim angle in radians. The animations set the sprite's own
## rotation / flip_v, so only the root is rotated toward the aim.
func play(animation: StringName, angle: float, vfx_scale: float = 1.0, _is_heavy: bool = false) -> void:
	rotation = angle
	scale = Vector2.ONE * vfx_scale
	sprite.flip_h = true
	if animation_player.has_animation(animation):
		animation_player.play(animation)
	else:
		animation_player.play(&"slash")


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	queue_free()
