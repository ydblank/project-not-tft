extends CharacterBody2D

@export var player_class_name: String = "knight"
@export var player_weapon_name: String = "sword"

@export var move_speed: float = 100.0
@export var starting_direction: Vector2 = Vector2(0, 1)
@export var team: int = 1
@export var respawn_position: Vector2 = Vector2.ZERO
@export var stocks: int = 3
@export var respawn_delay: float = 3.0
@export var lunge_distance: float = 10.0
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
@export var combo_final_cooldown: float = 0.5
@export var combo_chain_window: float = 0.5
@export var combo_stagger_duration: float = 0.2
@export var combo_pre_final_delay_multiplier: float = 1.15
@export var melee_slash_spawn_delay: float = 0.1

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var sprite: Sprite2D = $Sprite2D
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var player_hitbox: Area2D = $PlayerHitbox

const ATTACK_EFFECT = preload("res://assets/effects/slash.tscn")
@export var arrow_projectile: PackedScene = preload("res://assets/objects/arrow_projectile.tscn")
var classes_preload: ClassesDB = preload("res://assets/resources/classes.tres")
var weapons_preload: WeaponsDB = preload("res://assets/resources/weapons.tres")

var CombatClass = Combat

# ---------------- STATE ----------------
var player_stats: Dictionary
var player_weapon: Dictionary

var last_direction: Vector2 = Vector2.DOWN

var _can_attack := true
var _is_attacking := false
var _attack_effect_spawned := false

var _attack_timer: Timer
var _combo_window_timer: Timer
var _combo_step := 0

var _lunge_velocity := Vector2.ZERO
var _lunge_time_left := 0.0

# Dash
var _is_dashing := false
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_velocity := Vector2.ZERO
var _combo_lockout := false

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

	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(_attack_timer)

	_combo_window_timer = Timer.new()
	_combo_window_timer.one_shot = true
	_combo_window_timer.timeout.connect(_on_combo_window_timeout)
	add_child(_combo_window_timer)

	# Setup hitboxes
	_setup_hitboxes()

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

	# LOCK MOVEMENT ONLY DURING LUNGE OR DASH
	if _lunge_time_left > 0.0 or _is_dashing:
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
	else:
		velocity = input_dir * move_speed

	move_and_slide()

# NEW: only trigger on *just pressed*, not held
	if Input.is_action_just_pressed("Primary") and _can_attack and not _combo_lockout:
		_play_attack()

	if Input.is_action_just_pressed("dash") and not _is_dashing and _dash_cooldown_left <= 0.0:
		# Allow escaping stagger by dashing.
		stagger_timer = 0.0
		_start_dash(input_dir)

	var animation_direction = velocity.normalized() if velocity != Vector2.ZERO else last_direction
	update_animation_parameters(animation_direction)
	pick_new_state()

	_sync_state()

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
		_is_attacking,
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
	_is_attacking = remote_is_attacking
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

func _play_attack() -> void:
	# Set attack state
	_is_attacking = true
	_can_attack = false
	_attack_effect_spawned = false

	# Determine attack direction
	var attack_dir := _mouse_cardinal_direction()
	last_direction = attack_dir

	# Update attack hitbox position and enable it
	_update_attack_hitbox_position()
	# Using the slash effect Area2D for hit detection/knockback; keep AttackHitBox disabled.
	# _start_attack_hitbox()

	# Start lunge if not already moving
	if _weapon_type() != "range":
		if _lunge_time_left <= 0.0:
			_start_lunge_toward_mouse()
	else:
		_lunge_time_left = 0.0
		_lunge_velocity = Vector2.ZERO

	# Stop any running timers
	_attack_timer.stop()
	_combo_window_timer.stop()

	# Spawn attack payload (delay melee a bit so lunge starts first).
	var step_for_payload := _combo_step
	if _weapon_type() != "range" and melee_slash_spawn_delay > 0.0:
		var t := get_tree().create_timer(melee_slash_spawn_delay)
		t.timeout.connect(func() -> void:
			if is_dead:
				return
			if _attack_effect_spawned:
				return
			_spawn_attack_payload(step_for_payload)
			_attack_effect_spawned = true
		)
	else:
		_spawn_attack_payload(step_for_payload)
		_attack_effect_spawned = true

	# Start attack/combo timers (this used to be in here; without it, you get "freeze")
	var attack_speed: float = max(
		CombatClass.calculations.calculate_attack_speed(player_stats, player_weapon),
		0.001
	)
	var base_time: float = 0.3 / attack_speed
	var max_hits := _combo_total_hits()

	if _combo_step < max_hits - 1:
		# Normal chained hit → use attack timer
		var chain_wait := base_time * combo_chain_speed_multiplier
		# Make the transition into the final hit slightly slower than the first two.
		if _combo_step == max_hits - 2:
			chain_wait *= combo_pre_final_delay_multiplier
		_attack_timer.wait_time = chain_wait
		_combo_window_timer.wait_time = max(combo_chain_window, chain_wait * 1.25)
		_combo_window_timer.start()
		_attack_timer.start()
	else:
		# Final hit → skip normal attack timer, rely only on combo_final_cooldown
		_combo_lockout = true

		# End combo immediately
		_combo_step = 0
		_is_attacking = false
		_can_attack = true

		if combo_final_cooldown > 0.0:
			var lockout_timer := Timer.new()
			lockout_timer.one_shot = true
			lockout_timer.wait_time = combo_final_cooldown
			lockout_timer.timeout.connect(_on_combo_lockout_timeout)
			add_child(lockout_timer)
			lockout_timer.start()
		else:
			_combo_lockout = false

func _start_attack_hitbox() -> void:
	if not attack_hitbox:
		return
	var shape = attack_hitbox.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = false
	attack_hitbox.set_deferred("monitoring", true)
	_attack_hitbox_enabled = true
	# Disable after hitbox time
	var timer = get_tree().create_timer(ATTACK_HITBOX_TIME)
	timer.timeout.connect(_stop_attack_hitbox)

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
	_lunge_time_left = 0.0

	var max_hits := _combo_total_hits()
	if _combo_step < max_hits - 1:
		_combo_step += 1
		_can_attack = true
	else:
		# Combo finished → handled by lockout timer now
		_combo_step = 0
		_is_attacking = false
		_can_attack = false

func _on_combo_lockout_timeout() -> void:
	_combo_lockout = false
	_can_attack = true

func _on_combo_window_timeout() -> void:
	if _is_attacking:
		_combo_step = 0
		_is_attacking = false
		_can_attack = true

# ---------------- HELPERS ----------------
func _mouse_cardinal_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	if abs(to_mouse.x) > abs(to_mouse.y):
		return Vector2.RIGHT if to_mouse.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if to_mouse.y > 0.0 else Vector2.UP

func _attack_combo_animation(step: int) -> StringName:
	var to_mouse := get_global_mouse_position() - global_position
	var is_left := to_mouse.x < 0.0
	# Always alternate (works for any combo length):
	# Left:  slash_2, slash, slash_2, slash, ...
	# Right: slash,   slash_2, slash,   slash_2, ...
	if is_left:
		return &"slash_2" if (step % 2 == 0) else &"slash"
	return &"slash" if (step % 2 == 0) else &"slash_2"


func _play_attack_animation(anim_name: StringName) -> void:
	update_animation_parameters(last_direction)
	if animation_player.has_animation(anim_name):
		state_machine.travel("Attack")
		animation_tree.set("parameters/Attack/current_time", 0.0)


func _start_lunge_toward_mouse() -> void:
	var dir := (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = last_direction

	# Cover full distance in burst time
	_lunge_velocity = dir * (lunge_distance / max(lunge_burst_time, 0.001))
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
	if _is_attacking:
		state_machine.travel("Attack")
	elif _is_dashing or velocity != Vector2.ZERO:
		state_machine.travel("Walk")
	else:
		state_machine.travel("Idle")

func _weapon_type() -> String:
	if player_weapon == null:
		return ""
	return str(player_weapon.get("type", ""))

func _combo_total_hits() -> int:
	if player_weapon != null and player_weapon.has("quick_attack") and (player_weapon["quick_attack"] is Array):
		var arr: Array = player_weapon["quick_attack"]
		return maxi(arr.size(), 1)
	return maxi(combo_max_hits, 1)

func _weapon_combo_damage_multiplier(step: int) -> float:
	# Weapon-driven combo multipliers (array length == combo length).
	if player_weapon != null and player_weapon.has("quick_attack") and (player_weapon["quick_attack"] is Array):
		var arr: Array = player_weapon["quick_attack"]
		if arr.is_empty():
			return 1.0
		var idx: int = clampi(step, 0, arr.size() - 1)
		return float(arr[idx])
	# Fallback (older weapons): treat as no multiplier.
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

	# Pass combat info for hit/knockback
	var base_damage: float = CombatClass.calculations.calculate_attack_damage(player_stats, player_weapon)
	var mult: float = _weapon_combo_damage_multiplier(step)
	var total_damage: float = max(base_damage * mult, 1.0)
	var total_hits: int = _combo_total_hits()
	if fx.has_method("set_attack_context"):
		var attacker_id := -1
		if _net_active():
			attacker_id = get_multiplayer_authority()
		elif name.is_valid_int():
			attacker_id = int(name)
		fx.set_attack_context(attacker_id, team, total_damage, step, total_hits)
	print("[ATTACK] spawn_slash by=", name, " team=", team, " dmg=", total_damage, " anim=", fx.slash_effect)

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
	# PlayerHitbox (scene) is layer 8, mask 2; make AttackHitBox layer 2, mask 8
	# so we can use Area2D<->Area2D overlap via `area_entered`.
	attack_hitbox.collision_layer = 2
	attack_hitbox.collision_mask = 8
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
	
	# Don't hit yourself
	if body == self:
		return
	
	# Don't hit same team
	if body.has_method("get") and body.get("team") == team:
		return
	
	if body.has_method("take_hit"):
		print(
			"[HIT] attacker=", name,
			" auth=", get_multiplayer_authority(),
			" is_server=", multiplayer.is_server(),
			" target_name=", body.name,
			" target_auth=", body.get_multiplayer_authority(),
			" parent=", get_parent().name
		)
		var direction = (body.global_position - global_position).normalized()
		if direction == Vector2.ZERO:
			direction = last_direction
		
		# Calculate damage from class and weapon stats
		var class_dmg = float(player_stats.get("dmg", 0))
		var weapon_dmg = float(player_weapon.get("dmg", 0))
		var total_damage = class_dmg + weapon_dmg
		
		# Apply damage - if server, do directly; if client, send to server
		if body.name.is_valid_int():
			var target_id = int(body.name)
			if multiplayer.is_server():
				# Server handles directly - find target in parent
				var target = get_parent().get_node_or_null(str(target_id))
				print("[HIT] server_direct target_lookup=", str(target_id), " found=", target != null)
				if target and target.has_method("take_hit"):
					target.take_hit(direction, total_damage)
			else:
				# Client sends RPC to server - call on self, server will route via manager
				print("[HIT] client_rpc_to_server -> apply_hit_to_server target_id=", target_id, " dmg=", total_damage)
				apply_hit_to_server.rpc_id(1, target_id, direction, total_damage)
		else:
			print("[HIT] target name not int; can't route. target_name=", body.name)

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
	
	hp -= hp_damage
	hp = max(hp, 0)
	
	damage_percent += HIT_DAMAGE_PERCENT
	var scaled_knockback = BASE_KNOCKBACK * (1.0 + damage_percent / 100.0)
	
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
	visible = false
	velocity = Vector2.ZERO
	knockback_timer = 0.0
	stagger_timer = 0.0
	_lunge_time_left = 0.0
	_is_dashing = false
	_is_attacking = false

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
	global_position = respawn_position
	velocity = Vector2.ZERO
	damage_percent = 0.0
	knockback_timer = 0.0
	stagger_timer = 0.0
	_is_attacking = false
	_can_attack = true
	_combo_step = 0
	_combo_lockout = false
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
