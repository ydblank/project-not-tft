extends Node
class_name MultiplayerComponent

# Networking seam (singleplayer-first): the authority sends its transform and
# facing so remote copies can be drawn. No combat is applied over the network
# yet; hits only resolve locally. Inactive when no multiplayer peer exists.

@export var entity_path: NodePath = ^"../.."
@export var send_rate_hz: float = 20.0

var entity: CharacterBody2D
var _send_accum: float = 0.0


func _ready() -> void:
	entity = get_node(entity_path) as CharacterBody2D
	# Authority based on node name "1","2",...
	if entity and String(entity.name).is_valid_int():
		entity.set_multiplayer_authority(int(String(entity.name)))


func _physics_process(delta: float) -> void:
	if entity == null or not _net_active() or not entity.is_multiplayer_authority():
		return
	_send_accum += delta
	if _send_accum < 1.0 / maxf(send_rate_hz, 1.0):
		return
	_send_accum = 0.0
	rpc("sync_remote_state", entity.global_position, entity.velocity)


@rpc("unreliable", "any_peer")
func sync_remote_state(pos: Vector2, vel: Vector2) -> void:
	if entity == null or entity.is_multiplayer_authority():
		return
	entity.global_position = pos
	entity.velocity = vel


func _net_active() -> bool:
	var mp := multiplayer.multiplayer_peer
	return mp != null and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
