extends CharacterBody2D

# Player-specific life cycle: death -> respawn countdown -> respawn with a
# short invulnerable window, until the lives run out. Combat, movement and
# animation all live in the components under ComponentGroup.

signal respawned
signal out_of_lives

## Total lives. Dying uses one; at 0 left it is game over. Negative = infinite.
@export var lives: int = 3
@export var respawn_delay: float = 3.0
## Hurtbox is disabled (and the sprite blinks) for this long after respawning.
@export var invulnerable_time: float = 1.5
## Where to respawn. Zero = where the player started.
@export var respawn_position: Vector2 = Vector2.ZERO

@onready var _health: HealthComponent = $ComponentGroup/HealthComponent
@onready var _hitbox: HitboxComponent = $ComponentGroup/HitboxComponent
@onready var _combat: CombatComponent = $ComponentGroup/CombatComponent
@onready var _shield: ShieldComponent = $ComponentGroup/ShieldComponent
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = get_node_or_null("CanvasLayer/Label") as Label

var _spawn_position: Vector2 = Vector2.ZERO
var _status_label: Label
var _game_over: bool = false


func _ready() -> void:
	_spawn_position = global_position
	_build_status_label()
	_health.died.connect(_on_died)
	_update_lives_label()


func _on_died() -> void:
	if lives > 0:
		lives -= 1
	_update_lives_label()
	if lives == 0:
		_game_over = true
		_show_status("GAME OVER")
		out_of_lives.emit()
		return

	var remaining := respawn_delay
	while remaining > 0.0:
		_show_status("Respawning in %d" % ceili(remaining))
		await get_tree().create_timer(0.1, true, false, true).timeout
		if not is_inside_tree():
			return
		remaining -= 0.1
	respawn()


func respawn() -> void:
	if _game_over:
		return
	global_position = respawn_position if respawn_position != Vector2.ZERO else _spawn_position
	velocity = Vector2.ZERO
	_health.revive()
	_hitbox.knockback_scale = _hitbox.knockback_scale_start
	_shield.reset()
	_combat.revive()
	_show_status("")
	respawned.emit()
	_run_invulnerability()


func _run_invulnerability() -> void:
	_hitbox.can_be_hit = false
	var elapsed := 0.0
	while elapsed < invulnerable_time:
		_sprite.visible = fmod(elapsed, 0.2) < 0.1
		await get_tree().create_timer(0.05, true, false, true).timeout
		if not is_inside_tree():
			return
		elapsed += 0.05
	_sprite.visible = true
	_hitbox.can_be_hit = true


# ---- HUD ----

func _build_status_label() -> void:
	var layer := get_node_or_null("CanvasLayer")
	if layer == null:
		return
	_status_label = Label.new()
	_status_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status_label.offset_top = 20.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.visible = false
	layer.add_child(_status_label)


func _show_status(text: String) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.visible = text != ""


func _update_lives_label() -> void:
	if _name_label and lives >= 0:
		_name_label.text = "Player  x%d" % lives
