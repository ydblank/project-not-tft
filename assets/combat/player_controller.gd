extends Node2D
class_name PlayerController

# Turns player input into a CombatIntent every physics frame. Input is polled
# (not event-driven), so presses and releases can't be lost.

@export var entity: Node2D
@export var input_up: StringName = &"W"
@export var input_down: StringName = &"S"
@export var input_left: StringName = &"A"
@export var input_right: StringName = &"D"
@export var input_attack: StringName = &"Attack"
@export var input_block: StringName = &"Block"
@export var input_dash: StringName = &"dash"
@export var input_skill: StringName = &"skill"
## false = aim with the direction keys (last direction held, diagonals included) instead of the mouse.
@export var aim_with_mouse: bool = true
## Who the attack lunge stops in front of.
@export var lunge_target_groups: Array[String] = ["enemies", "dummies"]

var intent := CombatIntent.new()
## True while a controller is the active device. Aim then ignores the mouse cursor (which just sits wherever it was left).
var _pad_mode: bool = false
## Mouse movement (px) since the controller was last used; past MOUSE_TAKEOVER_PX the mouse takes over again.
var _mouse_travel: float = 0.0
## The direction the controller aim is turning toward (the last firm right-stick push, or the walking direction).
var _pad_target: Vector2 = Vector2.ZERO
## Seconds the attack button has been held (controller aim only).
var _attack_held_time: float = 0.0
var _combat: CombatComponent
## True while an aimed skill's button is held (controller aim treats it like a charge).
var _aiming_skill: bool = false
## Last frame's controller state, for the fine-aim turning: was the attack button held, was the aim stick pushed at
## all (past the fine-aim minimum), which stick it was (1 = right stick, 2 = the walking direction), and which way it pointed.
var _prev_charging: bool = false
var _prev_source_fine: bool = false
var _prev_source_id: int = 0
var _prev_source_angle: float = 0.0

## How far the right stick must be pushed (0..1, after its dead zone: a push of about 40% reads as 0.15) before the
## aim turns toward it. While fine-aiming a charge even a gentle push counts: PAD_AIM_FINE_MIN (just past the dead zone).
const PAD_AIM_COMMIT := 0.15
const PAD_AIM_FINE_MIN := 0.02
## How fast the controller aim turns toward its target when no attack button is held (higher = snappier).
const PAD_AIM_TURN := 26.0
## Once an attack button has been held for PAD_AIM_FAST_WINDOW seconds (charging a shot or aiming a skill) the aim works
## like a dial: it turns by as much as the aim stick turns (spin the stick round and round to keep turning it), and
## stops when the stick stops. Before that the aim snaps straight to the stick, so it can swing round at the start.
## The dial never turns faster than this many degrees per second (a safety cap against a single flick).
const PAD_AIM_MAX_DEG_PER_SEC := 1080.0
## From this much of the way to a full charge (0..1) the aim starts to slow down, and at a full charge it only follows
## this fraction of the stick's movement (and top speed), so the end of a charge is for small corrections.
const PAD_AIM_SLOW_START := 0.4
const PAD_AIM_FULL_CHARGE_SCALE := 0.25
## Aiming a skill gets finer over this many seconds (after the fast window), the way a charge does as it fills.
const PAD_SKILL_AIM_RAMP := 1.5
const PAD_AIM_FAST_WINDOW := 1.0
## How far the mouse must move, with no controller input in between, before it takes aim back from a controller.
const MOUSE_TAKEOVER_PX := 24.0
## With a controller, a point-aimed skill (fireball) lands at least this share of its range away; pushing the
## right stick further moves the spot out to the full range.
const PAD_SKILL_MIN_REACH := 0.35
const LUNGE_SCAN_RANGE := 60.0
## cos of the half-angle of the cone in front of you that counts as "your target".
const LUNGE_CONE_DOT := 0.8
## Stay this far from the target after lunging.
const LUNGE_STOP_GAP := 8.0


func _ready() -> void:
	if entity == null:
		entity = owner as Node2D
	# Read input before CombatComponent consumes the intent this frame.
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	if not _is_local_authority():
		intent.clear()
		return
	intent.move_dir = Input.get_vector(input_left, input_right, input_up, input_down)
	if not aim_with_mouse:
		if intent.move_dir != Vector2.ZERO:
			intent.aim_dir = intent.move_dir.normalized()
	else:
		if _pad_mode and GamepadControls.active:
			_aim_with_pad(delta)
		elif entity:
			var to_mouse := get_global_mouse_position() - entity.global_position
			if to_mouse != Vector2.ZERO and to_mouse.is_finite():
				intent.aim_dir = to_mouse.normalized()
	intent.lunge_limit = _lunge_limit()
	intent.attack_held = Input.is_action_pressed(input_attack)
	intent.block_held = Input.is_action_pressed(input_block)
	intent.dash_held = Input.is_action_pressed(input_dash)
	intent.skill_held = InputMap.has_action(input_skill) and Input.is_action_pressed(input_skill)
	intent.skill_target = _skill_target()


## True while a controller (not the mouse) is the device in use. Rumble only buzzes then.
func is_pad_in_use() -> bool:
	return _pad_mode and GamepadControls.active


## Tracks which device is in use, so a mouse cursor left to one side cannot steal the aim from a controller.
## A controller stick or button switches to controller mode; a mouse click, or a real move of the mouse
## with no controller input in between, switches back. (Pad events from devices Godot does not recognise are ignored.)
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not GamepadControls.active or not Input.is_joy_known(event.device):
			return # controller support is off (the default), or an unrecognised device
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.3:
			return # a stick resting near the centre
		if not _pad_mode:
			_pad_target = intent.aim_dir # take over from where the aim is now, so it does not jump
		_pad_mode = true
		_mouse_travel = 0.0
	elif event is InputEventMouseMotion:
		if _pad_mode:
			_mouse_travel += event.relative.length()
			if _mouse_travel > MOUSE_TAKEOVER_PX:
				_pad_mode = false
	elif event is InputEventMouseButton and event.pressed:
		_pad_mode = false


## Controller aim, easy to line up (a charged shot is aimed with it). The "aim stick" is the right stick when it is
## pushed, otherwise the direction you are walking (left stick / D-pad), so a controller with only the left stick in use
## aims where it walks:
## - when you are not attacking, the aim turns quickly but smoothly toward the aim stick (a stick resting near the
##   centre does not move it); with neither stick pushed it stays where it is;
## - in the first PAD_AIM_FAST_WINDOW seconds of an attack it snaps straight to the aim stick;
## - after that, while the attack button is still held (or an aimed skill is being aimed), the aim is a dial: it turns
##   by as much as you turn the aim stick (spin the stick round and round to keep turning the aim, finer the fuller the
##   charge) and stops the moment the stick stops or is let go;
## - on the frame an attack ends the aim is not moved, because the shot fires on it.
## Never the mouse cursor.
func _aim_with_pad(delta: float) -> void:
	var stick := Vector2.ZERO
	if InputMap.has_action(GamepadControls.AIM_LEFT):
		stick = Input.get_vector(GamepadControls.AIM_LEFT, GamepadControls.AIM_RIGHT, GamepadControls.AIM_UP, GamepadControls.AIM_DOWN)
	# Aiming a skill (the mage's fireball, the bow's volley) is aimed exactly like charging a shot.
	_aiming_skill = _is_aiming_skill()
	var charging := Input.is_action_pressed(input_attack) or _aiming_skill
	_attack_held_time = _attack_held_time + delta if charging else 0.0
	var slow_phase := charging and _attack_held_time >= PAD_AIM_FAST_WINDOW
	# Which stick aims: the right one while it is pushed (even gently), else the way you walk. Both are already past
	# their dead zones and rescaled, so 0 = resting and 1 = fully pushed.
	var using_right := stick.length() >= PAD_AIM_FINE_MIN
	var source := stick if using_right else intent.move_dir
	var source_fine := source.length() >= PAD_AIM_FINE_MIN
	var source_firm := source.length() >= (PAD_AIM_COMMIT if using_right else PAD_AIM_FINE_MIN)
	var source_id := 1 if using_right else 2
	if source_firm:
		_pad_target = source.normalized()
	var was_charging := _prev_charging
	var had_source := _prev_source_fine and _prev_source_id == source_id # a change of stick is not a turn
	var prev_source_angle := _prev_source_angle
	_prev_charging = charging
	_prev_source_fine = source_fine
	_prev_source_id = source_id
	_prev_source_angle = source.angle()
	if _pad_target == Vector2.ZERO:
		return # no direction chosen yet
	var current := intent.aim_dir if intent.aim_dir != Vector2.ZERO else _pad_target
	var angle: float
	if slow_phase:
			# Fine aiming works like a dial: the aim turns by as much as the stick turns, so spinning the stick round and
			# round keeps turning the aim the same way (it never "cancels" by heading back for where the stick points). It
			# stops the moment the stick stops. The fuller the charge, the less it turns for the same stick movement (down
			# to PAD_AIM_FULL_CHARGE_SCALE of it), so the last part of a charge is for small corrections.
			angle = current.angle()
			if source_fine and had_source:
				var turned := angle_difference(prev_source_angle, source.angle()) # how far the stick turned this frame
				var most := deg_to_rad(PAD_AIM_MAX_DEG_PER_SEC) * delta # a safety cap: one flick cannot throw the aim right round
				angle += clampf(turned * _charge_aim_scale(), -most, most)
	elif charging:
		angle = _pad_target.angle() # the first moments of an attack: snap straight to where the stick points
	elif was_charging:
		angle = current.angle() # the frame the attack ends: the shot fires on this aim, so leave it
	else:
		angle = lerp_angle(current.angle(), _pad_target.angle(), 1.0 - exp(-PAD_AIM_TURN * delta))
	intent.aim_dir = Vector2.from_angle(angle)


## True while an aimed skill is being aimed: its button is held, or its cast is still running (the bow's volley keeps
## reading the aim while it fires, so the aim must not swing toward the stick the moment the button is released).
func _is_aiming_skill() -> bool:
	if _combat == null and entity != null:
		_combat = CombatComponent.find_on(entity)
	var skill := _combat.get_skill() if _combat else null
	if skill == null or not skill.is_aimed():
		return false
	var state := _combat.get_state()
	if state == ActionStateMachine.State.SKILL_AIM or state == ActionStateMachine.State.SKILL:
		return true # the whole aim and cast, including the frame the button is released (no gap that would reset the aim)
	return InputMap.has_action(input_skill) and Input.is_action_pressed(input_skill)


## 1 early in an aim, easing down to PAD_AIM_FULL_CHARGE_SCALE: how much of the stick's movement the aim follows.
## A charged shot eases with its charge (from PAD_AIM_SLOW_START of the way to a full charge); an aimed skill has no
## charge, so it eases with the time spent aiming (over PAD_SKILL_AIM_RAMP seconds after the fast window).
func _charge_aim_scale() -> float:
	if _aiming_skill:
		var t := (_attack_held_time - PAD_AIM_FAST_WINDOW) / PAD_SKILL_AIM_RAMP
		return lerpf(1.0, PAD_AIM_FULL_CHARGE_SCALE, smoothstep(0.0, 1.0, t))
	if _combat == null and entity != null:
		_combat = CombatComponent.find_on(entity)
	var ratio := _combat.get_charge_ratio() if _combat else 0.0
	return lerpf(1.0, PAD_AIM_FULL_CHARGE_SCALE, smoothstep(PAD_AIM_SLOW_START, 1.0, ratio))


func _is_local_authority() -> bool:
	var mp := multiplayer.multiplayer_peer
	if mp == null or mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return true
	return entity == null or entity.is_multiplayer_authority()


## Stop the attack lunge just short of whoever is in front, so a lunge never
## carries you through (or past) the target and makes the rest of a combo whiff.
func _lunge_limit() -> float:
	if entity == null or intent.aim_dir == Vector2.ZERO:
		return INF
	var best := INF
	for group_name in lunge_target_groups:
		for node in get_tree().get_nodes_in_group(group_name):
			var other := node as Node2D
			if other == null or other == entity:
				continue
			var to_other := other.global_position - entity.global_position
			var dist := to_other.length()
			if not is_finite(dist) or dist > LUNGE_SCAN_RANGE or dist <= 0.0:
				continue
			if to_other.normalized().dot(intent.aim_dir) < LUNGE_CONE_DOT:
				continue
			best = minf(best, dist)
	if best == INF:
		return INF
	return maxf(best - LUNGE_STOP_GAP, 0.0)


## Where a point-aimed skill lands: the mouse cursor, or with a controller (or the 2P keyboard) a spot along
## the aim. With the right stick, pushing it further puts the spot further out (at least PAD_SKILL_MIN_REACH
## of the skill's range).
func _skill_target() -> Vector2:
	if entity == null:
		return Vector2.ZERO
	if aim_with_mouse and not (_pad_mode and GamepadControls.active):
		return get_global_mouse_position()
	if _combat == null:
		_combat = CombatComponent.find_on(entity)
	var skill := _combat.get_skill() if _combat else null
	var reach := skill.max_range if skill else 0.0
	if _pad_mode and GamepadControls.active and InputMap.has_action(GamepadControls.AIM_LEFT):
		var stick := Input.get_vector(GamepadControls.AIM_LEFT, GamepadControls.AIM_RIGHT, GamepadControls.AIM_UP, GamepadControls.AIM_DOWN)
		# The right stick's push sets the distance; with only the left stick in use, how hard you push it does.
		var push := stick.length() if stick.length() >= PAD_AIM_FINE_MIN else intent.move_dir.length()
		reach *= clampf(push, PAD_SKILL_MIN_REACH, 1.0)
	return entity.global_position + intent.aim_dir.normalized() * reach
