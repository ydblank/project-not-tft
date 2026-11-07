extends Node2D
class_name AnimationComponent

# Read-only view of the combat state: picks the AnimationTree state and blend
# direction, and draws charge shake/blink, block tint and the hit flash.

@export var combat_component: CombatComponent
@export var movement_component: MovementComponent

@export var animation_player_path: NodePath = NodePath("../AnimationPlayer")
@export var animation_tree_path: NodePath = NodePath("../AnimationTree")
@export var sprite_path: NodePath = NodePath("../Sprite2D")

@export_group("Animation States")
@export var idle_state_name: String = "Idle"
@export var walk_state_name: String = "Walk"
@export var attack_state_name: String = "Attack"
@export var block_state_name: String = "Block"
## Added to the AnimationTree at runtime (stagger / knockback).
@export var hurt_state_name: String = "Hurt"
## Added to the AnimationTree at runtime (dead).
@export var death_state_name: String = "Death"

@export_group("Feedback")
@export var block_tint: Color = Color(0.75, 0.85, 1.2, 1.0)
@export var hit_flash_color: Color = Color(1, 0.2, 0.2, 1)
@export var hit_flash_time: float = 0.08
@export var charge_shake_strength: float = 0.1
## Archers shiver while drawing a heavy shot (pixels; grows a little with the draw).
@export var ranged_charge_shake: float = 0.18
## Frame held while drawing a ranged heavy aimed left or right: the weapon-extended frame of the side attack.
## (Aimed up or down, or while walking, the normal animation plays and only the shiver shows.)
@export var aim_pose_frame: int = 115
## Faded look while the dash makes you untouchable.
@export var dash_tint: Color = Color(1, 1, 1, 0.5)
## Brief bright flash when a hit is blocked.
@export var block_flash_color: Color = Color(2.2, 2.2, 2.6, 1.0)
@export var block_flash_time: float = 0.1
## Afterimages left behind while dashing.
@export var dash_trail_enabled: bool = true
@export var dash_trail_color: Color = Color(0.6, 0.85, 1.0, 0.55)
@export var dash_trail_interval: float = 0.03

# Hurt / death frames in the character sheets (32px cells, 8 columns).
# "left" is the side view; "right" is the same row flipped.
const REACTION_DIRS := {
	"down": {"vec": Vector2(0, 1), "hurt_row": 3, "death_row": 9, "flip": false},
	"up": {"vec": Vector2(0, -1), "hurt_row": 4, "death_row": 10, "flip": false},
	"left": {"vec": Vector2(-1, 0), "hurt_row": 5, "death_row": 11, "flip": false},
	"right": {"vec": Vector2(1, 0), "hurt_row": 5, "death_row": 11, "flip": true},
}
const SHEET_COLUMNS := 8
const HURT_FRAMES := 2
const DEATH_FRAMES := 8
const HURT_FRAME_TIME := 0.1
const DEATH_FRAME_TIME := 0.08

var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var sprite: Sprite2D
var state_machine: AnimationNodeStateMachinePlayback

var _has_block_state: bool = false
var _has_reaction_states: bool = false
var _flash_left: float = 0.0
var _block_flash_left: float = 0.0
var _trail_timer: float = 0.0
var _aim_pose: bool = false
var _kick: Vector2 = Vector2.ZERO # push-back when a hit is blocked
var _charge_time: float = 0.0


func _ready() -> void:
	animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	animation_tree = get_node_or_null(animation_tree_path) as AnimationTree
	sprite = get_node_or_null(sprite_path) as Sprite2D
	if animation_tree:
		state_machine = animation_tree.get("parameters/playback")
		var root := animation_tree.tree_root as AnimationNodeStateMachine
		_has_block_state = root != null and root.has_node(block_state_name)
		_has_reaction_states = _install_reaction_states(root)
	if combat_component and combat_component.hitbox_component:
		combat_component.hitbox_component.hit_received.connect(_on_hit_received)
		combat_component.hitbox_component.hit_blocked.connect(_on_hit_blocked)
		combat_component.hitbox_component.blocked_hit.connect(_on_blocked_hit)
		combat_component.hitbox_component.parried.connect(_on_parried)
	_setup_block_visual.call_deferred() # the entity is still setting up its children


func _physics_process(delta: float) -> void:
	if combat_component == null or state_machine == null:
		return
	var state := combat_component.get_state()
	var facing := combat_component.get_facing()

	var drawing := _is_drawing_ranged_heavy(state, facing)
	_set_aim_pose(drawing)
	if drawing:
		_pose_aim(facing)
	else:
		_set_blend(facing)
		state_machine.travel(_pick_state(state))
	_update_feedback(state, delta)
	_update_dash_trail(state, delta)


func _pick_state(state: ActionStateMachine.State) -> String:
	if _has_reaction_states:
		match state:
			ActionStateMachine.State.STAGGER, ActionStateMachine.State.KNOCKBACK:
				return hurt_state_name
			ActionStateMachine.State.DEAD:
				return death_state_name
	match state:
		ActionStateMachine.State.ATTACK:
			var phase := combat_component.get_phase()
			if phase == ActionStateMachine.Phase.STARTUP or phase == ActionStateMachine.Phase.ACTIVE:
				return attack_state_name
		ActionStateMachine.State.SKILL:
			return attack_state_name # casting a skill uses the attack pose
		ActionStateMachine.State.BLOCK:
			if _has_block_state:
				return block_state_name
	return walk_state_name if _is_moving() else idle_state_name


func _set_blend(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	var d := dir.normalized()
	for state_name in [idle_state_name, walk_state_name, attack_state_name]:
		animation_tree.set("parameters/" + state_name + "/blend_position", d)
	if _has_block_state:
		animation_tree.set("parameters/" + block_state_name + "/blend_position", d)
	if _has_reaction_states:
		animation_tree.set("parameters/" + hurt_state_name + "/blend_position", d)
		animation_tree.set("parameters/" + death_state_name + "/blend_position", d)


# ======================================================================
# Hurt / death states, built in code so every character scene gets them
# without editing its AnimationTree by hand. The tree and the animation
# library are shared between instances of a scene, so this is idempotent.
# ======================================================================

func _install_reaction_states(root: AnimationNodeStateMachine) -> bool:
	if root == null or animation_player == null or sprite == null:
		return false
	var library := animation_player.get_animation_library(&"")
	if library == null:
		return false
	var sprite_track := String(animation_player.get_node(animation_player.root_node).get_path_to(sprite))

	for dir_name in REACTION_DIRS:
		var d: Dictionary = REACTION_DIRS[dir_name]
		var hurt_name := StringName("hurt_" + dir_name)
		var death_name := StringName("death_" + dir_name)
		if not library.has_animation(hurt_name):
			library.add_animation(hurt_name, _make_animation(sprite_track, d.hurt_row * SHEET_COLUMNS, HURT_FRAMES, HURT_FRAME_TIME, d.flip))
		if not library.has_animation(death_name):
			library.add_animation(death_name, _make_animation(sprite_track, d.death_row * SHEET_COLUMNS, DEATH_FRAMES, DEATH_FRAME_TIME, d.flip))

	_add_blend_state(root, hurt_state_name, "hurt_", Vector2(251, 366))
	_add_blend_state(root, death_state_name, "death_", Vector2(510, 366))

	var sources: Array[String] = [idle_state_name, walk_state_name, attack_state_name, hurt_state_name]
	if _has_block_state:
		sources.append(block_state_name)
	for from_state in sources:
		_add_transition(root, from_state, death_state_name)
		if from_state != hurt_state_name:
			_add_transition(root, from_state, hurt_state_name)
	_add_transition(root, hurt_state_name, idle_state_name)
	_add_transition(root, death_state_name, idle_state_name) # respawn
	return true


func _make_animation(sprite_track: String, first_frame: int, frame_count: int, frame_time: float, flip: bool) -> Animation:
	var anim := Animation.new()
	anim.length = frame_time * frame_count
	anim.loop_mode = Animation.LOOP_NONE # holds the last frame

	var frame_idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(frame_idx, NodePath(sprite_track + ":frame"))
	anim.track_set_interpolation_type(frame_idx, Animation.INTERPOLATION_NEAREST)
	anim.value_track_set_update_mode(frame_idx, Animation.UPDATE_DISCRETE)
	for i in frame_count:
		anim.track_insert_key(frame_idx, i * frame_time, first_frame + i)

	var flip_idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(flip_idx, NodePath(sprite_track + ":flip_h"))
	anim.value_track_set_update_mode(flip_idx, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(flip_idx, 0.0, flip)
	return anim


func _add_blend_state(root: AnimationNodeStateMachine, state_name: String, prefix: String, pos: Vector2) -> void:
	if root.has_node(state_name):
		return
	var blend := AnimationNodeBlendSpace2D.new()
	blend.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE
	for dir_name in REACTION_DIRS:
		var node := AnimationNodeAnimation.new()
		node.animation = StringName(prefix + dir_name)
		blend.add_blend_point(node, REACTION_DIRS[dir_name].vec, -1, StringName(dir_name))
	root.add_node(state_name, blend, pos)


func _add_transition(root: AnimationNodeStateMachine, from_state: String, to_state: String) -> void:
	if not root.has_node(from_state) or not root.has_node(to_state):
		return
	if root.has_transition(from_state, to_state):
		return
	root.add_transition(from_state, to_state, AnimationNodeStateMachineTransition.new())


func _update_feedback(state: ActionStateMachine.State, delta: float) -> void:
	if sprite == null:
		return

	# Charge: shake grows with the charge, sprite blinks.
	if state == ActionStateMachine.State.CHARGING:
		_charge_time += delta
		var ratio := combat_component.get_charge_ratio()
		var strength := ranged_charge_shake if _is_ranged() else charge_shake_strength
		var shake := strength * (1.0 + ratio * (0.8 if _is_ranged() else 1.0))
		sprite.position = Vector2(
			sin(_charge_time * (10.0 + 10.0 * ratio)) * shake,
			cos(_charge_time * (15.0 + 15.0 * ratio)) * shake)
		var blink_on := fmod(_charge_time * lerpf(4.0, 8.0, ratio), 2.0) < 1.0
		sprite.self_modulate = Color(1, 1, 1, 1) if blink_on else Color(1.5, 1.5, 1.5, 1)
	else:
		_charge_time = 0.0
		sprite.position = Vector2.ZERO
		sprite.self_modulate = Color(1, 1, 1, 1)

	# Push-back from a blocked hit, easing out.
	sprite.position += _kick
	_kick = _kick.move_toward(Vector2.ZERO, delta * 25.0)

	# Hit flash wins over the block tint.
	_flash_left = maxf(_flash_left - delta, 0.0)
	_block_flash_left = maxf(_block_flash_left - delta, 0.0)
	if _flash_left > 0.0:
		sprite.modulate = hit_flash_color
	elif _block_flash_left > 0.0:
		sprite.modulate = block_flash_color
	elif state == ActionStateMachine.State.BLOCK:
		sprite.modulate = block_tint
	elif state == ActionStateMachine.State.DASH and combat_component.dash_invulnerable:
		sprite.modulate = dash_tint
	elif state != ActionStateMachine.State.DEAD: # death fade-out owns the alpha
		sprite.modulate = Color(1, 1, 1, 1)


func _on_hit_blocked() -> void:
	_block_flash_left = block_flash_time


func _on_hit_received(_attacker: Node, _damage: float, _direction: Vector2) -> void:
	_flash_left = hit_flash_time


func _is_moving() -> bool:
	return movement_component != null and movement_component.is_moving()


func get_sprite() -> Sprite2D:
	return sprite


func _update_dash_trail(state: ActionStateMachine.State, delta: float) -> void:
	if not dash_trail_enabled or sprite == null:
		return
	var skill_dashing := state == ActionStateMachine.State.SKILL and combat_component.sm.movement_mode() == ActionStateMachine.MoveMode.SKILL_DASH
	if state != ActionStateMachine.State.DASH and not skill_dashing:
		_trail_timer = 0.0
		return
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = dash_trail_interval
		HitFX.afterimage(sprite, dash_trail_color)


func _is_ranged() -> bool:
	return combat_component != null and combat_component.weapon != null \
			and combat_component.weapon.kind == WeaponData.Kind.RANGED


func _is_drawing_ranged_heavy(state: ActionStateMachine.State, aim: Vector2) -> bool:
	return state == ActionStateMachine.State.CHARGING and _is_ranged() and sprite != null \
			and animation_tree != null and not _is_moving() and absf(aim.x) > absf(aim.y)


## While drawing, the animation tree is paused and the pose is set by hand:
## the weapon-extended frame, flipped toward the aim (no tilt).
func _set_aim_pose(on: bool) -> void:
	if on == _aim_pose:
		return
	_aim_pose = on
	if on:
		animation_tree.active = false
	else:
		animation_tree.active = true
		sprite.rotation = 0.0


func _pose_aim(aim: Vector2) -> void:
	if aim == Vector2.ZERO:
		aim = Vector2.LEFT
	sprite.frame = aim_pose_frame
	var facing_right := aim.x > 0.0
	sprite.flip_h = facing_right # the sheet's side frames point left
	sprite.rotation = 0.0


# ---- block visuals ----

func _setup_block_visual() -> void:
	if combat_component == null or combat_component.entity == null or combat_component.shield_component == null:
		return
	var visual := BlockVisual.new()
	visual.name = "BlockVisual"
	combat_component.entity.add_child(visual)
	visual.setup(combat_component, combat_component.shield_component)
	combat_component.shield_component.shield_broken.connect(_on_shield_broken)


func _on_blocked_hit(direction: Vector2, is_heavy: bool) -> void:
	_kick = direction * (3.0 if is_heavy else 1.8)


func _on_parried(direction: Vector2) -> void:
	_block_flash_left = block_flash_time * 1.5
	_kick = direction * 3.5


func _on_shield_broken() -> void:
	Sfx.play(&"guard_break", combat_component.sfx_db() if combat_component else 0.0)
	_flash_left = 0.25 # red flash, longer than a normal hit
	_kick = Vector2.ZERO
	if combat_component and combat_component.entity:
		HitFX.shatter(combat_component.entity, combat_component.entity.global_position + Vector2(0, -2))
