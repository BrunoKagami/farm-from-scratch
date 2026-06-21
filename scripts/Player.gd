extends CharacterBody2D

const SPEED := GameData.PLAYER_SPEED
# Sempre convergimos suavemente pro que o servidor diz — só teleporta de
# vez (sem suavizar) se a divergência for grande o bastante pra ser lag
# real (perda de pacote, spike de rede), não um resíduo pequeno e normal.
const SNAP_THRESHOLD := 32.0
const RECONCILE_LERP  := 0.3

var selected_crop: String = "lumifruit"
var _last_dir := "down"
var _suppress_correction_until_msec := 0

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Jogadores nunca colidiam entre si antes (PlayerRemote era só visual,
	# sem física). Os corpos autoritativos no servidor agora são CharacterBody2D
	# reais, então têm que ficar numa camada separada da dos outros jogadores,
	# senão colidem entre si e a simulação do servidor diverge da previsão do
	# cliente (que nunca trata outro jogador como obstáculo).
	collision_layer = 2
	collision_mask = 1

func _physics_process(_delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	# Previsão local: move imediatamente para resposta instantânea ao input.
	# Quem decide a posição "oficial" de todo mundo é sempre o servidor —
	# isto aqui é só o palpite local até a correção chegar.
	velocity = direction * SPEED
	move_and_slide()
	_update_anim(direction)

	var world_grid := get_node_or_null("/root/World")
	if world_grid and world_grid.has_method("report_movement"):
		world_grid.report_movement(direction, global_position, velocity)

# Chamado pelo servidor (via WorldGrid) quando a posição autoritativa diverge
# da nossa previsão local.
func server_correct(server_pos: Vector2, _server_vel: Vector2) -> void:
	if multiplayer.is_server():
		return
	if Time.get_ticks_msec() < _suppress_correction_until_msec:
		return
	if global_position.distance_to(server_pos) > SNAP_THRESHOLD:
		global_position = server_pos
	else:
		global_position = global_position.lerp(server_pos, RECONCILE_LERP)

# Logo após reconectar, o corpo novo do servidor nasce no spawn padrão até
# a mensagem _resume_at chegar — ignora correções por um instante pra não
# saltar pro spawn e voltar.
func suppress_correction(seconds: float) -> void:
	_suppress_correction_until_msec = Time.get_ticks_msec() + int(seconds * 1000)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("next_crop"):
		_cycle_crop()

func _try_interact() -> void:
	if _near_shop():
		_open_shop()
		return

	var grid_pos := Vector2i(
		int(global_position.x / GameData.TILE_SIZE),
		int(global_position.y / GameData.TILE_SIZE)
	)
	var world_grid := get_node_or_null("/root/World")
	if world_grid == null:
		return
	var tile: Node2D = world_grid.get_tile(grid_pos)
	if tile == null:
		_hud_msg("Fora da roça")
		return

	var s: int = tile.get("state")
	var my_id := multiplayer.get_unique_id()
	var call_direct := multiplayer.multiplayer_peer is OfflineMultiplayerPeer \
					   or multiplayer.is_server()

	if s == 0:
		var seed_name: String = selected_crop + "_seed"
		if not Inventory.remove(seed_name):
			_hud_msg("Sem semente de %s!" % selected_crop)
			return
		var hud := get_node_or_null("/root/World/HUD")
		if hud and hud.has_method("refresh_inv"):
			hud.refresh_inv()
		_hud_msg("Plantando %s..." % selected_crop)
		if call_direct:
			world_grid.server_plant(grid_pos, selected_crop, my_id)
		else:
			world_grid.rpc_id(1, "server_plant", grid_pos, selected_crop, my_id)

	elif s == 1:
		_hud_msg("Aguardando crescer...")

	elif s == 2:
		_hud_msg("Colhendo!")
		if call_direct:
			world_grid.server_harvest(grid_pos, my_id)
		else:
			world_grid.rpc_id(1, "server_harvest", grid_pos, my_id)

func _hud_msg(text: String) -> void:
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("show_msg"):
		hud.show_msg(text)

func _update_anim(dir: Vector2) -> void:
	if _anim == null:
		return
	if dir == Vector2.ZERO:
		_anim.play("idle_" + _last_dir)
		return
	if abs(dir.x) >= abs(dir.y):
		_last_dir = "right" if dir.x > 0 else "left"
	else:
		_last_dir = "down" if dir.y > 0 else "up"
	_anim.play("walk_" + _last_dir)

func _cycle_crop() -> void:
	var crops := ["lumifruit", "voidroot", "starbloom"]
	var idx := crops.find(selected_crop)
	selected_crop = crops[(idx + 1) % crops.size()]
	var hud := get_node_or_null("/root/World/HUD")
	if hud and hud.has_method("refresh_crop"):
		hud.refresh_crop(selected_crop)

func _near_shop() -> bool:
	var shop := get_node_or_null("/root/World/Shop")
	if shop == null:
		return false
	return global_position.distance_to(shop.global_position) < 96.0

func _open_shop() -> void:
	var hud := get_node_or_null("/root/World/HUD")
	if hud == null:
		return
	var panel := hud.get_node_or_null("ShopPanel")
	if panel:
		panel.visible = not panel.visible
