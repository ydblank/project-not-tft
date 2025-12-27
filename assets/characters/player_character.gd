extends CharacterBody2D

@export var player_class_name: String = "knight"
@export var player_weapon_name: String = "sword"

@export var move_speed: float = 100
@export var starting_direction: Vector2 = Vector2(0, 1)
@export var team: int = 1
@export var lunge_distance: float = 10
@export var lunge_duration: float = 0.08

@onready var animation_player = $AnimationPlayer
@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var main = get_tree().get_root().get_node("Node2D")
@onready var arrow_projectile = load("res://assets/objects/arrow_projectile.tscn")

# preloads
const attack_effect_preload = preload("res://assets/effects/slash.tscn")
var classes_preload: ClassesDB = preload("res://assets/resources/classes.tres")
var weapons_preload: WeaponsDB = preload("res://assets/resources/weapons.tres")

var CombatClass = Combat

# global variables
var player_stats = {
	"move_speed": move_speed,
	"lunge_distance": lunge_distance,
	"lunge_duration": lunge_duration
}

var player_weapon

var last_direction: Vector2 = Vector2.ZERO
var _can_attack := true
var _is_attacking := false
var _attack_effect_spawned := false
var _attack_timer: Timer

var _lunge_velocity: Vector2 = Vector2.ZERO
var _lunge_time_left: float = 0.0

func _ready() -> void:
	ready_new_player()
	last_direction = starting_direction
	update_animation_parameters(starting_direction)

	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(_attack_timer)

func ready_new_player():
	player_stats = CombatClass.calculations.assign_player_stats(player_stats, classes_preload.classes[player_class_name])
	player_weapon_name = classes_preload.classes[player_class_name]["starting_weapon"]
	player_weapon = weapons_preload.weapons[player_weapon_name]

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
	_attack_timer.wait_time = _attack_anim_length_seconds(anim_name) / max(CombatClass.calculations.calculate_attack_speed(player_stats, player_weapon), 0.001)
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
		animation_tree.set("parameters/Attack/scale", player_stats.get("attack_speed", 1.0))
		animation_player.play(anim_name)


func _attack_anim_length_seconds(anim_name: StringName) -> float:
	var anim: Animation = animation_player.get_animation(anim_name)
	return anim.length


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
	
func spawn_attack_effect():
	var attack_effect = attack_effect_preload.instantiate()
	attack_effect.global_position = global_position
	# Match the existing slash effect behavior: it looks at the mouse on spawn.
	get_parent().add_child(attack_effect)
