extends CharacterBody2D

@export var move_speed: float = 100
@export var starting_direction: Vector2 = Vector2(0, 1)
@export var hp: float = 20
@export var dmg: float = 4
@export var attack_speed: float = 1

@export var lunge_distance: float = 10
@export var lunge_duration: float = 0.08

@onready var animation_player = $AnimationPlayer
@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var main = get_tree().get_root().get_node("Node2D")
@onready var arrow_projectile = load("res://assets/objects/arrow_projectile.tscn")

const animation_attack_time := 0.6

var last_direction: Vector2 = Vector2.ZERO
var _can_attack := true
var _is_attacking := false
var _attack_effect_spawned := false
var _attack_timer: Timer

var _lunge_velocity: Vector2 = Vector2.ZERO
var _lunge_time_left: float = 0.0

func _ready() -> void:
	last_direction = starting_direction
	update_animation_parameters(starting_direction)

	_attack_timer = Timer.new()
	_attack_timer.wait_time = animation_attack_time / max(attack_speed, 0.001)
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(_attack_timer)

	animation_tree.set("parameters/Attack/scale", attack_speed)

func _physics_process(delta: float) -> void:
	var input_direction = Vector2(
		Input.get_action_strength("D") - Input.get_action_strength("A"),
		Input.get_action_strength("S") - Input.get_action_strength("W")
	)
	if _is_attacking:
		input_direction = Vector2.ZERO

	# Lunge overrides movement briefly.
	if _lunge_time_left > 0.0:
		_lunge_time_left = max(_lunge_time_left - delta, 0.0)
		velocity = _lunge_velocity
	else:
		_lunge_velocity = Vector2.ZERO
		velocity = Vector2.ZERO if _is_attacking else input_direction * move_speed
	
	move_and_slide()
	
	if Input.is_action_pressed("Primary") and _can_attack:
		_play_attack()

	# If we're in the middle of the attack animation, spawn the slash once.
	if _is_attacking and not _attack_effect_spawned:
		_attack_effect_spawned = true
		spawn_attack_effect()
	
	var animation_direction = velocity.normalized() if velocity != Vector2.ZERO else last_direction
	update_animation_parameters(animation_direction)
	pick_new_state()

func update_animation_parameters(move_input: Vector2) -> void:
	if (move_input != Vector2.ZERO):
		animation_tree.set("parameters/Walk/blend_position", move_input)
		animation_tree.set("parameters/Idle/blend_position", move_input)
		animation_tree.set("parameters/Attack/blend_position", move_input)
		

func pick_new_state():
	if _is_attacking:
		state_machine.travel("Attack")
	elif (velocity != Vector2.ZERO):
		state_machine.travel("Walk")
	else:
		state_machine.travel("Idle")

func _play_attack() -> void:
	_is_attacking = true
	_can_attack = false
	_attack_effect_spawned = false
	var attack_dir := _mouse_cardinal_direction()
	last_direction = attack_dir
	_start_lunge_toward_mouse()

	var anim_name := _attack_animation_name_for_dir(attack_dir)
	_play_attack_animation(anim_name)
	_attack_timer.wait_time = _attack_anim_length_seconds(anim_name) / max(attack_speed, 0.001)
	_attack_timer.start()


func _mouse_cardinal_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() <= 0.0001:
		return last_direction if last_direction != Vector2.ZERO else Vector2.DOWN

	# Decide cardinal direction by dominant axis.
	if abs(to_mouse.x) > abs(to_mouse.y):
		return Vector2.RIGHT if to_mouse.x > 0.0 else Vector2.LEFT
	else:
		return Vector2.DOWN if to_mouse.y > 0.0 else Vector2.UP


func _attack_animation_name_for_dir(dir: Vector2) -> StringName:
	if dir == Vector2.UP:
		return &"attack_up"
	if dir == Vector2.LEFT:
		return &"attack_left"
	if dir == Vector2.RIGHT:
		return &"attack_right"
	return &"attack_down"


func _play_attack_animation(anim_name: StringName) -> void:
	# If AnimationTree is driving body pose, keep it aimed the same way.
	update_animation_parameters(last_direction)

	if animation_player == null:
		return
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


func _attack_anim_length_seconds(anim_name: StringName) -> float:
	if animation_player == null:
		return animation_attack_time
	var anim: Animation = animation_player.get_animation(anim_name)
	return anim.length if anim != null else animation_attack_time


func _start_lunge_toward_mouse() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	var dir := to_mouse.normalized() if to_mouse.length_squared() > 0.0001 else last_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	last_direction = dir

	var dur: float = max(lunge_duration, 0.001)
	_lunge_velocity = dir * (lunge_distance / dur)
	_lunge_time_left = dur


func _on_attack_timer_timeout() -> void:
	_is_attacking = false
	_can_attack = true
	_attack_effect_spawned = false
	_lunge_time_left = 0.0
	
const attack_effect_preload = preload("res://assets/slash.tscn")
func spawn_attack_effect():
	var attack_effect = attack_effect_preload.instantiate()
	attack_effect.global_position = global_position
	# Match the existing slash effect behavior: it looks at the mouse on spawn.
	get_parent().add_child(attack_effect)
