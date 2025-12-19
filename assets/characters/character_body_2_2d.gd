extends CharacterBody2D

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

@onready var damage_label: Label = get_node("../CanvasLayer/DamageLabel2")
@export var respawn_position: Vector2
@export var stocks: int = 3

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
	hitbox.monitorable = true
	_update_label()

	if name.is_valid_int():
		set_multiplayer_authority(int(name))

	print(name, "READY. Authority:", is_multiplayer_authority())

	if not is_multiplayer_authority():
		set_process_input(false)
		set_physics_process(true)
		return

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if is_dead or stocks <= 0:
		return

	if outer_damage_timer > 0.0:
		outer_damage_timer -= delta

	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 1000 * delta)
		move_and_slide()
		_sync_state()
		return

	if dash_timer > 0.0:
		dash_timer -= delta
		var current_second = int(ceil(dash_timer))
		if current_second != last_printed_second:
			last_printed_second = current_second
			print("Dash cooldown:", current_second, "s")

	if dash_active > 0.0:
		dash_active -= delta
		velocity = last_direction.normalized() * DASH_SPEED
		move_and_slide()
		_sync_state()
		return

	if Input.is_action_just_pressed("attack") and not is_attacking:
		_start_attack()
		_sync_state()
		return

	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0:
		_cancel_attack_if_needed()
		_start_dash()
		dash_timer = DASH_COOLDOWN
		last_printed_second = int(DASH_COOLDOWN)
		print("Dash triggered! Cooldown started:", DASH_COOLDOWN, "s")

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		_sync_state()
		return

	var input_vector = Vector2(
		Input.get_axis("A", "D"),
		Input.get_axis("W", "S")
	).normalized()

	if input_vector != Vector2.ZERO:
		if input_vector.x != 0 and input_vector.y != 0:
			last_direction = Vector2(sign(input_vector.x), 0)
		else:
			last_direction = input_vector

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
	_sync_state()

# ---------------------------
# MULTIPLAYER SYNC
# ---------------------------

func _sync_state() -> void:
	if not is_multiplayer_authority():
		return
	var mp := multiplayer.multiplayer_peer
	if mp == null or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	rpc(
		"sync_remote_state",
		global_position,
		velocity,
		last_direction,
		hp,
		damage_percent,
		is_attacking,
		is_dead,
		stocks
	)

@rpc("unreliable", "any_peer")
func sync_remote_state(
	pos: Vector2,
	vel: Vector2,
	dir: Vector2,
	remote_hp: float,
	remote_damage_percent: float,
	remote_is_attacking: bool,
	remote_is_dead: bool,
	remote_stocks: int
) -> void:
	if is_multiplayer_authority():
		return

	global_position = pos
	velocity = vel
	last_direction = dir
	hp = remote_hp
	damage_percent = remote_damage_percent
	is_attacking = remote_is_attacking
	is_dead = remote_is_dead
	stocks = remote_stocks

	_update_label()

	if is_dead or stocks <= 0:
		visible = false
		set_physics_process(false)
	else:
		visible = true
		set_physics_process(true)

# ---------------------------
# ATTACK / ANIMATION
# ---------------------------

func _start_attack() -> void:
	is_attacking = true
	anim_state.travel("attack")
	anim_tree.set("parameters/attack/blend_position", last_direction)

	_update_hitbox_position()

	var shape := hitbox.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = false

	hitbox.set_deferred("monitoring", true)
	await get_tree().create_timer(ATTACK_HITBOX_TIME).timeout
	hitbox.set_deferred("monitoring", false)

	if shape:
		shape.disabled = true

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
	if not is_multiplayer_authority():
		return

	print("Hitbox triggered with:", body.name)
	if body.has_method("take_hit"):
		var direction = (body.global_position - global_position).normalized()
		rpc_id(0, "apply_hit", int(body.name), direction, HIT_DAMAGE_HP)

@rpc("reliable", "any_peer")
func apply_hit(target_id: int, direction: Vector2, damage: float) -> void:
	var target := get_tree().get_current_scene().get_node_or_null(str(target_id))
	if target and target.has_method("take_hit"):
		target.take_hit(direction, damage)

# ---------------------------
# DAMAGE / DEATH / RESPAWN
# ---------------------------

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
