extends Node

const PORT := 7777
const MAX_PLAYERS := 4

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed
signal connected_to_server

var players: Dictionary = {}
var is_dedicated := false

func _ready() -> void:
	is_dedicated = DisplayServer.get_name() == "headless"
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer and \
	   not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.poll()

func host() -> void:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		push_error("Failed to create server: %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	if not is_dedicated:
		players[1] = { "id": 1 }

func join(address: String) -> void:
	var url := _build_url(address)
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		push_error("Failed to connect to %s: %d" % [url, err])
		return
	multiplayer.multiplayer_peer = peer

func _build_url(input: String) -> String:
	# Normaliza: remove trailing slash e converte http(s):// para ws(s)://
	var s := input.strip_edges().trim_suffix("/")
	if s.begins_with("https://"):
		s = "wss://" + s.substr(8)
	elif s.begins_with("http://"):
		s = "ws://" + s.substr(7)
	if s.begins_with("ws://") or s.begins_with("wss://"):
		return s
	var on_web := OS.has_feature("web")
	if s == "localhost" or s.is_valid_ip_address():
		var scheme := "wss" if on_web else "ws"
		return "%s://%s:%d" % [scheme, s, PORT]
	return "wss://%s" % s

func disconnect_from_game() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()

func is_host() -> bool:
	return multiplayer.is_server()

func _on_peer_connected(peer_id: int) -> void:
	# O motor sempre dispara este sinal para o peer 1 (host) no lado do
	# cliente, mesmo quando o host é um servidor dedicado sem avatar.
	# Quem decide se o host vira avatar visível é o RPC _announce_player.
	if peer_id == 1 and not multiplayer.is_server():
		return
	players[peer_id] = { "id": peer_id }
	emit_signal("player_connected", peer_id)
	if multiplayer.is_server():
		for existing_id in players.keys():
			if existing_id != peer_id:
				rpc_id(peer_id, "_announce_player", existing_id)

@rpc("authority", "reliable")
func _announce_player(existing_id: int) -> void:
	if not players.has(existing_id):
		players[existing_id] = { "id": existing_id }
	emit_signal("player_connected", existing_id)

func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	emit_signal("player_disconnected", peer_id)

func _on_connected_to_server() -> void:
	emit_signal("connected_to_server")

func _on_connection_failed() -> void:
	emit_signal("connection_failed")
