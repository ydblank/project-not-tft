extends Node2D

var peer := ENetMultiplayerPeer.new()

func host_game(port := 9000):
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	print("Hosting on port %s" % port)

func join_game(ip: String, port := 9000):
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%s" % [ip, port])

func _on_HostButton_pressed():
	host_game()

func _on_JoinButton_pressed():
	var ip = $CanvasLayer/IPInput.text
	join_game(ip)
