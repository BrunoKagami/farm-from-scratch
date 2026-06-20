extends Node2D

var tile_scene := preload("res://scenes/FarmTile.tscn")
var tiles: Dictionary = {}
var tile_data: Dictionary = {}
var player_positions: Dictionary = {}

func _ready() -> void:
	_build_grid()
	_setup_input_map()

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

func get_tile(grid_pos: Vector2i) -> Node:
	return tiles.get(grid_pos, null)

func _setup_input_map() -> void:
	_add_action_key("interact", KEY_E)
	_add_action_key("next_crop", KEY_TAB)

func _add_action_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.keycode = key
		InputMap.action_add_event(action, ev)

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	for pos in tile_data.keys():
		var td: Dictionary = tile_data[pos]
		if td["state"] == 1:
			td["timer"] += delta
			if td["timer"] >= td["duration"]:
				td["state"] = 2
				_broadcast_tile(pos)

func send_player_state(pos: Vector2, vel: Vector2) -> void:
	var my_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		player_positions[my_id] = pos
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		rpc("_sync_player", my_id, pos, vel)

@rpc("any_peer", "unreliable")
func _sync_player(peer_id: int, pos: Vector2, _vel: Vector2) -> void:
	player_positions[peer_id] = pos

@rpc("authority", "reliable")
func request_plant(grid_pos: Vector2i, crop: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not tile_data.has(grid_pos):
		return
	var td: Dictionary = tile_data[grid_pos]
	if td["state"] != 0:
		return
	var cost: int = GameData.CROPS[crop]["seed_cost"]
	# Host validates money via GameManager (simplified: trust for now)
	td["state"] = 1
	td["crop"] = crop
	td["timer"] = 0.0
	td["duration"] = GameData.CROPS[crop]["grow_time"]
	_broadcast_tile(grid_pos)

@rpc("authority", "reliable")
func request_harvest(grid_pos: Vector2i) -> void:
	if not tile_data.has(grid_pos):
		return
	var td: Dictionary = tile_data[grid_pos]
	if td["state"] != 2:
		return
	var crop: String = td["crop"]
	td["state"] = 0
	td["crop"] = ""
	td["timer"] = 0.0
	td["duration"] = 0.0
	_broadcast_tile(grid_pos)

func _broadcast_tile(grid_pos: Vector2i) -> void:
	var td: Dictionary = tile_data[grid_pos]
	rpc("_apply_tile", grid_pos, td["state"], td["crop"],
	    td["timer"] / max(td["duration"], 1.0))

@rpc("authority", "reliable")
func _apply_tile(grid_pos: Vector2i, state: int, crop: String, progress: float) -> void:
	tile_data[grid_pos] = { "state": state, "crop": crop,
	                        "timer": 0.0, "duration": 0.0 }
	if tiles.has(grid_pos):
		tiles[grid_pos].apply_state(state, crop, progress)
