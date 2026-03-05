extends Node2D

const DEBUG_HITS := false

@export var slash_effect = "slash"
@export var attacker_id: int = -1
@export var attacker_team: int = -1
@export var damage: float = 0.0
@export var combo_step: int = 0
@export var combo_total_hits: int = 1
@export var hits_players: bool = true
@export var hits_dummies: bool = true

@export var follow_mouse: bool = true
@export var fixed_rotation: float = 0.0
@export var use_network_aim: bool = false
@export var network_aim_pos: Vector2 = Vector2.ZERO

# NEW: set by AttackComponent when spawning the slash
@export var knockback_mult: float = 1.0
var attacker_node_cached: Node = null

@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var area: Area2D = $Area2D

var weapon_damage: float = 1.0
var _hit_targets: Dictionary = {}


func set_attack_context(p_attacker_id: int, p_attacker_team: int, p_damage: float, p_combo_step: int, p_combo_total_hits: int) -> void:
	attacker_id = p_attacker_id
	attacker_team = p_attacker_team
	damage = p_damage
	combo_step = p_combo_step
	combo_total_hits = max(p_combo_total_hits, 1)


func _ready() -> void:
	if area:
		area.monitoring = true
		area.monitorable = true
		if not area.body_entered.is_connected(_on_area_2d_body_entered):
			area.body_entered.connect(_on_area_2d_body_entered)
		if not area.area_entered.is_connected(_on_area_2d_area_entered):
			area.area_entered.connect(_on_area_2d_area_entered)

	# -------------------------
	# LIGHT ATTACK (mouse aim)
	# -------------------------
	if follow_mouse:
		var mouse_position: Vector2 = get_global_mouse_position()
		if use_network_aim:
			mouse_position = network_aim_pos

		var dir: Vector2 = (mouse_position - global_position).normalized()
		look_at(mouse_position)

		var angle_deg: float = rad_to_deg(dir.angle())
		var ART_OFFSET_DEG: float = 0.0

		sprite.rotation = deg_to_rad(angle_deg + ART_OFFSET_DEG)
		sprite.flip_h = true

	# -------------------------
	# HEAVY ATTACK (fixed)
	# -------------------------
	else:
		rotation = deg_to_rad(fixed_rotation)
		sprite.rotation = deg_to_rad(fixed_rotation)
		sprite.flip_h = false

	# Final combo hit scaling (visual)
	if combo_step >= combo_total_hits - 1:
		sprite.scale = Vector2(1.2, 1.2)
		area.scale = Vector2(1.2, 1.2)

	animation_player.play(slash_effect)

	# Cache attacker node (AttackComponent should set attacker_node_cached directly.
	# Fallback: try find by attacker_id if needed.)
	if attacker_node_cached == null and attacker_id >= 0:
		var scene_root := get_tree().current_scene
		if scene_root:
			attacker_node_cached = scene_root.get_node_or_null(str(attacker_id))


func _process(_delta: float) -> void:
	if not follow_mouse and area:
		var ROT_OFFSET_DEG: float = -35.0
		if combo_step % 2 == 1:
			ROT_OFFSET_DEG = 40.0

		var rot_offset := deg_to_rad(ROT_OFFSET_DEG)

		var HITBOX_DISTANCE: float = 5.0
		if combo_step % 2 == 1:
			HITBOX_DISTANCE = 15.0

		var offset := Vector2(HITBOX_DISTANCE, 0).rotated(sprite.global_rotation + rot_offset)
		area.global_position = sprite.global_position + offset
		area.global_rotation = sprite.global_rotation + PI + rot_offset
		area.global_scale = sprite.global_scale


func _on_area_2d_body_entered(body: Node2D) -> void:
	if DEBUG_HITS:
		print("[SLASH] body_entered:", body.name, " type=", body.get_class())


func _on_area_2d_area_entered(hit_area: Area2D) -> void:
	if DEBUG_HITS:
		print("[SLASH] area_entered:", hit_area.name)

	var hit_owner := hit_area.get_parent() as Node2D
	if hit_owner == null:
		return

	# Skip hitting yourself (by numeric name convention)
	if hit_owner.name.is_valid_int() and hit_owner.name == str(attacker_id):
		if DEBUG_HITS:
			print("[DEBUG] Ignored self-hit from slash")
		return

	# -------------------------
	# HITBOX COMPONENT (PLAYERS)
	# -------------------------
	var hitbox: HitboxComponent = hit_area as HitboxComponent
	if hitbox != null and hits_players:
		# Team check
		if hitbox.is_same_team(attacker_team):
			if DEBUG_HITS:
				print("[DEBUG] Ignored teammate hit (team=", hitbox.team, ")")
			return

		# Avoid multi-hit spam
		var key := str(hit_owner.get_instance_id())
		if _hit_targets.has(key):
			return
		_hit_targets[key] = true

		# Damage and direction
		var dmg: float = damage if damage > 0.0 else weapon_damage
		var dir: Vector2 = (hit_owner.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT

		# FINAL HIT ONLY launches (meter still increases inside HitboxComponent)
		var is_final_hit: bool = (combo_step >= combo_total_hits - 1)

		# Apply damage
		hitbox.take_damage(dmg, attacker_node_cached, dir, is_final_hit, knockback_mult)
		return

	# -------------------------
	# DUMMIES / DESTRUCTIBLES
	# -------------------------
	if hit_owner.has_method("take_damage") and hits_dummies:
		var key_dummy := str(hit_owner.get_instance_id())
		if _hit_targets.has(key_dummy):
			return
		_hit_targets[key_dummy] = true

		var dmg_dummy: float = damage if damage > 0.0 else weapon_damage
		hit_owner.call("take_damage", dmg_dummy)
		return

	if DEBUG_HITS:
		print("[SLASH] area_entered:", hit_area.name, " owner=", hit_owner.name)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == slash_effect:
		queue_free()
