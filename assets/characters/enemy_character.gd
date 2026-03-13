extends CharacterBody2D


func _on_health_component_died() -> void:
	set_physics_process(false)
	set_process(false)
	
	await get_tree().create_timer(0.1).timeout
	call_deferred("queue_free")
