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
@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var area: Area2D = $Area2D
@export var follow_mouse: bool = true
@export var fixed_rotation: float = 0.0
@export var use_network_aim: bool = false
@export var network_aim_pos: Vector2 = Vector2.ZERO

var weapon_damage: float = 1.0
var _hit_targets: Dictionary = {}

func set_attack_context(p_attacker_id: int, p_attacker_team: int, p_damage: float, p_combo_step: int, p_combo_total_hits: int) -> void:
	attacker_id = p_attacker_id
	attacker_team = p_attacker_team
	damage = p_damage
	combo_step = p_combo_step
	combo_total_hits = p_combo_total_hits

func _ready():
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


		# Compute the angle in degrees from right (0°)
		var angle_deg := rad_to_deg(dir.angle())

		# Base art offset (how your sprite is drawn by default facing right)
		var ART_OFFSET_DEG := 0.0

		# Rotate the sprite properly
		sprite.rotation = deg_to_rad(angle_deg + ART_OFFSET_DEG)

		# Flip vertically or horizontally if needed (depends on art)
		sprite.flip_h = true # optional if sprite art is symmetric


	# -------------------------
	# HEAVY ATTACK (fixed)
	# -------------------------
	else:
		# Rotate the slash node to the heavy direction
		rotation = deg_to_rad(fixed_rotation)

		# Sprite keeps its visual offset for the art
		sprite.rotation = deg_to_rad(fixed_rotation)
		sprite.flip_h = false
		# ❌ Do NOT rotate area here anymore

	# Final combo hit scaling
	if combo_step >= combo_total_hits - 1:
		sprite.scale = Vector2(1.2, 1.2)
		area.scale = Vector2(1.2, 1.2)

	animation_player.play(slash_effect)

func _process(_delta):
	if not follow_mouse and area:
		# Default rotation offset for hitbox
		var ROT_OFFSET_DEG := -35.0

		# Apply special rotation offset for combo steps (e.g., every 2 hits)
		if combo_step % 2 == 1: # step 1, 3, 5, etc. (every 2nd hit visually)
			ROT_OFFSET_DEG = 40.0

		var rot_offset := deg_to_rad(ROT_OFFSET_DEG)

		# Distance from the sprite center (tweak per combo if needed)
		var HITBOX_DISTANCE := 5.0
		if combo_step % 2 == 1:
			HITBOX_DISTANCE = 15.0 # slightly farther for every 2nd hit

		# Position the hitbox in front of the sprite
		var offset := Vector2(HITBOX_DISTANCE, 0).rotated(sprite.global_rotation + rot_offset)
		area.global_position = sprite.global_position + offset
		area.global_rotation = sprite.global_rotation + PI + rot_offset
		area.global_scale = sprite.global_scale

func _on_area_2d_body_entered(body: Node2D) -> void:
	if DEBUG_HITS:
		print("[SLASH] body_entered:", body.name, " type=", body.get_class())

func _on_area_2d_area_entered(hit_area: Area2D) -> void:
	print('entered')
	var hit_owner := hit_area.get_parent() as Node2D
	if hit_owner == null:
		return

	# Skip hitting yourself
	if hit_owner.name.is_valid_int() and hit_owner.name == str(attacker_id):
		if DEBUG_HITS:
			print("[DEBUG] Ignored self-hit from slash")
		return

	# -------------------------
	# HITBOX COMPONENT (PLAYERS)
	# -------------------------
	var hitbox: HitboxComponent = hit_area as HitboxComponent
	if hitbox != null and hits_players:
		# Check team using HitboxComponent's method
		if hitbox.is_same_team(attacker_team):
			if DEBUG_HITS:
				print("[DEBUG] Ignored teammate hit (team=", hitbox.team, ")")
			return

		# Avoid multi-hit spam
		var key := str(hit_owner.get_instance_id())
		if _hit_targets.has(key):
			return
		_hit_targets[key] = true

		# Calculate damage and direction
		var dmg := damage if damage > 0.0 else weapon_damage
		var dir: Vector2 = (hit_owner.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT

		# Try to find attacker node
		var attacker_node: Node = null
		if attacker_id >= 0:
			var scene_root = get_tree().current_scene
			if scene_root:
				attacker_node = scene_root.get_node_or_null(str(attacker_id))

		# Apply damage via HitboxComponent
		hitbox.take_damage(dmg, attacker_node, dir)
		return

	# -------------------------
	# DUMMIES / DESTRUCTIBLES
	# -------------------------
	if hit_owner.has_method("take_damage") and hits_dummies:
		var key_dummy := str(hit_owner.get_instance_id())
		if _hit_targets.has(key_dummy):
			return
		_hit_targets[key_dummy] = true

		var dmg_dummy := damage if damage > 0.0 else weapon_damage
		hit_owner.call("take_damage", dmg_dummy)
		return

	# -------------------------
	# DEBUG
	# -------------------------
	if DEBUG_HITS:
		print("[SLASH] area_entered:", hit_area.name, " owner=", hit_owner.name)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == slash_effect:
		queue_free()
