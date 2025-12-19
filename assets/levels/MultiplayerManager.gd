extends Node2D

var peer

const PLAYER1 = preload("res://assets/characters/character_body_2d.tscn")
const PLAYER2 = preload("res://assets/characters/character_body2_2d.tscn")

func _ready():
	print("MultiplayerManager READY:", self)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id):
	print("Peer connected:", id)
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

	# Spawn host’s own player
	add_player(multiplayer.get_unique_id())

func join_game(ip: String, port := 9000):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%s" % [ip, port])

	# Spawn client’s own player only
	add_player(multiplayer.get_unique_id())

func add_player(id: int):
	if has_node(str(id)):
		return
	var player: CharacterBody2D = PLAYER1.instantiate() if id == 1 else PLAYER2.instantiate()
	player.name = str(id)
	add_child(player)


func _on_HostButton_pressed():
	host_game()

func _on_JoinButton_pressed():
	var ip = $CanvasLayer/IPInput.text
	join_game(ip)
