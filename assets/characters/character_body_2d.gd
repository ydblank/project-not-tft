extends CharacterBody2D

# Movement
const SPEED = 100.0
const DASH_SPEED = 200.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 0.8
const OUTER_TILE_SLOW_FACTOR = 0.5

# Melee attack
const ATTACK_HITBOX_TIME = 0.1
const ATTACK_RECOVERY = 0.1
const HIT_DAMAGE_HP = 5.0
const HIT_DAMAGE_PERCENT = 10.0

# Projectile attack
const PROJECTILE_COOLDOWN := 0.6
@onready var arrow_projectile = load("res://assets/objects/arrow_projectile.tscn")
var projectile_timer := 0.0

# Knockback
const BASE_KNOCKBACK = 200.0
const KNOCKBACK_DURATION = 0.3

# Outer tile damage
const OUTER_DAMAGE_INTERVAL := 0.25
const OUTER_DAMAGE_AMOUNT := 1.0

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state = anim_tree.get("parameters/playback")
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $AttackHitBox
@onready var tilemap: TileMap = $"../TileMap"

@onready var damage_label: Label = get_node("../CanvasLayer/DamageLabel")
@export var respawn_position: Vector2
@export var stocks: int = 3

var is_attacking: bool = false
var is_dead: bool = false
var last_direction: Vector2 = Vector2.DOWN
var dash_timer: float = 0.0
var dash_active: float = 0.0
var last_printed_second: int = -1
var knockback_timer: float = 0.0

var hp: float = 100.0
var damage_percent: float = 0.0
var outer_damage_timer: float = 0.0

func _ready() -> void:
	hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	hitbox.monitoring = false
	hitbox.monitorable = true
	_update_label()

	# Critical: set authority based on node name ("1", "2", ...)
	if name.is_valid_int():
		set_multiplayer_authority(int(name))

	print(name, "READY. Authority:", is_multiplayer_authority())

	# Remote players: no input, but still apply replicated state
	if not is_multiplayer_authority():
		set_process_input(false)
		set_physics_process(true)
		return

func _physics_process(delta: float) -> void:
	if is_dead or stocks <= 0:
		return

	# Projectile cooldown
	if projectile_timer > 0.0:
		projectile_timer -= delta

	# Outer tile damage cooldown tick
	if outer_damage_timer > 0.0:
		outer_damage_timer -= delta

	# Knockback overrides everything
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 1000 * delta)
		move_and_slide()
		_sync_state()
		return

	# Dash cooldown
	if dash_timer > 0.0:
		dash_timer -= delta

	# Dash active
	if dash_active > 0.0:
		dash_active -= delta
		velocity = last_direction.normalized() * DASH_SPEED
		move_and_slide()
		_sync_state()
		return

	# Melee attack
	if Input.is_action_just_pressed("attack_2") and not is_attacking:
		_start_attack()
		_sync_state()
		return

	# Ranged attack
	if Input.is_action_just_pressed("ranged_attack_2") and projectile_timer <= 0.0:
		_fire_projectile_networked()
		_sync_state()
		return

	# Dash input
	if Input.is_action_just_pressed("dash_2") and dash_timer <= 0.0:
		_cancel_attack_if_needed()
		_start_dash()
		dash_timer = DASH_COOLDOWN

	# If attacking, stop movement
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		_sync_state()
		return

	# Movement
	var input_vector = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()

	if input_vector != Vector2.ZERO:
		if input_vector.x != 0 and input_vector.y != 0:
			last_direction = Vector2(sign(input_vector.x), 0)
		else:
			last_direction = input_vector

	# Outer tile check
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
# Multiplayer sync
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
# Attack / animation
# ---------------------------

func _start_attack() -> void:
	is_attacking = true
	anim_state.travel("attack")
	anim_tree.set("parameters/attack/blend_position", last_direction)

	_update_hitbox_position()

	# Ensure the hitbox shape is enabled during the window
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

func _fire_projectile_networked() -> void:
	# Put ranged attack on cooldown
	projectile_timer = PROJECTILE_COOLDOWN

	# Play attack anim
	is_attacking = true
	anim_state.travel("attack")
	anim_tree.set("parameters/attack/blend_position", last_direction)

	# Spawn projectile halfway through the animation — spawn local, then broadcast
	await get_tree().create_timer(ATTACK_HITBOX_TIME).timeout
	# In _fire_projectile_networked()
	var spawn_pos = global_position + last_direction.normalized() * 20
	var ang = last_direction.angle()
	spawn_arrow(spawn_pos, ang)
	rpc_id(0, "spawn_arrow", spawn_pos, ang)


	# Recovery
	await get_tree().create_timer(ATTACK_RECOVERY).timeout
	is_attacking = false

@rpc("reliable", "any_peer", "call_local")
func spawn_arrow(spawn_pos: Vector2, angle: float) -> void:
	var instance = arrow_projectile.instantiate()

	# Place and orient directly
	instance.global_position = spawn_pos
	instance.rotation = angle

	# If the arrow scene has a setup API, use it
	if instance.has_method("setup"):
		# Pass shooter peer id so the arrow can set authority/ownership internally if needed
		instance.setup(spawn_pos, angle, int(name))

	# Add to a shared container to avoid viewport/parenting quirks
	var scene := get_tree().get_current_scene()
	var projectiles := scene.get_node_or_null("Projectiles")
	if projectiles == null:
		get_parent().add_child(instance)
	else:
		projectiles.add_child(instance)

func _cancel_attack_if_needed() -> void:
	if is_attacking:
		is_attacking = false

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
	# Only the authority applies damage; remote players just replicate results.
	if is_multiplayer_authority() and body.has_method("take_hit"):
		var direction = (body.global_position - global_position).normalized()
		body.take_hit(direction, HIT_DAMAGE_HP)

# ---------------------------
# Damage / death / respawn
# ---------------------------

func take_hit(direction: Vector2, hp_damage: float) -> void:
	hp -= hp_damage
	hp = max(hp, 0)

	damage_percent += HIT_DAMAGE_PERCENT
	var scaled_knockback = BASE_KNOCKBACK * (1.0 + damage_percent / 100.0)

	velocity = direction.normalized() * scaled_knockback
	knockback_timer = KNOCKBACK_DURATION

	_update_label()

	if hp <= 0:
		die()

func take_outer_damage(amount: float) -> void:
	hp -= amount
	hp = max(hp, 0)
	_update_label()
	if hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return

	is_dead = true
	visible = false
	velocity = Vector2.ZERO
	set_physics_process(false)

	stocks -= 1
	if stocks <= 0:
		return

	await get_tree().create_timer(3.0).timeout
	respawn()

func respawn() -> void:
	global_position = respawn_position
	hp = 100.0
	damage_percent = 0.0
	_update_label()
	visible = true
	is_dead = false
	set_physics_process(true)

func _update_label() -> void:
	if damage_label:
		damage_label.text = (
			"HP: " + str(int(hp)) +
			"   |   %: " + str(int(damage_percent)) +
			"   |   Stocks: " + str(stocks)
		)

func _start_dash() -> void:
	dash_active = DASH_DURATION
