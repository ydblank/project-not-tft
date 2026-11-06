extends Node
class_name DeathSlowMo

# When any fighter dies, the game drops into slow motion and the camera punches in on the body,
# then eases back to normal. It listens to every fighter's HealthComponent.died signal (fighters
# that appear later, such as respawns, are picked up as they enter the scene).
#
# The slow-motion goes through Combat.set_slowmo(), so a hitstop freeze still works on top of it. The
# camera zoom and focus go through CameraFollow.punch_*; the audio speed through
# AudioServer.playback_speed_scale (music and sounds slow down with it).
# Timing is in real seconds, so it is not stretched by its own slow-motion.

## Turn the whole effect off (pause menu: "Death slow-motion").
@export var enabled: bool = true
## Game speed at the deepest point (0.15 = about 7x slower).
@export_range(0.05, 1.0) var slow_scale: float = 0.15
## Seconds (real time) to drop into slow motion.
@export var ramp_in: float = 0.08
## Seconds (real time) spent at full slow motion.
@export var hold: float = 0.9
## Seconds (real time) to ease back to normal speed.
@export var ramp_out: float = 0.55
## Camera zoom on top of the normal zoom, at the deepest point (1.6 = 60% closer).
@export_range(1.0, 3.0) var zoom_multiplier: float = 1.6
## How far the camera moves toward the fallen fighter (0 = not at all, 1 = centred on it).
@export_range(0.0, 1.0) var focus_weight: float = 0.85
## Seconds (real time) for the camera to punch in.
@export var zoom_in_time: float = 0.3
## Audio speed at the deepest point (1 = leave the audio alone).
@export_range(0.3, 1.0) var audio_speed: float = 0.6

const FIGHTER_GROUPS := ["players", "enemies", "allies"]

var _elapsed: float = -1.0 # < 0 = idle
var _focus: Node2D
var _focus_pos: Vector2
var _camera_follow: CameraFollow
var _last_usec: int = 0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for group_name in FIGHTER_GROUPS:
		for node in get_tree().get_nodes_in_group(group_name):
			_watch(node)


func _exit_tree() -> void:
	_finish() # never leave the game slowed down


func _on_node_added(node: Node) -> void:
	if node is CharacterBody2D:
		_watch.call_deferred(node) # groups are set up by the time the deferred call runs


func _watch(node: Node) -> void:
	if not is_instance_valid(node) or not node is CharacterBody2D:
		return
	var is_fighter := false
	for group_name in FIGHTER_GROUPS:
		if node.is_in_group(group_name):
			is_fighter = true
	if not is_fighter:
		return
	var combat := CombatComponent.find_on(node)
	if combat == null or combat.health_component == null:
		return
	var health := combat.health_component
	if not health.died.is_connected(_on_died.bind(node)):
		health.died.connect(_on_died.bind(node))


## Starts the effect on `fighter`. Ignored while one is already running.
func trigger(fighter: Node2D) -> void:
	if not enabled or _elapsed >= 0.0 or not is_instance_valid(fighter):
		return
	_camera_follow = get_parent().get_node_or_null("CameraFollow") as CameraFollow if get_parent() else null
	_focus = fighter
	_focus_pos = fighter.global_position
	_elapsed = 0.0
	_last_usec = Time.get_ticks_usec()


func _on_died(fighter: Node) -> void:
	trigger(fighter as Node2D)


func _process(_delta: float) -> void:
	if _elapsed < 0.0:
		return
	# Real time (not the scaled delta), and never a huge jump after the game was paused.
	var now := Time.get_ticks_usec()
	var real_delta := clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.1)
	_last_usec = now
	_elapsed += real_delta

	var total := ramp_in + hold + ramp_out
	if _elapsed >= total:
		_finish()
		return
	var depth := 1.0 # 0 = normal, 1 = deepest slow motion
	if _elapsed < ramp_in:
		depth = _elapsed / maxf(ramp_in, 0.001)
	elif _elapsed > ramp_in + hold:
		depth = 1.0 - smoothstep(0.0, 1.0, (_elapsed - ramp_in - hold) / maxf(ramp_out, 0.001))

	Combat.set_slowmo(lerpf(1.0, slow_scale, depth))
	AudioServer.playback_speed_scale = lerpf(1.0, audio_speed, depth)

	if is_instance_valid(_focus):
		_focus_pos = _focus.global_position
	if _camera_follow:
		# The punch-in is quick (ease-out), and it leaves with the slow motion.
		var punch := minf(1.0 - pow(1.0 - clampf(_elapsed / maxf(zoom_in_time, 0.001), 0.0, 1.0), 3.0), depth)
		_camera_follow.punch_zoom = lerpf(1.0, zoom_multiplier, punch)
		_camera_follow.punch_weight = punch * focus_weight
		_camera_follow.punch_focus = _focus_pos


## Back to normal speed, audio and camera.
func _finish() -> void:
	_elapsed = -1.0
	_focus = null
	Combat.set_slowmo(1.0)
	AudioServer.playback_speed_scale = 1.0
	if is_instance_valid(_camera_follow):
		_camera_follow.punch_zoom = 1.0
		_camera_follow.punch_weight = 0.0
