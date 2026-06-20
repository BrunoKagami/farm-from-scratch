extends Node2D

var tile_scene := preload("res://scenes/FarmTile.tscn")
var tiles: Dictionary = {}
var tile_data: Dictionary = {}
var remote_players: Dictionary = {}
var _remote_scene := preload("res://scripts/PlayerRemote.gd")

func _ready() -> void:
	_build_grid()
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.player_connected.connect(_on_player_connected)
		nm.player_disconnected.connect(_on_player_disconnected)

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
	if peer_id == multiplayer.get_unique_id():
		return
	_spawn_remote_player(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	if remote_players.has(peer_id):
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)

func _spawn_remote_player(peer_id: int) -> void:
	if remote_players.has(peer_id):
		return
	var node: Node2D = Node2D.new()
	node.set_script(_remote_scene)
	node.name = "RemotePlayer_%d" % peer_id
	node.position = Vector2(288, 280)
	node.set("peer_id", peer_id)
	add_child(node)
	remote_players[peer_id] = node

# --- Grow timer (only on server) ---

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for pos in tile_data.keys():
		var td: Dictionary = tile_data[pos]
		if td["state"] == 1:
			td["timer"] += delta
			if td["timer"] >= td["duration"]:
				td["state"] = 2
				_sync_tile_visual(pos)
				_rpc_tile(pos)

# --- Player position sync ---

func send_player_state(pos: Vector2, vel: Vector2) -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		rpc("_sync_player", multiplayer.get_unique_id(), pos, vel)

@rpc("any_peer", "unreliable")
func _sync_player(peer_id: int, pos: Vector2, vel: Vector2) -> void:
	if remote_players.has(peer_id):
		remote_players[peer_id].update_state(pos, vel)

# --- Plant / Harvest ---

@rpc("any_peer", "reliable")
func server_plant(grid_pos: Vector2i, crop: String, _requester_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not tile_data.has(grid_pos):
		return
	var td: Dictionary = tile_data[grid_pos]
	if td["state"] != 0:
		return
	td["state"] = 1
	td["crop"] = crop
	td["timer"] = 0.0
	td["duration"] = GameData.CROPS[crop]["grow_time"]
	_sync_tile_visual(grid_pos)
	_rpc_tile(grid_pos)

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

# Atualiza o visual do tile localmente (host)
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
	# Apenas clientes executam — host usa _sync_tile_visual diretamente
	if multiplayer.is_server():
		return
	tile_data[grid_pos] = { "state": state, "crop": crop, "timer": 0.0, "duration": float(state == 1) * 999.0 }
	if tiles.has(grid_pos):
		tiles[grid_pos].apply_state(state, crop, progress)
