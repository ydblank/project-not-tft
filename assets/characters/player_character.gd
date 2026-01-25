extends CharacterBody2D

@export var player_class_name: String = "knight"
@export var player_weapon_name: String = "sword"

@export var move_speed: float = 100.0
@export var starting_direction: Vector2 = Vector2(0, 1)
@export var team: int = 1
@export var respawn_position: Vector2 = Vector2.ZERO
@export var stocks: int = 3
@export var respawn_delay: float = 3.0
@export var lunge_distance: float = 5.0
@export var lunge_duration: float = 0.5
@export var lunge_burst_time: float = 0.1   # how long the burst lasts
@export var lunge_pause_time: float = 0.2   # pause after burst
# Dash
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.5

# Combo
@export var combo_max_hits: int = 3
@export var combo_chain_speed_multiplier: float = 0.6
@export var combo_final_cooldown: float = .5
@export var combo_chain_window: float = 0.5
@export var combo_stagger_duration: float = 0.2
@export var combo_pre_final_delay_multiplier: float = 1.15
@export var melee_slash_spawn_delay: float = 0.1
@export var combo_pause_time: float = 0.25  # new pause duration

# UI
@export var player_healthbar: HealthBarComponent

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var sprite: Sprite2D = $Sprite2D
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var player_hitbox: Area2D = $PlayerHitbox
@onready var attack_timer: Timer = get_node_or_null("AttackTimer")

const ATTACK_EFFECT = preload("res://assets/effects/slash.tscn")
@export var arrow_projectile: PackedScene = preload("res://assets/objects/arrow_projectile.tscn")
var classes_preload: ClassesDB = preload("res://assets/resources/classes.tres")
var weapons_preload: WeaponsDB = preload("res://assets/resources/weapons.tres")

var CombatClass = Combat

# ---------------- STATE ----------------
var player_stats: Dictionary
var player_weapon: Dictionary

var last_direction: Vector2 = Vector2.DOWN

var _movement_locked := false
var _attack_effect_spawned := false
var _attack_hit_targets: Dictionary = {}

# ---------------- ATTACK STATE MACHINE ----------------
enum AttackState { IDLE, STARTUP, ACTIVE, RECOVERY, COMBO_WINDOW }
enum AttackType { LIGHT, HEAVY }
var current_attack_type: AttackType = AttackType.LIGHT
var attack_state: AttackState = AttackState.IDLE
var combo_step := 0
var buffered_attack := false
var _lunge_velocity := Vector2.ZERO
var _lunge_time_left := 0.0

# ---------------- CHARGE LOGIC ----------------
var _shake_strength: float = 0.1
var _shake_time: float = 0.0
var is_charging := false
var charge_time := 0.0
var max_charge_time := 1.5   # seconds
var _charge_damage_mult: float = 1.0
var _charge_knockback_mult: float = 1.0

# Dash
var _is_dashing := false
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_velocity := Vector2.ZERO

# Damage/Knockback
const BASE_KNOCKBACK = 200.0
const KNOCKBACK_DURATION = 0.3
const HIT_DAMAGE_PERCENT = 10.0
const ATTACK_HITBOX_TIME = 0.1

var hp: float = 100.0
var damage_percent: float = 0.0
var knockback_timer: float = 0.0
var stagger_timer: float = 0.0
var attack_hitbox: Area2D
var _attack_hitbox_enabled := false
var is_dead := false
var _initial_spawn_pos: Vector2 = Vector2.ZERO

# ---------------- NET HELPERS ----------------
func _net_active() -> bool:
	var mp := multiplayer.multiplayer_peer
	return mp != null and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _local_is_authority() -> bool:
	# When no multiplayer peer exists (singleplayer/offline), treat this instance as authority.
	return (not _net_active()) or is_multiplayer_authority()

# ---------------- READY ----------------
func _ready() -> void:
	add_to_group("team " + str(team))

	# Set multiplayer authority based on node name ("1", "2", ...)
	if name.is_valid_int():
		set_multiplayer_authority(int(name))

	# Remote players: no input processing (only when multiplayer is active)
	if _net_active() and not is_multiplayer_authority():
		set_process_input(false)
		set_physics_process(true)

	player_stats = {
		"move_speed": move_speed,
		"lunge_distance": lunge_distance,
		"lunge_duration": lunge_duration
	}

	ready_new_player()
	
	# Set HP from class stats (after ready_new_player assigns it)
	if player_stats.has("hp"):
		hp = float(player_stats["hp"])

	# Default respawn position to where we started (if not set in scene)
	_initial_spawn_pos = global_position
	if respawn_position == Vector2.ZERO:
		respawn_position = _initial_spawn_pos

	last_direction = starting_direction
	update_animation_parameters(starting_direction)

	# Ensure we have an AttackTimer node (scene-based preferred; fallback to code).
	if attack_timer == null:
		attack_timer = Timer.new()
		attack_timer.name = "AttackTimer"
		attack_timer.one_shot = true
		add_child(attack_timer)
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Setup hitboxes
	_setup_hitboxes()
	
	# Healthbar
	player_healthbar.init_health(hp)

func ready_new_player() -> void:
	player_stats = CombatClass.calculations.assign_player_stats(
		player_stats,
		classes_preload.classes[player_class_name]
	)

	player_weapon_name = classes_preload.classes[player_class_name]["starting_weapon"]
	player_weapon = weapons_preload.weapons[player_weapon_name]
	sprite.texture = load(classes_preload.classes[player_class_name]["sprite_path"])

# ---------------- PROCESS ----------------
func _physics_process(delta: float) -> void:
	# Only process input if this is the authority player (when multiplayer is active).
	# Avoid calling multiplayer APIs when no peer exists (they spam errors).
	if _net_active() and not is_multiplayer_authority():
		_sync_state()
		return

	# Handle knockback - must be first, overrides everything
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 1000 * delta)
		move_and_slide()
		_sync_state()
		return
	
	var raw_input_dir := Vector2(
		Input.get_action_strength("D") - Input.get_action_strength("A"),
		Input.get_action_strength("S") - Input.get_action_strength("W")
	)

	var input_dir := raw_input_dir

	# LOCK MOVEMENT DURING LUNGE, DASH, OR CHARGE
	if _lunge_time_left > 0.0 or _is_dashing or is_charging:
		input_dir = Vector2.ZERO

	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = max(_dash_cooldown_left - delta, 0.0)

	# Stagger: lock movement briefly (but allow dash to escape)
	if stagger_timer > 0.0:
		stagger_timer = max(stagger_timer - delta, 0.0)
		input_dir = Vector2.ZERO

	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()

	if _is_dashing:
		_dash_time_left -= delta
		velocity = _dash_velocity
		if _dash_time_left <= 0.0:
			_is_dashing = false
			_dash_cooldown_left = dash_cooldown
	elif _lunge_time_left > 0.0:
		_lunge_time_left -= delta
		if _lunge_time_left > lunge_pause_time:
			velocity = _lunge_velocity   # burst phase
		else:
			velocity = Vector2.ZERO      # pause phase
			if _lunge_time_left <= (lunge_pause_time) and not _attack_effect_spawned:
				_spawn_attack_payload(combo_step)
				_attack_effect_spawned = true

	else:
		if _movement_locked:
			velocity = Vector2.ZERO
		else:
			velocity = input_dir * move_speed
	move_and_slide()


	if Input.is_action_just_pressed("Light Attack"):
		handle_attack_input(AttackType.LIGHT)		

	if Input.is_action_just_pressed("dash") and not _is_dashing and _dash_cooldown_left <= 0.0:
		# Allow escaping stagger by dashing.
		stagger_timer = 0.0
		_start_dash(input_dir)

	var animation_direction = velocity.normalized() if velocity != Vector2.ZERO else last_direction
	update_animation_parameters(animation_direction)
	pick_new_state()

	_sync_state()

func handle_attack_input(attack: AttackType) -> void:
	if is_dead:
		return
		
	current_attack_type = attack
	
	match attack_state:
		AttackState.IDLE:
			if attack == AttackType.LIGHT:
				start_attack()
			elif attack == AttackType.HEAVY:
				start_heavy_attack()
		AttackState.COMBO_WINDOW:
			var max_hits := _combo_total_hits()
			if combo_step < max_hits - 1:
				combo_step += 1
				if attack == AttackType.LIGHT:
					start_attack()
				elif attack == AttackType.HEAVY:
					start_heavy_attack()
		_:
			buffered_attack = true

func _input(event):
	if is_dead:
		return

	# Only allow charging when idle (not mid-combo/attack)
	if attack_state != AttackState.IDLE:
		return

	if event.is_action_pressed("Heavy Attack"):
		is_charging = true
		charge_time = 0.0
	elif event.is_action_released("Heavy Attack") and is_charging:
		is_charging = false
		charge_heavy_attack()

func charge_heavy_attack() -> void:
	var charge_ratio := charge_time / max_charge_time
	var threshold := 0.25
	if charge_time < threshold:
		_charge_damage_mult = 1.0
		_charge_knockback_mult = 1.0
	else:
		var damage_multiplier: float = 1.0 + pow(charge_ratio, 2) * 0.5
		var knockback_multiplier: float = 1.0 + pow(charge_ratio, 2) * 0.5

		_charge_damage_mult = damage_multiplier
		_charge_knockback_mult = knockback_multiplier

	print("Charged heavy attack! Time:", charge_time,
		  " Damage x", _charge_damage_mult,
		  " Knockback x", _charge_knockback_mult)

	# Reset visuals immediately
	sprite.position = Vector2.ZERO
	sprite.self_modulate = Color(1,1,1,1)
	is_charging = false
	charge_time = 0.0
	_shake_time = 0.0

	handle_attack_input(AttackType.HEAVY)

func _process(delta):
	if is_charging:
		charge_time = min(charge_time + delta, max_charge_time)
		_shake_time += delta

		var ratio: float = clamp(charge_time / max_charge_time, 0.0, 1.0)

		# --- Shake (gentle ramp) ---
		if charge_time >= 0.2:
			var shake_intensity: float = _shake_strength * (1.0 + ratio)
			var freq_x: float = 10.0 + 10.0 * ratio
			var freq_y: float = 15.0 + 15.0 * ratio
			sprite.position.x = sin(_shake_time * freq_x) * shake_intensity
			sprite.position.y = cos(_shake_time * freq_y) * shake_intensity

		# --- Simple blink ---
		# Blink speed ramps up with charge, but capped
		var blink_speed: float = lerp(4.0, 8.0, ratio)  # starts at 4 Hz, max ~8 Hz
		var blink_phase: int = int(_shake_time * blink_speed) % 2

		if blink_phase == 0:
			sprite.self_modulate = Color(1, 1, 1, 1)
		else:
			var glow_strength: float = lerp(1.2, 1.8, ratio)
			sprite.self_modulate = Color(glow_strength, glow_strength, glow_strength, 1)

	else:
		sprite.position = Vector2.ZERO
		sprite.self_modulate = Color(1, 1, 1, 1)

func start_attack() -> void:
	attack_state = AttackState.STARTUP
	buffered_attack = false
	_attack_effect_spawned = false
	_attack_hit_targets.clear()

	# Determine attack direction (also used for hitbox placement + animation blend).
	last_direction = _mouse_cardinal_direction()
	update_animation_parameters(last_direction)
	
	# Lunge only for melee weapons.
	if _weapon_type() != "range":
		_start_lunge_toward_mouse()

	attack_timer.wait_time = get_startup_time()
	attack_timer.start()
	
func start_heavy_attack() -> void:
	print("heavy")
	var startup_time := get_startup_time()

	if combo_step == 0:
		# First heavy hit: big wind‑up
		await get_tree().create_timer(0.05).timeout
	else:
		# Second heavy hit: snappier follow‑through
		await get_tree().create_timer(0.08).timeout

	attack_state = AttackState.STARTUP
	buffered_attack = false
	_attack_effect_spawned = false
	_attack_hit_targets.clear()

	last_direction = _mouse_cardinal_direction()
	update_animation_parameters(last_direction)

	if _weapon_type() != "range":
		_start_lunge_toward_mouse(1.5)

	attack_timer.wait_time = startup_time
	attack_timer.start()



# ---------------- MULTIPLAYER SYNC ----------------
func _sync_state() -> void:
	if not _net_active():
		return
	if not is_multiplayer_authority():
		return
	rpc(
		"sync_remote_state",
		global_position,
		velocity,
		last_direction,
		attack_state != AttackState.IDLE,
		_is_dashing,
		_lunge_time_left,
		hp,
		damage_percent,
		knockback_timer,
		is_dead,
		stocks
	)

@rpc("unreliable", "any_peer")
func sync_remote_state(
	pos: Vector2,
	vel: Vector2,
	dir: Vector2,
	remote_is_attacking: bool,
	remote_is_dashing: bool,
	remote_lunge_time_left: float,
	remote_hp: float,
	remote_damage_percent: float,
	remote_knockback_timer: float,
	remote_is_dead: bool,
	remote_stocks: int
) -> void:
	if _net_active() and is_multiplayer_authority():
		return

	global_position = pos
	velocity = vel
	last_direction = dir
	attack_state = (AttackState.ACTIVE if remote_is_attacking else AttackState.IDLE)
	_is_dashing = remote_is_dashing
	_lunge_time_left = remote_lunge_time_left
	hp = remote_hp
	damage_percent = remote_damage_percent
	knockback_timer = remote_knockback_timer
	is_dead = remote_is_dead
	stocks = remote_stocks

	# Apply death visuals on non-authority instances
	if is_dead:
		visible = false
		if player_hitbox:
			player_hitbox.set_deferred("monitoring", false)
			player_hitbox.set_deferred("monitorable", false)
	else:
		visible = true
		if player_hitbox:
			player_hitbox.set_deferred("monitoring", true)
			player_hitbox.set_deferred("monitorable", true)

	update_animation_parameters(velocity.normalized() if velocity != Vector2.ZERO else last_direction)
	pick_new_state()

func _start_attack_hitbox() -> void:
	if not attack_hitbox:
		return
	var shape = attack_hitbox.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = false
	attack_hitbox.set_deferred("monitoring", true)
	_attack_hitbox_enabled = true

func _stop_attack_hitbox() -> void:
	if not attack_hitbox:
		return
	var shape = attack_hitbox.get_node_or_null("CollisionShape2D")
	attack_hitbox.set_deferred("monitoring", false)
	_attack_hitbox_enabled = false
	if shape:
		shape.disabled = true

# ---------------- TIMERS ----------------

func _on_attack_timer_timeout() -> void:
	match attack_state:
		AttackState.STARTUP:
			if current_attack_type == AttackType.HEAVY:
				# Add predelay before hitbox turns on
				var pre_delay := 0.25   # tune this value
				attack_timer.wait_time = pre_delay
				attack_state = AttackState.ACTIVE

				attack_timer.start()

			else:
				enable_hitbox()
				attack_timer.wait_time = get_active_time()
				attack_state = AttackState.ACTIVE
				attack_timer.start()
		AttackState.ACTIVE:
			attack_state = AttackState.RECOVERY
			disable_hitbox()
			var t := get_recovery_time()
			attack_timer.wait_time = t
			attack_timer.start()
		AttackState.RECOVERY:
			if current_attack_type == AttackType.HEAVY and combo_step < _combo_total_hits() - 1:
				# Still chaining heavy hits
				combo_step += 1
				start_heavy_attack()
			else:
				if _is_final_combo_step():
					buffered_attack = false
					combo_step = 0
					attack_state = AttackState.IDLE
					# Reset charge multipliers after the final heavy hit
					_charge_damage_mult = 1.0
					_charge_knockback_mult = 1.0
				else:
					attack_state = AttackState.COMBO_WINDOW
					attack_timer.wait_time = combo_chain_window
					attack_timer.start()
		AttackState.COMBO_WINDOW:
			if current_attack_type == AttackType.HEAVY:
				# Auto‑chain heavy attacks
				var max_hits := _combo_total_hits()
				if combo_step < max_hits - 1:
					combo_step += 1
					start_heavy_attack()
				else:
					combo_step = 0
					attack_state = AttackState.IDLE
			elif buffered_attack:
				buffered_attack = false
				var max_hits := _combo_total_hits()
				if combo_step < max_hits - 1:
					combo_step += 1
					if current_attack_type == AttackType.LIGHT:
						start_attack()
				else:
					combo_step = 0
					attack_state = AttackState.IDLE
			else:
				combo_step = 0
				attack_state = AttackState.IDLE


#func _on_combo_window_timeout() -> void:
	#if _is_attacking:
		#_combo_step = 0
		#_is_attacking = false

# ---------------- HELPERS ----------------
func _mouse_cardinal_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	if abs(to_mouse.x) > abs(to_mouse.y):
		return Vector2.RIGHT if to_mouse.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if to_mouse.y > 0.0 else Vector2.UP

func _attack_combo_animation(step: int) -> StringName:
	var to_mouse := get_global_mouse_position() - global_position
	var is_left := to_mouse.x < 0.0

	if current_attack_type == AttackType.HEAVY:
		match step:
			0: return &"slash_2"   # first heavy hit
			1: return &"slash"     # second heavy hit (or &"slash_3" if you prefer)
			_: return &"slash"     # fallback
	else:
		if is_left:
			return &"slash_2" if step % 2 == 0 else &"slash"
		else:
			return &"slash" if step % 2 == 0 else &"slash_2"

func _play_attack_animation() -> void:
	update_animation_parameters(last_direction)

func _start_lunge_toward_mouse(multiplier: float = 1.0) -> void:
	var dir := (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = last_direction

	var distance := lunge_distance * multiplier

	if _is_final_combo_step():
		distance *= 2

	_lunge_velocity = dir * (distance / max(lunge_burst_time, 0.001))
	_lunge_time_left = lunge_burst_time + lunge_pause_time

func _start_dash(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		dir = last_direction
	_is_dashing = true
	_dash_time_left = dash_duration
	_dash_velocity = dir.normalized() * dash_speed
	last_direction = dir

func update_animation_parameters(dir: Vector2) -> void:
	animation_tree.set("parameters/Idle/blend_position", dir)
	animation_tree.set("parameters/Walk/blend_position", dir)
	animation_tree.set("parameters/Attack/blend_position", dir)

func pick_new_state() -> void:
	if attack_state == AttackState.IDLE:
		if _is_dashing or velocity != Vector2.ZERO:
			state_machine.travel("Walk")
		else:
			state_machine.travel("Idle")
	elif attack_state == AttackState.STARTUP or attack_state == AttackState.ACTIVE:
		state_machine.travel("Attack")
	elif attack_state == AttackState.RECOVERY or attack_state == AttackState.COMBO_WINDOW:
		# Let it fall back to Idle/Walk so next hit retriggers Attack
		if velocity != Vector2.ZERO:
			state_machine.travel("Walk")
		else:
			state_machine.travel("Idle")


func _weapon_type() -> String:
	if player_weapon == null:
		return ""
	return str(player_weapon.get("type", ""))

func _combo_total_hits() -> int:
	if player_weapon == null:
		return 1

	if current_attack_type == AttackType.LIGHT:
		print('light')
		if player_weapon.has("quick_attack") and (player_weapon["quick_attack"] is Array):
			var arr: Array = player_weapon["quick_attack"]
			return maxi(arr.size(), 1)
	elif current_attack_type == AttackType.HEAVY:
		print("heavy")
		if player_weapon.has("heavy_attack") and (player_weapon["heavy_attack"] is Array):
			var arr: Array = player_weapon["heavy_attack"]
			return maxi(arr.size(), 1)

	return maxi(combo_max_hits, 1)


func _weapon_combo_damage_multiplier(step: int) -> float:
	if player_weapon == null:
		return 1.0

	if current_attack_type == AttackType.LIGHT:
		if player_weapon.has("quick_attack") and (player_weapon["quick_attack"] is Array):
			var arr: Array = player_weapon["quick_attack"]
			if arr.is_empty():
				return 1.0
			var idx: int = clampi(step, 0, arr.size() - 1)
			return float(arr[idx])
	elif current_attack_type == AttackType.HEAVY:
		if player_weapon.has("heavy_attack") and (player_weapon["heavy_attack"] is Array):
			var arr: Array = player_weapon["heavy_attack"]
			if arr.is_empty():
				return 1.0
			var idx: int = clampi(step, 0, arr.size() - 1)
			return float(arr[idx])
	return 1.0



func _spawn_attack_payload(step: int) -> void:
	# Melee => slash hitbox. Range => projectile.
	if _weapon_type() == "range":
		spawn_projectile(step)
	else:
		spawn_attack_effect(step)


func spawn_projectile(step: int) -> void:
	# Currently only supports the arrow projectile scene.
	# If later you add per-weapon scenes, we can read player_weapon["projectile"] here.
	if arrow_projectile == null:
		return
	var projectile = arrow_projectile.instantiate()
	projectile.global_position = global_position
	projectile.rotation = (get_global_mouse_position() - global_position).angle()
	var base_damage: float = CombatClass.calculations.calculate_attack_damage(player_stats, player_weapon)
	var mult: float = _weapon_combo_damage_multiplier(step)
	projectile.weapon_damage = max(base_damage * mult, 1.0)
	projectile.shooter = self
	get_parent().add_child(projectile)


func spawn_attack_effect(step: int) -> void:
	var fx = ATTACK_EFFECT.instantiate()
	fx.global_position = global_position

	# Use the combo animation helper to decide which animation to play
	var anim_name := _attack_combo_animation(step)
	fx.slash_effect = str(anim_name)  # assign to the effect scene
	# When using the timer-driven hitbox system, this slash effect should not hit players
	# (otherwise we'd double-apply damage). Keep dummy damage enabled.
	fx.hits_players = false

	# Pass combat info for hit/knockback
	var base_damage: float = CombatClass.calculations.calculate_attack_damage(player_stats, player_weapon)
	var mult: float = _weapon_combo_damage_multiplier(step)
	var total_damage: float = max(base_damage * mult * _charge_damage_mult, 1.0)
	var total_hits: int = _combo_total_hits()
	if fx.has_method("set_attack_context"):
		var attacker_id := -1
		if _net_active():
			attacker_id = get_multiplayer_authority()
		elif name.is_valid_int():
			attacker_id = int(name)
		fx.set_attack_context(attacker_id, team, total_damage, step, total_hits)
	#print("[ATTACK] spawn_slash by=", name, " team=", team, " dmg=", total_damage, " anim=", fx.slash_effect)

	get_parent().add_child(fx)

# ---------------- HITBOX SETUP ----------------
func _setup_hitboxes() -> void:
	# Setup player hitbox for receiving damage
	if player_hitbox:
		player_hitbox.monitoring = true
		player_hitbox.monitorable = true
		player_hitbox.body_entered.connect(_on_player_hitbox_body_entered)
		player_hitbox.area_entered.connect(_on_player_hitbox_area_entered)

	# Create attack hitbox for dealing damage
	attack_hitbox = Area2D.new()
	attack_hitbox.name = "AttackHitBox"
	# Ensure our hitbox can "see" the player's hitbox layer (varies by scene setup).
	attack_hitbox.collision_layer = 1
	attack_hitbox.collision_mask = (player_hitbox.collision_layer if player_hitbox else 2)
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	add_child(attack_hitbox)

	var attack_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(14, 14)
	attack_shape.shape = rect_shape
	attack_hitbox.add_child(attack_shape)

	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)

func _update_attack_hitbox_position() -> void:
	if not attack_hitbox:
		return
	var shape = attack_hitbox.get_node_or_null("CollisionShape2D")
	if not shape:
		return

	if last_direction.x < 0:
		attack_hitbox.position = Vector2(-6, -4)
	elif last_direction.x > 0:
		attack_hitbox.position = Vector2(6, -4)
	elif last_direction.y < 0:
		attack_hitbox.position = Vector2(0, -12)
	elif last_direction.y > 0:
		attack_hitbox.position = Vector2(0, 7)

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if not is_multiplayer_authority():
		return
	if not _attack_hitbox_enabled:
		return
	var body: Node = area.get_parent()
	if body == null:
		return
	var body2d := body as Node2D
	if body2d == null:
		return

	# Don't hit yourself
	if body == self:
		return

	# Don't hit same team
	if body.has_method("get") and body.get("team") == team:
		return

	# Avoid multi-hit spam during a single ACTIVE window.
	var key := str(body.get_instance_id())
	if _attack_hit_targets.has(key):
		return
	_attack_hit_targets[key] = true

	# Dummy / destructible targets: apply local damage (offline or online).
	if body.has_method("take_damage"):
		var base_damage_dummy: float = CombatClass.calculations.calculate_attack_damage(player_stats, player_weapon)
		var mult_dummy: float = _weapon_combo_damage_multiplier(combo_step)
		var dmg_dummy: float = max(base_damage_dummy * mult_dummy, 1.0)
		body.call("take_damage", dmg_dummy)
		return

	# Player targets: apply via receive_combo_hit so final hit knockback + earlier stagger works.
	if not body2d.has_method("receive_combo_hit"):
		return
	var direction: Vector2 = (body2d.global_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = last_direction
	var base_damage_p: float = CombatClass.calculations.calculate_attack_damage(player_stats, player_weapon)
	var mult_p: float = _weapon_combo_damage_multiplier(combo_step)
	var dmg_p: float = max(base_damage_p * mult_p, 1.0)
	var total_hits_p: int = _combo_total_hits()

	var mp := multiplayer.multiplayer_peer
	if mp == null or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		body2d.call("receive_combo_hit", direction, dmg_p, combo_step, total_hits_p)
		return
	var target_auth: int = int(body2d.get_multiplayer_authority())
	if target_auth <= 0:
		return
	body2d.rpc_id(target_auth, "receive_combo_hit", direction, dmg_p, combo_step, total_hits_p)

func _on_player_hitbox_body_entered(body: Node) -> void:
	# This is for receiving hits - handled via RPC
	pass

func _on_player_hitbox_area_entered(area: Area2D) -> void:
	# Debug receiver: confirms the slash Area2D overlaps this player.
	var src := area.get_parent()
	print("[RECV] PlayerHitbox area_entered from=", (src.name if src else area.name))

@rpc("reliable", "any_peer", "call_local")
func receive_hit(direction: Vector2, damage: float) -> void:
	# Only the authority for this player applies damage/knockback; it will sync to others.
	if not _local_is_authority():
		return
	print("[HIT] receive_hit on=", name, " dmg=", damage)
	take_hit(direction, damage)

@rpc("reliable", "any_peer", "call_local")
func receive_combo_hit(direction: Vector2, damage: float, combo_step: int, combo_total_hits: int) -> void:
	# First two combo hits stagger only; final hit applies knockback.
	if not _local_is_authority():
		return
	print("[HIT] receive_combo_hit on=", name, " dmg=", damage, " step=", combo_step, " total=", combo_total_hits)
	var max_hits: int = maxi(combo_total_hits, 1)
	var is_final: bool = combo_step >= (max_hits - 1)
	if is_final:
		take_hit(direction, damage, true)
	else:
		take_hit(direction, damage, false, combo_stagger_duration)

@rpc("reliable", "any_peer")
func apply_hit_to_server(target_id: int, direction: Vector2, damage: float) -> void:
	# Only server processes this - route to manager
	print(
		"[RPC] apply_hit_to_server recv on=", name,
		" net_active=", _net_active(),
		" is_server=", (multiplayer.is_server() if _net_active() else false),
		" from_sender=", (multiplayer.get_remote_sender_id() if _net_active() else -1),
		" target_id=", target_id,
		" dmg=", damage,
		" parent=", get_parent().name
	)
	if not _net_active() or not multiplayer.is_server():
		return

	var manager = get_parent()
	if manager and manager.has_method("apply_hit_to_player"):
		print("[RPC] routing to manager.apply_hit_to_player target_id=", target_id)
		manager.apply_hit_to_player(target_id, direction, damage)
	else:
		print("[RPC] manager missing apply_hit_to_player; manager=", manager)


func take_hit(direction: Vector2, hp_damage: float, apply_knockback: bool = true, p_stagger_time: float = 0.0) -> void:
	if not _local_is_authority():
		return
	if is_dead:
		return

	# Getting hit cancels your attack state.
	_reset_attack_state()

	hp -= hp_damage
	hp = max(hp, 0)
	player_healthbar.health = hp

	damage_percent += HIT_DAMAGE_PERCENT
	var scaled_knockback = BASE_KNOCKBACK * (1.0 + damage_percent / 100.0) * _charge_knockback_mult

	if apply_knockback:
		# Apply knockback velocity immediately
		velocity = direction.normalized() * scaled_knockback
		knockback_timer = KNOCKBACK_DURATION
		stagger_timer = 0.0
	else:
		# Stagger: no push, just lock movement for a bit
		velocity = Vector2.ZERO
		knockback_timer = 0.0
		stagger_timer = max(stagger_timer, max(p_stagger_time, 0.0))
	# Stop any ongoing attacks/movement
	_lunge_time_left = 0.0
	_is_dashing = false

	print(
		name,
		" took hit | HP:",
		hp,
		" | %:",
		damage_percent,
		" | KB:",
		(scaled_knockback if apply_knockback else 0.0),
		" | stagger:",
		(stagger_timer if not apply_knockback else 0.0)
	)

	if hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	_reset_attack_state()
	visible = false
	velocity = Vector2.ZERO
	knockback_timer = 0.0
	stagger_timer = 0.0
	_lunge_time_left = 0.0
	_is_dashing = false

	# Stop taking hits / stop movement
	if player_hitbox:
		player_hitbox.set_deferred("monitoring", false)
		player_hitbox.set_deferred("monitorable", false)
	set_physics_process(false)

	stocks -= 1
	if _net_active():
		_sync_state()
	if stocks <= 0:
		return

	await get_tree().create_timer(respawn_delay).timeout
	respawn()

func respawn() -> void:
	# In multiplayer, only authority should respawn and sync to others
	if _net_active() and not is_multiplayer_authority():
		return

	is_dead = false
	_reset_attack_state()
	global_position = respawn_position
	velocity = Vector2.ZERO
	damage_percent = 0.0
	knockback_timer = 0.0
	stagger_timer = 0.0
	_attack_effect_spawned = false
	_lunge_time_left = 0.0
	_lunge_velocity = Vector2.ZERO

	# Restore HP to class HP if available
	hp = float(player_stats.get("hp", 100.0))
	visible = true
	if player_hitbox:
		player_hitbox.set_deferred("monitoring", true)
		player_hitbox.set_deferred("monitorable", true)
	set_physics_process(true)
	if _net_active():
		_sync_state()

func enable_hitbox() -> void:
	_attack_hit_targets.clear()
	_update_attack_hitbox_position()
	if _weapon_type() != "range":
		_start_attack_hitbox()

func disable_hitbox() -> void:
	_stop_attack_hitbox()

func get_startup_time() -> float:
	var atk_speed: float = max(
		float(CombatClass.calculations.calculate_attack_speed(player_stats, player_weapon)),
		0.001
	)
	return 0.05 / atk_speed

func get_active_time() -> float:
	return 0.10

func get_recovery_time() -> float:
	if current_attack_type == AttackType.HEAVY:
		return 0.1
	return 0.01   # default for light


func _is_final_combo_step() -> bool:
	var max_hits := _combo_total_hits()
	return combo_step >= (max_hits - 1)

func _reset_attack_state() -> void:
	attack_state = AttackState.IDLE
	combo_step = 0
	buffered_attack = false
	_attack_effect_spawned = false
	_attack_hit_targets.clear()
	_charge_damage_mult = 1.0
	_charge_knockback_mult = 1.0
	if attack_timer:
		attack_timer.stop()
	_stop_attack_hitbox()
