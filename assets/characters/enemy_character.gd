extends CharacterBody2D

## Time the death animation plays before the body starts fading.
@export var death_linger: float = 0.8
@export var fade_time: float = 0.3


func _on_health_component_died() -> void:
	# The CombatComponent / AnimationComponent keep running so the death
	# animation plays; only the body stops blocking other characters.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	await get_tree().create_timer(death_linger).timeout
	if not is_inside_tree():
		return
	var sprite := get_node_or_null("Sprite2D") as CanvasItem
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, fade_time)
		await tween.finished
	queue_free()
