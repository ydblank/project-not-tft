extends Node
class_name TrainingAttacker

# A fixed-pattern "brain" for the parry trainer. It stands in for the AIComponent on one fighter:
# it walks up to the player, then swings on a steady timer, so the player can practise timing a parry.
# CombatComponent reads `intent` from its controller, exactly like it does for the AI or the player.

enum Pattern {SINGLE_LIGHT, LIGHT_COMBO, MIXED}

const PATTERN_NAMES := ["Single light", "Light combo x3", "Light, light, heavy"]
## Walks up to this distance (px) from the player, then stops.
const APPROACH_DISTANCE := 28.0
## Extra time (seconds) held past the charge threshold so the heavy reliably registers.
const HEAVY_HOLD_EXTRA := 0.15
## Pause (seconds) after being parried, hit or staggered before the next sequence.
const RECOVER_PAUSE := 0.8
## Colour the knight fades to right before a warned swing.
const WARN_TINT := Color(1.0, 0.45, 0.4)

var intent: CombatIntent = CombatIntent.new()
var entity: CharacterBody2D
var combat: CombatComponent
var pattern: Pattern = Pattern.SINGLE_LIGHT
## Seconds between swing sequences.
var interval: float = 2.0

## Seconds of warning (knight stands still and reddens) before a sequence's first swing. 0 = none.
var warn_time: float = 0.4

var _queue: Array[String] = []
var _warn_left: float = 0.0
var _warning_on: bool = false
var _wait_left: float = 1.0
var _tap_down: bool = false
var _hold_left: float = 0.0
var _mixed_step: int = 0


## Forget the current sequence and start over after `delay` seconds.
func restart(delay: float = 1.0) -> void:
	_queue.clear()
	_tap_down = false
	_hold_left = 0.0
	_mixed_step = 0
	_wait_left = delay
	_warn_left = 0.0
	_show_warning(false)
	intent.clear()


func _exit_tree() -> void:
	_show_warning(false)


func _physics_process(delta: float) -> void:
	if entity == null or combat == null:
		return
	var target := _find_target()
	if target == null:
		intent.clear()
		return
	var to_target := target.global_position - entity.global_position
	var distance := to_target.length()
	intent.aim_dir = to_target / distance if distance > 1.0 else Vector2.RIGHT
	intent.block_held = false
	intent.dash_held = false

	# A tap is a press followed by a release one frame later.
	if _tap_down:
		intent.attack_held = false
		_tap_down = false
		return

	var state := combat.get_state()
	if state == ActionStateMachine.State.DEAD:
		intent.clear()
		return
	if state == ActionStateMachine.State.STAGGER or state == ActionStateMachine.State.KNOCKBACK:
		# Parried or hit: drop the sequence and take a breath.
		_queue.clear()
		_hold_left = 0.0
		_warn_left = 0.0
		_show_warning(false)
		intent.attack_held = false
		intent.move_dir = Vector2.ZERO
		_wait_left = maxf(_wait_left, RECOVER_PAUSE)
		return

	# Heavy: hold the button for the charge, then let go.
	if _hold_left > 0.0:
		_hold_left -= delta
		intent.attack_held = _hold_left > 0.0
		intent.move_dir = Vector2.ZERO
		return

	var free := state == ActionStateMachine.State.IDLE
	intent.move_dir = intent.aim_dir if (free and distance > APPROACH_DISTANCE) else Vector2.ZERO

	if _queue.is_empty():
		if _warn_left > 0.0:
			# Warning phase: stand still and show the "!" so the player can react in time.
			_warn_left -= delta
			_tint_warning()
			intent.move_dir = Vector2.ZERO
			if _warn_left <= 0.0:
				_show_warning(false)
				_queue = _next_sequence()
		elif free and not combat.sm.is_in_combo_window() and distance <= APPROACH_DISTANCE + 8.0:
			_wait_left -= delta
			if _wait_left <= 0.0:
				if warn_time > 0.0:
					_warn_left = warn_time
					_show_warning(true)
				else:
					_queue = _next_sequence()
		return

	if free:
		var kind: String = _queue.pop_front()
		if kind == "heavy":
			var threshold := combat.weapon.charge_threshold if combat.weapon else 0.4
			_hold_left = threshold + HEAVY_HOLD_EXTRA
			intent.attack_held = true
		else:
			intent.attack_held = true
			_tap_down = true
		if _queue.is_empty():
			_wait_left = interval


func _next_sequence() -> Array[String]:
	var seq: Array[String] = []
	match pattern:
		Pattern.SINGLE_LIGHT:
			seq.append("light")
		Pattern.LIGHT_COMBO:
			seq.append_array(["light", "light", "light"])
		Pattern.MIXED:
			# light, light, heavy, repeat
			seq.append("heavy" if _mixed_step % 3 == 2 else "light")
			_mixed_step += 1
	return seq


## Subtle tell: the knight's body warms to a red tint as the swing gets close (on = start, off = clear).
func _show_warning(on: bool) -> void:
	_warning_on = on
	if not on and is_instance_valid(entity):
		entity.modulate = Color.WHITE


func _tint_warning() -> void:
	if not _warning_on or not is_instance_valid(entity) or warn_time <= 0.0:
		return
	var progress := clampf(1.0 - _warn_left / warn_time, 0.0, 1.0)
	entity.modulate = Color.WHITE.lerp(WARN_TINT, progress * progress)


func _find_target() -> Node2D:
	for node in get_tree().get_nodes_in_group("players"):
		var candidate := node as Node2D
		if candidate and candidate.is_multiplayer_authority() and candidate.visible:
			return candidate
	return null
