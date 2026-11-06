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
## Once an attack button has been held for PAD_AIM_FAST_WINDOW seconds (charging a shot): while the stick is being
## turned faster than PAD_AIM_CHASE_MIN_DEG_PER_SEC the aim heads for where the stick points at no more than
## PAD_AIM_CHARGE_DEG_PER_SEC (degrees per second); turned more gently it just moves with the stick; and it stops
## when the stick stops. Before the fast window ends the aim snaps straight to the stick, so it can swing round at the start.
const PAD_AIM_CHARGE_DEG_PER_SEC := 150.0
const PAD_AIM_CHASE_MIN_DEG_PER_SEC := 45.0
## From this much of the way to a full charge (0..1) the aim starts to slow down, and at a full charge it only follows
## this fraction of the stick's movement (and top speed), so the end of a charge is for small corrections.
const PAD_AIM_SLOW_START := 0.4
const PAD_AIM_FULL_CHARGE_SCALE := 0.25
const PAD_AIM_FAST_WINDOW := 1.0
## How far the mouse must move, with no controller input in between, before it takes aim back from a controller.
const MOUSE_TAKEOVER_PX := 24.0
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
## - after that, while the attack button is still held, the aim only moves while you turn the aim stick and stops the
##   moment the stick stops or is let go: turning it faster than PAD_AIM_CHASE_MIN_DEG_PER_SEC heads for where it
##   points at no more than PAD_AIM_CHARGE_DEG_PER_SEC, turning it gently moves the aim with it 1:1;
## - on the frame an attack ends the aim is not moved, because the shot fires on it.
## Never the mouse cursor.
func _aim_with_pad(delta: float) -> void:
	var stick := Vector2.ZERO
	if InputMap.has_action(GamepadControls.AIM_LEFT):
		stick = Input.get_vector(GamepadControls.AIM_LEFT, GamepadControls.AIM_RIGHT, GamepadControls.AIM_UP, GamepadControls.AIM_DOWN)
	var charging := Input.is_action_pressed(input_attack)
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
		# Fine aiming: the aim only moves while the aim stick is turned, and stops with it. The fuller the charge, the
		# less it moves for the same stick movement (down to PAD_AIM_FULL_CHARGE_SCALE of it), so the last part of a
		# charge is for small corrections.
		angle = current.angle()
		if source_fine and had_source:
			var fine := _charge_aim_scale()
			var turned := angle_difference(prev_source_angle, source.angle()) # how far the stick turned this frame
			if absf(turned) >= deg_to_rad(PAD_AIM_CHASE_MIN_DEG_PER_SEC) * delta:
				# Being turned: head for where it points, at the slow speed. This catches up an aim left behind by a
				# quick flick, so turning the stick again always resumes the aim.
				var cap := deg_to_rad(PAD_AIM_CHARGE_DEG_PER_SEC) * delta * fine
				angle += clampf(angle_difference(angle, source.angle()), -cap, cap)
			else:
				angle += turned * fine # turning gently (or noise): the aim moves with the stick, 1:1 early in the charge
	elif charging:
		angle = _pad_target.angle() # the first moments of an attack: snap straight to where the stick points
	elif was_charging:
		angle = current.angle() # the frame the attack ends: the shot fires on this aim, so leave it
	else:
		angle = lerp_angle(current.angle(), _pad_target.angle(), 1.0 - exp(-PAD_AIM_TURN * delta))
	intent.aim_dir = Vector2.from_angle(angle)

## 1 early in a charge, easing down to PAD_AIM_FULL_CHARGE_SCALE as the shot reaches a full charge (from
## PAD_AIM_SLOW_START of the way): how much of the stick's movement the aim follows.
func _charge_aim_scale() -> float:
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
