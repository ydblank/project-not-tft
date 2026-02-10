extends CharacterBody2D
#
#@export var stats: StatsComponent
#
#var move_speed: float = 100.0
#@export var starting_direction: Vector2 = Vector2(0, 1)
#@export var team: int = 1
#@export var respawn_position: Vector2 = Vector2.ZERO
#@export var stocks: int = 3
#@export var respawn_delay: float = 3.0
#@export var lunge_distance: float = 5.0
#@export var lunge_duration: float = 0.5
#@export var lunge_burst_time: float = 0.1 # how long the burst lasts
#@export var lunge_pause_time: float = 0.2 # pause after burst
## Dash
#var dash_speed: float = 300.0
#var dash_duration: float = 0.2
#var dash_cooldown: float = 0.5
#
## Combo
#var combo_max_hits: int = 3
#var combo_chain_speed_multiplier: float = 0.6
#var combo_final_cooldown: float = .5
#var combo_chain_window: float = 0.5
#var combo_stagger_duration: float = 0.2
#var combo_pre_final_delay_multiplier: float = 1.15
#var melee_slash_spawn_delay: float = 0.1
#var combo_pause_time: float = 0.25 # new pause duration
#
#@onready var animation_player: AnimationPlayer = $AnimationPlayer
#@onready var animation_tree: AnimationTree = $AnimationTree
#@onready var sprite: Sprite2D = $Sprite2D
#@onready var state_machine = animation_tree.get("parameters/playback")
#@onready var player_hitbox: Area2D = $HitboxComponent
#@onready var attack_component: AttackComponent = $AttackComponent
#@export var arrow_projectile: PackedScene = preload("res://assets/objects/arrow_projectile.tscn")
#@onready var shield: Node = $ShieldComponent
#@export var damage_number_scene: PackedScene = preload("res://assets/effects/damage_number.tscn")
#
#const ATTACK_EFFECT = preload("res://assets/effects/slash.tscn")
#var classes_preload: ClassesDB = preload("res://assets/resources/classes.tres")
#var weapons_preload: WeaponsDB = preload("res://assets/resources/weapons.tres")
#var CombatClass = Combat
#
## ---------------- STATE ----------------
#var player_stats: Dictionary
#var player_weapon: Dictionary
#
#var last_direction: Vector2 = Vector2.DOWN
#
#var _movement_locked := false
#var _movement_slowed: float = 0.25 # 25% of normal speed
#
#var _lunge_velocity := Vector2.ZERO
#var _lunge_time_left := 0.0
#
## Dash
#var _is_dashing := false
#var _dash_time_left := 0.0
#var _dash_cooldown_left := 0.0
#var _dash_velocity := Vector2.ZERO
#
## Damage/Knockback
#const BASE_KNOCKBACK = 200.0
#const KNOCKBACK_DURATION = 0.3
#const HIT_DAMAGE_PERCENT = 10.0
#var damage_percent: float = 0.0
#var knockback_timer: float = 0.0
#var stagger_timer: float = 0.0
#var attack_hitbox: Area2D
#var _attack_hitbox_enabled := false
#var is_dead := false
#var _initial_spawn_pos: Vector2 = Vector2.ZERO
#
## Multiplayer
#var net_last_direction: Vector2 = Vector2.DOWN
#var local_attack_facing: Vector2 = Vector2.DOWN
#var facing_direction: Vector2 = Vector2.DOWN
#
#
## ---------------- NET HELPERS ----------------
#func _net_active() -> bool:
	#var mp := multiplayer.multiplayer_peer
	#return mp != null and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
#
#func _local_is_authority() -> bool:
	## When no multiplayer peer exists (singleplayer/offline), treat this instance as authority.
	#return (not _net_active()) or is_multiplayer_authority()
#
## ---------------- READY ----------------
#func _ready() -> void:
	#add_to_group("team " + str(team))
#
	## Set multiplayer authority based on node name ("1", "2", ...)
	#if name.is_valid_int():
		#set_multiplayer_authority(int(name))
#
	## Remote players: no input processing (only when multiplayer is active)
	#if _net_active() and not is_multiplayer_authority():
		#set_process_input(false)
		#set_physics_process(true)
#
	#_apply_stats_resource()
	#player_stats = {
		#"move_speed": move_speed,
		#"lunge_distance": lunge_distance,
		#"lunge_duration": lunge_duration
	#}
#
	#ready_new_player()
	#
	## Set HP from class stats (after ready_new_player assigns it)
	#if health_component and player_stats.has("hp"):
		#health_component.set_max_hp(float(player_stats["hp"]))
		#health_component.set_hp(float(player_stats["hp"]))
#
	## Default respawn position to where we started (if not set in scene)
	#_initial_spawn_pos = global_position
	#if respawn_position == Vector2.ZERO:
		#respawn_position = _initial_spawn_pos
#
	#last_direction = starting_direction
	#update_animation_parameters(starting_direction)
#
	## Remote players: disable AttackComponent input too.
	#if _net_active() and not is_multiplayer_authority():
		#if attack_component:
			#attack_component.set_process_input(false)
			#attack_component.set_process(false)
#
	## Setup hitboxes
	#_setup_hitboxes()
#
#func _apply_stats_resource() -> void:
	#if stats == null:
		#push_error("PlayerCharacter: 'stats' is not assigned. Assign a Stats resource in the inspector.")
		#return
#
	## Pull gameplay-tuned numbers from the Stats resource
	#var s_player_stats: Dictionary = stats.get_entity_stats()
	#move_speed = float(s_player_stats.get("move_speed", move_speed))
#
	#dash_speed = stats.dash_speed
	#dash_duration = stats.dash_duration
	#dash_cooldown = stats.dash_cooldown
#
	#combo_max_hits = stats.combo_max_hits
	#combo_chain_speed_multiplier = stats.combo_chain_speed_multiplier
	#combo_final_cooldown = stats.combo_final_cooldown
	#combo_chain_window = stats.combo_chain_window
	#combo_stagger_duration = stats.combo_stagger_duration
	#combo_pre_final_delay_multiplier = stats.combo_pre_final_delay_multiplier
	#melee_slash_spawn_delay = stats.melee_slash_spawn_delay
	#combo_pause_time = stats.combo_pause_time
#
#func ready_new_player() -> void:
	#if stats == null:
		#return
#
	#player_stats = stats.get_entity_stats()
	#player_stats["lunge_distance"] = lunge_distance
	#player_stats["lunge_duration"] = lunge_duration
#
	#player_weapon = stats.get_entity_weapon()
#
	#var sprite_path := ""
	#if stats.class_obj is Dictionary:
		#sprite_path = str(stats.class_obj.get("sprite_path", ""))
	#if sprite_path != "":
		#sprite.texture = load(sprite_path)
#
## ---------------- PROCESS ----------------
#func _physics_process(delta: float) -> void:
	## Only process input if this is the authority player (when multiplayer is active).
	## Avoid calling multiplayer APIs when no peer exists (they spam errors).
	#if _local_is_authority():
		#if Input.is_action_pressed("Block"):
			#shield.activate_shield(self )
		#else:
			#shield.deactivate_shield()
#
	#if _net_active() and not is_multiplayer_authority():
		#_sync_state()
		#return
#
	## Handle knockback - must be first, overrides everything
	#if knockback_timer > 0.0:
		#knockback_timer -= delta
		#velocity = velocity.move_toward(Vector2.ZERO, 1000 * delta)
		#move_and_slide()
		#_sync_state()
		#return
	#
	#var raw_input_dir := Vector2(
		#Input.get_action_strength("D") - Input.get_action_strength("A"),
		#Input.get_action_strength("S") - Input.get_action_strength("W")
	#)
#
	#var input_dir := raw_input_dir
	#var is_currently_attacking = attack_component and attack_component.get_attack_state() != AttackComponent.AttackState.IDLE
	#
	#if _local_is_authority():
		#if input_dir != Vector2.ZERO:
			#net_last_direction = input_dir.normalized()
			## Only update facing direction when NOT attacking
			#if not is_currently_attacking:
				#print("[DEBUG _physics_process INPUT] Updating facing_direction from ", facing_direction, " to ", net_last_direction)
				#facing_direction = net_last_direction
				#last_direction = net_last_direction
			#else:
				#print("[DEBUG _physics_process INPUT] BLOCKED facing_direction update (attacking). input=", net_last_direction, " current facing=", facing_direction)
		#elif velocity != Vector2.ZERO and not is_currently_attacking:
			#last_direction = velocity.normalized()
#
#
	## Early return if nothing is happening
	#if input_dir == Vector2.ZERO and \
	   #not _is_dashing and \
	   #_lunge_time_left <= 0.0 and \
	   #(not attack_component or not attack_component.get_attack_is_holding()) and \
	   #stagger_timer <= 0.0 and \
	   #knockback_timer <= 0.0:
		## Update animation / state so we don't get stuck walking
		#var idle_dir := last_direction
		#update_animation_parameters(idle_dir)
#
		#if (not attack_component) or (attack_component.get_attack_state() == AttackComponent.AttackState.IDLE):
			#state_machine.travel("Idle")
		#return
#
	## LOCK MOVEMENT DURING LUNGE, DASH, OR CHARGE
	#if _lunge_time_left > 0.0 or _is_dashing or (attack_component and attack_component.get_is_charging()):
		#input_dir = Vector2.ZERO
#
	#if _dash_cooldown_left > 0.0:
		#_dash_cooldown_left = max(_dash_cooldown_left - delta, 0.0)
#
	## Stagger: lock movement briefly (but allow dash to escape)
	#if stagger_timer > 0.0:
		#stagger_timer = max(stagger_timer - delta, 0.0)
		#input_dir = Vector2.ZERO
#
	#if input_dir != Vector2.ZERO and not is_currently_attacking:
		#net_last_direction = input_dir.normalized()
		#facing_direction = net_last_direction
#
#
	#if _is_dashing:
		#_dash_time_left -= delta
		#velocity = _dash_velocity
		#if _dash_time_left <= 0.0:
			#_is_dashing = false
			#_dash_cooldown_left = dash_cooldown
	#elif _lunge_time_left > 0.0:
		#_lunge_time_left -= delta
		#if _lunge_time_left > lunge_pause_time:
			#velocity = _lunge_velocity # burst phase
		#else:
			#velocity = Vector2.ZERO # pause phase
			#if _lunge_time_left <= lunge_pause_time and attack_component:
				#attack_component.maybe_spawn_payload_during_lunge_pause()
#
	#else:
		#if _movement_locked:
			#velocity = Vector2.ZERO
		#else:
			#var current_speed := move_speed
			## ✅ Slow down if charging heavy attack
			#if _local_is_authority():
				#if attack_component and attack_component.get_attack_is_holding() and attack_component.attack_hold_time >= attack_component.heavy_threshold:
					#current_speed *= _movement_slowed
			#velocity = input_dir * current_speed
#
	#move_and_slide()
#
	#if Input.is_action_just_pressed("dash") \
	#and not _is_dashing \
	#and _dash_cooldown_left <= 0.0 \
	#and (not attack_component or attack_component.get_attack_state() == AttackComponent.AttackState.IDLE):
		## Allow escaping stagger by dashing, but not during attack combos
		#stagger_timer = 0.0
		#_start_dash(input_dir)
#
	## Use facing_direction (locked during attacks) instead of velocity for animation
	#var animation_direction = facing_direction if is_currently_attacking else (velocity.normalized() if velocity != Vector2.ZERO else facing_direction)
	#print("[DEBUG _physics_process] is_currently_attacking=", is_currently_attacking, " animation_direction=", animation_direction, " facing_direction=", facing_direction, " velocity=", velocity)
	#update_animation_parameters(animation_direction)
#
	#if _local_is_authority():
		#pick_new_state() # only authority decides attack state
	#else:
		## remote players already sync animation state via sync_remote_state
		#pass
#
	#_sync_state()
## ---------------- MULTIPLAYER SYNC ----------------
#func _sync_state() -> void:
	#if not _net_active():
		#return
	#if not is_multiplayer_authority():
		#return
	#rpc(
		#"sync_remote_state",
		#global_position,
		#velocity,
		#net_last_direction,
		#(attack_component and attack_component.get_attack_state() != AttackComponent.AttackState.IDLE),
		#_is_dashing,
		#_lunge_time_left,
		#health_component.get_hp() if health_component else 0.0,
		#damage_percent,
		#knockback_timer,
		#is_dead,
		#stocks
	#)
#
#@rpc("unreliable", "any_peer")
#func sync_remote_state(
	#pos: Vector2,
	#vel: Vector2,
	#dir: Vector2,
	#remote_is_attacking: bool,
	#remote_is_dashing: bool,
	#remote_lunge_time_left: float,
	#remote_hp: float,
	#remote_damage_percent: float,
	#remote_knockback_timer: float,
	#remote_is_dead: bool,
	#remote_stocks: int
#) -> void:
	#if _net_active() and is_multiplayer_authority():
		#return
#
	#global_position = pos
	#velocity = vel
	#if vel != Vector2.ZERO:
		#net_last_direction = dir
	#if attack_component:
		#attack_component.set_remote_attacking(remote_is_attacking)
	#_is_dashing = remote_is_dashing
	#_lunge_time_left = remote_lunge_time_left
	#if health_component:
		#health_component.set_hp(remote_hp)
	#damage_percent = remote_damage_percent
	#knockback_timer = remote_knockback_timer
	#is_dead = remote_is_dead
	#stocks = remote_stocks
#
	## Apply death visuals on non-authority instances
	#if is_dead:
		#visible = false
		#if player_hitbox:
			#player_hitbox.set_deferred("monitoring", false)
			#player_hitbox.set_deferred("monitorable", false)
	#else:
		#visible = true
		#if player_hitbox:
			#player_hitbox.set_deferred("monitoring", true)
			#player_hitbox.set_deferred("monitorable", true)
#
	#update_animation_parameters(velocity.normalized() if velocity != Vector2.ZERO else net_last_direction)
	#pick_new_state()
#@rpc("reliable", "any_peer", "call_local")
#func rpc_show_damage_number(amount: int, pos: Vector2) -> void:
	#if damage_number_scene == null:
		#return
	#var dn := damage_number_scene.instantiate()
	#get_tree().current_scene.add_child(dn)
#
	#if dn.has_method("setup"):
		#dn.call("setup", amount, pos)
	#else:
		#(dn as Node2D).global_position = pos
#
#func _start_attack_hitbox() -> void:
	#print("[DEBUG _start_attack_hitbox] local_attack_facing=", local_attack_facing, " facing_direction=", facing_direction, " last_direction=", last_direction)
	#if not attack_hitbox:
		#return
#
	#_update_attack_hitbox_position()
	#var shape = attack_hitbox.get_node_or_null("CollisionShape2D")
	#if shape:
		#shape.disabled = false
	#attack_hitbox.set_deferred("monitoring", true)
	#_attack_hitbox_enabled = true
#
#func _update_attack_hitbox_position() -> void:
	#if not attack_hitbox:
		#return
	#var dir := local_attack_facing
	#print("[DEBUG _update_attack_hitbox_position] local_attack_facing=", dir)
	#if dir.x < 0:
		#attack_hitbox.position = Vector2(-6, -4)
	#elif dir.x > 0:
		#attack_hitbox.position = Vector2(6, -4)
	#elif dir.y < 0:
		#attack_hitbox.position = Vector2(0, -12)
	#elif dir.y > 0:
		#attack_hitbox.position = Vector2(0, 7)
#
#func _stop_attack_hitbox() -> void:
	#print("[DEBUG _stop_attack_hitbox] called")
	#if not attack_hitbox:
		#return
	#var shape = attack_hitbox.get_node_or_null("CollisionShape2D")
	#attack_hitbox.set_deferred("monitoring", false)
	#_attack_hitbox_enabled = false
	#if shape:
		#shape.disabled = true
#
## ---------------- HELPERS ----------------
#func _start_dash(dir: Vector2) -> void:
	## If no input direction, dash toward where the player is facing
	#if dir == Vector2.ZERO:
		#if local_attack_facing != Vector2.ZERO:
			#dir = local_attack_facing
		#elif facing_direction != Vector2.ZERO:
			#dir = facing_direction
		#else:
			#dir = last_direction # final fallback
#
	#_is_dashing = true
	#_dash_time_left = dash_duration
	#_dash_velocity = dir.normalized() * dash_speed
	#facing_direction = dir
#
#
#func _show_damage_number(amount: int) -> void:
	#if amount <= 0:
		#return
#
	#var spawn_pos := global_position + Vector2(0, -20)
	#var marker := get_node_or_null("DamageSpawn")
	#if marker != null and marker is Node2D:
		#spawn_pos = (marker as Node2D).global_position
#
	## Broadcast to everyone (including self)
	#rpc("rpc_show_damage_number", amount, spawn_pos)
#
#
#func update_animation_parameters(dir: Vector2) -> void:
	#animation_tree.set("parameters/Idle/blend_position", dir)
	#animation_tree.set("parameters/Walk/blend_position", dir)
	#animation_tree.set("parameters/Attack/blend_position", dir)
#
#func pick_new_state() -> void:
	#var astate := (attack_component.get_attack_state() if attack_component else AttackComponent.AttackState.IDLE)
	#print("[DEBUG pick_new_state] attack_state=", astate, " velocity=", velocity, " facing_direction=", facing_direction)
	#if astate == AttackComponent.AttackState.IDLE:
		#if _is_dashing or velocity != Vector2.ZERO:
			#state_machine.travel("Walk")
		#else:
			#state_machine.travel("Idle")
	#elif astate == AttackComponent.AttackState.STARTUP or astate == AttackComponent.AttackState.ACTIVE:
		#print("[DEBUG pick_new_state] Switching to Attack state")
		#state_machine.travel("Attack")
	#elif astate == AttackComponent.AttackState.RECOVERY or astate == AttackComponent.AttackState.COMBO_WINDOW:
		## Let it fall back to Idle/Walk so next hit retriggers Attack
		#if velocity != Vector2.ZERO:
			#state_machine.travel("Walk")
		#else:
			#state_machine.travel("Idle")
#
#
## ---------------- HITBOX SETUP ----------------
#func _setup_hitboxes() -> void:
	## Setup player hitbox for receiving damage
	#if player_hitbox:
		#player_hitbox.monitoring = true
		#player_hitbox.monitorable = true
		#player_hitbox.body_entered.connect(_on_player_hitbox_body_entered)
		#player_hitbox.area_entered.connect(_on_player_hitbox_area_entered)
#
	#
#func _on_player_hitbox_body_entered(body: Node) -> void:
	## This is for receiving hits - handled via RPC
	#pass
#
#func _on_player_hitbox_area_entered(area: Area2D) -> void:
	## Debug receiver: confirms the slash Area2D overlaps this player.
	#var src := area.get_parent()
	#print("[RECV] PlayerHitbox area_entered from=", (src.name if src else area.name))
#
#@rpc("reliable", "any_peer", "call_local")
#func receive_hit(direction: Vector2, damage: float) -> void:
	## Only the authority for this player applies damage/knockback; it will sync to others.
	#if not _local_is_authority():
		#return
	#print("[HIT] receive_hit on=", name, " dmg=", damage)
	#take_hit(direction, damage)
#
#@rpc("reliable", "any_peer", "call_local")
#func receive_combo_hit(direction: Vector2, damage: float, p_combo_step: int, combo_total_hits: int) -> void:
	## First two combo hits stagger only; final hit applies knockback.
	#if not _local_is_authority():
		#return
	#print("[HIT] receive_combo_hit on=", name, " dmg=", damage, " step=", p_combo_step, " total=", combo_total_hits)
	#var max_hits: int = maxi(combo_total_hits, 1)
	#var is_final: bool = p_combo_step >= (max_hits - 1)
	#if is_final:
		#take_hit(direction, damage, true)
	#else:
		#take_hit(direction, damage, false, combo_stagger_duration)
#
#@rpc("reliable", "any_peer")
#func apply_hit_to_server(target_id: int, direction: Vector2, damage: float) -> void:
	## Only server processes this - route to manager
	#print(
		#"[RPC] apply_hit_to_server recv on=", name,
		#" net_active=", _net_active(),
		#" is_server=", (multiplayer.is_server() if _net_active() else false),
		#" from_sender=", (multiplayer.get_remote_sender_id() if _net_active() else -1),
		#" target_id=", target_id,
		#" dmg=", damage,
		#" parent=", get_parent().name
	#)
	#if not _net_active() or not multiplayer.is_server():
		#return
#
	#var manager = get_parent()
	#if manager and manager.has_method("apply_hit_to_player"):
		#print("[RPC] routing to manager.apply_hit_to_player target_id=", target_id)
		#manager.apply_hit_to_player(target_id, direction, damage)
	#else:
		#print("[RPC] manager missing apply_hit_to_player; manager=", manager)
#
#
#func take_hit(direction: Vector2, hp_damage: float, apply_knockback: bool = true, p_stagger_time: float = 0.0) -> void:
	#if not _local_is_authority():
		#return
	#if is_dead:
		#return
#
	## Getting hit cancels your attack state.
	#if attack_component:
		#attack_component.reset_attack_state()
	#hp -= hp_damage
	#hp = max(hp, 0)
	#player_healthbar.health = hp
	#_show_damage_number(int(round(hp_damage)))
	#print("take_hit called, damage=", hp_damage) # 🔎 Debug
#
	#damage_percent += HIT_DAMAGE_PERCENT
	#var kb_mult := (attack_component.get_knockback_mult() if attack_component else 1.0)
	#var scaled_knockback = BASE_KNOCKBACK * (1.0 + damage_percent / 100.0) * kb_mult
#
	#if apply_knockback:
		## Apply knockback velocity immediately
		#velocity = direction.normalized() * scaled_knockback
		#knockback_timer = KNOCKBACK_DURATION
		#stagger_timer = 0.0
	#else:
		## Stagger: no push, just lock movement for a bit
		#velocity = Vector2.ZERO
		#knockback_timer = 0.0
		#stagger_timer = max(stagger_timer, max(p_stagger_time, 0.0))
	## Stop any ongoing attacks/movement
	#_lunge_time_left = 0.0
	#_is_dashing = false
#
	#print(
		#name,
		#" took hit | HP:",
		#health_component.get_hp() if health_component else 0.0,
		#" | %:",
		#damage_percent,
		#" | KB:",
		#(scaled_knockback if apply_knockback else 0.0),
		#" | stagger:",
		#(stagger_timer if not apply_knockback else 0.0)
	#)
#
	#if health_component and health_component.get_hp() <= 0:
		#die()
#
#func die() -> void:
	#if is_dead:
		#return
	#is_dead = true
	#if attack_component:
		#attack_component.reset_attack_state()
	#visible = false
	#velocity = Vector2.ZERO
	#knockback_timer = 0.0
	#stagger_timer = 0.0
	#_lunge_time_left = 0.0
	#_is_dashing = false
#
	## Stop taking hits / stop movement
	#if player_hitbox:
		#player_hitbox.set_deferred("monitoring", false)
		#player_hitbox.set_deferred("monitorable", false)
	#set_physics_process(false)
#
	#stocks -= 1
	#if _net_active():
		#_sync_state()
	#if stocks <= 0:
		#return
#
	#await get_tree().create_timer(respawn_delay).timeout
	#respawn()
#
#func respawn() -> void:
	## In multiplayer, only authority should respawn and sync to others
	#if _net_active() and not is_multiplayer_authority():
		#return
#
	#is_dead = false
	#if attack_component:
		#attack_component.reset_attack_state()
	#global_position = respawn_position
	#velocity = Vector2.ZERO
	#damage_percent = 0.0
	#knockback_timer = 0.0
	#stagger_timer = 0.0
	#_lunge_time_left = 0.0
	#_lunge_velocity = Vector2.ZERO
#
	## Restore HP to class HP if available
	#if health_component:
		#var max_hp = float(player_stats.get("hp", 100.0))
		#health_component.set_max_hp(max_hp)
		#health_component.revive(max_hp)
	#visible = true
	#if player_hitbox:
		#player_hitbox.set_deferred("monitoring", true)
		#player_hitbox.set_deferred("monitorable", true)
	#set_physics_process(true)
	#if _net_active():
		#_sync_state()
