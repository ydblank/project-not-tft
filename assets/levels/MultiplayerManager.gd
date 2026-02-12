extends Node2D

var peer

const PLAYER_CHARACTER := preload("res://assets/characters/player_character.tscn")

# Drag this in the inspector:
# Example value: "ComponentGroup/MultiplayerComponent"
@export var multiplayer_component_path: NodePath

func _ready() -> void:
	print("MultiplayerManager READY:", self)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int) -> void:
	print("Peer connected:", id)
	if multiplayer.is_server():
		add_player(id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected:", id)
	if has_node(str(id)):
		get_node(str(id)).queue_free()

func host_game(port := 9000) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	print("Hosting on port %s" % port)

	var existing_player := _find_existing_player()
	if existing_player:
		if not existing_player.name.is_valid_int():
			existing_player.name = str(multiplayer.get_unique_id())
		if existing_player.name.is_valid_int():
			existing_player.set_multiplayer_authority(int(existing_player.name))

		_set_player_team(existing_player, 1)

func join_game(ip: String, port := 9000) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%s" % [ip, port])

	await multiplayer.connected_to_server

	if not has_node("1"):
		var existing_player := _find_existing_player()
		if existing_player and not existing_player.name.is_valid_int():
			existing_player.name = "1"
			existing_player.set_multiplayer_authority(1)
			existing_player.set_process_input(false)
			_set_player_team(existing_player, 1)
		else:
			add_player(1)

	add_player(multiplayer.get_unique_id())

func _find_existing_player() -> CharacterBody2D:
	for child in get_children():
		if child is CharacterBody2D and child.has_method("ready_new_player"):
			return child
	return null

func add_player(id: int) -> void:
	if has_node(str(id)):
		return

	var player: CharacterBody2D = PLAYER_CHARACTER.instantiate()
	player.name = str(id)

	if player.name.is_valid_int():
		player.set_multiplayer_authority(int(player.name))

	var team_id := 1 if id == 1 else 2
	_set_player_team(player, team_id)

	add_child(player, true)

func _set_player_team(player: CharacterBody2D, team_id: int) -> void:
	if player == null:
		return

	if multiplayer_component_path == NodePath():
		push_warning("MultiplayerManager: multiplayer_component_path is not set.")
		return

	var mp := player.get_node_or_null(multiplayer_component_path) as MultiplayerComponent
	if mp == null:
		push_warning("Player %s missing MultiplayerComponent at path %s"
			% [player.name, multiplayer_component_path])
		return

	if mp.hitbox_component == null:
		push_warning("Player %s MultiplayerComponent.hitbox_component is null"
			% player.name)
		return

	mp.hitbox_component.team = team_id

@rpc("reliable", "any_peer", "call_local")
func apply_hit_to_player(target_id: int, direction: Vector2, damage: float) -> void:
	if not multiplayer.is_server():
		return

	var target := get_node_or_null(str(target_id))
	if target and target.has_method("take_hit"):
		target.call("take_hit", direction, damage)

func _on_HostButton_pressed() -> void:
	host_game()

func _on_JoinButton_pressed() -> void:
	var ip: String = String($CanvasLayer/IPInput.text)
	join_game(ip)
