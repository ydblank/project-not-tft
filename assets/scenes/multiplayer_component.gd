# res://scripts/components/MultiplayerComponent.gd
extends Node
class_name MultiplayerComponent

@export var player: CharacterBody2D
@export var attack_component: AttackComponent
@export var health_component: HealthComponent
@export var hitbox_component: HitboxComponent
@export var stat_component: StatsComponent
@export var animation_component: AnimationComponent # <-- ADD THIS

@export var set_authority_from_node_name := true

var _dbg_send_count := 0
var _dbg_recv_count := 0

func _ready() -> void:
	# Auto-assign player if you didn't wire it in the inspector
	if player == null:
		player = get_parent() as CharacterBody2D

	print("[MPComp] READY node=", name,
		" parent=", get_parent().name,
		" player=", player,
		" net_active=", net_active(),
		" unique_id=", multiplayer.get_unique_id())

	setup_multiplayer_authority_and_input()

	if player != null:
		print("[MPComp] AFTER setup player_name=", player.name,
			" is_authority=", player.is_multiplayer_authority(),
			" authority_id=", player.get_multiplayer_authority())

	# DEBUG: ensure this component ticks so it can prove sending
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	# DEBUG: minimal auto-sync so you can confirm packets are moving
	if not net_active() or player == null:
		return
	if not player.is_multiplayer_authority():
		return

	_dbg_send_count += 1
	if _dbg_send_count % 30 == 0:
		print("[MPComp] SENDING from=", player.name,
			" pos=", player.global_position,
			" vel=", player.velocity)

	# Send a minimal state packet.
	# Once you're confident, call sync_state(...) from your player script instead.
	sync_state(Vector2.ZERO, false, false, 0.0, 0.0, 0.0, false, 0)

func net_active() -> bool:
	var mp := multiplayer.multiplayer_peer
	return mp != null and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func local_is_authority() -> bool:
	return (not net_active()) or (player != null and player.is_multiplayer_authority())

func setup_multiplayer_authority_and_input() -> void:
	if player == null:
		push_error("MultiplayerComponent: 'player' not assigned and couldn't auto-assign.")
		return

	# Optional: set authority from node name ("1", "123456", etc.)
	if set_authority_from_node_name and player.name.is_valid_int():
		player.set_multiplayer_authority(int(player.name))

	# Remote players: no input, and DON'T run physics movement (prevents overwriting synced pos)
	if net_active() and not player.is_multiplayer_authority():
		player.set_process_input(false)
		player.set_physics_process(false)

		if attack_component:
			if attack_component.has_method("set_process_input"):
				attack_component.call("set_process_input", false)
			attack_component.set_process(false)

func apply_remote_death_visuals(is_dead: bool) -> void:
	if player == null:
		return

	player.visible = not is_dead

	# HitboxComponent is an Area2D, so we can toggle it directly
	if hitbox_component:
		hitbox_component.set_deferred("monitoring", not is_dead)
		hitbox_component.set_deferred("monitorable", not is_dead)

func sync_state(
	net_last_direction: Vector2,
	is_attacking: bool,
	is_dashing: bool,
	lunge_time_left: float,
	damage_percent: float,
	knockback_timer: float,
	is_dead: bool,
	stocks: int
) -> void:
	if not net_active():
		return
	if player == null:
		return
	if not player.is_multiplayer_authority():
		return

	var hp := 0.0
	if health_component and health_component.has_method("get_hp"):
		hp = float(health_component.call("get_hp"))

	# Animation info to drive remote animation even though remote physics is off
	var remote_anim_dir := net_last_direction
	var remote_is_moving := player.velocity.length() > 0.0

	rpc(
		"sync_remote_state",
		player.global_position,
		player.velocity,
		net_last_direction,
		is_attacking,
		is_dashing,
		lunge_time_left,
		hp,
		damage_percent,
		knockback_timer,
		is_dead,
		stocks,
		remote_anim_dir,
		remote_is_moving
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
	remote_stocks: int,
	remote_anim_dir: Vector2,
	remote_is_moving: bool
) -> void:
	if player == null:
		return

	# If we're the authority, ignore incoming sync
	if net_active() and player.is_multiplayer_authority():
		return

	_dbg_recv_count += 1
	if _dbg_recv_count % 30 == 0:
		print("[MPComp] RECEIVING on=", player.name,
			" pos=", pos,
			" vel=", vel,
			" local_authority=", player.is_multiplayer_authority())

	# Apply remote state
	player.global_position = pos
	player.velocity = vel

	if attack_component and attack_component.has_method("set_remote_attacking"):
		attack_component.call("set_remote_attacking", remote_is_attacking)

	if health_component and health_component.has_method("set_hp"):
		health_component.call("set_hp", remote_hp)

	# Replace old has_variable(...) usage with `"var" in player`
	if "damage_percent" in player:
		player.damage_percent = remote_damage_percent
	if "knockback_timer" in player:
		player.knockback_timer = remote_knockback_timer
	if "is_dead" in player:
		player.is_dead = remote_is_dead
	if "stocks" in player:
		player.stocks = remote_stocks
	if "_is_dashing" in player:
		player._is_dashing = remote_is_dashing
	if "_lunge_time_left" in player:
		player._lunge_time_left = remote_lunge_time_left

	apply_remote_death_visuals(remote_is_dead)

	# Drive remote animations explicitly (remote isn't authority, and its physics is disabled)
	if animation_component:
		animation_component.sync_remote_animation(remote_anim_dir, remote_is_attacking, remote_is_moving)

@rpc("reliable", "any_peer", "call_local")
func rpc_show_damage_number(amount: int, pos: Vector2, damage_number_scene: PackedScene) -> void:
	if player == null or damage_number_scene == null:
		return

	var dn := damage_number_scene.instantiate()
	player.get_tree().current_scene.add_child(dn)

	if dn.has_method("setup"):
		dn.call("setup", amount, pos)
	else:
		(dn as Node2D).global_position = pos

@rpc("reliable", "any_peer", "call_local")
func receive_hit(direction: Vector2, damage: float) -> void:
	if not local_is_authority():
		return
	if player and player.has_method("take_hit"):
		player.call("take_hit", direction, damage)

@rpc("reliable", "any_peer", "call_local")
func receive_combo_hit(direction: Vector2, damage: float, p_combo_step: int, combo_total_hits: int) -> void:
	if not local_is_authority():
		return
	if player == null:
		return

	var max_hits: int = maxi(combo_total_hits, 1)
	var is_final: bool = p_combo_step >= (max_hits - 1)

	if player.has_method("take_hit"):
		if is_final:
			player.call("take_hit", direction, damage, true)
		else:
			var stagger := 0.0
			if "combo_stagger_duration" in player:
				stagger = float(player.combo_stagger_duration)
			player.call("take_hit", direction, damage, false, stagger)

@rpc("reliable", "any_peer")
func apply_hit_to_server(target_id: int, direction: Vector2, damage: float) -> void:
	if not net_active() or not multiplayer.is_server():
		return
	if player == null:
		return

	var manager := player.get_parent()
	if manager and manager.has_method("apply_hit_to_player"):
		manager.call("apply_hit_to_player", target_id, direction, damage)
