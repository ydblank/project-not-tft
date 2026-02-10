extends CharacterBody2D

#@export var stats: StatsComponent
#
#
#@export var move_speed: float = 100
#@export var starting_direction: Vector2 = Vector2(0, 1)
#
#@onready var animation_tree = $AnimationTree
#@onready var state_machine = animation_tree.get("parameters/playback")
#
#var last_direction: Vector2 = Vector2.ZERO
#
#func _ready() -> void:
	#last_direction = starting_direction
#
#func _physics_process(_delta: float) -> void:
	#var input_direction = Vector2(
		#Input.get_action_strength("D") - Input.get_action_strength("A"),
		#Input.get_action_strength("S") - Input.get_action_strength("W")
	#)
		#
	#velocity = input_direction * move_speed
			#
	#
	#move_and_slide()
