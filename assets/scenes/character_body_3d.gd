extends CharacterBody3D
@onready var sprite: Sprite3D = $Sprite3D

@export var speed := 0.5
@export var jump_velocity := 1.5

@export var acceleration := 18.0      # how fast you reach max speed
@export var deceleration := 22.0      # how fast you slow down when no input
@export var air_control := 6.0        # lower = heavier in air

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Input
	var input_dir := Input.get_vector("A", "D", "W", "S")
	var wish_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	if input_dir.x > 0.0:
		sprite.flip_h = false   # walking right
	elif input_dir.x < 0.0:
		sprite.flip_h = true    # walking left

	# Current horizontal velocity
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var target := wish_dir * speed

	if wish_dir != Vector3.ZERO:
		var accel := acceleration if is_on_floor() else air_control
		horiz = horiz.move_toward(target, accel * delta)
	else:
		var decel := deceleration if is_on_floor() else (deceleration * 0.2)
		horiz = horiz.move_toward(Vector3.ZERO, decel * delta)

	velocity.x = horiz.x
	velocity.z = horiz.z

	move_and_slide()


func _on_exit_trigger_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	call_deferred("_do_scene_change")

func _do_scene_change() -> void:
	get_tree().change_scene_to_file("res://assets/levels/node_2d.tscn")
