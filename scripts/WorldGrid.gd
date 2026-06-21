extends Node2D

var tile_scene := preload("res://scenes/FarmTile.tscn")
var tiles: Dictionary = {}
var tile_data: Dictionary = {}
var remote_players: Dictionary = {}
var _remote_scene := preload("res://scripts/PlayerRemote.gd")

# --- Movimentação server-authoritative ---
# Só populados/usados no servidor. peer_inputs guarda a última direção
# recebida de cada cliente; remote_bodies guarda o corpo físico que o
# servidor simula para representar cada cliente (exceto ele mesmo, que já
# tem o nó $Player local fazendo isso diretamente).
var peer_inputs: Dictionary = {}
var remote_bodies: Dictionary = {}

func _ready() -> void:
	_build_grid()
	if DisplayServer.get_name() == "headless":
		var local_player := get_node_or_null("Player")
		if local_player: local_player.queue_free()
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.player_connected.connect(_on_player_connected)
		nm.player_disconnected.connect(_on_player_disconnected)
		for peer_id in nm.players.keys():
			_on_player_connected(peer_id)
	# Cliente pede o estado completo ao servidor agora que o World está pronto
	if not multiplayer.is_server() and \
	   not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		rpc_id(1, "request_full_state")

func _build_grid() -> void:
	var farm := GameData.FARM_RECT
	for y in range(farm.position.y, farm.position.y + farm.size.y):
		for x in range(farm.position.x, farm.position.x + farm.size.x):
			var tile: Node2D = tile_scene.instantiate()
			tile.position = Vector2(x * GameData.TILE_SIZE, y * GameData.TILE_SIZE)
			tile.name = "Tile_%d_%d" % [x, y]
			tile.z_index = -1
			add_child(tile)
			var pos := Vector2i(x, y)
			tiles[pos] = tile
			tile_data[pos] = { "state": 0, "crop": "", "timer": 0.0, "duration": 0.0 }

func get_tile(grid_pos: Vector2i) -> Node2D:
	return tiles.get(grid_pos, null)

# --- Remote players ---

func _on_player_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_spawn_remote_body(peer_id)
	if peer_id == multiplayer.get_unique_id():
		return
	_spawn_remote_player(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	if remote_players.has(peer_id):
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
	if remote_bodies.has(peer_id):
		remote_bodies[peer_id].queue_free()
		remote_bodies.erase(peer_id)
	peer_inputs.erase(peer_id)

func _spawn_remote_player(peer_id: int) -> void:
	if remote_players.has(peer_id):
		return
	var node: Node2D = Node2D.new()
	node.set_script(_remote_scene)
	node.name = "RemotePlayer_%d" % peer_id
	node.position = GameData.PLAYER_SPAWN
	node.set("peer_id", peer_id)
	add_child(node)
	remote_players[peer_id] = node

# O servidor simula fisicamente cada cliente remoto com um corpo próprio
# (a si mesmo ele já simula via $Player diretamente, sem indireção).
func _spawn_remote_body(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id() or remote_bodies.has(peer_id):
		return
	var body := CharacterBody2D.new()
	body.name = "ServerBody_%d" % peer_id
	body.position = GameData.PLAYER_SPAWN
	var shape := CollisionShape2D.new()
	shape.position = Vector2(-13, 0)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	remote_bodies[peer_id] = body

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for peer_id in remote_bodies.keys():
		var body: CharacterBody2D = remote_bodies[peer_id]
		var direction: Vector2 = peer_inputs.get(peer_id, Vector2.ZERO)
		body.velocity = direction * GameData.PLAYER_SPEED
		body.move_and_slide()
		rpc("_apply_authoritative_state", peer_id, body.global_position, body.velocity, Engine.get_physics_frames())

@rpc("any_peer", "reliable")
func request_full_state() -> void:
	if not multiplayer.is_server():
		return
	_send_full_state(multiplayer.get_remote_sender_id())

func _send_full_state(peer_id: int) -> void:
	for pos in tile_data.keys():
		var td: Dictionary = tile_data[pos]
		if td["state"] == 0:
			continue
		var progress: float = float(td["timer"]) / max(float(td["duration"]), 1.0)
		rpc_id(peer_id, "_apply_tile_client", pos, td["state"], td["crop"], progress)

# --- Grow timer (only on server) ---

func _process(delta: float) -> void:
	if multiplayer.is_server():
		for pos in tile_data.keys():
			var td: Dictionary = tile_data[pos]
			if td["state"] == 1:
				td["timer"] += delta
				if td["timer"] >= td["duration"]:
					td["state"] = 2
					_sync_tile_visual(pos)
					_rpc_tile(pos)
				else:
					_sync_tile_visual(pos)
	else:
		# Interpolação visual local — sem autoridade, só para exibir progresso suavemente
		for pos in tile_data.keys():
			var td: Dictionary = tile_data[pos]
			if td["state"] == 1:
				td["timer"] = min(td["timer"] + delta, td["duration"] - 0.01)
				_sync_tile_visual(pos)

# --- Movimentação server-authoritative ---
# Cliente nunca declara sua própria posição final: ou ele É o servidor (e
# então já É autoridade), ou ele só manda a intenção (direção) e aceita o
# que o servidor decidir.

func report_movement(direction: Vector2, pos: Vector2, vel: Vector2) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if multiplayer.is_server():
		rpc("_apply_authoritative_state", multiplayer.get_unique_id(), pos, vel, Engine.get_physics_frames())
	else:
		rpc_id(1, "_receive_input", direction)

@rpc("any_peer", "unreliable")
func _receive_input(direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		return
	peer_inputs[sender] = direction.limit_length(1.0)

# Canal "unreliable" não garante ordem de entrega — sem isso, um pacote
# antigo chegando depois de um mais novo (comum em rede instável/celular)
# sobrescreveria a posição com dados desatualizados. _last_tick descarta
# qualquer atualização mais antiga que a última já aplicada por peer.
var _last_tick: Dictionary = {}

@rpc("authority", "unreliable")
func _apply_authoritative_state(peer_id: int, pos: Vector2, vel: Vector2, tick: int) -> void:
	if multiplayer.is_server():
		return
	if tick <= _last_tick.get(peer_id, -1):
		return
	_last_tick[peer_id] = tick
	if peer_id == multiplayer.get_unique_id():
		var local_player := get_node_or_null("Player")
		if local_player and local_player.has_method("server_correct"):
			local_player.server_correct(pos, vel)
	elif remote_players.has(peer_id):
		remote_players[peer_id].update_state(pos, vel)

# --- Plant / Harvest ---

@rpc("any_peer", "reliable")
func server_plant(grid_pos: Vector2i, crop: String, requester_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not tile_data.has(grid_pos):
		# Fix 1: reembolsa semente se tile inválido
		_refund_or_call(requester_id, crop + "_seed")
		return
	var td: Dictionary = tile_data[grid_pos]
	if td["state"] != 0:
		# Fix 1: reembolsa semente se tile já ocupado (race condition)
		_refund_or_call(requester_id, crop + "_seed")
		return
	td["state"] = 1
	td["crop"] = crop
	td["timer"] = 0.0
	td["duration"] = GameData.CROPS[crop]["grow_time"]
	_sync_tile_visual(grid_pos)
	_rpc_tile(grid_pos)

# Fix 1: devolve a semente ao cliente que plantou se o servidor rejeitar
func _refund_or_call(requester_id: int, seed: String) -> void:
	if requester_id == multiplayer.get_unique_id():
		_refund_seed(seed)
	else:
		rpc_id(requester_id, "_refund_seed", seed)

@rpc("authority", "reliable")
func _refund_seed(seed: String) -> void:
	Inventory.add(seed)
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("refresh_inv"):
		hud.refresh_inv()

@rpc("any_peer", "reliable")
func server_harvest(grid_pos: Vector2i, requester_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not tile_data.has(grid_pos):
		return
	var td: Dictionary = tile_data[grid_pos]
	if td["state"] != 2:
		return
	var crop: String = td["crop"]
	var price: int = GameData.CROPS[crop]["sell_price"]
	td["state"] = 0
	td["crop"] = ""
	td["timer"] = 0.0
	td["duration"] = 0.0
	_sync_tile_visual(grid_pos)
	_rpc_tile(grid_pos)
	if requester_id == multiplayer.get_unique_id():
		_credit_harvest(crop, price)
	else:
		rpc_id(requester_id, "_credit_harvest", crop, price)

@rpc("authority", "reliable")
func _credit_harvest(crop: String, _price: int) -> void:
	Inventory.add(crop)
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("refresh_inv"):
		hud.refresh_inv()

func _sync_tile_visual(grid_pos: Vector2i) -> void:
	var td: Dictionary = tile_data[grid_pos]
	var progress: float = float(td["timer"]) / max(float(td["duration"]), 1.0)
	if tiles.has(grid_pos):
		tiles[grid_pos].apply_state(td["state"], td["crop"], progress)

func _rpc_tile(grid_pos: Vector2i) -> void:
	var td: Dictionary = tile_data[grid_pos]
	var progress: float = float(td["timer"]) / max(float(td["duration"]), 1.0)
	rpc("_apply_tile_client", grid_pos, td["state"], td["crop"], progress)

@rpc("authority", "reliable")
func _apply_tile_client(grid_pos: Vector2i, state: int, crop: String, progress: float) -> void:
	if multiplayer.is_server():
		return
	var duration: float = GameData.CROPS[crop]["grow_time"] if crop != "" else 1.0
	var timer: float = progress * duration
	tile_data[grid_pos] = { "state": state, "crop": crop, "timer": timer, "duration": duration }
	if tiles.has(grid_pos):
		tiles[grid_pos].apply_state(state, crop, progress)
