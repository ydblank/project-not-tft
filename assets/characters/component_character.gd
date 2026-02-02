extends CharacterBody2D

@export var stats: StatsComponent


@export var move_speed: float = 100
@export var starting_direction: Vector2 = Vector2(0, 1)

@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")

var last_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	last_direction = starting_direction
	update_animation_parameters(starting_direction)

func _physics_process(_delta: float) -> void:
	var input_direction = Vector2(
		Input.get_action_strength("D") - Input.get_action_strength("A"),
		Input.get_action_strength("S") - Input.get_action_strength("W")
	)
		
	velocity = input_direction * move_speed
	if input_direction != Vector2.ZERO:
		last_direction = input_direction
			
	
	move_and_slide()
	
	var animation_direction = velocity.normalized() if velocity != Vector2.ZERO else last_direction
	update_animation_parameters(animation_direction)
	pick_new_state()

func update_animation_parameters(move_input: Vector2) -> void:
	if (move_input != Vector2.ZERO):
		animation_tree.set("parameters/Walk/blend_position", move_input)
		animation_tree.set("parameters/Idle/blend_position", move_input)	

func pick_new_state():
	if (velocity != Vector2.ZERO):
		state_machine.travel("Walk")
	else:
		state_machine.travel("Idle")
