extends CharacterBody2D

@onready var sync := $MultiplayerSync

# Movement
const SPEED = 100.0
const DASH_SPEED = 200.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.8
const OUTER_TILE_SLOW_FACTOR = 0.5

# Attack
const ATTACK_HITBOX_TIME = 0.1
const ATTACK_RECOVERY = 0.1

# Knockback
const BASE_KNOCKBACK = 200.0
const KNOCKBACK_DURATION = 0.3

# Hybrid system
const HIT_DAMAGE_HP = 5.0
const HIT_DAMAGE_PERCENT = 10.0
const MAX_HP = 100.0

# Outer tile damage over time
const OUTER_DAMAGE_INTERVAL := 0.25
const OUTER_DAMAGE_AMOUNT := 1.0

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $AttackHitBox
@onready var tilemap: TileMap = $"../TileMap"

@export var damage_label: Label
@export var respawn_position: Vector2
@export var stocks: int = 3

# ✅ Exported so MultiplayerSynchronizer can see them
@export var is_attacking: bool = false
@export var is_dead: bool = false
@export var last_direction: Vector2 = Vector2.DOWN
@export var dash_timer: float = 0.0
@export var dash_active: float = 0.0
@export var knockback_timer: float = 0.0
@export var hp: float = MAX_HP
@export var damage_percent: float = 0.0

var outer_damage_timer: float = 0.0
var last_printed_second: int = -1


func _ready() -> void:
	hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	hitbox.monitoring = false
	_update_label()

	# ✅ Non-authority players still need physics to interpolate
	if not is_multiplayer_authority():
		set_process_input(false)
		set_physics_process(true)
		return


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if is_dead or stocks <= 0:
		return

	# Outer tile damage cooldown tick
	if outer_damage_timer > 0.0:
		outer_damage_timer -= delta

	# Knockback overrides everything
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 1000 * delta)
		move_and_slide()
		return

	# Dash cooldown
	if dash_timer > 0.0:
		dash_timer -= delta
		var current_second = int(ceil(dash_timer))
		if current_second != last_printed_second:
			last_printed_second = current_second
			print("Dash cooldown:", current_second, "s")

	# Dash active
	if dash_active > 0.0:
		dash_active -= delta
		velocity = last_direction.normalized() * DASH_SPEED
		move_and_slide()
		return

	# Attack input
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_start_attack()
		return

	# Dash input
	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		_cancel_attack_if_needed()
		_start_dash()
		dash_timer = DASH_COOLDOWN
		last_printed_second = int(DASH_COOLDOWN)
		print("Dash triggered! Cooldown started:", DASH_COOLDOWN, "s")

	# If attacking, stop movement
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Movement input
	var input_vector = Vector2(
		Input.get_axis("A", "D"),
		Input.get_axis("W", "S")
	).normalized()

	if input_vector != Vector2.ZERO:
		if input_vector.x != 0 and input_vector.y != 0:
			last_direction = Vector2(sign(input_vector.x), 0)
		else:
			last_direction = input_vector

	# ✅ OUTER TILE CHECK
	var tile_pos = tilemap.local_to_map(global_position)
	var atlas_coords = tilemap.get_cell_atlas_coords(0, tile_pos)

	var current_speed = SPEED

	if atlas_coords == Vector2i(15, 2):
		if outer_damage_timer <= 0.0:
			take_outer_damage(OUTER_DAMAGE_AMOUNT)
			outer_damage_timer = OUTER_DAMAGE_INTERVAL

		current_speed = SPEED * OUTER_TILE_SLOW_FACTOR
	else:
		outer_damage_timer = 0.0

	velocity = input_vector * current_speed
	move_and_slide()

	_update_anim(input_vector)


func _start_attack() -> void:
	is_attacking = true
	anim_state.travel("attack")
	anim_tree.set("parameters/attack/blend_position", last_direction)

	_update_hitbox_position()
	hitbox.set_deferred("monitoring", true)
	await get_tree().create_timer(ATTACK_HITBOX_TIME).timeout
	hitbox.set_deferred("monitoring", false)

	await get_tree().create_timer(ATTACK_RECOVERY).timeout
	is_attacking = false


func _cancel_attack_if_needed() -> void:
	if is_attacking:
		is_attacking = false
		print("Attack cancelled by dash!")


func _update_anim(input_vector: Vector2) -> void:
	if is_attacking:
		return

	if input_vector == Vector2.ZERO:
		anim_state.travel("idle")
	else:
		anim_state.travel("walk")

	anim_tree.set("parameters/walk/blend_position", last_direction)
	anim_tree.set("parameters/idle/blend_position", last_direction)


func _update_hitbox_position() -> void:
	if last_direction.x < 0:
		hitbox.position = Vector2(-6, -4)
	elif last_direction.x > 0:
		hitbox.position = Vector2(6, -4)
	elif last_direction.y < 0:
		hitbox.position = Vector2(0, -12)
	elif last_direction.y > 0:
		hitbox.position = Vector2(0, 7)


func _on_hitbox_body_entered(body: Node) -> void:
	print("Hitbox triggered by:", body.name)
	if body.has_method("take_hit"):
		var direction = (body.global_position - global_position).normalized()
		body.take_hit(direction, HIT_DAMAGE_HP)


func take_hit(direction: Vector2, hp_damage: float) -> void:
	hp -= hp_damage
	hp = max(hp, 0)

	damage_percent += HIT_DAMAGE_PERCENT

	var scaled_knockback = BASE_KNOCKBACK * (1.0 + damage_percent / 100.0)

	velocity = direction.normalized() * scaled_knockback
	knockback_timer = KNOCKBACK_DURATION

	_update_label()

	if hp <= 0 and not is_dead:
		die()

	print(name, "took hit | HP:", hp, "| %:", damage_percent, "| KB:", scaled_knockback)


func take_outer_damage(amount: float) -> void:
	hp -= amount
	hp = max(hp, 0)

	_update_label()

	if hp <= 0 and not is_dead:
		die()

	print(name, "took OUTER TILE damage | HP:", hp)


func die() -> void:
	is_dead = true
	visible = false
	velocity = Vector2.ZERO
	set_physics_process(false)

	stocks -= 1
	print(name, "lost a stock! Remaining:", stocks)

	if stocks <= 0:
		print(name, "is OUT OF STOCKS — GAME OVER")
		return

	print(name, "has died. Respawning in 3 seconds...")
	await get_tree().create_timer(3.0).timeout
	respawn()


func respawn() -> void:
	global_position = respawn_position

	hp = MAX_HP
	damage_percent = 0.0
	_update_label()

	visible = true
	is_dead = false
	set_physics_process(true)

	print(name, "has respawned!")


func _update_label() -> void:
	if damage_label:
		damage_label.text = "HP: " + str(int(hp)) \
		+ "  |  %: " + str(int(damage_percent)) \
		+ "  |  Stocks: " + str(stocks)


func _start_dash() -> void:
	dash_active = DASH_DURATION
