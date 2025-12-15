extends CharacterBody2D

@export var move_speed: float = 100
@export var starting_direction: Vector2 = Vector2(0, 1)
@export var hp: float = 20
@export var dmg: float = 4
@export var attack_speed: float = 1

@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var main = get_tree().get_root().get_node("Node2D")
@onready var arrow_projectile = load("res://assets/objects/arrow_projectile.tscn")

const animation_attack_time = 0.6

var last_direction: Vector2 = Vector2.ZERO
var is_attacking: bool = false
var is_shooting_projectile: bool = false
var attack_timer: Timer

func _ready() -> void:
	last_direction = starting_direction
	update_animation_parameters(starting_direction)
	
	attack_timer = Timer.new()
	attack_timer.wait_time = animation_attack_time / attack_speed
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)
	
	animation_tree.set("parameters/Attack/scale", attack_speed)

func _physics_process(_delta: float) -> void:
	if not is_attacking:
		var input_direction = Vector2(
			Input.get_action_strength("right") - Input.get_action_strength("left"),
			Input.get_action_strength("down") - Input.get_action_strength("up")
		)
		
		if Input.is_action_just_pressed("attack"):
			is_attacking = true
			velocity = Vector2.ZERO
			attack_timer.start()
		else:
			velocity = input_direction * move_speed
			if input_direction != Vector2.ZERO:
				last_direction = input_direction
	else:
		velocity = Vector2.ZERO
		var time_remaining = attack_timer.time_left
		var cooldown_progress = 1.0 - (time_remaining / attack_timer.wait_time)
		
		if cooldown_progress >= 0.5 && !is_shooting_projectile:
			attack_action()
	
	move_and_slide()
	
	var animation_direction = velocity.normalized() if velocity != Vector2.ZERO else last_direction
	update_animation_parameters(animation_direction)
	pick_new_state()

func update_animation_parameters(move_input: Vector2) -> void:
	if (move_input != Vector2.ZERO):
		animation_tree.set("parameters/Walk/blend_position", move_input)
		animation_tree.set("parameters/Idle/blend_position", move_input)
		animation_tree.set("parameters/Attack/blend_position", move_input)
		

func pick_new_state():
	if is_attacking:
		state_machine.travel("Attack")
	elif (velocity != Vector2.ZERO):
		state_machine.travel("Walk")
	else:
		state_machine.travel("Idle")

func _on_attack_timer_timeout() -> void:
	is_attacking = false
	is_shooting_projectile = false

func attack_action() -> void:
	is_shooting_projectile = true
	var bow_position = Vector2(global_position.x, global_position.y - 5)
	var instance = arrow_projectile.instantiate()
	instance.dir = last_direction.angle()
	instance.spawnPos = bow_position
	instance.spawnRot = last_direction.angle()
	main.add_child.call_deferred(instance)
