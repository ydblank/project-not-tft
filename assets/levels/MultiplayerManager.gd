extends Node2D

var peer

const PLAYER_CHARACTER = preload("res://assets/characters/player_character.tscn")

func _ready():
	print("MultiplayerManager READY:", self)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id):
	print("Peer connected:", id)
	# Only the host spawns remote players
	if multiplayer.is_server():
		add_player(id)

func _on_peer_disconnected(id):
	print("Peer disconnected:", id)
	if has_node(str(id)):
		get_node(str(id)).queue_free()

func host_game(port := 9000):
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	print("Hosting on port %s" % port)

	# Don't spawn - use the existing character in the scene as the host's player
	# Set its name to the host's unique ID if it doesn't have one
	var existing_player = _find_existing_player()
	if existing_player:
		if not existing_player.name.is_valid_int():
			existing_player.name = str(multiplayer.get_unique_id())
			if existing_player.name.is_valid_int():
				existing_player.set_multiplayer_authority(int(existing_player.name))
		# Host is always team 1
		if existing_player.has_method("set") or ("team" in existing_player):
			existing_player.team = 1

func join_game(ip: String, port := 9000):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%s" % [ip, port])
	
	# Wait for connection to establish before spawning
	await multiplayer.connected_to_server
	# Ensure the host player (peer 1) exists locally.
	# Prefer reusing the pre-placed scene character (so its class overrides match),
	# otherwise instantiate a new one.
	if not has_node("1"):
		var existing_player := _find_existing_player()
		if existing_player and not existing_player.name.is_valid_int():
			existing_player.name = "1"
			existing_player.set_multiplayer_authority(1)
			# This node was created before multiplayer was active; ensure it won't process local input.
			existing_player.set_process_input(false)
			# Host is always team 1
			if existing_player.has_method("set") or ("team" in existing_player):
				existing_player.team = 1
		else:
			add_player(1)
	# Spawn client's own player only after connection is established
	add_player(multiplayer.get_unique_id())

func _find_existing_player() -> CharacterBody2D:
	# Find the existing player character in the scene
	for child in get_children():
		if child is CharacterBody2D and child.has_method("ready_new_player"):
			return child
	return null

func add_player(id: int):
	if has_node(str(id)):
		return
	var player: CharacterBody2D = PLAYER_CHARACTER.instantiate()
	player.name = str(id)
	# Simple team assignment: host(1)=team1, everyone else=team2
	if player.has_method("set") or ("team" in player):
		player.team = 1 if id == 1 else 2
	add_child(player, true)

@rpc("reliable", "any_peer", "call_local")
func apply_hit_to_player(target_id: int, direction: Vector2, damage: float) -> void:
	# Only server processes this
	print(
		"[RPC] apply_hit_to_player on=", name,
		" is_server=", multiplayer.is_server(),
		" from_sender=", multiplayer.get_remote_sender_id(),
		" target_id=", target_id,
		" dmg=", damage
	)
	if not multiplayer.is_server():
		return
	
	var target = get_node_or_null(str(target_id))
	print("[RPC] manager target_lookup=", str(target_id), " found=", target != null)
	if target and target.has_method("take_hit"):
		target.take_hit(direction, damage)


func _on_HostButton_pressed():
	host_game()

func _on_JoinButton_pressed():
	var ip = $CanvasLayer/IPInput.text
	join_game(ip)
