extends Node

const PORT := 7777
const MAX_PLAYERS := 4

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed
signal connected_to_server
signal reconnecting(attempt: int)
signal reconnect_failed
signal name_accepted
signal name_rejected(reason: String)

var players: Dictionary = {}
var is_dedicated := false
var player_name := ""
# Mensagem pra Lobby mostrar na próxima vez que _ready() rodar (ex: nome
# já em uso em outra sessão). Lobby limpa depois de exibir.
var last_error := ""

# Identidade entre sessões: reservada AQUI (antes de entrar no World),
# pra recusar nome duplicado sem nunca deixar a segunda sessão sequer ver
# o jogo. Só usado/populado no servidor.
var peer_names: Dictionary = {}

# Reconexão automática: navegador mobile suspende a aba quando a tela
# bloqueia, e o WebSocket morre de verdade nesse meio tempo (confirmado via
# overlay de debug — get_connection_status() volta DISCONNECTED e o ID some).
# Sem isso, o jogador fica olhando uma tela "viva" mas sem rede pra sempre.
const RECONNECT_DELAY := 3.0
const MAX_RECONNECT_ATTEMPTS := 10
var last_address := ""
var _was_connected := false
var _reconnecting := false
var _reconnect_attempts := 0
var _reconnect_timer := 0.0

func _ready() -> void:
	is_dedicated = DisplayServer.get_name() == "headless"
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer and \
	   not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.poll()
		_watch_connection_status()
	if _reconnecting:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_attempt_reconnect()

func _watch_connection_status() -> void:
	# Só clientes reconectam — o host não "perde conexão consigo mesmo".
	if multiplayer.is_server() or last_address.is_empty():
		return
	var status := multiplayer.multiplayer_peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_CONNECTED:
		_was_connected = true
	elif status == MultiplayerPeer.CONNECTION_DISCONNECTED and _was_connected and not _reconnecting:
		_was_connected = false
		_reconnecting = true
		_reconnect_attempts = 0
		_reconnect_timer = 0.5

func _attempt_reconnect() -> void:
	_reconnect_attempts += 1
	if _reconnect_attempts > MAX_RECONNECT_ATTEMPTS:
		_reconnecting = false
		emit_signal("reconnect_failed")
		return
	emit_signal("reconnecting", _reconnect_attempts)
	join(last_address)
	_reconnect_timer = RECONNECT_DELAY

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
	last_address = address
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
	last_address = ""
	_was_connected = false
	_reconnecting = false

func is_host() -> bool:
	return multiplayer.is_server()

@rpc("authority", "reliable")
func _announce_player(existing_id: int) -> void:
	if not players.has(existing_id):
		players[existing_id] = { "id": existing_id }
	emit_signal("player_connected", existing_id)

func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	peer_names.erase(peer_id)
	emit_signal("player_disconnected", peer_id)

# Reserva o nome ANTES de entrar no World — se já tiver alguém conectado
# com esse nome, a conexão é recusada e desfeita aqui mesmo, sem nunca
# deixar a segunda sessão renderizar o jogo.
func register_name(requested_name: String) -> void:
	var clean := requested_name.strip_edges()
	if clean.is_empty():
		clean = "Jogador%d" % (randi() % 10000)
	player_name = clean
	if multiplayer.is_server():
		_claim_name(clean)
	else:
		rpc_id(1, "_claim_name", clean)

@rpc("any_peer", "reliable")
func _claim_name(requested_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var peer_id := sender if sender != 0 else multiplayer.get_unique_id()
	for existing_id in peer_names.keys():
		if existing_id != peer_id and peer_names[existing_id] == requested_name:
			# Recusa só por RPC — quem desconecta é o próprio cliente ao
			# receber _claim_rejected. Se o servidor derrubasse a conexão
			# aqui, corria o risco de fechar o socket antes da RPC sair.
			if sender != 0:
				rpc_id(sender, "_claim_rejected", requested_name)
			return
	peer_names[peer_id] = requested_name
	# Só agora o jogador "existe" pro resto do jogo — antes da aceitação do
	# nome, ninguém deve ver avatar nenhum aparecer (evita o fantasma de
	# uma sessão que acaba sendo recusada por nome duplicado).
	players[peer_id] = { "id": peer_id }
	emit_signal("player_connected", peer_id)
	for existing_id in players.keys():
		if existing_id != peer_id:
			rpc_id(peer_id, "_announce_player", existing_id)
	if sender != 0:
		rpc_id(sender, "_claim_accepted")
	else:
		emit_signal("name_accepted")

@rpc("authority", "reliable")
func _claim_accepted() -> void:
	emit_signal("name_accepted")

@rpc("authority", "reliable")
func _claim_rejected(requested_name: String) -> void:
	last_error = "O nome \"%s\" já está em uso em outra sessão." % requested_name
	disconnect_from_game()
	emit_signal("name_rejected", requested_name)

func _on_connected_to_server() -> void:
	_reconnecting = false
	_reconnect_attempts = 0
	_was_connected = true
	emit_signal("connected_to_server")

func _on_connection_failed() -> void:
	emit_signal("connection_failed")
