extends Node2D
class_name ShieldComponent

signal shield_broken() # fire when shield HP hits 0 (use this to stun player)

@export var offset_distance: float = 5.0
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $HitboxComponent
@export var hitbox_shape: HitboxComponent # kept as you had it

@export var max_shield_hp: float = 10.0
@export var shield_hp: float = 10.0
@export var broken_recover_percent_per_sec: float = 0.50 # 50% of max per second

# Shield bar
@export var shield_bar: ShieldBarComponent

var _is_broken: bool = false

# Block tuning
@export var damage_mult_while_blocking: float = 1.0
@export var knockback_mult_while_blocking: float = 0.25
@export var block_arc_degrees: float = 140.0

# Regen
@export var regen_per_sec: float = 2.0
@export var regen_delay_after_hit: float = 0.5

# Debug
@export var debug_shield: bool = false

var _player: Node2D = null
var is_active: bool = false

var _regen_delay_timer: float = 0.0
var _did_emit_break: bool = false


func _ready() -> void:
	visible = false
	if hitbox:
		hitbox.monitoring = false

	shield_hp = clamp(shield_hp, 0.0, max_shield_hp)

	if shield_bar:
		shield_bar.init_shield(max_shield_hp)
		shield_bar.shield = shield_hp


func activate_shield(player: Node2D) -> void:
	if _is_broken:
		return

	_player = player
	is_active = true
	visible = true
	if hitbox:
		hitbox.monitoring = true
	_update_position(player)


func deactivate_shield() -> void:
	_player = null
	is_active = false
	visible = false
	if hitbox:
		hitbox.monitoring = false


func _process(delta: float) -> void:
	# Broken recovery
	if _is_broken:
		var recover_rate: float = max_shield_hp * broken_recover_percent_per_sec
		shield_hp = min(shield_hp + recover_rate * delta, max_shield_hp)
		_update_shield_bar()

		if shield_hp > 0.0:
			_is_broken = false
			_did_emit_break = false

		if is_active:
			deactivate_shield()

		return

	# Normal regen only when shield is not active
	if not is_active:
		if _regen_delay_timer > 0.0:
			_regen_delay_timer = max(_regen_delay_timer - delta, 0.0)
		elif shield_hp < max_shield_hp:
			shield_hp = min(shield_hp + regen_per_sec * delta, max_shield_hp)
			_update_shield_bar()

	# Follow player / aim only when active
	if not is_active or _player == null:
		return

	_update_position(_player)


func _update_position(player: Node2D) -> void:
	var dir: Vector2 = (get_global_mouse_position() - player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	position = dir * offset_distance
	rotation = dir.angle()


func _get_facing_dir() -> Vector2:
	return Vector2.RIGHT.rotated(global_rotation)


func blocks_attack_from(attacker: Node) -> bool:
	if not is_active or _player == null:
		return false
	if attacker == null or not (attacker is Node2D):
		return true

	var attacker_2d: Node2D = attacker as Node2D
	var to_attacker: Vector2 = (attacker_2d.global_position - _player.global_position).normalized()
	if to_attacker == Vector2.ZERO:
		return true

	var facing: Vector2 = _get_facing_dir()
	var half_arc: float = deg_to_rad(block_arc_degrees * 0.5)
	return abs(facing.angle_to(to_attacker)) <= half_arc


# Returns leftover damage that should go to player HP
func absorb_damage(dmg: float) -> float:
	if dmg <= 0.0:
		return 0.0

	_regen_delay_timer = regen_delay_after_hit

	var before: float = shield_hp
	var absorbed: float = minf(shield_hp, dmg)
	shield_hp -= absorbed
	var leftover: float = dmg - absorbed

	if shield_hp <= 0.0 and not _did_emit_break:
		shield_hp = 0.0
		_is_broken = true
		_did_emit_break = true
		deactivate_shield()
		shield_broken.emit()

	_update_shield_bar()

	if debug_shield:
		print(
			"[SHIELD] before=", snappedf(before, 0.01),
			" dmg_in=", snappedf(dmg, 0.01),
			" absorbed=", snappedf(absorbed, 0.01),
			" after=", snappedf(shield_hp, 0.01),
			" leftover=", snappedf(leftover, 0.01),
			" regen_delay=", snappedf(_regen_delay_timer, 0.01)
		)

	return leftover


func _update_shield_bar() -> void:
	if shield_bar:
		shield_bar.shield = shield_hp
