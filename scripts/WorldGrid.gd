extends Node2D

var tile_scene := preload("res://scenes/FarmTile.tscn")
var tiles: Dictionary = {}
var tile_data: Dictionary = {}
var remote_players: Dictionary = {}
var _remote_scene := preload("res://scripts/PlayerRemote.gd")

var trees: Dictionary = {}
var tree_data: Dictionary = {}
var _tree_scene := preload("res://scripts/Tree.gd")

# --- Movimentação server-authoritative ---
# Só populados/usados no servidor. peer_inputs guarda a última direção
# recebida de cada cliente; remote_bodies guarda o corpo físico que o
# servidor simula para representar cada cliente (exceto ele mesmo, que já
# tem o nó $Player local fazendo isso diretamente).
var peer_inputs: Dictionary = {}
var remote_bodies: Dictionary = {}

# --- Economia server-authoritative ---
# Só populado/usado no servidor: dinheiro e inventário reais de cada
# jogador. O cliente nunca é dono dessa verdade — Inventory/GameManager
# locais são só um cache otimista que o servidor corrige quando diverge.
var player_state: Dictionary = {}
var peer_names: Dictionary = {}
const ECONOMY_RESYNC_INTERVAL := 10.0
var _economy_resync_timer := 0.0

func _ready() -> void:
	_build_grid()
	_build_trees()
	if multiplayer.is_server():
		_load_world_state()
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
	register_my_name()
	if nm:
		# Reconexão automática (NetworkManager): ao reconectar, viramos um
		# peer novo do ponto de vista do servidor — jogadores remotos já
		# voltam pelo handshake normal de conexão, mas o estado dos
		# canteiros (tile_data) e nosso registro de nome precisam ser
		# pedidos de novo.
		nm.connected_to_server.connect(_on_reconnected)

func _on_reconnected() -> void:
	if not multiplayer.is_server() and \
	   not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		rpc_id(1, "request_full_state")
		# Reconectar nos dá um peer id novo pro servidor — ele não tem
		# memória de onde estávamos até carregarmos o save pelo nome.
		# Suprime correção por um instante pra não saltar pro spawn
		# enquanto isso (o corpo novo nasce lá até o save carregar).
		var local_player := get_node_or_null("Player")
		if local_player and local_player.has_method("suppress_correction"):
			local_player.suppress_correction(1.0)
		register_my_name()

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

func _build_trees() -> void:
	for i in GameData.TREE_SPAWN_POSITIONS.size():
		var tree := Node2D.new()
		tree.set_script(_tree_scene)
		tree.position = GameData.TREE_SPAWN_POSITIONS[i]
		tree.name = "Tree_%d" % i
		add_child(tree)
		trees[i] = tree
		tree_data[i] = { "chopped": false, "timer": 0.0 }

func get_near_tree(global_pos: Vector2) -> int:
	for tree_id in trees.keys():
		if tree_data[tree_id]["chopped"]:
			continue
		if global_pos.distance_to(trees[tree_id].global_position) < 28.0:
			return tree_id
	return -1

# --- Remote players ---

func _on_player_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_spawn_remote_body(peer_id)
	if peer_id == multiplayer.get_unique_id():
		return
	_spawn_remote_player(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_save_player_state(peer_id)
	if remote_players.has(peer_id):
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
	if remote_bodies.has(peer_id):
		remote_bodies[peer_id].queue_free()
		remote_bodies.erase(peer_id)
	peer_inputs.erase(peer_id)
	player_state.erase(peer_id)
	peer_names.erase(peer_id)

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
	# Mesma camada do $Player local: colide com o mundo, nunca com outro jogador.
	body.collision_layer = 2
	body.collision_mask = 1
	var shape := CollisionShape2D.new()
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
	for tree_id in tree_data.keys():
		if tree_data[tree_id]["chopped"]:
			rpc_id(peer_id, "_apply_tree_client", tree_id, true)

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
		for tree_id in tree_data.keys():
			var trd: Dictionary = tree_data[tree_id]
			if trd["chopped"]:
				trd["timer"] += delta
				if trd["timer"] >= GameData.TREE_REGROW_TIME:
					trd["chopped"] = false
					trd["timer"] = 0.0
					_sync_tree_visual(tree_id)
					_rpc_tree(tree_id)
		# Resync periódico: garante que dinheiro/inventário do cliente nunca
		# fiquem divergentes para sempre por um RPC perdido — de tempo em
		# tempo o servidor reafirma a verdade pra todo mundo, igual já
		# fazemos com o horário do dia. Aproveita o mesmo timer pra salvar
		# em disco — perde no máximo ECONOMY_RESYNC_INTERVAL segundos de
		# progresso se o servidor cair sem o save de desconexão/shutdown.
		_economy_resync_timer += delta
		if _economy_resync_timer >= ECONOMY_RESYNC_INTERVAL:
			_economy_resync_timer = 0.0
			for peer_id in player_state.keys():
				_push_economy_state(peer_id)
				_save_player_state(peer_id)
			_save_world_state()
	else:
		# Interpolação visual local — sem autoridade, só para exibir progresso suavemente
		for pos in tile_data.keys():
			var td: Dictionary = tile_data[pos]
			if td["state"] == 1:
				td["timer"] = min(td["timer"] + delta, td["duration"] - 0.01)
				_sync_tile_visual(pos)
	_update_debug_positions()

# Debug temporário para diagnosticar divergência de posição entre clientes.
func _update_debug_positions() -> void:
	var hud := get_node_or_null("HUD")
	if hud == null or not hud.has_method("update_debug_positions"):
		return
	var lines: Array[String] = []
	if multiplayer.multiplayer_peer:
		lines.append("conn:%s" % _connection_status_name())
	var local_player := get_node_or_null("Player")
	if local_player:
		lines.append("eu(%d): %s" % [multiplayer.get_unique_id(), _fmt(local_player.global_position)])
	for peer_id in remote_players.keys():
		lines.append("p%d: %s" % [peer_id, _fmt(remote_players[peer_id].position)])
	hud.update_debug_positions(" | ".join(lines))

# Diagnóstico temporário: ajuda a confirmar se o WebSocket morre de verdade
# quando o celular bloqueia a tela, ou se só fica suspenso e volta sozinho.
func _connection_status_name() -> String:
	match multiplayer.multiplayer_peer.get_connection_status():
		MultiplayerPeer.CONNECTION_DISCONNECTED: return "DISCONNECTED"
		MultiplayerPeer.CONNECTION_CONNECTING: return "CONNECTING"
		MultiplayerPeer.CONNECTION_CONNECTED: return "CONNECTED"
		_: return "?"

func _fmt(v: Vector2) -> String:
	return "(%d,%d)" % [v.x, v.y]

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

# --- Economia: dinheiro e inventário ---
# Único dono da verdade é o servidor. Cliente só manda intenção
# (plantar, colher, comprar, vender); o servidor valida contra o
# player_state real e empurra o resultado de volta.

# Identidade entre sessões: nome digitado no Lobby. Servidor dedicado
# (sem $Player) não tem ninguém pra registrar.
func register_my_name() -> void:
	if DisplayServer.get_name() == "headless" and multiplayer.is_server():
		return
	var nm := get_node_or_null("/root/NetworkManager")
	var player_name: String = nm.player_name if nm else ""
	if multiplayer.is_server():
		_register_name(player_name)
	else:
		rpc_id(1, "_register_name", player_name)

@rpc("any_peer", "reliable")
func _register_name(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var peer_id := sender if sender != 0 else multiplayer.get_unique_id()
	var clean: String = player_name.strip_edges()
	if clean.is_empty():
		clean = "Jogador%d" % peer_id
	# Impede duas conexões simultâneas com o mesmo nome — sem isso, os dois
	# peers ficam pisando no mesmo save/player_state em paralelo.
	for existing_id in peer_names.keys():
		if existing_id != peer_id and peer_names[existing_id] == clean:
			# Recusa só por RPC — o cliente se desconecta sozinho ao
			# receber, sem corrida entre o servidor fechar o socket e a
			# RPC de fato sair.
			if sender != 0:
				rpc_id(sender, "_name_rejected", clean)
			return
	peer_names[peer_id] = clean
	var saved := SaveManager.load_player(clean)
	if saved.is_empty():
		player_state[peer_id] = {
			"money": 100,
			"inventory": { "lumifruit_seed": 3, "voidroot_seed": 1 },
		}
	else:
		player_state[peer_id] = {
			"money": int(saved.get("money", 100)),
			"inventory": saved.get("inventory", {}),
		}
		if saved.has("pos"):
			var p: Array = saved["pos"]
			_set_player_position(peer_id, Vector2(p[0], p[1]))
	_push_economy_state(peer_id)

@rpc("authority", "reliable")
func _name_rejected(player_name: String) -> void:
	if multiplayer.is_server():
		return
	var nm := get_node_or_null("/root/NetworkManager")
	if nm:
		nm.last_error = "O nome \"%s\" já está em uso em outra sessão." % player_name
		nm.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _set_player_position(peer_id: int, pos: Vector2) -> void:
	if peer_id == multiplayer.get_unique_id():
		var local_player := get_node_or_null("Player")
		if local_player:
			local_player.global_position = pos
	elif remote_bodies.has(peer_id):
		remote_bodies[peer_id].global_position = pos

func _get_player_position(peer_id: int) -> Vector2:
	if peer_id == multiplayer.get_unique_id():
		var local_player := get_node_or_null("Player")
		return local_player.global_position if local_player else GameData.PLAYER_SPAWN
	if remote_bodies.has(peer_id):
		return remote_bodies[peer_id].global_position
	return GameData.PLAYER_SPAWN

func _save_player_state(peer_id: int) -> void:
	if not player_state.has(peer_id) or not peer_names.has(peer_id):
		return
	var st: Dictionary = player_state[peer_id]
	var pos := _get_player_position(peer_id)
	SaveManager.save_player(peer_names[peer_id], {
		"money": st["money"],
		"inventory": st["inventory"],
		"pos": [pos.x, pos.y],
	})

func _load_world_state() -> void:
	var saved := SaveManager.load_world()
	var arr: Array = saved.get("tiles", [])
	for entry in arr:
		var pos := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if not tile_data.has(pos):
			continue
		tile_data[pos] = {
			"state": int(entry.get("state", 0)),
			"crop": entry.get("crop", ""),
			"timer": float(entry.get("timer", 0.0)),
			"duration": float(entry.get("duration", 0.0)),
		}
		_sync_tile_visual(pos)
	var tree_arr: Array = saved.get("trees", [])
	for entry in tree_arr:
		var tree_id: int = int(entry.get("id", -1))
		if not tree_data.has(tree_id):
			continue
		tree_data[tree_id] = { "chopped": true, "timer": float(entry.get("timer", 0.0)) }
		_sync_tree_visual(tree_id)

func _save_world_state() -> void:
	var arr: Array = []
	for pos in tile_data.keys():
		var td: Dictionary = tile_data[pos]
		if td["state"] == 0:
			continue
		arr.append({
			"x": pos.x, "y": pos.y,
			"state": td["state"], "crop": td["crop"],
			"timer": td["timer"], "duration": td["duration"],
		})
	var tree_arr: Array = []
	for tree_id in tree_data.keys():
		var trd: Dictionary = tree_data[tree_id]
		if trd["chopped"]:
			tree_arr.append({ "id": tree_id, "timer": trd["timer"] })
	SaveManager.save_world({ "tiles": arr, "trees": tree_arr })

# Salva tudo antes do servidor encerrar (fechar a janela / Ctrl+C),
# pra não perder progresso entre o último resync periódico e a queda.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and multiplayer.is_server():
		for peer_id in player_state.keys():
			_save_player_state(peer_id)
		_save_world_state()

func _push_economy_state(peer_id: int) -> void:
	var st: Dictionary = player_state.get(peer_id, {})
	if st.is_empty():
		return
	if peer_id == multiplayer.get_unique_id():
		_apply_economy_state(st["money"], st["inventory"])
	else:
		rpc_id(peer_id, "_apply_economy_state", st["money"], st["inventory"])

@rpc("authority", "reliable")
func _apply_economy_state(money: int, inventory: Dictionary) -> void:
	GameManager.set_money_authoritative(money)
	Inventory.set_items_authoritative(inventory)
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("refresh_inv"):
		hud.refresh_inv()

# Confere que quem está pedindo em nome de requester_id é de fato ele —
# sem isso, um cliente poderia gastar/plantar usando o ID de outro jogador.
func _valid_sender(requester_id: int) -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == 0 or sender == requester_id

func request_buy_seed(seed: String) -> void:
	var my_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_server_buy_seed(seed, my_id)
	else:
		rpc_id(1, "_server_buy_seed", seed, my_id)

@rpc("any_peer", "reliable")
func _server_buy_seed(seed: String, requester_id: int) -> void:
	if not multiplayer.is_server() or not _valid_sender(requester_id):
		return
	var st: Dictionary = player_state.get(requester_id, {})
	if st.is_empty():
		return
	var cost: int = GameData.SEED_COSTS.get(seed, -1)
	if cost >= 0 and st["money"] >= cost:
		st["money"] -= cost
		st["inventory"][seed] = st["inventory"].get(seed, 0) + 1
	_push_economy_state(requester_id)

func request_sell_crop(crop: String) -> void:
	var my_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_server_sell_crop(crop, my_id)
	else:
		rpc_id(1, "_server_sell_crop", crop, my_id)

@rpc("any_peer", "reliable")
func _server_sell_crop(crop: String, requester_id: int) -> void:
	if not multiplayer.is_server() or not _valid_sender(requester_id):
		return
	var st: Dictionary = player_state.get(requester_id, {})
	if st.is_empty():
		return
	var price: int = GameData.SELL_PRICES.get(crop, -1)
	if price >= 0 and st["inventory"].get(crop, 0) > 0:
		st["inventory"][crop] -= 1
		if st["inventory"][crop] <= 0:
			st["inventory"].erase(crop)
		st["money"] += price
	_push_economy_state(requester_id)

# --- Plant / Harvest ---

@rpc("any_peer", "reliable")
func server_plant(grid_pos: Vector2i, crop: String, requester_id: int) -> void:
	if not multiplayer.is_server() or not _valid_sender(requester_id):
		return
	var st: Dictionary = player_state.get(requester_id, {})
	var seed_name: String = crop + "_seed"
	var can_plant: bool = not st.is_empty() and tile_data.has(grid_pos) \
		and tile_data[grid_pos]["state"] == 0 \
		and st["inventory"].get(seed_name, 0) > 0
	if not can_plant:
		# Cliente pode ter previsto errado (semente que ele achava ter,
		# tile que outro jogador ocupou primeiro etc). Corrige o estado dele.
		_push_economy_state(requester_id)
		return
	st["inventory"][seed_name] -= 1
	if st["inventory"][seed_name] <= 0:
		st["inventory"].erase(seed_name)
	var td: Dictionary = tile_data[grid_pos]
	td["state"] = 1
	td["crop"] = crop
	td["timer"] = 0.0
	td["duration"] = GameData.CROPS[crop]["grow_time"]
	_sync_tile_visual(grid_pos)
	_rpc_tile(grid_pos)
	_push_economy_state(requester_id)

@rpc("any_peer", "reliable")
func server_harvest(grid_pos: Vector2i, requester_id: int) -> void:
	if not multiplayer.is_server() or not _valid_sender(requester_id):
		return
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
	_sync_tile_visual(grid_pos)
	_rpc_tile(grid_pos)
	var st: Dictionary = player_state.get(requester_id, {})
	if st.is_empty():
		return
	st["inventory"][crop] = st["inventory"].get(crop, 0) + 1
	_push_economy_state(requester_id)

# --- Árvores ---

func request_chop_tree(tree_id: int) -> void:
	var my_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_server_chop_tree(tree_id, my_id)
	else:
		rpc_id(1, "_server_chop_tree", tree_id, my_id)

@rpc("any_peer", "reliable")
func _server_chop_tree(tree_id: int, requester_id: int) -> void:
	if not multiplayer.is_server() or not _valid_sender(requester_id):
		return
	if not tree_data.has(tree_id) or tree_data[tree_id]["chopped"]:
		return
	tree_data[tree_id]["chopped"] = true
	tree_data[tree_id]["timer"] = 0.0
	_sync_tree_visual(tree_id)
	_rpc_tree(tree_id)
	var st: Dictionary = player_state.get(requester_id, {})
	if st.is_empty():
		return
	st["inventory"]["wood"] = st["inventory"].get("wood", 0) + GameData.WOOD_YIELD
	_push_economy_state(requester_id)

func _sync_tree_visual(tree_id: int) -> void:
	if trees.has(tree_id):
		trees[tree_id].apply_state(tree_data[tree_id]["chopped"])

func _rpc_tree(tree_id: int) -> void:
	rpc("_apply_tree_client", tree_id, tree_data[tree_id]["chopped"])

@rpc("authority", "reliable")
func _apply_tree_client(tree_id: int, chopped: bool) -> void:
	if multiplayer.is_server():
		return
	if tree_data.has(tree_id):
		tree_data[tree_id]["chopped"] = chopped
		_sync_tree_visual(tree_id)

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
