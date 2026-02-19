extends Node2D

var peer: ENetMultiplayerPeer

const PLAYER_CHARACTER: PackedScene = preload("res://assets/characters/player_character.tscn")

@export var multiplayer_ui_path: NodePath = ^"CanvasLayer" # set to the UI root you want hidden (buttons/labels)
@export var host_team: int = 1
@export var client_team: int = 2

func _ready() -> void:
	print("MultiplayerManager READY:", self)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _set_multiplayer_ui_visible(visible: bool) -> void:
	var ui := get_node_or_null(multiplayer_ui_path)
	if ui == null:
		return

	# Hide/show the whole container
	if "visible" in ui:
		ui.visible = visible

	# Also stop UI from consuming input while hidden
	if ui is CanvasItem:
		(ui as CanvasItem).set_process_input(visible)
		(ui as CanvasItem).set_process_unhandled_input(visible)

func _get_hitbox(player: Node) -> HitboxComponent:
	# First try direct children (fast)
	for c in player.get_children():
		if c is HitboxComponent:
			return c as HitboxComponent

	# Fallback: recursive search (in case Hitbox is nested)
	for child in player.get_children():
		if child is Node:
			var found := _get_hitbox(child)
			if found:
				return found

	return null

func _set_player_team(player: Node, team_value: int) -> void:
	var hitbox := _get_hitbox(player)
	if hitbox:
		hitbox.set_team(team_value) # or: hitbox.team = team_value
	else:
		push_warning("No HitboxComponent found under player %s; cannot set team." % player.name)

func _find_existing_player() -> CharacterBody2D:
	# Find an already-placed player character in the scene
	for child in get_children():
		if child is CharacterBody2D and child.has_method("ready_new_player"):
			return child as CharacterBody2D
	return null

func _on_peer_connected(id: int) -> void:
	print("Peer connected:", id)
	# Only the host spawns remote players (clients will receive replication)
	if multiplayer.is_server():
		add_player(id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected:", id)
	var n := get_node_or_null(str(id))
	if n:
		n.queue_free()

func _on_connected_to_server() -> void:
	print("Connected to server.")
	_set_multiplayer_ui_visible(false)

func _on_connection_failed() -> void:
	print("Connection failed.")
	_set_multiplayer_ui_visible(true)

func _on_server_disconnected() -> void:
	print("Disconnected from server.")
	_set_multiplayer_ui_visible(true)

func host_game(port := 9000) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("Failed to host on port %s (err=%s)" % [port, err])
		_set_multiplayer_ui_visible(true)
		return

	multiplayer.multiplayer_peer = peer
	print("Hosting on port %s" % port)

	# Reuse the existing character in the scene as the host player
	var existing_player := _find_existing_player()
	if existing_player:
		# Name it with the host unique id so it matches network node naming scheme
		if not existing_player.name.is_valid_int():
			existing_player.name = str(multiplayer.get_unique_id())

		# Make host authoritative over their own character
		if existing_player.name.is_valid_int():
			existing_player.set_multiplayer_authority(int(existing_player.name))

		# Host is always team 1
		_set_player_team(existing_player, host_team)
	else:
		# If you *don’t* have a pre-placed host player, uncomment:
		# add_player(multiplayer.get_unique_id())
		push_warning("No pre-placed host player found in scene. Host will have no character unless you spawn one.")

func join_game(ip: String, port := 9000) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to connect to %s:%s (err=%s)" % [ip, port, err])
		_set_multiplayer_ui_visible(true)
		return

	multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%s" % [ip, port])

	# Wait for connection to establish before doing local setup/spawning
	await multiplayer.connected_to_server

	# Ensure the host player (peer id 1) exists locally.
	# Prefer reusing the pre-placed scene character (so class overrides match),
	# otherwise instantiate a new one.
	if not has_node("1"):
		var existing_player := _find_existing_player()
		if existing_player and not existing_player.name.is_valid_int():
			existing_player.name = "1"
			existing_player.set_multiplayer_authority(1)

			# This node was created before multiplayer was active; ensure it won't process local input.
			existing_player.set_process_input(false)

			_set_player_team(existing_player, host_team)
		else:
			add_player(1)

	# Spawn client's own player after connection is established
	add_player(multiplayer.get_unique_id())

func add_player(id: int) -> void:
	if has_node(str(id)):
		return

	var player := PLAYER_CHARACTER.instantiate() as CharacterBody2D
	player.name = str(id)

	# Authority: the peer with matching id controls this player
	player.set_multiplayer_authority(id)

	# Simple team assignment: host(1)=team1, everyone else=team2
	_set_player_team(player, host_team if id == 1 else client_team)

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

	var target := get_node_or_null(str(target_id))
	print("[RPC] manager target_lookup=", str(target_id), " found=", target != null)

	if target and target.has_method("take_hit"):
		target.take_hit(direction, damage)

func _on_HostButton_pressed() -> void:
	_set_multiplayer_ui_visible(false)
	host_game()

func _on_JoinButton_pressed() -> void:
	_set_multiplayer_ui_visible(false)
	var ip: String = $CanvasLayer/IPInput.text
	join_game(ip)
