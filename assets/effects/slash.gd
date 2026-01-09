extends Node2D

const DEBUG_HITS := false

@export var slash_effect = "slash"
@export var attacker_id: int = -1
@export var attacker_team: int = -1
@export var damage: float = 0.0
@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var area: Area2D = $Area2D

var weapon_damage: float = 1.0
var _hit_targets: Dictionary = {}

func set_attack_context(p_attacker_id: int, p_attacker_team: int, p_damage: float) -> void:
	attacker_id = p_attacker_id
	attacker_team = p_attacker_team
	damage = p_damage

func _ready():
	print("[SLASH] ready attacker_id=", attacker_id, " team=", attacker_team, " dmg=", damage)
	# Ensure we log hits whether the target is a PhysicsBody or an Area2D hitbox.
	if area:
		area.monitoring = true
		area.monitorable = true
		if not area.body_entered.is_connected(_on_area_2d_body_entered):
			area.body_entered.connect(_on_area_2d_body_entered)
		if not area.area_entered.is_connected(_on_area_2d_area_entered):
			area.area_entered.connect(_on_area_2d_area_entered)

	var mouse_position = get_global_mouse_position()
	look_at(mouse_position)
	
	if mouse_position.x > global_position.x:
		sprite.rotation = 45.0
		sprite.flip_h = true
	else:
		sprite.rotation = 90.0
	
	animation_player.play(slash_effect)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if DEBUG_HITS:
		print("[SLASH] body_entered:", body.name, " type=", body.get_class())

func _on_area_2d_area_entered(hit_area: Area2D) -> void:
	var owner := hit_area.get_parent() as Node2D
	if DEBUG_HITS:
		print(
			"[SLASH] area_entered:",
			hit_area.name,
			" owner=",
			(owner.name if owner else "null"),
			" owner_type=",
			(owner.get_class() if owner else "null")
		)

	# Apply knockback/damage via the player's RPC handler (runs on target authority).
	if owner == null:
		return
	if owner.name.is_valid_int() and owner.name == str(attacker_id):
		return
	if owner.has_method("get") and int(owner.get("team")) == attacker_team:
		return
	if not owner.has_method("receive_hit"):
		return

	# Avoid multi-hit spam for a single slash animation.
	var key := owner.name
	if _hit_targets.has(key):
		return
	_hit_targets[key] = true
	print("[SLASH] HIT confirmed target=", key, " dmg=", (damage if damage > 0.0 else weapon_damage))

	var dir: Vector2 = (owner.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var dmg := damage if damage > 0.0 else weapon_damage
	var target_auth := owner.get_multiplayer_authority()
	print("[SLASH] applying hit target=", owner.name, " target_auth=", target_auth, " dmg=", dmg)
	# Guard: don't call RPCs when multiplayer isn't active (or authority is invalid).
	var mp := multiplayer.multiplayer_peer
	if mp == null or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		# Offline / not connected: apply locally (player script treats local as authority)
		owner.receive_hit(dir, dmg)
		return
	if target_auth <= 0:
		return
	owner.receive_hit.rpc_id(target_auth, dir, dmg)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == slash_effect:
		queue_free()
