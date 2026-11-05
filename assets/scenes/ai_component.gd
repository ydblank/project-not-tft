extends Node2D
class_name AIComponent

# Enemy brain. Like PlayerController, it only writes a CombatIntent each
# physics frame; CombatComponent decides what actually happens.
#
# Modes:
#   IDLE      no target (optional wander)
#   CHASE     path toward the target, keeping min_distance
#   CAUTIOUS  hold distance around flee_range
#   RETREAT   back away, sliding along walls; cornered/stuck -> fight
#   ENGAGE    tap through a light combo while in engage range
#   CHARGE    hold a heavy until the rolled charge, then release
#   BLOCK     hold the shield toward a threatening target
#   RECOVER   attack cooldown: keep spacing until it can attack again
#
# Dodge: on top of the modes, the AI can dash out of the way of an incoming
# arrow or the target's wind-up (dash gives i-frames). See _update_dodge().

enum Mode {IDLE, CHASE, CAUTIOUS, RETREAT, ENGAGE, CHARGE, BLOCK, RECOVER}
enum Personality {COURAGEOUS, COWARDLY}

const PERSONALITY_VALUES := {
	Personality.COURAGEOUS: {"chase": 0.9, "dash_forward": 1.0, "dash_backward": 0.5, "block": 0.3, "heavy": 0.3, "dodge": 0.5, "combo_break": 0.6, "punish": 0.8},
	Personality.COWARDLY: {"chase": 0.6, "dash_forward": 0.5, "dash_backward": 1.0, "block": 0.6, "heavy": 0.15, "dodge": 0.8, "combo_break": 0.85, "punish": 0.5},
}

@export var entity: CharacterBody2D
@export var combat_component: CombatComponent
@export var movement_component: MovementComponent
@export var hitbox_component: HitboxComponent

@export_group("Targeting")
@export var target_groups: Array[String] = ["players", "allies"]
## Only target hurtboxes on this team (-1 = any other team).
@export var target_team: int = 0
@export var detection_range: float = 200.0
@export var chase_range: float = 400.0

@export_group("Spacing")
@export var flee_range: float = 80.0
@export var cautious_tolerance: float = 20.0
@export var min_distance: float = 20.0
@export var heavy_range: float = 90.0
@export var retreat_probe_distance: float = 16.0

@export_group("Timing")
@export var attack_cooldown: float = 0.7
@export var personality_interval: float = 1.2
@export var retreat_duration: float = 1.0
@export var dash_decision_interval: float = 1.5
@export var block_hold_max: float = 0.8
@export var path_update_interval: float = 0.1

@export_group("Arena")
## Treat the arena edge like a wall: no steps or dashes that leave it, and walk back in if pushed out.
@export var stay_in_arena: bool = true
## How far ahead (pixels) a step is checked to stay inside the arena.
@export var arena_lookahead: float = 12.0

@export_group("Dodge")
## Dash out of the way of incoming arrows / wind-ups (chance per threat comes from the personality).
@export var dodge_enabled: bool = true
## Minimum seconds between two dodges.
@export var dodge_cooldown: float = 0.8
## An arrow is dodged when it would hit within this many seconds.
@export var dodge_reaction_time: float = 0.4
## How close to the arrow's path counts as "in line" (pixels).
@export var projectile_hit_radius: float = 14.0

@export_group("Smarts")
## Dash out of a combo that has us locked in hitstun.
@export var smart_combo_break: bool = true
## Seconds into a stun before the AI reacts and tries to break out.
@export var combo_break_reaction: float = 0.22
## Dash in to punish a target that is stunned or recovering from a swing.
@export var smart_punish: bool = true
## Soft changes (chase / retreat) wait at least this long, so the AI stops flip-flopping.
@export var mode_min_hold: float = 0.7
## Pick targets by opening, health and teammates instead of just the nearest.
@export var smart_targeting: bool = true
## Seconds a target is kept before a better one can take over.
@export var target_hold_time: float = 1.0
## Flank with a teammate and peel for a low-health teammate.
@export var teamwork: bool = true
## Block / dodge more against a target that spams attacks; wait out dashes before a heavy.
@export var adapt_to_target: bool = true
## Push the target toward the arena edge, and stay away from it ourselves.
@export var use_arena_edge: bool = true

@export_group("Behaviour")
@export var personality: Personality = Personality.COURAGEOUS
@export var idle_wander: bool = false
@export var wander_radius: float = 50.0
@export var use_pathfinding: bool = true
@export var debug_logs: bool = false

const RETREAT_STUCK_CHECK_INTERVAL := 0.5
const RETREAT_STUCK_MIN_PROGRESS := 2.0
const RETREAT_ESCAPE_ANGLES := [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0]

var intent := CombatIntent.new()
var mode: Mode = Mode.IDLE
var current_target: Node2D = null

var _target_combat: CombatComponent = null
var _cooldown_left: float = 0.0
var _mode_time: float = 0.0
var _personality_timer: float = 0.0
var _dash_timer: float = 0.0
var _path_timer: float = 0.0
var _attacks_this_engage: int = 0
var _target_charge_ratio: float = 1.0
var _heavy_rolled: bool = false
var _was_threatened: bool = false
var _retreat_check_timer: float = 0.0
var _retreat_check_pos: Vector2 = Vector2.ZERO
var _spawn_position: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _attack_tap_down: bool = false
var _tap_released_this_frame: bool = false
var _dash_tap_down: bool = false
var _dodge_timer: float = 0.0
var _dodge_pending: bool = false
var _dodge_dir: Vector2 = Vector2.ZERO
var _dodge_was_threatened: bool = false
var _rolled_arrows: Dictionary = {} # arrow instance id -> true (each arrow is rolled once)
var _stagger_time: float = 0.0
var _stagger_rolled: bool = false
var _retreat_lockout: float = 0.0
var _target_hold_left: float = 0.0
var _watched_combat: CombatComponent = null
var _target_attack_times: Array[float] = []

@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")


func _ready() -> void:
	if entity == null:
		entity = owner as CharacterBody2D
	process_physics_priority = -10 # write the intent before CombatComponent reads it
	_spawn_position = entity.global_position
	_wander_target = _spawn_position
	_personality_timer = personality_interval
	_dash_timer = 0.6 # no instant dash the moment the fight starts
	add_to_group("ai_fighters")
	if navigation_agent:
		navigation_agent.path_desired_distance = 4.0
		navigation_agent.target_desired_distance = min_distance
	if combat_component:
		combat_component.attack_started.connect(_on_own_attack_started)


# ======================================================================
# Frame loop
# ======================================================================

func _physics_process(delta: float) -> void:
	if entity == null or combat_component == null:
		return

	# One-frame taps: release whatever was pressed last frame. The release must
	# reach CombatComponent before another press, or two taps merge into a hold.
	_tap_released_this_frame = _attack_tap_down
	if _attack_tap_down:
		intent.attack_held = false
		_attack_tap_down = false
	if _dash_tap_down:
		intent.dash_held = false
		_dash_tap_down = false

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dodge_timer = maxf(_dodge_timer - delta, 0.0)
	_retreat_lockout = maxf(_retreat_lockout - delta, 0.0)
	_target_hold_left = maxf(_target_hold_left - delta, 0.0)
	_path_timer += delta
	_mode_time += delta

	var own_state := combat_component.get_state()
	if own_state == ActionStateMachine.State.DEAD:
		intent.clear()
		return
	if own_state == ActionStateMachine.State.STAGGER or own_state == ActionStateMachine.State.KNOCKBACK:
		# Being hit cancels whatever we were doing.
		intent.clear()
		if mode == Mode.ENGAGE or mode == Mode.CHARGE or mode == Mode.BLOCK:
			_end_attack_sequence()
		_update_combo_break(own_state, delta)
		return
	_stagger_time = 0.0
	_stagger_rolled = false

	_update_target()
	if current_target == null:
		_set_mode(Mode.IDLE)
		_do_idle()
		return

	var to_target := current_target.global_position - entity.global_position
	var distance := to_target.length()
	intent.aim_dir = to_target.normalized() if distance > 0.0 else intent.aim_dir
	intent.lunge_limit = maxf(distance - min_distance, 0.0)

	_update_personality(delta)
	_update_dodge(distance, to_target)
	_check_threat(distance)
	_update_mode(distance)
	_act(distance, to_target)
	_apply_arena_tactics(distance)
	_apply_dodge()
	_keep_in_arena()


# ======================================================================
# Decisions
# ======================================================================

func _update_mode(distance: float) -> void:
	var engage_range := _engage_range()
	match mode:
		Mode.IDLE:
			_set_mode(Mode.CAUTIOUS if distance <= flee_range else Mode.CHASE)
		Mode.CHASE, Mode.CAUTIOUS:
			if _cooldown_left <= 0.0:
				if distance <= engage_range:
					_set_mode(Mode.ENGAGE)
				elif distance <= heavy_range:
					if not _heavy_rolled:
						_heavy_rolled = true
						if randf() < _heavy_chance():
							_target_charge_ratio = randf_range(0.3, 1.0)
							_set_mode(Mode.CHARGE)
				else:
					_heavy_rolled = false
		Mode.RECOVER:
			if _cooldown_left <= 0.0:
				_set_mode(Mode.CHASE)
		Mode.RETREAT:
			if distance >= flee_range or _mode_time >= retreat_duration:
				_set_mode(Mode.CAUTIOUS)
		Mode.ENGAGE:
			_update_engage(distance, engage_range)
		Mode.CHARGE:
			_update_charge()
		Mode.BLOCK:
			if not _target_is_threatening(distance) or _mode_time >= block_hold_max:
				intent.block_held = false
				_set_mode(Mode.CHASE)


func _update_engage(distance: float, engage_range: float) -> void:
	var state := combat_component.get_state()
	var free := state == ActionStateMachine.State.IDLE
	if not free:
		return
	var combo_open := combat_component.sm.is_in_combo_window()
	if _attacks_this_engage > 0 and not combo_open:
		_end_attack_sequence() # combo finished (final hit or window expired)
	elif distance <= engage_range:
		_press_attack()
	elif _attacks_this_engage == 0:
		_set_mode(Mode.CHASE) # target stepped away before we swung


func _update_charge() -> void:
	var state := combat_component.get_state()
	if state == ActionStateMachine.State.CHARGING:
		if combat_component.get_charge_ratio() >= _target_charge_ratio:
			intent.attack_held = false # release -> heavy
		else:
			intent.attack_held = true
	elif state == ActionStateMachine.State.ATTACK:
		intent.attack_held = false
	elif state == ActionStateMachine.State.IDLE:
		if _attacks_this_engage > 0:
			_end_attack_sequence()
		else:
			intent.attack_held = true # start / keep holding


func _end_attack_sequence() -> void:
	intent.attack_held = false
	intent.block_held = false
	_attack_tap_down = false
	if _attacks_this_engage > 0:
		_cooldown_left = attack_cooldown
	_attacks_this_engage = 0
	_set_mode(Mode.RECOVER)


# Personality roll: periodically choose to press in or back off.
func _update_personality(delta: float) -> void:
	_personality_timer -= delta
	if _personality_timer > 0.0:
		return
	_personality_timer = personality_interval * randf_range(0.8, 1.6)
	if mode != Mode.CHASE and mode != Mode.CAUTIOUS and mode != Mode.RETREAT and mode != Mode.RECOVER:
		return
	if _mode_time < mode_min_hold:
		return # committed to the current plan for a moment
	var chase_chance := _trait("chase")
	if _own_health_ratio() < 0.35:
		chase_chance *= 0.5 # hurt: much more likely to back off
	if _retreat_lockout > 0.0:
		chase_chance = 1.0 # we just got cornered, don't run straight back into it
	if randf() < chase_chance:
		if mode != Mode.RECOVER:
			_set_mode(Mode.CHASE)
	else:
		_set_mode(Mode.RETREAT)


# Shield reaction: roll once each time the target starts threatening us.
func _check_threat(distance: float) -> void:
	var threatened := _target_is_threatening(distance)
	var rising := threatened and not _was_threatened
	_was_threatened = threatened
	if not rising or mode == Mode.BLOCK or _dodge_pending:
		return
	if combat_component.get_state() != ActionStateMachine.State.IDLE:
		return
	if randf() < _adapted("block"):
		_attacks_this_engage = 0
		intent.attack_held = false
		_set_mode(Mode.BLOCK)


func _target_is_threatening(distance: float) -> bool:
	if _target_combat == null:
		return false
	var s := _target_combat.get_state()
	var winding_up := s == ActionStateMachine.State.CHARGING \
		or (s == ActionStateMachine.State.ATTACK and _target_combat.get_phase() != ActionStateMachine.Phase.RECOVERY)
	return winding_up and distance <= _target_combat.get_threat_range() + 10.0


# ======================================================================
# Actions (movement for the current mode)
# ======================================================================

func _act(distance: float, to_target: Vector2) -> void:
	var toward := to_target.normalized() if distance > 0.0 else Vector2.ZERO
	intent.block_held = mode == Mode.BLOCK
	match mode:
		Mode.CHASE:
			intent.move_dir = _chase_direction(toward)
			_apply_min_distance(distance, toward)
			var dash_len := _dash_length()
			if intent.move_dir != Vector2.ZERO and distance > min_distance + dash_len:
				_try_dash(_trait("dash_forward"))
			_try_punish_dash(distance, toward)
		Mode.CAUTIOUS, Mode.RECOVER:
			if distance < flee_range - cautious_tolerance:
				intent.move_dir = -toward * 0.8
			elif distance > flee_range + cautious_tolerance:
				intent.move_dir = toward * 0.8
			else:
				intent.move_dir = Vector2.ZERO
			_apply_min_distance(distance, toward)
			_try_punish_dash(distance, toward)
		Mode.RETREAT:
			var escape := _pick_escape_direction(-toward)
			if escape == Vector2.ZERO or _is_retreat_stuck():
				_log("cornered -> CHASE")
				_retreat_lockout = 1.5
				_set_mode(Mode.CHASE)
				intent.move_dir = Vector2.ZERO
			else:
				intent.move_dir = escape
				_try_dash(_trait("dash_backward"))
		Mode.ENGAGE, Mode.CHARGE, Mode.BLOCK:
			intent.move_dir = Vector2.ZERO
			_apply_min_distance(distance, toward)


func _do_idle() -> void:
	intent.attack_held = false
	intent.block_held = false
	if idle_wander:
		if entity.global_position.distance_to(_wander_target) < 10.0:
			_wander_target = _spawn_position + Vector2.RIGHT.rotated(randf() * TAU) * wander_radius
		intent.move_dir = (_wander_target - entity.global_position).normalized() * 0.5
	else:
		intent.move_dir = Vector2.ZERO


## Hold at min_distance; back off when closer than 75% of it.
func _apply_min_distance(distance: float, toward: Vector2) -> void:
	if distance > min_distance:
		return
	intent.move_dir = -toward * 0.5 if distance < min_distance * 0.75 else Vector2.ZERO


func _chase_direction(toward: Vector2) -> Vector2:
	return _flanked(_path_direction(toward), toward)


func _path_direction(toward: Vector2) -> Vector2:
	if not use_pathfinding or navigation_agent == null or not _has_navigation():
		return toward
	if _path_timer >= path_update_interval:
		_path_timer = 0.0
		navigation_agent.target_position = current_target.global_position
	if navigation_agent.is_navigation_finished():
		return toward
	var next := navigation_agent.get_next_path_position()
	if entity.global_position.distance_to(next) < 1.0:
		return toward
	return (next - entity.global_position).normalized()


func _has_navigation() -> bool:
	var map := navigation_agent.get_navigation_map()
	return map.is_valid() and NavigationServer2D.map_get_iteration_id(map) > 0


func _press_attack() -> void:
	if _tap_released_this_frame:
		return
	intent.attack_held = true
	_attack_tap_down = true


func _try_dash(chance: float) -> void:
	if _dash_timer > 0.0 or not combat_component.sm.dash_ready():
		return
	# Movement dashes keep the last charge in reserve so there is always one for a dodge.
	if dodge_enabled and combat_component.sm.dash_max_charges > 1 and combat_component.sm.dash_charges() <= 1:
		return
	# Never dash out of the arena.
	var dash_dir := intent.move_dir.normalized() if intent.move_dir != Vector2.ZERO else combat_component.get_facing()
	if not _inside_after(dash_dir, _dash_length()):
		return
	_dash_timer = dash_decision_interval
	if randf() < chance:
		intent.dash_held = true
		_dash_tap_down = true

func _dash_length() -> float:
	if movement_component == null or combat_component.sm == null:
		return 60.0
	return movement_component.dash_speed * combat_component.sm.dash_duration


## Tries `away` first, then fans out to slide along walls. ZERO = cornered.
func _pick_escape_direction(away: Vector2) -> Vector2:
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	for angle_deg in RETREAT_ESCAPE_ANGLES:
		var dir := away.rotated(deg_to_rad(angle_deg))
		if not entity.test_move(entity.global_transform, dir * retreat_probe_distance) and _inside_after(dir, retreat_probe_distance * 2.0):
			return dir
	return Vector2.ZERO


func _is_retreat_stuck() -> bool:
	_retreat_check_timer += get_physics_process_delta_time()
	if _retreat_check_timer < RETREAT_STUCK_CHECK_INTERVAL:
		return false
	var progress := entity.global_position.distance_to(_retreat_check_pos)
	_retreat_check_timer = 0.0
	_retreat_check_pos = entity.global_position
	return progress < RETREAT_STUCK_MIN_PROGRESS


# ======================================================================
# Targeting
# ======================================================================

const TARGET_SWITCH_MARGIN := 25.0


func _update_target() -> void:
	if current_target and (not _is_valid_target(current_target) or _distance_to(current_target) > chase_range):
		current_target = null
	var best := _find_best_target()
	if best and best != current_target:
		if current_target == null:
			_switch_target(best)
		elif not smart_targeting:
			if _distance_to(best) < _distance_to(current_target):
				_switch_target(best)
		elif _target_hold_left <= 0.0 and _target_score(best) + TARGET_SWITCH_MARGIN < _target_score(current_target):
			_switch_target(best)
	_target_combat = CombatComponent.find_on(current_target) if current_target else null
	_watch_target(_target_combat)


func _switch_target(target: Node2D) -> void:
	current_target = target
	_target_hold_left = target_hold_time


func _find_best_target() -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for group_name in target_groups:
		for node in get_tree().get_nodes_in_group(group_name):
			var target := node as Node2D
			if target == null or not _is_valid_target(target):
				continue
			if _distance_to(target) > detection_range:
				continue
			var score := _target_score(target) if smart_targeting else _distance_to(target)
			if score < best_score:
				best_score = score
				best = target
	return best


## Lower is better: distance, minus bonuses for an opening / a hurt target / a
## target threatening a hurt friend, plus a penalty when a teammate is already on it.
func _target_score(target: Node2D) -> float:
	var score := _distance_to(target)
	if not smart_targeting:
		return score
	var combat := CombatComponent.find_on(target)
	if combat:
		match combat.get_state():
			ActionStateMachine.State.STAGGER, ActionStateMachine.State.KNOCKBACK:
				score -= 30.0
			ActionStateMachine.State.ATTACK:
				if combat.get_phase() == ActionStateMachine.Phase.RECOVERY:
					score -= 30.0
			ActionStateMachine.State.CHARGING:
				score -= 10.0
	var hurtbox := _find_hurtbox(target)
	if hurtbox and hurtbox.health:
		score -= 50.0 * (1.0 - clampf(hurtbox.health.get_hp_percentage() / 100.0, 0.0, 1.0))
	if teamwork:
		for mate in _teammates():
			if mate.current_target == target:
				score += 20.0
		for friend in _friends():
			var friend_hurtbox := _find_hurtbox(friend)
			if friend_hurtbox and friend_hurtbox.health and friend_hurtbox.health.get_hp_percentage() < 35.0 \
					and friend.global_position.distance_to(target.global_position) < 70.0:
				score -= 45.0 # peel: go after whoever is on top of a hurt friend
	return score


func _is_valid_target(target: Node2D) -> bool:
	if not is_instance_valid(target) or target == entity:
		return false
	var hurtbox := _find_hurtbox(target)
	if hurtbox == null or not hurtbox.can_be_hit:
		return false
	if hitbox_component and hitbox_component.is_same_team(hurtbox.team):
		return false
	if target_team >= 0 and hurtbox.team != target_team:
		return false
	return hurtbox.health == null or not hurtbox.health.is_dead()


func _find_hurtbox(target: Node) -> HitboxComponent:
	for child in target.get_children():
		if child is HitboxComponent:
			return child
		for grandchild in child.get_children():
			if grandchild is HitboxComponent:
				return grandchild
	return null


func _distance_to(target: Node2D) -> float:
	return entity.global_position.distance_to(target.global_position)


# ======================================================================
# Helpers
# ======================================================================

func _on_own_attack_started(_move: AttackMove, _is_heavy: bool) -> void:
	if mode == Mode.ENGAGE or mode == Mode.CHARGE:
		_attacks_this_engage += 1


func _engage_range() -> float:
	var weapon := combat_component.weapon
	return weapon.ai_engage_range if weapon else 30.0


func _trait(key: String) -> float:
	return float(PERSONALITY_VALUES[personality][key])


func _set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	_log(Mode.keys()[mode], " -> ", Mode.keys()[new_mode])
	mode = new_mode
	_mode_time = 0.0
	if new_mode == Mode.RETREAT:
		_retreat_check_timer = 0.0
		_retreat_check_pos = entity.global_position
	if new_mode != Mode.ENGAGE and new_mode != Mode.CHARGE:
		intent.attack_held = false
		_attack_tap_down = false


func _log(...args: Array) -> void:
	if not debug_logs:
		return
	var text := ""
	for a in args:
		text += str(a)
	print("[AI ", entity.name, "] ", text)


func get_mode() -> Mode:
	return mode


func get_current_target() -> Node2D:
	return current_target


# ======================================================================
# Dodge (dash out of the way)
#   - an arrow flying at us that would land within dodge_reaction_time, or
#   - the target starting a wind-up (attack / charge) within its reach.
# Each threat is rolled once against the personality's "dodge" chance, and the
# dash itself gives i-frames, so a well-timed dodge makes the attack whiff.
# ======================================================================

func _update_dodge(distance: float, to_target: Vector2) -> void:
	_dodge_pending = false
	# Track the target's wind-up every frame so only its start counts as a threat.
	var threatened := _target_is_threatening(distance)
	var rising := threatened and not _dodge_was_threatened
	_dodge_was_threatened = threatened

	if not dodge_enabled or _dodge_timer > 0.0:
		return
	var own_state := combat_component.get_state()
	if own_state != ActionStateMachine.State.IDLE and own_state != ActionStateMachine.State.CHARGING \
			and own_state != ActionStateMachine.State.ATTACK and own_state != ActionStateMachine.State.BLOCK:
		return
	if not combat_component.sm.dash_ready():
		return

	# 1) Incoming arrows.
	var arrow_dir := _incoming_arrow_dodge_dir()
	if arrow_dir != Vector2.ZERO:
		_queue_dodge(arrow_dir, "arrow")
		return

	# 2) The target winding up an attack at us (rising edge only).
	if rising and randf() < _adapted("dodge"):
		var away := -to_target.normalized() if distance > 0.0 else Vector2.RIGHT
		var dir := _free_dash_direction([away.rotated(randf_range(-0.7, 0.7)), away.rotated(1.2), away.rotated(-1.2), away])
		if dir != Vector2.ZERO:
			_queue_dodge(dir, "wind-up")


func _queue_dodge(dir: Vector2, reason: String) -> void:
	_dodge_pending = true
	_dodge_dir = dir
	_log("dodge (", reason, ") -> ", dir)


## Direction to dash to leave the line of an arrow that would hit us soon.
## Returns ZERO when there is none, it was already rolled, or the roll failed.
func _incoming_arrow_dodge_dir() -> Vector2:
	var arrows := get_tree().get_nodes_in_group("projectiles")
	if arrows.is_empty():
		_rolled_arrows.clear()
		return Vector2.ZERO
	for node in arrows:
		var arrow := node as ArrowProjectile
		if arrow == null or arrow.shooter == entity or arrow.hit == null:
			continue
		if hitbox_component and arrow.hit.team == hitbox_component.team:
			continue
		var id := arrow.get_instance_id()
		if _rolled_arrows.has(id):
			continue
		var path := Vector2.RIGHT.rotated(arrow.rotation)
		var rel := entity.global_position - arrow.global_position
		var along := rel.dot(path)
		if along <= 0.0 or along / maxf(arrow.projectile_speed, 1.0) > dodge_reaction_time:
			continue
		var side := rel.dot(path.orthogonal()) # which side of the arrow's line we are on
		if absf(side) > projectile_hit_radius:
			continue
		_rolled_arrows[id] = true # decide once per arrow
		if randf() >= _adapted("dodge"):
			continue
		var perp := path.orthogonal() * (1.0 if side >= 0.0 else -1.0)
		return _free_dash_direction([perp, -perp, perp.rotated(0.6), (-perp).rotated(-0.6)])
	return Vector2.ZERO


## First candidate direction with room to dash (not blocked by a wall).
func _free_dash_direction(candidates: Array) -> Vector2:
	var length := _dash_length()
	for candidate in candidates:
		var dir: Vector2 = candidate
		if dir == Vector2.ZERO:
			continue
		dir = dir.normalized()
		if not entity.test_move(entity.global_transform, dir * length) and _inside_after(dir, length):
			return dir
	return Vector2.ZERO


## Turns a queued dodge into a dash tap this frame (cancels what we were doing).
func _apply_dodge() -> void:
	if not _dodge_pending:
		return
	_dodge_pending = false
	if mode == Mode.ENGAGE or mode == Mode.CHARGE or mode == Mode.BLOCK:
		_end_attack_sequence()
	intent.move_dir = _dodge_dir
	intent.dash_held = true
	_dash_tap_down = true
	_dodge_timer = dodge_cooldown


# ======================================================================
# Staying inside the arena
# ======================================================================

var _arena: ArenaBounds


func _get_arena() -> ArenaBounds:
	if not stay_in_arena:
		return null
	if not is_instance_valid(_arena):
		_arena = get_tree().get_first_node_in_group("arena") as ArenaBounds
	return _arena


## True if standing `distance` pixels along `dir` is still inside the arena
## (always true when there is no arena).
func _inside_after(dir: Vector2, distance: float) -> bool:
	var arena := _get_arena()
	if arena == null or dir == Vector2.ZERO:
		return true
	return arena.is_inside(entity.global_position + dir.normalized() * distance)


## Final pass over the intent: never walk out of the arena, slide along the edge
## instead, and head back in if we are already outside (knocked out).
func _keep_in_arena() -> void:
	var arena := _get_arena()
	if arena == null or intent.dash_held:
		return # a dash was already checked when it was chosen
	var pos := entity.global_position
	if not arena.is_inside(pos):
		var back := arena.closest_inside_point(pos) - pos
		if back.length() > 0.5:
			intent.move_dir = back.normalized()
		return
	if intent.move_dir == Vector2.ZERO:
		return
	var dir := intent.move_dir.normalized()
	if arena.is_inside(pos + dir * arena_lookahead):
		return
	for angle in [35.0, -35.0, 70.0, -70.0, 100.0, -100.0]:
		var alt := dir.rotated(deg_to_rad(angle))
		if arena.is_inside(pos + alt * arena_lookahead):
			intent.move_dir = alt * intent.move_dir.length()
			return
	intent.move_dir = Vector2.ZERO


# ======================================================================
# Smarts
# ======================================================================

# ---- 1. Break out of a combo with a dash --------------------------------

func _update_combo_break(state: ActionStateMachine.State, delta: float) -> void:
	if not smart_combo_break or state != ActionStateMachine.State.STAGGER or not combat_component.sm.can_dash_out():
		_stagger_time = 0.0
		return
	_stagger_time += delta
	if _stagger_rolled or _stagger_time < combo_break_reaction:
		return
	_stagger_rolled = true # one decision per stun
	if not combat_component.sm.dash_ready() or randf() >= _trait("combo_break"):
		return
	var away := Vector2.RIGHT.rotated(randf() * TAU)
	if is_instance_valid(current_target):
		away = (entity.global_position - current_target.global_position).normalized()
	var dir := _free_dash_direction([away, away.rotated(1.0), away.rotated(-1.0), away.rotated(1.9), away.rotated(-1.9)])
	if dir == Vector2.ZERO:
		return
	_log("combo break -> ", dir)
	intent.move_dir = dir
	intent.dash_held = true
	_dash_tap_down = true


# ---- 2. Dash in on an opening (can spend the last charge) ----------------

func _try_punish_dash(distance: float, toward: Vector2) -> void:
	if not smart_punish or _dash_timer > 0.0 or _target_combat == null:
		return
	if not combat_component.sm.dash_ready() or not _target_is_open():
		return
	var reach := _engage_range()
	if distance <= reach + 4.0 or distance > reach + _dash_length() * 0.9:
		return
	if not _inside_after(toward, minf(distance, _dash_length())):
		return
	_dash_timer = 0.8
	if randf() < _trait("punish"):
		_log("punish dash")
		intent.move_dir = toward
		intent.dash_held = true
		_dash_tap_down = true


## Target is stunned, knocked back or recovering from a swing.
func _target_is_open() -> bool:
	if _target_combat == null:
		return false
	match _target_combat.get_state():
		ActionStateMachine.State.STAGGER, ActionStateMachine.State.KNOCKBACK:
			return true
		ActionStateMachine.State.ATTACK:
			return _target_combat.get_phase() == ActionStateMachine.Phase.RECOVERY
	return false


# ---- 5. Teamwork ----------------------------------------------------------

## Other active AI fighters on our team.
func _teammates() -> Array[AIComponent]:
	var out: Array[AIComponent] = []
	if hitbox_component == null:
		return out
	for node in get_tree().get_nodes_in_group("ai_fighters"):
		var mate := node as AIComponent
		if mate == null or mate == self or not mate.can_process() or mate.hitbox_component == null:
			continue
		if mate.hitbox_component.team != hitbox_component.team or mate.combat_component == null:
			continue
		if mate.combat_component.get_state() == ActionStateMachine.State.DEAD:
			continue
		out.append(mate)
	return out


## Living fighters on our team (AI or human), not counting us.
func _friends() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if hitbox_component == null:
		return out
	var seen: Dictionary = {}
	for group_name in ["players", "allies", "enemies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var fighter := node as Node2D
			if fighter == null or fighter == entity or seen.has(fighter):
				continue
			seen[fighter] = true
			var hurtbox := _find_hurtbox(fighter)
			if hurtbox and hurtbox.team == hitbox_component.team and (hurtbox.health == null or not hurtbox.health.is_dead()):
				out.append(fighter)
	return out


## Two fighters on the same target come in from opposite sides.
func _flanked(dir: Vector2, _toward: Vector2) -> Vector2:
	if not teamwork or current_target == null:
		return dir
	for mate in _teammates():
		if mate.current_target == current_target:
			var side := 1.0 if get_instance_id() < mate.get_instance_id() else -1.0
			var strength := clampf((_distance_to(current_target) - _engage_range()) / 60.0, 0.0, 1.0)
			return dir.rotated(side * 0.6 * strength)
	return dir


# ---- 6. Adapt to the target ------------------------------------------------

func _watch_target(combat: CombatComponent) -> void:
	if combat == _watched_combat:
		return
	if is_instance_valid(_watched_combat) and _watched_combat.attack_started.is_connected(_on_watched_attack):
		_watched_combat.attack_started.disconnect(_on_watched_attack)
	_watched_combat = combat
	_target_attack_times.clear()
	if combat:
		combat.attack_started.connect(_on_watched_attack)


func _on_watched_attack(_move: AttackMove, _is_heavy: bool) -> void:
	_target_attack_times.append(Time.get_ticks_msec() / 1000.0)


## 0 = calm target, 1 = spamming attacks (3+ in the last 3 seconds ramps it up).
func _spam_pressure() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	while not _target_attack_times.is_empty() and now - _target_attack_times[0] > 3.0:
		_target_attack_times.remove_at(0)
	return clampf((_target_attack_times.size() - 2) / 3.0, 0.0, 1.0)


## Personality chance, raised against an attack-spamming target (block / dodge).
func _adapted(key: String) -> float:
	var value := _trait(key)
	if adapt_to_target and (key == "block" or key == "dodge"):
		value = minf(value * (1.0 + _spam_pressure() * 0.8), 0.95)
	return value


## Heavies are risky while the target can still dash away: bait the dash first.
func _heavy_chance() -> float:
	var value := _trait("heavy")
	if adapt_to_target and _target_combat:
		if _target_is_open():
			value *= 1.5
		elif _target_combat.get_dash_charges() > 0:
			value *= 0.35
		else:
			value *= 1.6 # out of dashes: a heavy can't be sidestepped
	return clampf(value, 0.0, 0.9)


func _own_health_ratio() -> float:
	if hitbox_component and hitbox_component.health:
		return clampf(hitbox_component.health.get_hp_percentage() / 100.0, 0.0, 1.0)
	return 1.0


# ---- 7. Use the arena edge ---------------------------------------------------

## Sum of directions that leave the arena within `probe` pixels (ZERO = clear of the edge).
func _edge_vector(arena: ArenaBounds, point: Vector2, probe: float) -> Vector2:
	var out := Vector2.ZERO
	for i in 8:
		var dir := Vector2.RIGHT.rotated(i * TAU / 8.0)
		if not arena.is_inside(point + dir * probe):
			out += dir
	return out


func _apply_arena_tactics(distance: float) -> void:
	if not use_arena_edge or intent.dash_held:
		return
	var arena := _get_arena()
	if arena == null or current_target == null:
		return
	var pos := entity.global_position
	var my_edge := _edge_vector(arena, pos, 22.0)
	if my_edge != Vector2.ZERO:
		# Don't hang around the edge: drift back toward the middle unless we are mid-fight.
		if mode == Mode.CAUTIOUS or mode == Mode.RECOVER or mode == Mode.RETREAT:
			intent.move_dir = (intent.move_dir - my_edge.normalized() * 0.7).limit_length(1.0)
		return
	if mode != Mode.CHASE or intent.move_dir == Vector2.ZERO:
		return
	var target_edge := _edge_vector(arena, current_target.global_position, 26.0)
	if target_edge == Vector2.ZERO or distance <= _engage_range() * 1.2:
		return
	# Approach from the inside so every hit pushes them toward the edge.
	var spot := current_target.global_position - target_edge.normalized() * _engage_range() * 0.9
	var to_spot := spot - pos
	if to_spot.length() > 1.0:
		intent.move_dir = intent.move_dir.lerp(to_spot.normalized(), 0.5).limit_length(1.0)
